--!nonstrict
-- Chunk streaming for one run: keeps CHUNK_LOOKAHEAD chunks generated ahead of the player, sends
-- each validated chunk to its owner, and prunes lanes and collectibles that are far behind.
--
-- Only the server generates. Clients receive ChunkDef tables and render from them; the server
-- never creates a single Part for a run.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local GameConfig = require(Shared.Config.GameConfig)
local Net = require(Shared.Constants.Net)
local Remotes = require(Shared.Net.Remotes)
local ChunkGenerator = require(Shared.Simulation.ChunkGenerator)
local ObstacleSim = require(Shared.Simulation.ObstacleSim)

local ChunkService = {}

local PRUNE_LANES_ABOVE = 90

function ChunkService.collectibleKey(col: number, row: number): number
	return row * 32 + (col + 16)
end

local function registerChunk(run, chunk)
	run.chunks[#run.chunks + 1] = chunk

	for _, lane in ipairs(chunk.lanes) do
		run.lanes[#run.lanes + 1] = lane
		run.lanesByRow[lane.row] = lane
	end

	for _, collectible in ipairs(chunk.collectibles) do
		run.collectibles[ChunkService.collectibleKey(collectible.col, collectible.row)] = collectible
	end

	for _, obstacle in ipairs(chunk.obstacles or {}) do
		run.obstacleList[#run.obstacleList + 1] = obstacle
	end

	run.obstacleIndex = ObstacleSim.buildIndex({ obstacles = run.obstacleList })
end

local function prune(run)
	if #run.lanes <= PRUNE_LANES_ABOVE then
		return
	end

	local keepRow = run.row - GameConfig.CHUNK_RECYCLE_BEHIND

	local kept = {}
	local keptByRow = {}
	for _, lane in ipairs(run.lanes) do
		if lane.row >= keepRow then
			kept[#kept + 1] = lane
			keptByRow[lane.row] = lane
		end
	end
	run.lanes = kept
	run.lanesByRow = keptByRow

	for key, collectible in pairs(run.collectibles) do
		if collectible.row < keepRow then
			run.collectibles[key] = nil
		end
	end

	local keptObstacles = {}
	for _, obstacle in ipairs(run.obstacleList) do
		if obstacle.row >= keepRow then
			keptObstacles[#keptObstacles + 1] = obstacle
		end
	end
	run.obstacleList = keptObstacles
	run.obstacleIndex = ObstacleSim.buildIndex({ obstacles = run.obstacleList })
end

-- Generates ahead until the player has enough road, then tells the client about anything new.
function ChunkService.ensure(run)
	local targetRow = run.row + GameConfig.CHUNK_ROWS * (GameConfig.CHUNK_LOOKAHEAD + 1)
	local remote = Remotes.get(Net.REMOTES.ChunkLoaded)

	while run.generatedRows < targetRow do
		local chunk = ChunkGenerator.generateValidated({
			seed = run.seed,
			index = run.nextChunkIndex,
			startRow = run.generatedRows,
			world = run.world,
		})

		run.nextChunkIndex += 1
		run.generatedRows = chunk.startRow + chunk.rowCount

		registerChunk(run, chunk)

		if remote then
			remote:FireClient(run.player, chunk)
		end

		if not chunk.validated then
			warn(("[ChunkService] chunk %d shipped unvalidated (attempt %d)"):format(chunk.index, chunk.attempts))
		end
	end

	prune(run)
end

return ChunkService
