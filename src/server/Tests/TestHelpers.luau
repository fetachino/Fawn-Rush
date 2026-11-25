--!nonstrict
-- Shared test fixtures.
--
-- Kept separate from TestKit (which is the assertion/report engine) so a suite can depend on a
-- fixture without pulling in the reporting side, and so two suites can compare generated data the
-- same way instead of each growing its own slightly different signature.

local GameConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config.GameConfig)

local TestHelpers = {}

-- Stable text signature of a whole chunk. Determinism tests compare this rather than counts, because
-- lane speed/headway/phase and obstacle placement are what a client re-derives.
function TestHelpers.chunkSignature(chunk)
	local parts = { ("v%s rows%d"):format(tostring(chunk.v), chunk.rowCount) }

	for _, lane in ipairs(chunk.lanes) do
		parts[#parts + 1] = ("L%d|%s|%d|%.3f|%.3f|%.3f|%.3f"):format(
			lane.row,
			tostring(lane.type),
			lane.dir,
			lane.speed,
			lane.headway,
			lane.phase,
			lane.overhang or 0
		)
	end

	for _, collectible in ipairs(chunk.collectibles) do
		parts[#parts + 1] = ("C%d|%d|%d|%s"):format(
			collectible.row,
			collectible.col,
			collectible.value,
			tostring(collectible.kind)
		)
	end

	for _, obstacle in ipairs(chunk.obstacles or {}) do
		parts[#parts + 1] = ("O%d|%s|%s|%.3f|%.3f"):format(
			obstacle.row,
			tostring(obstacle.kind),
			tostring(obstacle.col or obstacle.species),
			obstacle.period or 0,
			obstacle.phase or 0
		)
	end

	return table.concat(parts, ";")
end

-- Deepest sampled row for a world: far enough that the difficulty ramp is at or near its cap, so a
-- generation test exercises the hardest case the world can produce.
function TestHelpers.deepStartRow(world, index: number): number
	return math.max(world.rampRows, GameConfig.CHUNK_ROWS * 4) + index * GameConfig.CHUNK_ROWS
end

return TestHelpers
