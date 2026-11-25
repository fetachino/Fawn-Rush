--!nonstrict
-- Run lifecycle and the authoritative simulation loop.
--
-- This service owns every value that can be scored: the tile a player occupies, whether a step or a
-- jump is legal, whether a vehicle or an animal hit them, which collectibles were taken, which near
-- misses count, the combo multiplier, and the final score. The client sends intent and nothing else.
--
-- Phase 3 adds near misses, combos, jumps, static closures and wildlife. Every one of those is
-- decided here from the same deterministic lane data the client renders from.
--
-- See docs/04_GAMEPLAY_MECHANICS_SPEC.md §7 and §10, docs/02_TECHNICAL_ARCHITECTURE.md §6.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RobloxRunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local WorldConfig = require(Shared.Config.WorldConfig)
local GridMath = require(Shared.Util.GridMath)
local Rng = require(Shared.Util.Rng)
local Signal = require(Shared.Util.Signal)
local TrafficSim = require(Shared.Simulation.TrafficSim)
local Scoring = require(Shared.Simulation.Scoring)
local Combo = require(Shared.Simulation.Combo)
local NearMiss = require(Shared.Simulation.NearMiss)
local ObstacleSim = require(Shared.Simulation.ObstacleSim)
local WorldUnlock = require(Shared.Simulation.WorldUnlock)
local Net = require(Shared.Constants.Net)
local Remotes = require(Shared.Net.Remotes)

local ChunkService = require(script.Parent.ChunkService)
local ZoneService = require(script.Parent.ZoneService)

local RunService = {}

-- Other services observe these instead of polling run state.
RunService.events = {
	runStarted = Signal.new(),
	runEnded = Signal.new(),
}

local DEATH_NAMES = {
	compact = "a car",
	sports = "a sports car",
	truck = "a truck",
	van = "a van",
	bus = "a bus",
	motorcycle = "a motorcycle",
	train = "a train",
	wildlife = "an animal",
}

local PlayerDataService = require(script.Parent.PlayerDataService)

local runs = {}
local sessionBest = {}
local loopHandle = nil
local running = false

local function now(): number
	return workspace:GetServerTimeNow()
end

local function scorePayload(run)
	local atTime = now()
	return {
		rows = run.rows,
		score = Scoring.compute({
			rows = run.rows,
			nearMissPoints = run.nearMissPoints,
			collectiblePoints = run.acornValue,
		}),
		acorns = run.acorns,
		col = run.toCol,
		row = run.toRow,
		combo = Combo.current(run.combo, atTime),
		comboTime = Combo.timeLeft(run.combo, atTime) / GameConfig.COMBO_DECAY,
	}
end

-- Linear interpolation between the last two tiles, matching the client exactly so that what a
-- player sees is what the server judged.
function RunService.currentPosition(run, atTime: number): (number, number)
	local elapsed = atTime - run.stepStart
	if elapsed < 0 then
		elapsed = 0
	end

	local alpha = math.clamp(elapsed / GameConfig.STEP_TIME, 0, 1)
	local col = run.fromCol + (run.toCol - run.fromCol) * alpha
	local row = run.fromRow + (run.toRow - run.fromRow) * alpha
	return col, row
end

function RunService.findHit(run, x: number, z: number, elapsed: number)
	-- Only the lane the player's body can reach is worth testing. A body is under one tile deep, so
	-- the row under it plus its two neighbours covers every lane that could overlap; scanning all
	-- ~90 retained lanes was wasted work at 20 Hz per player.
	local row = math.floor(-z / GameConfig.TILE + 0.5)
	for offset = -1, 1 do
		local lane = run.lanesByRow[row + offset]
		if lane and TrafficSim.isHitAt(lane, x, z, elapsed) then
			return lane
		end
	end

	return nil
end

local function createRun(player, world, runIndex)
	return {
		player = player,
		world = world,
		runIndex = runIndex,
		seed = Rng.mix(player.UserId, runIndex, 13),
		startTime = now(),

		phase = "running",
		alive = true,
		deathCause = nil,

		col = 0,
		row = 0,
		fromCol = 0,
		fromRow = 0,
		toCol = 0,
		toRow = 0,
		stepStart = -100,
		lastStepAt = -100,

		airborne = false,
		jumpStart = -100,
		lastJumpAt = -100,

		rows = 0,
		acorns = 0,
		acornValue = 0,
		collectibleCount = 0,
		secretHazardClear = true,
		startedClock = os.clock(),
		nearMissPoints = 0,
		nearMisses = 0,
		combo = Combo.new(),
		nearMissAwarded = {},
		nearMissAwardedCount = 0,

		generatedRows = 0,
		nextChunkIndex = 0,
		chunks = {},
		lanes = {},
		lanesByRow = {},
		collectibles = {},
		obstacleList = {},
		obstacleIndex = { barriers = {}, wildlife = {} },

		stepWindowStart = 0,
		stepCount = 0,
		lastSent = nil,
	}
