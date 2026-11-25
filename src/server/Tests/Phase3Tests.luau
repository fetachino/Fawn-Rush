--!nonstrict
-- Phase 3 test suite: animal cast integrity, rig contract, animation state machine, near misses,
-- combos, obstacles, hazard-aware generation, lobby presence ownership and the chunk wire format.
--
-- Runs on server boot in Studio after the Phase 2 suite. Nothing here claims to prove the game
-- looks right — that needs eyes on a screen. It proves the data and the pure logic are consistent.
--
-- The Phase 3 closure audit strengthened several assertions that only proved a module returned
-- *something* (a pose with one joint, a chunk with a version field) so they now prove *behaviour*
-- (real joint coverage, finite angles, a real train crossing window, a real detour width, wildlife
-- placement rules). A weak assertion is worse than none: it reads as coverage.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local HazardConfig = require(Shared.Config.HazardConfig)
local AnimalConfig = require(Shared.Config.AnimalConfig)
local AnimalBuilder = require(Shared.Builders.AnimalBuilder)
local AnimationLib = require(Shared.Animation.AnimationLib)
local Animator = require(Shared.Animation.Animator)
local ChunkFormat = require(Shared.Simulation.ChunkFormat)
local ChunkGenerator = require(Shared.Simulation.ChunkGenerator)
local Combo = require(Shared.Simulation.Combo)
local NearMiss = require(Shared.Simulation.NearMiss)
local ObstacleSim = require(Shared.Simulation.ObstacleSim)
local PresenceRules = require(Shared.Simulation.PresenceRules)
local WorldConfig = require(Shared.Config.WorldConfig)

local TestKit = require(script.Parent.TestKit)

local Phase3Tests = {}

local TILE = GameConfig.TILE
local PLAYFIELD_COLUMNS = GameConfig.PLAYFIELD_MAX_COL - GameConfig.PLAYFIELD_MIN_COL + 1

local function syntheticLane(overrides)
	local lane = {
		type = "vehicle",
		row = 0,
		dir = 1,
		speed = 10,
		headway = 5,
		phase = 0,
		vehicleType = "compact",
		spanX = 60,
		overhang = 14,
	}
	for key, value in pairs(overrides or {}) do
		lane[key] = value
	end
	return lane
end

-- Stable text signature of a whole chunk, so determinism covers parameters and not just counts.
local function chunkSignature(chunk)
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

-- First rail lane the generator produces, or nil if it produced none in the sample.
local function findRailLane(world)
	for index = 0, 23 do
		local chunk = ChunkGenerator.generateValidated({
			seed = 8123 + index * 31,
			index = index,
			startRow = 420 + index * GameConfig.CHUNK_ROWS,
			world = world,
		})
		for _, lane in ipairs(chunk.lanes) do
			if lane.type == "rail" then
				return lane
			end
		end
	end
	return nil
end

