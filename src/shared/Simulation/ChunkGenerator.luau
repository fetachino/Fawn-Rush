--!nonstrict
-- Deterministic chunk generation.
--
-- A chunk is CHUNK_ROWS rows: median rows (safe standing) and corridors (1-3 traffic lanes sharing
-- one direction). Every chunk starts and ends on a median, so the validator's goal row is always
-- standable and a player always has somewhere to think.
--
-- Phase 3 adds three hazard families beyond plain traffic:
--   * rail corridors — a single train lane, long headway, always crossable between trains
--   * static closures — barriers on road rows, never enough to seal the 17-column playfield
--   * wildlife — a creature crossing laterally, position a closed-form function of time
--
-- generateValidated() is the only entry point gameplay uses. It retries with progressively gentler
-- parameters and finally falls back to a template that cannot fail.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local HazardConfig = require(Shared.Config.HazardConfig)
local ChunkFormat = require(Shared.Simulation.ChunkFormat)
local Rng = require(Shared.Util.Rng)
local SafePathValidator = require(Shared.Simulation.SafePathValidator)

local ChunkGenerator = {}

local TILE = GameConfig.TILE

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function pickWeighted(rng, weights): number
	local total = 0
	for i = 1, #weights do
		total += weights[i]
	end
	if total <= 0 then
		return 1
	end

	local roll = rng:float() * total
	local accumulator = 0
	for i = 1, #weights do
		accumulator += weights[i]
		if roll <= accumulator then
			return i
		end
	end
	return #weights
end

local function pickVehicleType(rng, world): string
	local total = 0
	for _, entry in ipairs(world.vehicleWeights) do
		total += entry.weight
	end

	local roll = rng:float() * total
	local accumulator = 0
	for _, entry in ipairs(world.vehicleWeights) do
		accumulator += entry.weight
		if roll <= accumulator then
			return entry.id
		end
	end

	return world.vehicleWeights[1].id
end

-- Fairness floor from docs/04 §4.3. A lane's headway may never fall below this, whatever the
-- difficulty curve asks for.
local function minHeadwayFor(speed: number, lengthStuds: number): number
	return (lengthStuds + TILE * 1.6 + GameConfig.GAP_SAFETY) / speed + GameConfig.REACTION
end

local function makeLane(rng, world, difficulty, row, dir, phase, headwayBoost)
	local vehicleType = pickVehicleType(rng, world)
	local def = GameConfig.VEHICLES[vehicleType]

	local baseSpeed = lerp(world.vMin, world.vMax, difficulty ^ world.speedRamp)
	local jitter = 1 + (rng:float() * 2 - 1) * 0.08
	local speed = baseSpeed * def.speedMul * jitter

	local lengthStuds = def.lengthTiles * TILE
	local floor = minHeadwayFor(speed, lengthStuds)

	local scale = lerp(world.headwayScaleStart, world.headwayScaleEnd, difficulty) * headwayBoost
	local headway = math.max(floor * scale * (0.92 + rng:float() * 0.24), floor * 1.02)

	return {
		type = "vehicle",
		row = row,
		dir = dir,
		speed = speed,
		headway = headway,
		phase = phase % headway,
		vehicleType = vehicleType,
		spanX = GameConfig.LANE_SPAN_X,
		overhang = GameConfig.VEHICLE_OVERHANG,
	}
end

-- A train lane. The overhang carries half the train so it spawns fully off-screen rather than
-- popping into view, and the headway floor guarantees a crossing window between trains.
local function makeRailLane(rng, world, difficulty, row, dir)
	local def = GameConfig.VEHICLES.train
	local baseSpeed = lerp(world.vMin, world.vMax, difficulty ^ world.speedRamp)
	local speed = baseSpeed * def.speedMul
	local lengthStuds = def.lengthTiles * TILE
	local floor = minHeadwayFor(speed, lengthStuds)
	local headway = math.max(HazardConfig.rail.headwayMin, floor * HazardConfig.rail.headwayScale)

	return {
		type = "rail",
		row = row,
		dir = dir,
		speed = speed,
		headway = headway,
		phase = rng:float() * headway,
		vehicleType = "train",
		spanX = GameConfig.LANE_SPAN_X,
		overhang = GameConfig.VEHICLE_OVERHANG + lengthStuds * 0.5,
	}
end

local function hazardRoll(rng, difficulty: number, cfg, gate: number): boolean
	if difficulty < gate then
		return false
	end
	local chance = lerp(cfg.chanceStart, cfg.chanceEnd, difficulty)
	return rng:chance(chance)