end

function RunService.pushState(run, force: boolean?)
	local payload = scorePayload(run)
	local previous = run.lastSent

	if
		not force
		and previous
		and previous.rows == payload.rows
		and previous.score == payload.score
		and previous.acorns == payload.acorns
		and math.abs((previous.combo or 1) - (payload.combo or 1)) < 0.001
	then
		return
	end

	run.lastSent = payload
	local remote = Remotes.get(Net.REMOTES.RunState)
	if remote then
		remote:FireClient(run.player, payload)
	end
end

local function pushEvent(run, payload)
	local remote = Remotes.get(Net.REMOTES.RunEvent)
	if remote then
		remote:FireClient(run.player, payload)
	end
end

function RunService.startRun(player, worldId: string): (boolean, string?)
	local existing = runs[player]
	if existing and existing.phase == "running" then
		return false, "already_running"
	end

	if not PlayerDataService.isLoaded(player) then
		return false, "profile_unavailable"
	end
	local world = WorldConfig.get(worldId)
	local profile = PlayerDataService.get(player)
	if not profile then return false, "profile_unavailable" end
	if GameConfig.WORLD_UNLOCK_ENFORCED and not WorldUnlock.isUnlocked(world.id, profile) then
		return false, "locked"
	end

	local zoneIndex = ZoneService.allocate(player)
	local runIndex = (existing and existing.runIndex + 1) or 1
	local run = createRun(player, world, runIndex)

	run.zoneIndex = zoneIndex
	run.origin = ZoneService.originFor(zoneIndex)

	runs[player] = run

	-- Origin first: the client cannot interpret a chunk until it knows where the strip is.
	local zoneRemote = Remotes.get(Net.REMOTES.ZoneInit)
	if zoneRemote then
		zoneRemote:FireClient(player, {
			origin = run.origin,
			startTime = run.startTime,
			worldId = world.id,
			runIndex = runIndex,
		})
	end

	ChunkService.ensure(run)
	RunService.pushState(run, true)
	RunService.events.runStarted:Fire(player, run)

	return true
end

function RunService.tryCollect(run, col: number, row: number)
	local key = ChunkService.collectibleKey(col, row)
	local collectible = run.collectibles[key]
	if not collectible then
		return
	end

	run.collectibles[key] = nil
	run.acorns += collectible.value
	run.acornValue += collectible.value
	run.collectibleCount += 1

	pushEvent(run, {
		kind = "pickup",
		id = collectible.id,
		col = col,
		row = row,
	})

	RunService.pushState(run, true)
end

-- Awards a near miss if the tile the player is on just had a vehicle pass within the threshold.
function RunService.checkNearMiss(run, x: number, z: number, elapsed: number, atTime: number)
	local lane = run.lanesByRow[run.row]
	if not lane then
		return
	end

	local gap, key = NearMiss.clearance(lane, x, z, elapsed)
	if not key or not NearMiss.qualifies(gap) then
		return
	end

	local last = run.nearMissAwarded[key]
	if last and (atTime - last) < GameConfig.NEAR_MISS_DEDUPE then
		return
	end

	run.nearMissAwarded[key] = atTime
	run.nearMissAwardedCount += 1

	Combo.settle(run.combo, atTime)
	local multiplier = Combo.register(run.combo, atTime)
	local acorns = Combo.acornReward(multiplier)

	run.nearMisses += 1
	run.acorns += acorns
	run.nearMissPoints += Combo.scoreReward(multiplier)

	pushEvent(run, {
		kind = "near_miss",
		combo = multiplier,
		row = run.row,
		col = run.toCol,
		acorns = acorns,
	})

	RunService.pushState(run, true)
end