function Phase3Tests.run()
	local world = WorldConfig.get(WorldConfig.DEFAULT)

	TestKit.describe("Animal cast", function()
		TestKit.it("thirteen animals are registered and valid", function()
			TestKit.expectEqual(#AnimalConfig.ORDER, 13, "animal count")
			local problems = AnimalConfig.validate()
			TestKit.expectEqual(#problems, 0, "config problems: " .. table.concat(problems, "; "))
		end)

		TestKit.it("every rarity tier is represented", function()
			local seen = {}
			for _, animalId in ipairs(AnimalConfig.ORDER) do
				seen[AnimalConfig.animals[animalId].rarity] = true
			end
			for rarity in pairs(AnimalConfig.RARITY) do
				TestKit.expectTrue(seen[rarity] == true, "no animal of rarity " .. rarity)
			end
		end)

		TestKit.it("proportions are genuinely distinct, not recolours", function()
			local signatures = {}
			for _, animalId in ipairs(AnimalConfig.ORDER) do
				local build = AnimalConfig.animals[animalId].build
				local signature = ("%.2f|%.2f|%.2f|%.2f"):format(
					build.bodyLength,
					build.legLength,
					build.headSize,
					build.earLength
				)
				TestKit.expectTrue(signatures[signature] == nil, "duplicate proportions on " .. animalId)
				signatures[signature] = true
			end
		end)

		-- Pins the roster the design actually ships: the twelve animals in the original brief plus
		-- one Secret-tier animal. docs/01 §9.1 lists all thirteen; this keeps config and docs aligned.
		TestKit.it("the roster is twelve collectable animals plus one secret", function()
			local secret = 0
			for _, animalId in ipairs(AnimalConfig.ORDER) do
				if AnimalConfig.animals[animalId].rarity == "Secret" then
					secret += 1
				end
			end
			TestKit.expectEqual(#AnimalConfig.ORDER - secret, 12, "collectable animals")
			TestKit.expectEqual(secret, 1, "secret animals")
		end)
	end)

	TestKit.describe("Rig contract", function()
		TestKit.it("a rig carries the joints the animation system needs", function()
			local rig = AnimalBuilder.buildRig("deer")
			for _, name in ipairs({ "Torso", "Head", "Tail", "LegFL", "LegFR", "LegBL", "LegBR", "EarL", "EarR" }) do
				TestKit.expectTrue(rig.joints[name] ~= nil, "missing joint " .. name)
			end
			TestKit.expectTrue(rig.model.PrimaryPart ~= nil, "model has no PrimaryPart")
			rig.model:Destroy()
		end)

		TestKit.it("every joint has a part, a base CFrame and a pivot", function()
			local rig = AnimalBuilder.buildRig("rabbit")
			for name, joint in pairs(rig.joints) do
				TestKit.expectTrue(joint.part ~= nil, name .. " has no part")
				TestKit.expectTrue(typeof(joint.base) == "CFrame", name .. " has no base CFrame")
				TestKit.expectTrue(typeof(joint.pivot) == "Vector3", name .. " has no pivot")
			end
			rig.model:Destroy()
		end)

		TestKit.it("hooves follow their leg joint", function()
			local rig = AnimalBuilder.buildRig("deer")
			TestKit.expectEqual(rig.joints.HoofFL.follow, "LegFL", "hoof follow target")
			rig.model:Destroy()
		end)

		TestKit.it("all thirteen species build without error", function()
			for _, animalId in ipairs(AnimalConfig.ORDER) do
				local rig = AnimalBuilder.buildRig(animalId)
				TestKit.expectTrue(rig.height > 0.5, animalId .. " has no height")
				-- A rig with only a torso would pass a height check and still fail to animate.
				TestKit.expectTrue(#rig.model:GetChildren() >= 12, animalId .. " built too few parts")
				rig.model:Destroy()
			end
		end)
	end)

	TestKit.describe("Animation", function()
		-- Replaces "a pose is not empty": a state that posed one joint would have passed that.
		TestKit.it("every state poses a core joint and at least three joints", function()
			local animal = AnimalConfig.get("deer")
			for _, state in ipairs(AnimationLib.STATES) do
				local pose = AnimationLib.sample(state, 0.3, animal, AnimationLib.newPose())

				local count = 0
				for _ in pairs(pose) do
					count += 1
				end

				TestKit.expectTrue(count >= 3, state .. " posed only " .. count .. " joints")
				TestKit.expectTrue(pose.Torso ~= nil or pose.Head ~= nil, state .. " posed no core joint")
			end
		end)

		-- A NaN anywhere in a pose silently blanks the rig on screen, so it is checked per axis.
		TestKit.it("every state produces finite joint angles", function()
			local animal = AnimalConfig.get("deer")
			local times = { 0, 0.05, 0.3, 1.2, 3.0 }

			for _, state in ipairs(AnimationLib.STATES) do
				for _, t in ipairs(times) do
					local pose = AnimationLib.sample(state, t, animal, AnimationLib.newPose())
					for name, rotation in pairs(pose) do
						for axis = 1, 3 do
							local value = rotation[axis]
							local ok = type(value) == "number" and value == value and math.abs(value) < 1e6
							TestKit.expectTrue(
								ok,
								("%s at t=%.2f produced a bad angle on %s[%d]"):format(state, t, name, axis)
							)
						end
					end
				end
			end
		end)

		TestKit.it("an unknown state falls back to idle", function()
			local animal = AnimalConfig.get("deer")
			local fallback = AnimationLib.sample("not_a_state", 0.3, animal, AnimationLib.newPose())
			local idle = AnimationLib.sample("idle", 0.3, animal, AnimationLib.newPose())

			TestKit.expectTrue(fallback.Torso ~= nil, "fallback posed no torso")
			TestKit.expectTrue(idle.Torso ~= nil, "idle posed no torso")
			for axis = 1, 3 do
				TestKit.expectEqual(fallback.Torso[axis], idle.Torso[axis], "fallback torso axis " .. axis)
			end
		end)

		TestKit.it("death outranks running and locks the machine", function()
			local animator = Animator.new(AnimalConfig.get("deer"))
			animator:request("run")
			TestKit.expectEqual(animator.state, "run", "state after run")

			animator:request("death")
			TestKit.expectEqual(animator.state, "death", "state after death")

			animator:update(0.02, { running = true })
			TestKit.expectEqual(animator.state, "death", "death must not be interrupted by movement")
		end)

		TestKit.it("a sticky state holds for its duration", function()
			local animator = Animator.new(AnimalConfig.get("deer"))
			animator:request("stumble")
			animator:update(0.05, { running = true })
			TestKit.expectEqual(animator.state, "stumble", "stumble must hold while locked")

			for _ = 1, 20 do
				animator:update(0.02, { running = true })
			end
			TestKit.expectEqual(animator.state, "run", "stumble should release after its duration")
		end)

		TestKit.it("sampling blends without error at every blend value", function()
			local animator = Animator.new(AnimalConfig.get("duck"))
			animator:request("walk")
			for _ = 1, 12 do
				animator:update(0.016, { walking = true })
				local pose = animator:sample()
				TestKit.expectTrue(pose ~= nil, "sample returned nil")
			end
		end)
	end)

	TestKit.describe("Combo", function()
		TestKit.it("the ladder climbs and clamps", function()
			local combo = Combo.new()
			local expected = GameConfig.COMBO_STEPS
			for hits = 1, #expected do
				TestKit.expectEqual(Combo.register(combo, 10), expected[hits], "multiplier at " .. hits)
			end
			TestKit.expectEqual(Combo.register(combo, 10), expected[#expected], "multiplier past the cap")
		end)

		TestKit.it("decays to one after the decay window", function()
			local combo = Combo.new()
			Combo.register(combo, 100)
			Combo.register(combo, 100)
			TestKit.expectTrue(Combo.current(combo, 101) > 1.2, "should still be multiplied")
			TestKit.expectEqual(Combo.current(combo, 100 + GameConfig.COMBO_DECAY + 0.1), 1.0, "should decay")
		end)

		TestKit.it("rewards are capped", function()
			TestKit.expectEqual(Combo.acornReward(1.0), GameConfig.NEAR_MISS_ACORNS, "base acorns")
			TestKit.expectTrue(Combo.acornReward(10) <= GameConfig.NEAR_MISS_ACORNS_CAP, "acorn cap")
		end)
	end)

	TestKit.describe("Near miss", function()
		TestKit.it("a close pass qualifies and a distant one does not", function()
			local lane = syntheticLane()

			-- The vehicle's centre reaches x = 6 studs at t = 8.0, which is 1.1 studs from contact.
			local closeGap = NearMiss.clearance(lane, 0, 0, 8.0)
			TestKit.expectTrue(NearMiss.qualifies(closeGap), "close pass should qualify: " .. tostring(closeGap))

			local farGap = NearMiss.clearance(lane, 0, 0, 8.5)
			TestKit.expectFalse(NearMiss.qualifies(farGap), "distant pass should not qualify: " .. tostring(farGap))
		end)

		TestKit.it("standing in a different lane cannot produce one", function()
			local lane = syntheticLane()
			local gap = NearMiss.clearance(lane, 0, -TILE, 8.0)
			TestKit.expectTrue(gap == math.huge, "wrong lane should report no clearance")
		end)

		TestKit.it("an actual overlap is not a near miss", function()
			local lane = syntheticLane()
			local gap = NearMiss.clearance(lane, 0, 0, 7.4)
			TestKit.expectFalse(NearMiss.qualifies(gap), "overlap must not award")
		end)

		-- The boundary decides whether a reward is granted, so it is pinned rather than assumed.
		TestKit.it("the threshold is inclusive at the limit and exclusive above it", function()
			local limit = NearMiss.thresholdStuds()
			TestKit.expectTrue(NearMiss.qualifies(limit), "exactly at the limit must qualify")
			TestKit.expectFalse(NearMiss.qualifies(limit + 0.0001), "just past the limit must not")
			TestKit.expectFalse(NearMiss.qualifies(0), "zero clearance is a contact, not a near miss")
		end)
	end)

	TestKit.describe("Obstacles", function()
		TestKit.it("barriers are found by tile", function()
			local index = ObstacleSim.buildIndex({
				obstacles = { { kind = "barrier", row = 5, col = 2 } },
			})
			TestKit.expectTrue(ObstacleSim.isBarrier(index, 5, 2), "barrier at 5,2")
			TestKit.expectFalse(ObstacleSim.isBarrier(index, 5, 3), "no barrier at 5,3")
		end)

		TestKit.it("wildlife crosses on a closed-form period", function()
			local obstacle = { kind = "wildlife", row = 3, phase = 0, period = 10, dir = 1 }
			TestKit.expectEqual(ObstacleSim.wildlifeX(obstacle, 0), -HazardConfig.wildlife.spanX, "start")
			TestKit.expectEqual(ObstacleSim.wildlifeX(obstacle, 5), 0, "midpoint")
			TestKit.expectEqual(ObstacleSim.wildlifeX(obstacle, 10), -HazardConfig.wildlife.spanX, "loop")
		end)

		TestKit.it("a static barrier always blocks its tile", function()
			local index = ObstacleSim.buildIndex({
				obstacles = { { kind = "barrier", row = 7, col = -1 } },
			})
			TestKit.expectTrue(ObstacleSim.isTileBlocked(index, 7, -1, 0, 0.25), "blocked tile")
			TestKit.expectFalse(ObstacleSim.isTileBlocked(index, 7, 0, 0, 0.25), "free tile")
		end)

		-- `halfLength` was configured but ignored before the audit: the row was rounded to an integer
		-- and the body's depth never entered the test. This pins both axes.
		TestKit.it("a crosser only hits on its own row", function()
			local index = ObstacleSim.buildIndex({
				obstacles = {
					{ kind = "wildlife", row = 5, species = "squirrel", phase = 0, period = 10, dir = 1 },
				},
			})

			-- At elapsed 5 the crosser sits at x = 0, the midpoint of its sweep.
			local onRow = ObstacleSim.wildlifeHit(index, 0, -5 * TILE, 5)
			TestKit.expectTrue(onRow ~= nil, "crosser should hit on its own row")

			local farRow = ObstacleSim.wildlifeHit(index, 0, -9 * TILE, 5)
			TestKit.expectTrue(farRow == nil, "crosser must not reach four rows away")

			local across = ObstacleSim.wildlifeHit(index, 20, -5 * TILE, 5)
			TestKit.expectTrue(across == nil, "crosser must not hit across the road")
		end)
	end)

	TestKit.describe("Hazard generation", function()
		local samples = 40
		local rails = 0
		local barriers = 0
		local wildlifeCount = 0
		local unvalidated = 0
		local emptyFallbacks = 0
		local barrierRowViolations = 0
		local narrowDetours = 0
		local railRowSharing = 0
		local graceViolations = 0
		local finalRowViolations = 0
		local speedMismatches = 0
		local firstWildlife = nil

		local grace = HazardConfig.wildlife.entryGraceRows
		local speedTolerance = 1e-6

		for index = 0, samples - 1 do
			-- Start deep into the run so the hazard gates are open.
			local chunk = ChunkGenerator.generateValidated({
				seed = 5150 + index * 17,
				index = index,
				startRow = 400 + index * GameConfig.CHUNK_ROWS,
				world = world,
			})

			if not chunk.validated then
				unvalidated += 1
			end
			if #chunk.lanes == 0 then
				emptyFallbacks += 1
			end

			local railRows = {}
			for _, rowDef in ipairs(chunk.rows) do
				if rowDef.kind == "rail" then
					railRows[rowDef.row] = true
				end
			end

			for _, lane in ipairs(chunk.lanes) do
				if lane.type == "rail" then
					rails += 1
				end
			end

			local perRow = {}
			local lastRow = chunk.startRow + chunk.rowCount - 1

			for _, obstacle in ipairs(chunk.obstacles or {}) do
				if obstacle.kind == "barrier" then
					barriers += 1
					perRow[obstacle.row] = (perRow[obstacle.row] or 0) + 1
				elseif obstacle.kind == "wildlife" then
					wildlifeCount += 1
					if not firstWildlife then
						firstWildlife = obstacle
					end

					if railRows[obstacle.row] then
						railRowSharing += 1
					end
					if obstacle.row < chunk.startRow + grace then
						graceViolations += 1
					end
					if obstacle.row >= lastRow then
						finalRowViolations += 1
					end

					local derived = ObstacleSim.wildlifeSpeed(obstacle)
					if
						math.abs(derived - (obstacle.speed or derived)) > speedTolerance
						or derived < HazardConfig.wildlife.speedMin - speedTolerance
						or derived > HazardConfig.wildlife.speedMax + speedTolerance
					then
						speedMismatches += 1
					end
				end
			end

			for _, count in pairs(perRow) do
				if count > HazardConfig.closure.maxPerRow then
					barrierRowViolations += 1
				end
				if PLAYFIELD_COLUMNS - count < HazardConfig.closure.minClearColumns then
					narrowDetours += 1
				end
			end
		end

		TestKit.it("every sampled chunk is survivable without the emergency fallback", function()
			TestKit.expectEqual(unvalidated, 0, "unvalidated chunks")
			TestKit.expectEqual(emptyFallbacks, 0, "chunks that fell back to an empty median strip")
		end)

		TestKit.it("rails, closures and wildlife all appear at depth", function()
			TestKit.expectTrue(rails > 0, "no rail corridors generated")
			TestKit.expectTrue(barriers > 0, "no closures generated")
			TestKit.expectTrue(wildlifeCount > 0, "no wildlife generated")
		end)

		TestKit.it("closures never exceed the per-row limit", function()
			TestKit.expectEqual(barrierRowViolations, 0, "rows over the limit")
		end)

		-- Replaces a check against a hard-coded "sealed" threshold of 15, which could never fire.
		TestKit.it("every barrier row keeps a wide detour", function()
			TestKit.expectEqual(narrowDetours, 0, "rows with too little clear width")
			TestKit.expectTrue(
				PLAYFIELD_COLUMNS - HazardConfig.closure.maxPerRow >= HazardConfig.closure.minClearColumns,
				"the configured closure limit could seal the field"
			)
		end)

		TestKit.it("wildlife never shares a row with a train", function()
			TestKit.expectEqual(railRowSharing, 0, "wildlife placed on rail rows")
		end)

		TestKit.it("wildlife never appears in a chunk's entry grace rows", function()
			TestKit.expectEqual(graceViolations, 0, "wildlife inside the entry grace")
		end)

		TestKit.it("wildlife never appears on a chunk's final row", function()
			TestKit.expectEqual(finalRowViolations, 0, "wildlife on the junction median")
		end)

		TestKit.it("wildlife speed always matches its cycle", function()
			TestKit.expectTrue(firstWildlife ~= nil, "no wildlife to measure")
			TestKit.expectEqual(speedMismatches, 0, "crossers outside the configured speed range")
		end)

		TestKit.it("hazard generation is deterministic", function()
			local a = ChunkGenerator.generateValidated({
				seed = 777,
				index = 2,
				startRow = 300,
				world = world,
			})
			local b = ChunkGenerator.generateValidated({
				seed = 777,
				index = 2,
				startRow = 300,
				world = world,
			})

			-- Full signature, not just counts: lane speed/headway/phase and obstacle placement are
			-- what a client re-derives, so any drift there is a real server/client divergence.
			TestKit.expectEqual(chunkSignature(a), chunkSignature(b), "chunk signature")
		end)
	end)

	TestKit.describe("Hazard tuning", function()
		-- Replaces a tautology that compared a config constant with itself. This measures the
		-- crossing window of a lane the generator actually produced.
		TestKit.it("a generated train lane always leaves a crossable window", function()
			local railLane = findRailLane(world)
			TestKit.expectTrue(railLane ~= nil, "no train lane was generated to measure")
			if not railLane then
				return
			end

			local def = GameConfig.VEHICLES[railLane.vehicleType]
			local bodyStuds = def.lengthTiles * TILE + 2 * (GameConfig.PLAYER_HALF_X + GameConfig.CONTACT_PAD_X)
			local blocked = bodyStuds / railLane.speed
			local window = railLane.headway - blocked

			TestKit.expectTrue(
				window >= GameConfig.REACTION,
				("train window %.2fs is below the %.2fs reaction floor"):format(window, GameConfig.REACTION)
			)
		end)

		TestKit.it("playfield math leaves room for closures", function()
			TestKit.expectTrue(
				PLAYFIELD_COLUMNS - HazardConfig.closure.maxPerRow >= HazardConfig.closure.minClearColumns,
				"closures could seal the field"
			)
		end)
	end)

	-- Closes docs/12 S3 with a truth table rather than a manual workaround.
	TestKit.describe("Lobby presence", function()
		TestKit.it("a client never renders its own lobby model", function()
			TestKit.expectFalse(PresenceRules.shouldRender(42, false, 42), "own model")
			TestKit.expectTrue(PresenceRules.shouldRender(7, false, 42), "another player's model")
		end)

		TestKit.it("a player's lobby model hides while they run", function()
			TestKit.expectFalse(PresenceRules.shouldRender(7, true, 42), "another player running")
			TestKit.expectFalse(PresenceRules.shouldRender(42, true, 42), "own model while running")
		end)

		TestKit.it("a model with no owner is never rendered", function()
			TestKit.expectFalse(PresenceRules.shouldRender(nil, false, 42), "unowned model")
			TestKit.expectFalse(PresenceRules.shouldRender("42", false, 42), "malformed owner")
		end)
	end)

	TestKit.describe("Chunk format", function()
		TestKit.it("generated chunks carry the current version", function()
			local chunk = ChunkGenerator.generateValidated({
				seed = 99,
				index = 0,
				startRow = 40,
				world = world,
			})
			TestKit.expectEqual(chunk.v, ChunkFormat.VERSION, "chunk version")
		end)

		TestKit.it("older and malformed versions are handled", function()
			TestKit.expectTrue(ChunkFormat.isSupported(1), "v1 must remain readable")
			TestKit.expectTrue(ChunkFormat.isSupported(nil), "a chunk with no version is v1")
			TestKit.expectTrue(ChunkFormat.isSupported(ChunkFormat.VERSION), "current version")
			TestKit.expectFalse(ChunkFormat.isSupported(ChunkFormat.VERSION + 1), "a future version must be refused")
			TestKit.expectFalse(ChunkFormat.isSupported("garbage"), "a non-numeric version must not crash")
		end)
	end)

	TestKit.report()
end

return Phase3Tests