end

local function makeWildlife(rng, row: number, worldId: string)
	local wildlife = HazardConfig.wildlife
	local species = wildlife.kinds[worldId] or "squirrel"

	-- Speed first, cycle second. Deriving the period keeps `speedMin`/`speedMax` authoritative
	-- instead of decorative (the Phase 3 first cut configured a period range and ignored the speeds,
	-- which produced crossers faster than the stated maximum).
	local speed = lerp(wildlife.speedMin, wildlife.speedMax, rng:float())
	local period = (wildlife.spanX * 2) / speed

	return {
		kind = "wildlife",
		row = row,
		species = species,
		speed = speed,
		period = period,
		phase = rng:float() * period,
		dir = (row % 2 == 0) and 1 or -1,
	}
end

-- Raw generation. Call generateValidated() from gameplay; this can produce a wall.
local function generate(opts)
	local world = opts.world
	local index = opts.index
	local startRow = opts.startRow
	local laneCap = opts.laneCap or GameConfig.MAX_CORRIDOR_LANES
	local headwayBoost = opts.headwayBoost or 1
	local allowHazards = opts.allowHazards ~= false

	local rng = Rng.new(Rng.mix(opts.seed, index * 7919 + 13, 7))

	local rows = {}
	local lanes = {}
	local collectibles = {}
	local obstacles = {}

	local cursor = startRow
	local endRow = startRow + GameConfig.CHUNK_ROWS
	local corridorIndex = 0

	while cursor < endRow do
		local difficulty = math.clamp(cursor / world.rampRows, 0, 1) ^ 0.85

		local medianRows = rng:int(GameConfig.MEDIAN_MIN_ROWS, GameConfig.MEDIAN_MAX_ROWS)
		for _ = 1, medianRows do
			if cursor >= endRow then
				break
			end
			rows[#rows + 1] = { row = cursor, kind = "median" }
			cursor += 1
		end

		-- Leave one row for the closing median.
		if endRow - cursor < 2 then
			break
		end

		corridorIndex += 1
		local dir = (corridorIndex % 2 == 1) and -1 or 1

		local isRail = allowHazards
			and hazardRoll(rng, difficulty, HazardConfig.rail, HazardConfig.unlockDifficulty.rail)

		if isRail then
			local lane = makeRailLane(rng, world, difficulty, cursor, dir)
			lanes[#lanes + 1] = lane
			rows[#rows + 1] = { row = cursor, kind = "rail", lane = lane }
			cursor += 1
		else
			local weights = {
				lerp(world.corridorWeightsStart[1], world.corridorWeightsEnd[1], difficulty),
				lerp(world.corridorWeightsStart[2], world.corridorWeightsEnd[2], difficulty),
				lerp(world.corridorWeightsStart[3], world.corridorWeightsEnd[3], difficulty),
			}

			local laneCount = math.min(pickWeighted(rng, weights), laneCap, endRow - cursor - 1)
			if laneCount < 1 then
				laneCount = 1
			end

			local basePhase = rng:float() * 0.8
			for j = 0, laneCount - 1 do
				local lane = makeLane(
					rng,
					world,
					difficulty,
					cursor,
					dir,
					basePhase + j * GameConfig.LANE_PHASE_STEP,
					headwayBoost
				)
				lanes[#lanes + 1] = lane
				rows[#rows + 1] = { row = cursor, kind = "road", lane = lane }
				cursor += 1
			end
		end
	end

	-- A chunk must end on a median.
	while #rows > 0 and (rows[#rows].kind == "road" or rows[#rows].kind == "rail") do
		local removed = table.remove(rows)
		for i = #lanes, 1, -1 do
			if lanes[i] == removed.lane then
				table.remove(lanes, i)
				break
			end
		end
	end

	-- Static closures on road rows. At most `maxPerRow`, so the 17-column field is never sealed.
	for _, rowDef in ipairs(rows) do
		local difficulty = math.clamp(rowDef.row / world.rampRows, 0, 1) ^ 0.85
		if
			allowHazards
			and rowDef.kind == "road"
			and hazardRoll(rng, difficulty, HazardConfig.closure, HazardConfig.unlockDifficulty.closure)
		then
			local count = rng:int(1, HazardConfig.closure.maxPerRow)
			local used = {}

			for _ = 1, count do
				local col = rng:int(-7, 7)
				if not used[col] then
					used[col] = true
					obstacles[#obstacles + 1] = { kind = "barrier", row = rowDef.row, col = col }
				end
			end
		end
	end

	-- Wildlife crossers, on medians and roads alike — but never on a chunk's opening rows, where the
	-- player has just arrived and has no reaction time, and never on a rail row, where a train
	-- already owns that lane's attention.
	local lastRow = rows[#rows] and rows[#rows].row or startRow
	local grace = HazardConfig.wildlife.entryGraceRows

	for _, rowDef in ipairs(rows) do
		local difficulty = math.clamp(rowDef.row / world.rampRows, 0, 1) ^ 0.85

		local eligible = allowHazards
			and rowDef.kind ~= "rail"
			and rowDef.row >= startRow + grace
			and rowDef.row < lastRow

		if
			eligible
			and hazardRoll(rng, difficulty, HazardConfig.wildlife, HazardConfig.unlockDifficulty.wildlife)
		then
			obstacles[#obstacles + 1] = makeWildlife(rng, rowDef.row, world.id)
		end
	end

	-- Collectibles. A tile holding a closure is never bait.
	local function isBarrierTile(row: number, col: number): boolean
		for _, obstacle in ipairs(obstacles) do
			if obstacle.kind == "barrier" and obstacle.row == row and obstacle.col == col then
				return true
			end
		end
		return false
	end

	for _, rowDef in ipairs(rows) do
		local isSafeRow = rowDef.kind == "median"
		local chance = isSafeRow and world.acornChanceMedian or world.acornChanceRoad
		if rng:float() < chance then
			local col = rng:int(-6, 6)
			if not isBarrierTile(rowDef.row, col) then
				collectibles[#collectibles + 1] = {
					id = string.format("c%d_%d", index, rowDef.row),
					row = rowDef.row,
					col = col,
					kind = isSafeRow and "acorn_safe" or "acorn_road",
					value = isSafeRow and GameConfig.ACORN_VALUE_SAFE or GameConfig.ACORN_VALUE_ROAD,
				}
			end
		end
	end

	return {
		v = ChunkFormat.VERSION,
		index = index,
		startRow = startRow,
		rowCount = #rows,
		rows = rows,
		lanes = lanes,
		collectibles = collectibles,
		obstacles = obstacles,
		validated = false,
		attempts = 1,
	}
end

ChunkGenerator.generate = generate

-- Attempt ladder from docs/04 §6.2, plus an unconditional fallback.
local ATTEMPTS = {
	{ laneCap = 3, headwayBoost = 1.00, allowHazards = true },
	{ laneCap = 3, headwayBoost = 1.35, allowHazards = true },
	{ laneCap = 2, headwayBoost = 1.70, allowHazards = false },
	{ laneCap = 1, headwayBoost = 2.40, allowHazards = false },
}

function ChunkGenerator.generateValidated(opts): any
	local world = opts.world

	for attempt = 1, #ATTEMPTS do
		local spec = ATTEMPTS[attempt]
		local chunk = generate({
			seed = opts.seed + attempt * 104729,
			index = opts.index,
			startRow = opts.startRow,
			world = world,
			laneCap = spec.laneCap,
			headwayBoost = spec.headwayBoost,
			allowHazards = spec.allowHazards,
		})
		chunk.attempts = attempt

		local survivable = SafePathValidator.validate(chunk, world)
		if survivable then
			chunk.validated = true
			return chunk
		end
	end

	-- Guaranteed template: single-lane corridors with maximum spacing and no extra hazards.
	local chunk = generate({
		seed = opts.seed + 999983,
		index = opts.index,
		startRow = opts.startRow,
		world = world,
		laneCap = 1,
		headwayBoost = 3.0,
		allowHazards = false,
	})
	chunk.attempts = #ATTEMPTS + 1
	chunk.validated = SafePathValidator.validate(chunk, world)

	if not chunk.validated then
		warn("[ChunkGenerator] fallback template failed validation; generating empty median chunk")
		local rows = {}
		for row = opts.startRow, opts.startRow + GameConfig.CHUNK_ROWS - 1 do
			rows[#rows + 1] = { row = row, kind = "median" }
		end
		chunk = {
			v = ChunkFormat.VERSION,
			index = opts.index,
			startRow = opts.startRow,
			rowCount = GameConfig.CHUNK_ROWS,
			rows = rows,
			lanes = {},
			collectibles = {},
			obstacles = {},
			validated = true,
			attempts = #ATTEMPTS + 2,
		}
	end

	return chunk
end

return ChunkGenerator
