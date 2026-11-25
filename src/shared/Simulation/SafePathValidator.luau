--!nonstrict
-- Safe-path validation: the fairness guarantee from docs/01_GAME_DESIGN_DOCUMENT.md §7.2.
--
-- A chunk of generated rows is only allowed to exist if a time-indexed search can find a sequence
-- of steps from the first row to the last that never overlaps traffic. This catches the failure
-- that per-lane spacing rules cannot: three lanes whose gaps each satisfy the fairness floor but
-- whose phases interleave into a wall.
--
-- Search: breadth-first over a time-expanded grid, where each node is (row, col, t). Waiting costs
-- one solver tick, moving costs STEP_COOLDOWN. A move into a tile requires that tile to be clear
-- of traffic for SOLVER_MARGIN seconds, which is the reaction buffer a player actually needs.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local TrafficSim = require(Shared.Simulation.TrafficSim)
local ObstacleSim = require(Shared.Simulation.ObstacleSim)

local SafePathValidator = {}

local MOVE_DIRS = {
	{ 0, 1 },
	{ 0, -1 },
	{ -1, 0 },
	{ 1, 0 },
}

-- Returns (survivable: boolean, expansions: number).
function SafePathValidator.validate(chunk, world): (boolean, number)
	local lanesByRow = {}
	for _, lane in ipairs(chunk.lanes) do
		lanesByRow[lane.row] = lane
	end

	local obstacleIndex = ObstacleSim.buildIndex(chunk)

	local startRow = chunk.startRow
	local goalRow = startRow + chunk.rowCount - 1
	local minCol = GameConfig.PLAYFIELD_MIN_COL
	local maxCol = GameConfig.PLAYFIELD_MAX_COL
	local dt = GameConfig.SOLVER_DT
	local stepTicks = math.max(1, math.floor(GameConfig.STEP_COOLDOWN / dt + 0.5))
	local maxTicks = math.floor(GameConfig.SOLVER_HORIZON / dt)

	local function tileSafe(row: number, col: number, elapsed: number): boolean
		if ObstacleSim.isTileBlocked(obstacleIndex, row, col, elapsed, GameConfig.SOLVER_MARGIN) then
			return false
		end

		local lane = lanesByRow[row]
		if not lane then
			return true
		end
		return TrafficSim.isTileSafe(lane, col, elapsed, GameConfig.SOLVER_MARGIN)
	end

	if not tileSafe(startRow, 0, 0) then
		return false, 0
	end

	local visited = {}
	local layers = {}
	local expansions = 0

	local function key(row: number, col: number, t: number): number
		return ((row - startRow) * 32 + (col + 16)) * 512 + t
	end

	local function push(t: number, row: number, col: number)
		if t > maxTicks or row < startRow or row > goalRow then
			return
		end
		if col < minCol or col > maxCol then
			return
		end
		local k = key(row, col, t)
		if visited[k] then
			return
		end
		visited[k] = true
		local layer = layers[t]
		if not layer then
			layer = {}
			layers[t] = layer
		end
		layer[#layer + 1] = { row = row, col = col }
	end

	visited[key(startRow, 0, 0)] = true
	layers[0] = { { row = startRow, col = 0 } }

	for t = 0, maxTicks do
		local layer = layers[t]
		if layer then
			for index = 1, #layer do
				local state = layer[index]

				if state.row >= goalRow then
					return true, expansions
				end

				expansions += 1
				if expansions > GameConfig.SOLVER_NODE_CAP then
					return false, expansions
				end

				-- Wait one tick (only if the tile stays clear for that tick).
				local waitT = t + 1
				if waitT <= maxTicks and tileSafe(state.row, state.col, waitT * dt) then
					push(waitT, state.row, state.col)
				end

				-- Take one step.
				local moveT = t + stepTicks
				if moveT <= maxTicks then
					for d = 1, #MOVE_DIRS do
						local nr = state.row + MOVE_DIRS[d][2]
						local nc = state.col + MOVE_DIRS[d][1]
						if tileSafe(nr, nc, moveT * dt) then
							if nr >= goalRow then
								return true, expansions + 1
							end
							push(moveT, nr, nc)
						end
					end
				end
			end
		end
	end

	return false, expansions
end

return SafePathValidator
