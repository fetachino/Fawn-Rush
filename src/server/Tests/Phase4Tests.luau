--!nonstrict
-- Phase 4 test suite: the world registry, selection, unlock rules, per-world generation, scenery
-- budgets, ambient effects, the graphics tier, and the asset manifest.
--
-- Runs after the Phase 2 and Phase 3 suites. Everything here is pure logic plus DataModel instance
-- creation; no client, no rendering, no Studio-only behaviour.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local WorldConfig = require(Shared.Config.WorldConfig)
local WorldKit = require(Shared.World.WorldKit)
local ChunkGenerator = require(Shared.Simulation.ChunkGenerator)
local SafePathValidator = require(Shared.Simulation.SafePathValidator)
local WorldUnlock = require(Shared.Simulation.WorldUnlock)
local GraphicsTier = require(Shared.Util.GraphicsTier)

local TestKit = require(script.Parent.TestKit)
local TestHelpers = require(script.Parent.TestHelpers)

local Phase4Tests = {}

local PLAYFIELD_EDGE = GameConfig.PLAYFIELD_MAX_COL * GameConfig.TILE
local SAMPLE_CHUNKS = 8

local KNOWN_STATUS = {
	procedural = true,
	todo = true,
	exported = true,
	"upload pending" = true,
	uploaded = true,
	verified = true,
	partial = true,
}

-- Every table in the manifest, however deeply nested.
local function walk(node, visit, seen)
	if type(node) ~= "table" then
		return
	end
	seen = seen or {}
	if seen[node] then
		return
	end
	seen[node] = true

	visit(node)
	for _, child in pairs(node) do
		walk(child, visit, seen)
	end
end