function RunService.acceptStep(player, dir: string): (boolean, string?)
	local run = runs[player]
	if not run or run.phase ~= "running" or not run.alive then
		return false, "state"
	end

	if run.airborne then
		return false, "airborne"
	end

	if not GridMath.DIR_OFFSETS[dir] then
		return false, "direction"
	end

	local atTime = now()
	if atTime - run.lastStepAt < GameConfig.STEP_COOLDOWN - 0.002 then
		return false, "cooldown"
	end

	if atTime - run.stepWindowStart > 1 then
		run.stepWindowStart = atTime
		run.stepCount = 0
	end
	if run.stepCount >= GameConfig.MAX_STEPS_PER_SECOND then
		return false, "rate"
	end

	-- Steps chain from the pending target, so a buffered input during the current hop is honoured.
	local targetCol, targetRow = GridMath.targetTile(run.toCol, run.toRow, dir)
	if not targetCol or not GridMath.isValidTile(targetCol, targetRow) then
		return false, "bounds"
	end

	-- Static closures are a soft block: no death, and no extra cooldown beyond the normal one.
	if ObstacleSim.isBarrier(run.obstacleIndex, targetRow, targetCol) then
		return false, "blocked"
	end

	local col, row = RunService.currentPosition(run, atTime)

	run.fromCol = col
	run.fromRow = row
	run.toCol = targetCol
	run.toRow = targetRow
	run.stepStart = atTime
	run.lastStepAt = atTime
	run.col = targetCol
	run.row = targetRow
	run.stepCount += 1

	if targetRow > run.rows then
		run.rows = targetRow
	end

	RunService.tryCollect(run, targetCol, targetRow)
	ChunkService.ensure(run)

	return true
end

-- A jump is a committed one-tile leap. It carries the player forward if the tile ahead is legal and
-- otherwise is an in-place hop. Wildlife cannot reach a player at the apex.
function RunService.acceptJump(player): (boolean, string?)
	local run = runs[player]
	if not run or run.phase ~= "running" or not run.alive then
		return false, "state"
	end

	local atTime = now()
	if run.airborne then
		return false, "airborne"
	end
	if atTime - run.lastJumpAt < GameConfig.JUMP_COOLDOWN then
		return false, "cooldown"
	end

	run.airborne = true
	run.jumpStart = atTime
	run.lastJumpAt = atTime

	local targetCol, targetRow = GridMath.targetTile(run.toCol, run.toRow, "fwd")
	if
		targetCol
		and GridMath.isValidTile(targetCol, targetRow)
		and not ObstacleSim.isBarrier(run.obstacleIndex, targetRow, targetCol)
	then
		local col, row = RunService.currentPosition(run, atTime)
		run.fromCol = col
		run.fromRow = row
		run.toCol = targetCol
		run.toRow = targetRow
		run.stepStart = atTime
		run.col = targetCol
		run.row = targetRow
		if targetRow > run.rows then
			run.rows = targetRow
		end
		RunService.tryCollect(run, targetCol, targetRow)
		ChunkService.ensure(run)
	end

	return true
end

-- Height factor 0..1 through the jump arc.
function RunService.jumpProgress(run, atTime: number): number
	if not run.airborne then
		return 0
	end
	local t = math.clamp((atTime - run.jumpStart) / GameConfig.JUMP_TIME, 0, 1)
	return math.sin(t * math.pi)
end

function RunService.finish(player, reason: string)
	local run = runs[player]
	if not run or run.phase ~= "running" then
		return
	end

	run.phase = "finished"
	run.alive = false
	Combo.reset(run.combo)

	local userId = player.UserId
	local previousBest = sessionBest[userId] or 0
	sessionBest[userId] = math.max(previousBest, run.rows)

	-- Progression listeners run synchronously before the results payload is sent. They consume only
	-- server-owned run state and may attach a progression summary for the player's own result screen.
	RunService.events.runEnded:Fire(player, run, reason)
	local bestRows = math.max(sessionBest[userId] or 0, run.persistentBestRows or 0)
	local payload = scorePayload(run)
	local remote = Remotes.get(Net.REMOTES.RunEnded)
	if remote then
		remote:FireClient(player, {
			reason = reason,
			runIndex = run.runIndex,
			rows = payload.rows,
			score = payload.score,
			acorns = payload.acorns,
			nearMisses = run.nearMisses,
			bestRows = bestRows,
			deathCause = run.deathCause and DEATH_NAMES[run.deathCause] or nil,
			progression = run.progressionSummary,
			unlockedAnimals = run.unlockedAnimals,
		})
	end
end

