--!nonstrict
-- Phase 2 test suite: determinism, generation invariants, the fairness guarantee, and collision.
-- Runs on server boot in Studio. Any failure here means the prototype is not trustworthy.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local WorldConfig = require(Shared.Config.WorldConfig)
local Rng = require(Shared.Util.Rng)
local GridMath = require(Shared.Util.GridMath)
local TrafficSim = require(Shared.Simulation.TrafficSim)
local ChunkGenerator = require(Shared.Simulation.ChunkGenerator)
local SafePathValidator = require(Shared.Simulation.SafePathValidator)
local Scoring = require(Shared.Simulation.Scoring)

local TestKit = require(script.Parent.TestKit)

local Phase2Tests = {}

local function floorHeadway(speed: number, lengthTiles: number): number
	return (lengthTiles * GameConfig.TILE + GameConfig.TILE * 1.6 + GameConfig.GAP_SAFETY) / speed
		+ GameConfig.REACTION
end

local function syntheticChunk(lane)
	local rows = {}
	for row = 100, 111 do
		rows[#rows + 1] = { row = row, kind = "median" }
	end
	rows[6] = { row = 105, kind = "road", lane = lane }

	return {
		v = 1,
		index = 0,
		startRow = 100,
		rowCount = 12,
		rows = rows,
		lanes = { lane },
		collectibles = {},
		validated = false,
		attempts = 1,
	}
end

function Phase2Tests.run()
	local world = WorldConfig.get(WorldConfig.DEFAULT)
	local startedAt = os.clock()

	TestKit.describe("Rng determinism", function()
		TestKit.it("same seed produces the same sequence", function()
			local a = Rng.new(1234567)
			local b = Rng.new(1234567)
			for _ = 1, 20 do
				TestKit.expectEqual(a:next(), b:next(), "sequence")
			end
		end)

		TestKit.it("different seeds diverge", function()
			local a = Rng.new(1)
			local b = Rng.new(2)
			local differs = false
			for _ = 1, 10 do
				if a:next() ~= b:next() then
					differs = true
				end
			end
			TestKit.expectTrue(differs, "two seeds produced identical streams")
		end)
	end)

	TestKit.describe("Grid maths", function()
		TestKit.it("tile to world conversion is exact", function()
			local position = GridMath.tileToLocal(2, 3)
			TestKit.expectEqual(position.X, 8, "x")
			TestKit.expectEqual(position.Z, -12, "z")
		end)

		TestKit.it("adjacency matches the direction table", function()
			local col, row = GridMath.targetTile(0, 0, "fwd")
			TestKit.expectEqual(col, 0, "col")
			TestKit.expectEqual(row, 1, "row")

			col, row = GridMath.targetTile(0, 5, "left")
			TestKit.expectEqual(col, -1, "left col")

			col, row = GridMath.targetTile(0, 5, "back")
			TestKit.expectEqual(row, 4, "back row")
		end)

		TestKit.it("column bounds are enforced", function()
			TestKit.expectTrue(GridMath.isValidTile(8, 0), "col 8 valid")
			TestKit.expectFalse(GridMath.isValidTile(9, 0), "col 9 invalid")
			TestKit.expectFalse(GridMath.isValidTile(0, -1), "row -1 invalid")
		end)
	end)

	TestKit.describe("Scoring", function()
		TestKit.it("rows dominate the score", function()
			TestKit.expectEqual(Scoring.compute({ rows = 10 }), 100, "ten rows")
			TestKit.expectEqual(Scoring.compute({ rows = 10, collectiblePoints = 5 }), 105, "with acorns")
			TestKit.expectEqual(Scoring.compute({ rows = 0 }), 0, "no progress")
		end)
	end)

	TestKit.describe("Traffic simulation", function()
		local lane = {
			type = "vehicle",
			row = 0,
			dir = 1,
			speed = 10,
			headway = 2,
			phase = 0,
			vehicleType = "compact",
			spanX = 60,
			overhang = 14,
		}

		TestKit.it("vehicle position is a pure function of time", function()
			local x1 = TrafficSim.vehicleAt(lane, 0, 7.4)
			local x2 = TrafficSim.vehicleAt(lane, 0, 7.4)
			TestKit.expectEqual(x1, x2, "determinism")

			local travel = TrafficSim.travelTime(lane)
			local atStart = TrafficSim.vehicleAt(lane, 0, 0)
			local atEnd = TrafficSim.vehicleAt(lane, 0, travel)
			TestKit.expectTrue(atStart < 0, "vehicle starts off-screen")
			TestKit.expectTrue(atEnd > 0, "vehicle exits the other side")
		end)

		TestKit.it("a vehicle overlaps the tile it is on", function()
			-- At 7.4s the first vehicle's centre is at x = 0, which is column 0.
			TestKit.expectTrue(TrafficSim.isHitAt(lane, 0, 0, 7.4), "should hit column 0")
			TestKit.expectFalse(TrafficSim.isHitAt(lane, 20, 0, 7.4), "should not hit column 5")
			TestKit.expectFalse(TrafficSim.isHitAt(lane, 0, -GameConfig.TILE, 7.4), "should not hit the next row")
		end)

		TestKit.it("tile safety covers the reaction margin", function()
			TestKit.expectFalse(TrafficSim.isTileSafe(lane, 0, 7.3, 0.3), "tile about to be occupied")
			TestKit.expectTrue(TrafficSim.isTileSafe(lane, 0, 0.2, 0.3), "tile long before the vehicle")
		end)
	end)

	TestKit.describe("Fairness guarantee", function()
		TestKit.it("a solid wall of traffic is rejected", function()
			local wall = syntheticChunk({
				type = "vehicle",
				row = 105,
				dir = 1,
				speed = 20,
				headway = 0.4, -- gap = 0.4 * 20 - 8 studs = 0
				phase = 0,
				vehicleType = "compact",
				spanX = 60,
				overhang = 14,
			})

			local survivable = SafePathValidator.validate(wall, world)
			TestKit.expectFalse(survivable, "validator accepted an unwinnable wall")
		end)

		TestKit.it("a wide gap in the same lane is accepted", function()
			local open = syntheticChunk({
				type = "vehicle",
				row = 105,
				dir = 1,
				speed = 20,
				headway = 3.0,
				phase = 0,
				vehicleType = "compact",
				spanX = 60,
				overhang = 14,
			})

			local survivable = SafePathValidator.validate(open, world)
			TestKit.expectTrue(survivable, "validator rejected a survivable lane")
		end)
	end)

	TestKit.describe(("Generated chunks (%d samples)"):format(GameConfig.TEST_CHUNK_SAMPLES), function()
		local samples = GameConfig.TEST_CHUNK_SAMPLES
		local generated = {}
		local unvalidated = 0
		local fallback = 0
		local headwayViolations = 0
		local widthViolations = 0
		local medianViolations = 0

		for index = 0, samples - 1 do
			local chunk = ChunkGenerator.generateValidated({
				seed = 987654 + index * 31,
				index = index,
				startRow = index * GameConfig.CHUNK_ROWS,
				world = world,
			})
			generated[#generated + 1] = chunk

			if not chunk.validated then
				unvalidated += 1
			end
			if chunk.attempts > 1 then
				fallback += 1
			end

			-- Every lane must clear the fairness floor.
			for _, lane in ipairs(chunk.lanes) do
				local def = GameConfig.VEHICLES[lane.vehicleType]
				local floor = floorHeadway(lane.speed, def.lengthTiles)
				if lane.headway < floor * 0.98 then
					headwayViolations += 1
				end
			end

			-- No corridor wider than MAX_CORRIDOR_LANES.
			local run = 0
			for _, rowDef in ipairs(chunk.rows) do
				if rowDef.kind == "road" then
					run += 1
					if run > GameConfig.MAX_CORRIDOR_LANES then
						widthViolations += 1
					end
				else
					run = 0
				end
			end

			-- Every chunk starts and ends on a median.
			local first = chunk.rows[1]
			local last = chunk.rows[#chunk.rows]
			if not first or first.kind ~= "median" or not last or last.kind ~= "median" then
				medianViolations += 1
			end
		end

		TestKit.it("every chunk validated", function()
			TestKit.expectEqual(unvalidated, 0, "unvalidated chunks")
		end)

		TestKit.it("headway never falls below the fairness floor", function()
			TestKit.expectEqual(headwayViolations, 0, "headway violations")
		end)

		TestKit.it("no corridor exceeds the lane cap", function()
			TestKit.expectEqual(widthViolations, 0, "corridor width violations")
		end)

		TestKit.it("every chunk starts and ends on a median", function()
			TestKit.expectEqual(medianViolations, 0, "median violations")
		end)

		TestKit.it("generation is deterministic for a given seed", function()
			local a = ChunkGenerator.generateValidated({
				seed = 424242,
				index = 3,
				startRow = 36,
				world = world,
			})
			local b = ChunkGenerator.generateValidated({
				seed = 424242,
				index = 3,
				startRow = 36,
				world = world,
			})

			TestKit.expectEqual(#a.rows, #b.rows, "row count")
			TestKit.expectEqual(#a.lanes, #b.lanes, "lane count")
			for index = 1, #a.lanes do
				TestKit.expectEqual(a.lanes[index].headway, b.lanes[index].headway, "lane headway")
				TestKit.expectEqual(a.lanes[index].phase, b.lanes[index].phase, "lane phase")
			end
		end)

		print(("[tests] generated %d chunks in %.0f ms (%d needed a retry)"):format(
			samples,
			(os.clock() - startedAt) * 1000,
			fallback
		))
	end)

	TestKit.report()
end

return Phase2Tests
