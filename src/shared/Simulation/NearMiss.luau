--!nonstrict
-- Near-miss measurement. Pure: given a lane, a player position and the elapsed run time, report how
-- close the nearest vehicle came.
--
-- Used by the server (authority: it decides whether to award) and readable by the client for local
-- feedback, though the client never awards anything itself.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local TrafficSim = require(Shared.Simulation.TrafficSim)

local NearMiss = {}

local TILE = GameConfig.TILE

-- Distance in studs between the player's box and the nearest vehicle's box in `lane`.
-- Negative means overlapping (which is a death, not a near miss).
-- Returns (gapStuds, vehicleKey).
function NearMiss.clearance(lane, x: number, z: number, elapsed: number): (number, string?)
	local def = GameConfig.VEHICLES[lane.vehicleType]
	local laneZ = -lane.row * TILE

	-- Only the lane the player is actually standing in can produce a near miss.
	if math.abs(z - laneZ) >= TILE * 0.6 then
		return math.huge, nil
	end

	local halfLength = def.lengthTiles * TILE * 0.5
	local reach = def.halfWidth + GameConfig.PLAYER_HALF_Z
	if math.abs(z - laneZ) >= reach then
		return math.huge, nil
	end

	local kMin, kMax = TrafficSim.indexRange(lane, elapsed)
	local best = math.huge
	local bestKey = nil

	for k = kMin, kMax do
		local vehicleX = TrafficSim.vehicleAt(lane, k, elapsed)
		local gap = math.abs(vehicleX - x) - (halfLength + GameConfig.PLAYER_HALF_X)
		if gap < best then
			best = gap
			bestKey = ("%d:%d"):format(lane.row, k)
		end
	end

	return best, bestKey
end

function NearMiss.thresholdStuds(): number
	return GameConfig.NEAR_MISS_TILES * TILE
end

-- A near miss is a vehicle that passed within the threshold but did not hit.
function NearMiss.qualifies(gapStuds: number): boolean
	return gapStuds > 0 and gapStuds <= NearMiss.thresholdStuds()
end

return NearMiss