function Phase4Tests.run()
	TestKit.describe("World registry", function()
		TestKit.it("five worlds are registered and valid", function()
			TestKit.expectEqual(#WorldConfig.ORDER, 5, "world count")
			local problems = WorldConfig.validate()
			TestKit.expectEqual(#problems, 0, "config problems: " .. table.concat(problems, "; "))
		end)

		TestKit.it("the registry is ordered and the first world is free", function()
			local first = WorldConfig.worlds[WorldConfig.ORDER[1]]
			TestKit.expectTrue(first ~= nil, "the first world does not exist")
			TestKit.expectEqual(first.unlock.level, 1, "first world level requirement")
			TestKit.expectEqual(first.unlock.lifetimeRows or 0, 0, "first world row requirement")

			local previous = 0
			for _, world in ipairs(WorldConfig.list()) do
				TestKit.expectTrue(world.unlock.level > previous, world.id .. " does not increase the level gate")
				previous = world.unlock.level
			end
		end)

		TestKit.it("every world has a complete palette", function()
			for _, world in ipairs(WorldConfig.list()) do
				for _, key in ipairs({ "grass", "road", "line", "rock", "accent", "hazard", "collectible" }) do
					TestKit.expectTrue(typeof(world.colors[key]) == "Color3", world.id .. " is missing " .. key)
				end
			end
		end)

		-- Catches a copy-paste world: two worlds sharing a full difficulty signature are one world.
		TestKit.it("every world has a distinct difficulty signature", function()
			local signatures = {}
			for _, world in ipairs(WorldConfig.list()) do
				local laneWeights = table.concat(world.corridorWeightsEnd, ",")
				local vehicles = {}
				for _, entry in ipairs(world.vehicleWeights) do
					vehicles[#vehicles + 1] = entry.id .. ":" .. entry.weight
				end
				table.sort(vehicles)

				local signature = ("%.1f|%.1f|%d|%s|%d"):format(
					world.vMin,
					world.vMax,
					world.rampRows,
					laneWeights,
					#world.vehicleWeights
				)
				TestKit.expectTrue(signatures[signature] == nil, world.id .. " duplicates another world's difficulty")
				signatures[signature] = true

				_ = vehicles
			end
		end)

		TestKit.it("every configured prop kind has a builder", function()
			for _, world in ipairs(WorldConfig.list()) do
				for _, kind in ipairs(world.props.kinds) do
					TestKit.expectTrue(
						WorldKit.has(kind.id),
						("%s uses prop kind '%s' that WorldKit cannot build"):format(world.id, kind.id)
					)
				end
			end
		end)
	end)

	TestKit.describe("World selection", function()
		TestKit.it("next() cycles the registry and wraps", function()
			local seen = {}
			local current = WorldConfig.ORDER[1]
			for _ = 1, #WorldConfig.ORDER do
				TestKit.expectTrue(seen[current] == nil, "next() repeated a world")
				seen[current] = true
				current = WorldConfig.next(current)
			end
			TestKit.expectEqual(current, WorldConfig.ORDER[1], "next() did not wrap to the first world")
		end)

		TestKit.it("an unknown world falls back to the default", function()
			TestKit.expectEqual(WorldConfig.get("not_a_world").id, WorldConfig.DEFAULT, "fallback world")
			TestKit.expectEqual(WorldConfig.get(nil).id, WorldConfig.DEFAULT, "nil world id")
		end)

		TestKit.it("exists() is exact", function()
			for _, worldId in ipairs(WorldConfig.ORDER) do
				TestKit.expectTrue(WorldConfig.exists(worldId), worldId .. " should exist")
			end
			TestKit.expectFalse(WorldConfig.exists("greenwood2"), "a non-world must not exist")
			TestKit.expectFalse(WorldConfig.exists(nil), "nil must not exist")
		end)
	end)

	TestKit.describe("World unlock", function()
		TestKit.it("a brand new player can play exactly one world", function()
			local snapshot = WorldUnlock.snapshot(WorldUnlock.EMPTY_PROGRESS)
			TestKit.expectEqual(#snapshot, #WorldConfig.ORDER, "snapshot size")

			local unlocked = 0
			for _, entry in ipairs(snapshot) do
				if entry.unlocked then
					unlocked += 1
				end
			end
			TestKit.expectEqual(unlocked, 1, "worlds unlocked for a new player")
		end)

		TestKit.it("a qualifying profile unlocks a world and reports what is missing", function()
			local missingRows = WorldUnlock.evaluate("desert", { level = 12, lifetimeRows = 2999 })
			TestKit.expectFalse(missingRows, "desert should still be locked")

			local _, missingLevel, missingRowCount = WorldUnlock.evaluate("desert", { level = 12, lifetimeRows = 2999 })
			TestKit.expectEqual(missingLevel, 0, "missing level")
			TestKit.expectEqual(missingRowCount, 1, "missing rows")

			local fullyQualified = WorldUnlock.isUnlocked("desert", { level = 12, lifetimeRows = 3000 })
			TestKit.expectTrue(fullyQualified, "desert should unlock at the requirement")
		end)

		TestKit.it("a maxed profile unlocks every world, in order", function()
			local profile = { level = 99, lifetimeRows = 100000 }
			local snapshot = WorldUnlock.snapshot(profile)
			for index, entry in ipairs(snapshot) do
				TestKit.expectEqual(entry.id, WorldConfig.ORDER[index], "snapshot order")
				TestKit.expectTrue(entry.unlocked, entry.id .. " should be unlocked")
			end
		end)

		TestKit.it("an unknown world is never unlockable", function()
			TestKit.expectFalse(WorldUnlock.isUnlocked("not_a_world", { level = 99, lifetimeRows = 1e6 }), "unknown world")
		end)
	end)

	TestKit.describe("World generation", function()
		local summaries = {}

		for _, world in ipairs(WorldConfig.list()) do
			local validated, empty, lanes, obstacles = 0, 0, 0, 0
			local vehicleTypes = {}
			local allowed = {}
			for _, entry in ipairs(world.vehicleWeights) do
				allowed[entry.id] = true
			end

			for index = 0, SAMPLE_CHUNKS - 1 do
				local chunk = ChunkGenerator.generateValidated({
					seed = 90210 + index * 37,
					index = index,
					startRow = TestHelpers.deepStartRow(world, index),
					world = world,
				})

				if chunk.validated then
					validated += 1
				end
				if #chunk.lanes == 0 then
					empty += 1
				end

				lanes += #chunk.lanes
				obstacles += #(chunk.obstacles or {})

				for _, lane in ipairs(chunk.lanes) do
					if lane.type ~= "rail" then
						vehicleTypes[lane.vehicleType] = true
					end
				end
			end

			summaries[world.id] = {
				validated = validated,
				empty = empty,
				lanes = lanes,
				obstacles = obstacles,
				vehicleTypes = vehicleTypes,
				allowed = allowed,
			}
		end

		TestKit.it("every world produces validated chunks", function()
			for _, world in ipairs(WorldConfig.list()) do
				local summary = summaries[world.id]
				TestKit.expectEqual(summary.validated, SAMPLE_CHUNKS, world.id .. " unvalidated chunks")
			end
		end)

		TestKit.it("no world degenerates into the empty-strip fallback", function()
			for _, world in ipairs(WorldConfig.list()) do
				local summary = summaries[world.id]
				TestKit.expectTrue(
					summary.empty <= 1,
					("%s fell back to an empty strip %d times"):format(world.id, summary.empty)
				)
				TestKit.expectTrue(summary.lanes > 0, world.id .. " generated no lanes at all")
			end
		end)

		TestKit.it("every world generates hazards at depth", function()
			for _, world in ipairs(WorldConfig.list()) do
				TestKit.expectTrue(summaries[world.id].obstacles > 0, world.id .. " generated no hazards")
			end
		end)

		TestKit.it("a world only uses the vehicles it declares", function()
			for _, world in ipairs(WorldConfig.list()) do
				local summary = summaries[world.id]
				for vehicleType in pairs(summary.vehicleTypes) do
					TestKit.expectTrue(
						summary.allowed[vehicleType] == true,
						("%s generated a '%s' that its profile does not list"):format(world.id, vehicleType)
					)
				end
			end
		end)

		TestKit.it("generation is deterministic per world", function()
			for _, world in ipairs(WorldConfig.list()) do
				local a = ChunkGenerator.generateValidated({
					seed = 4242,
					index = 3,
					startRow = TestHelpers.deepStartRow(world, 3),
					world = world,
				})
				local b = ChunkGenerator.generateValidated({
					seed = 4242,
					index = 3,
					startRow = TestHelpers.deepStartRow(world, 3),
					world = world,
				})

				TestKit.expectEqual(
					TestHelpers.chunkSignature(a),
					TestHelpers.chunkSignature(b),
					world.id .. " is not deterministic"
				)
			end
		end)

		-- The fairness guarantee has to survive every profile, including Neon's 0.98 headway scaler.
		TestKit.it("every world's generated chunks pass the safe-path validator", function()
			for _, world in ipairs(WorldConfig.list()) do
				for index = 0, 3 do
					local chunk = ChunkGenerator.generate({
						seed = 777 + index,
						index = index,
						startRow = TestHelpers.deepStartRow(world, index),
						world = world,
					})
					local survivable = SafePathValidator.validate(chunk, world)
					TestKit.expectTrue(survivable, world.id .. " produced an unsurvivable raw chunk at index " .. index)
				end
			end
		end)
	end)

	TestKit.describe("World budget", function()
		TestKit.it("scenery never overlaps the playfield", function()
			for _, world in ipairs(WorldConfig.list()) do
				TestKit.expectTrue(
					world.props.bandMin > PLAYFIELD_EDGE,
					("%s places scenery at %d studs, inside the %d-stud playfield"):format(
						world.id,
						world.props.bandMin,
						PLAYFIELD_EDGE
					)
				)
			end
		end)

		TestKit.it("the worst-case prop count stays within the hard cap", function()
			for _, world in ipairs(WorldConfig.list()) do
				local requested = world.props.perRow * GameConfig.CHUNK_ROWS
				TestKit.expectTrue(
					requested <= GameConfig.MAX_PROPS_PER_CHUNK,
					("%s requests %d props per chunk, above the %d cap"):format(
						world.id,
						requested,
						GameConfig.MAX_PROPS_PER_CHUNK
					)
				)
			end
			TestKit.expectTrue(GameConfig.MAX_PROPS_PER_CHUNK <= 64, "the prop cap is too high for mobile")
		end)

		TestKit.it("ambient effect rates stay within the mobile budget", function()
			for _, world in ipairs(WorldConfig.list()) do
				local ambient = world.effects and world.effects.ambient
				if ambient then
					TestKit.expectTrue(ambient.rate <= 30, world.id .. " ambient rate is too high")
				end
			end
		end)

		TestKit.it("no world switches lighting off entirely", function()
			for _, world in ipairs(WorldConfig.list()) do
				local lighting = world.lighting
				TestKit.expectTrue(lighting.brightness > 0, world.id .. " has no brightness")
				TestKit.expectTrue(lighting.fogEnd > 1000, world.id .. " fog would hide the road")
			end
		end)
	end)

	TestKit.describe("Graphics tier", function()
		TestKit.it("every tier keeps some ambience", function()
			for _, tier in ipairs({ GraphicsTier.LOW, GraphicsTier.MEDIUM, GraphicsTier.HIGH }) do
				TestKit.expectTrue(GraphicsTier.rateScale(tier) > 0, tier .. " silences all effects")
				TestKit.expectTrue(GraphicsTier.rateScale(tier) <= 1, tier .. " amplifies effects")
			end
		end)

		TestKit.it("accents are dropped only on the lowest tier", function()
			TestKit.expectFalse(GraphicsTier.allowAccents(GraphicsTier.LOW), "low tier should drop accents")
			TestKit.expectTrue(GraphicsTier.allowAccents(GraphicsTier.MEDIUM), "medium tier should keep accents")
			TestKit.expectTrue(GraphicsTier.allowAccents(GraphicsTier.HIGH), "high tier should keep accents")
		end)
	end)

	TestKit.describe("Missing asset handling", function()
		TestKit.it("an unknown prop kind is skipped, not raised", function()
			local folder = Instance.new("Folder")
			folder.Name = "Phase4PropTest"

			TestKit.expectFalse(WorldKit.has("definitelyNotAProp"), "unknown kind reported as known")
			local model = WorldKit.prop(folder, "definitelyNotAProp", Vector3.zero, 1, WorldConfig.BASE_PALETTE, 1)
			TestKit.expectTrue(model == nil, "an unknown kind built something")

			folder:Destroy()
		end)

		TestKit.it("a known prop kind builds and parents", function()
			local folder = Instance.new("Folder")
			folder.Name = "Phase4PropTest"
			local model = WorldKit.prop(folder, "tree", Vector3.zero, 1, WorldConfig.BASE_PALETTE, 1)

			TestKit.expectTrue(model ~= nil, "tree did not build")
			TestKit.expectTrue(#model:GetChildren() >= 3, "tree built too few parts")

			folder:Destroy()
		end)
	end)

	TestKit.describe("Asset manifest", function()
		local manifest = ServerStorage:FindFirstChild("Manifest")

		TestKit.it("the manifest is mapped and declares every world", function()
			TestKit.expectTrue(manifest ~= nil, "ServerStorage.Manifest is missing — is default.project.json synced?")
			if not manifest then
				return
			end

			local data = require(manifest)
			TestKit.expectTrue(type(data) == "table", "the manifest is not a table")

			for _, worldId in ipairs(WorldConfig.ORDER) do
				TestKit.expectTrue(
					type(data.worlds) == "table" and data.worlds[worldId] ~= nil,
					"the manifest does not declare world '" .. worldId .. "'"
				)
			end
		end)

		TestKit.it("every prop kind is named in the manifest", function()
			if not manifest then
				return
			end
			local data = require(manifest)
			local byKind = (data.environment or {}).byKind
			TestKit.expectTrue(type(byKind) == "table", "the manifest has no environment.byKind")

			for _, world in ipairs(WorldConfig.list()) do
				for _, kind in ipairs(world.props.kinds) do
					TestKit.expectTrue(
						byKind[kind.id] ~= nil,
						("%s prop kind '%s' has no manifest entry"):format(world.id, kind.id)
					)
				end
			end
		end)

		TestKit.it("no manifest asset carries an invented id", function()
			if not manifest then
				return
			end
			local data = require(manifest)

			walk(data, function(node)
				local id = node.robloxId
				if id == nil then
					return
				end
				if id == "" then
					return
				end

				-- A real id is a positive integer. "0", "abc" and a table are all failures.
				local numeric = tonumber(id)
				TestKit.expectTrue(
					type(numeric) == "number" and numeric > 0 and tostring(numeric) == tostring(id),
					"a manifest asset has a fabricated id: " .. tostring(id)
				)
			end)
		end)

		TestKit.it("every declared status is from the documented set", function()
			if not manifest then
				return
			end
			local data = require(manifest)

			walk(data, function(node)
				local status = node.status
				if type(status) ~= "string" then
					return
				end
				TestKit.expectTrue(KNOWN_STATUS[status] == true, "unknown manifest status '" .. status .. "'")
			end)
		end)
	end)

	TestKit.report()
end

return Phase4Tests