-- One collision pass plus the ~10 Hz state push.
local function hazardWithinSecretRadius(run, x: number, z: number, elapsed: number): boolean
	local radius = 3 * GameConfig.TILE
	local radiusSquared = radius * radius
	local centerRow = math.floor(-z / GameConfig.TILE + 0.5)
	for row = centerRow - 3, centerRow + 3 do
		local lane = run.lanesByRow[row]
		if lane then
			local first, last = TrafficSim.indexRange(lane, elapsed)
			for vehicleIndex = first, last do
				local vehicleX = TrafficSim.vehicleAt(lane, vehicleIndex, elapsed)
				local dx = vehicleX - x
				local dz = TrafficSim.laneZ(lane) - z
				if dx * dx + dz * dz <= radiusSquared then return true end
			end
		end
	end
	for _, obstacle in ipairs(run.obstacleList) do
		local obstacleZ = -obstacle.row * GameConfig.TILE
		if math.abs(obstacleZ - z) <= radius then
			if obstacle.kind == "barrier" then
				local dx = obstacle.col * GameConfig.TILE - x
				local dz = obstacleZ - z
				if dx * dx + dz * dz <= radiusSquared then return true end
			elseif obstacle.kind == "wildlife" then
				local obstacleX = ObstacleSim.wildlifeX(obstacle, elapsed)
				local dx = obstacleX - x
				local dz = obstacleZ - z
				if dx * dx + dz * dz <= radiusSquared then return true end
			end
		end
	end
	return false
end

function RunService.tick(atTime: number)
	for player, run in pairs(runs) do
		if run.phase == "running" and run.alive then
			local col, row = RunService.currentPosition(run, atTime)
			local x = col * GameConfig.TILE
			local z = -row * GameConfig.TILE
			local elapsed = atTime - run.startTime
			if run.secretHazardClear and run.rows <= 150 and hazardWithinSecretRadius(run, x, z, elapsed) then
				run.secretHazardClear = false
			end

			-- Landing resolves before collision, so a player is never killed while still airborne.
			if run.airborne and (atTime - run.jumpStart) >= GameConfig.JUMP_TIME then
				run.airborne = false
				pushEvent(run, { kind = "land", row = run.row })
			end

			local jumpHeight = RunService.jumpProgress(run, atTime)
			local aboveWildlife = jumpHeight * GameConfig.JUMP_APEX >= GameConfig.WILDLIFE_AIRBORNE_CLEARANCE

			local lane = RunService.findHit(run, x, z, elapsed)
			local wildlife = nil
			if not aboveWildlife then
				wildlife = ObstacleSim.wildlifeHit(run.obstacleIndex, x, z, elapsed)
			end

			if lane or wildlife then
				local forgiven = false

				-- Favour the player: a contact that exists now but did not exist at the moment the
				-- current step began is not a death. Bounded by STEP_TIME, so it cannot be farmed.
				if (atTime - run.stepStart) < GameConfig.STEP_TIME then
					local startElapsed = run.stepStart - run.startTime
					local startX = run.fromCol * GameConfig.TILE
					local startZ = -run.fromRow * GameConfig.TILE
					local startLane = RunService.findHit(run, startX, startZ, startElapsed)
					local startWildlife = ObstacleSim.wildlifeHit(run.obstacleIndex, startX, startZ, startElapsed)
					if not startLane and not startWildlife then
						forgiven = true
					end
				end

				if not forgiven then
					run.deathCause = lane and lane.vehicleType or "wildlife"
					RunService.finish(player, "death")
				end
			end

			if run.alive then
				RunService.checkNearMiss(run, x, z, elapsed, atTime)

				-- The de-duplication table only needs to survive the dedupe window.
				if run.nearMissAwardedCount > 96 then
					run.nearMissAwarded = {}
					run.nearMissAwardedCount = 0
				end
			end
		end
	end
end

function RunService.getRun(player)
	return runs[player]
end

function RunService.playerRemoving(player)
	RunService.finish(player, "leave")
	runs[player] = nil
	sessionBest[player.UserId] = nil
end

function RunService.start()
	if running then
		return
	end
	running = true

	loopHandle = task.spawn(function()
		local tickAccumulator = 0
		local stateAccumulator = 0

		while running do
			local dt = RobloxRunService.Heartbeat:Wait()
			tickAccumulator += dt
			stateAccumulator += dt

			if tickAccumulator >= GameConfig.TICK_DT then
				tickAccumulator = 0
				RunService.tick(now())
			end

			if stateAccumulator >= 0.1 then
				stateAccumulator = 0
				for _, run in pairs(runs) do
					if run.phase == "running" then
						RunService.pushState(run, false)
					end
				end
			end
		end
	end)
end

function RunService.stop()
	running = false
	if loopHandle then
		task.cancel(loopHandle)
		loopHandle = nil
	end
end

return RunService
