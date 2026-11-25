--!nonstrict
-- Closed-form traffic simulation.
--
-- A vehicle's position is a pure function of (lane parameters, vehicle index, elapsed time). No
-- state is stepped, so the server and every client agree exactly, bandwidth carries lane
-- *definitions* rather than positions, and rewinding for lag compensation costs one extra
-- evaluation. See docs/04_GAMEPLAY_MECHANICS_SPEC.md §4.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.GameConfig)

local TrafficSim = {}

local TILE = GameConfig.TILE

-- Seconds for a vehicle to traverse the full visible span.
function TrafficSim.travelTime(lane): number
	return (2 * (lane.spanX + lane.overhang)) / lane.speed
end

-- Inclusive range of vehicle indices that can be visible at `elapsed` seconds into the run.
function TrafficSim.indexRange(lane, elapsed: number): (number, number)
	local travel = TrafficSim.travelTime(lane)
	local kMin = math.floor((elapsed - lane.phase - travel) / lane.headway) - 1
	local kMax = math.floor((elapsed - lane.phase) / lane.headway) + 1
	return kMin, kMax
end

-- World X of vehicle `k` and its length in studs.
function TrafficSim.vehicleAt(lane, k: number, elapsed: number): (number, number, number)
	local def = GameConfig.VEHICLES[lane.vehicleType]
	local t0 = lane.phase + k * lane.headway
	local xIn = -lane.dir * (lane.spanX + lane.overhang)
	local x = xIn + lane.dir * lane.speed * (elapsed - t0)
	return x, -lane.row * TILE, def.lengthTiles * TILE
end

function TrafficSim.laneZ(lane): number
	return -lane.row * TILE
end

-- Does a vehicle in `lane` overlap a body of PLAYER_HALF_X/Z centred on (x, z) at `elapsed`?
function TrafficSim.isHitAt(lane, x: number, z: number, elapsed: number): boolean
	local def = GameConfig.VEHICLES[lane.vehicleType]

	if math.abs(z - TrafficSim.laneZ(lane)) >= def.halfWidth + GameConfig.PLAYER_HALF_Z then
		return false
	end

	local limit = def.lengthTiles * TILE * 0.5 + GameConfig.PLAYER_HALF_X + GameConfig.CONTACT_PAD_X
	local kMin, kMax = TrafficSim.indexRange(lane, elapsed)

	for k = kMin, kMax do
		local vehicleX = TrafficSim.vehicleAt(lane, k, elapsed)
		if math.abs(vehicleX - x) < limit then
			return true
		end
	end

	return false
end

-- Is the tile (row, col) free of traffic across [elapsed, elapsed + margin]?
-- Sampled rather than continuous: SOLVER_SAMPLES points across the margin is enough for the
-- validator, and keeps a 10k-chunk soak inside its time budget.
function TrafficSim.isTileSafe(lane, col: number, elapsed: number, margin: number): boolean
	local def = GameConfig.VEHICLES[lane.vehicleType]
	local limit = def.lengthTiles * TILE * 0.5 + GameConfig.PLAYER_HALF_X + GameConfig.CONTACT_PAD_X
	local x = col * TILE
	local travel = TrafficSim.travelTime(lane)
	local samples = GameConfig.SOLVER_SAMPLES

	for i = 0, samples do
		local t = elapsed + margin * (i / samples)
		local kMin = math.floor((t - lane.phase - travel) / lane.headway) - 1
		local kMax = math.floor((t - lane.phase) / lane.headway) + 1

		for k = kMin, kMax do
			local t0 = lane.phase + k * lane.headway
			local vehicleX = -lane.dir * (lane.spanX + lane.overhang) + lane.dir * lane.speed * (t - t0)
			if math.abs(vehicleX - x) < limit then
				return false
			end
		end
	end

	return true
end

return TrafficSim
