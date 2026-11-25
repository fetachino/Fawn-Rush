--!nonstrict
-- Static and moving obstacle simulation: road closures and wildlife crossers.
--
-- Pure, like TrafficSim: a wildlife animal's position is a closed-form function of elapsed time, so
-- the server and every client agree without synchronising anything. Static barriers are just data.
--
-- See docs/01_GAME_DESIGN_DOCUMENT.md §7.1 (hazards 8 and 9) and docs/04 §5.5.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local HazardConfig = require(Shared.Config.HazardConfig)

local ObstacleSim = {}

local TILE = GameConfig.TILE
local WILDLIFE = HazardConfig.wildlife

-- Builds a row-indexed lookup for a chunk so validation and collision are O(1) per tile.
function ObstacleSim.buildIndex(chunk)
	local index = {
		barriers = {},
		wildlife = {},
	}

	for _, obstacle in ipairs(chunk.obstacles or {}) do
		if obstacle.kind == "barrier" then
			index.barriers[obstacle.row * 32 + (obstacle.col + 16)] = true
		elseif obstacle.kind == "wildlife" then
			local bucket = index.wildlife[obstacle.row]
			if not bucket then
				bucket = {}
				index.wildlife[obstacle.row] = bucket
			end
			bucket[#bucket + 1] = obstacle
		end
	end

	return index
end

function ObstacleSim.isBarrier(index, row: number, col: number): boolean
	return index.barriers[row * 32 + (col + 16)] == true
end

-- World X of a wildlife crosser at `elapsed` seconds into the run.
function ObstacleSim.wildlifeX(obstacle, elapsed: number): number
	local span = WILDLIFE.spanX * 2
	local period = obstacle.period or 1
	if period <= 0 then
		return -WILDLIFE.spanX
	end

	local progress = ((elapsed + obstacle.phase) % period) / period
	if obstacle.dir < 0 then
		progress = 1 - progress
	end
	return -WILDLIFE.spanX + progress * span
end

-- Studs per second implied by the crosser's cycle. Speed is the authoritative design number; the
-- period is derived from it, so this always lands inside [speedMin, speedMax].
function ObstacleSim.wildlifeSpeed(obstacle): number
	local period = obstacle.period or 0
	if period <= 0 then
		return 0
	end
	return (WILDLIFE.spanX * 2) / period
end

-- X overlap between a crosser and a body centred on `x`.
local function overlapsX(obstacle, x: number, elapsed: number): boolean
	local limit = WILDLIFE.halfWidth + GameConfig.PLAYER_HALF_X
	return math.abs(ObstacleSim.wildlifeX(obstacle, elapsed) - x) < limit
end

-- Z overlap between a crosser and a body centred on `z`. This is what makes `halfLength` real: the
-- Phase 3 first cut rounded the player's row to an integer and ignored the depth of both bodies.
local function overlapsZ(obstacle, z: number): boolean
	local obstacleZ = -obstacle.row * TILE
	return math.abs(obstacleZ - z) < WILDLIFE.halfLength + GameConfig.PLAYER_HALF_Z
end

-- Does any wildlife on `row` overlap a body centred on `col` during [elapsed, elapsed + margin]?
function ObstacleSim.wildlifeBlocks(index, row: number, col: number, elapsed: number, margin: number): boolean
	local bucket = index.wildlife[row]
	if not bucket then
		return false
	end

	local tileX = col * TILE
	local tileZ = -row * TILE
	local samples = math.max(1, GameConfig.SOLVER_SAMPLES)

	for _, obstacle in ipairs(bucket) do
		if overlapsZ(obstacle, tileZ) then
			for i = 0, samples do
				local at = elapsed + margin * (i / samples)
				if overlapsX(obstacle, tileX, at) then
					return true
				end
			end
		end
	end

	return false
end

-- Full tile test: static barrier or a wildlife body inside the window.
function ObstacleSim.isTileBlocked(index, row: number, col: number, elapsed: number, margin: number): boolean
	if ObstacleSim.isBarrier(index, row, col) then
		return true
	end
	return ObstacleSim.wildlifeBlocks(index, row, col, elapsed, margin)
end

-- Precise wildlife overlap for collision at an exact position (used by the server tick).
-- Both bodies are treated as boxes: X and Z must overlap, which is stricter and more honest than the
-- row-rounding approximation it replaces.
function ObstacleSim.wildlifeHit(index, x: number, z: number, elapsed: number): any?
	local row = math.floor(-z / TILE + 0.5)

	-- The body spans less than one tile in Z, so the crosser's own row is the only bucket that can
	-- overlap; the neighbours are checked because a player between rows is half in each.
	for offset = -1, 1 do
		local bucket = index.wildlife[row + offset]
		if bucket then
			for _, obstacle in ipairs(bucket) do
				if overlapsZ(obstacle, z) and overlapsX(obstacle, x, elapsed) then
					return obstacle
				end
			end
		end
	end

	return nil
end

return ObstacleSim
