--!nonstrict
-- Phase 5 UI contracts: design tokens, safe-band geometry, responsive classes, and the real catalog data.
-- These code-level checks do not claim that the UI has been rendered or device-verified.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UIConfig = require(Shared.Config.UIConfig)
local AnimalConfig = require(Shared.Config.AnimalConfig)
local WorldConfig = require(Shared.Config.WorldConfig)
local PreviewBudget = require(Shared.Util.PreviewBudget)
local TestKit = require(script.Parent.TestKit)

local Phase5Tests = {}

function Phase5Tests.run()
	TestKit.describe("Phase 5 UI design system", function()
		TestKit.it("tokens satisfy contrast, type, spacing and preview-budget validation", function()
			local problems = UIConfig.validate()
			TestKit.expectEqual(#problems, 0, "UI token validation: " .. table.concat(problems, "; "))
		end)

		TestKit.it("contrast locks meet their specified WCAG thresholds", function()
			local colors = UIConfig.colors
			TestKit.expectAtLeast(UIConfig.contrastRatio(colors.inkHigh, colors.bgBase), 7, "primary text contrast")
			TestKit.expectAtLeast(UIConfig.contrastRatio(colors.inkMid, colors.surface1), 4.5, "secondary text contrast")
			TestKit.expectAtLeast(UIConfig.contrastRatio(colors.bark, colors.gold), 4.5, "gold button text contrast")
			TestKit.expectAtLeast(UIConfig.contrastRatio(colors.white, colors.danger), 4.5, "danger text contrast")
		end)

		TestKit.it("currency formatting groups values and abbreviates only large amounts", function()
			TestKit.expectEqual(UIConfig.formatNumber(0), "0", "zero")
			TestKit.expectEqual(UIConfig.formatNumber(1234), "1,234", "grouped value")
			TestKit.expectEqual(UIConfig.formatNumber(12000), "12.0K", "thousands abbreviation")
			TestKit.expectEqual(UIConfig.formatNumber(2500000), "2.5M", "millions abbreviation")
			TestKit.expectEqual(UIConfig.formatNumber(-1234), "-1,234", "negative formatting")
		end)

		TestKit.it("responsive breakpoints cover compact, regular and expanded heights", function()
			TestKit.expectEqual(UIConfig.breakpointFor(Vector2.new(844, 390)), "compact", "landscape phone")
			TestKit.expectEqual(UIConfig.breakpointFor(Vector2.new(390, 844)), "expanded", "portrait phone")
			TestKit.expectEqual(UIConfig.breakpointFor(Vector2.new(1280, 600)), "regular", "short tablet")
		end)

		TestKit.it("HUD layout rectangles stay on-screen and outside the protected band", function()
			local scenarios = {
				{ viewport = Vector2.new(1920, 1080) },
				{ viewport = Vector2.new(2535, 1170) },
				{ viewport = Vector2.new(1024, 768) },
				{ viewport = Vector2.new(1440, 960) },
				{ viewport = Vector2.new(2520, 1080) },
				{ viewport = Vector2.new(390, 844) },
				{ viewport = Vector2.new(844, 390) },
				{ viewport = Vector2.new(390, 844), insets = { left = 0, top = 44, right = 0, bottom = 32 } },
				{ viewport = Vector2.new(320, 400) },
			}
			local function overlaps(first, second)
				return first.x < second.x + second.width
					and second.x < first.x + first.width
					and first.y < second.y + second.height
					and second.y < first.y + first.height
			end

			for index, scenario in ipairs(scenarios) do
				local viewport = scenario.viewport
				local layout = UIConfig.hudLayout(viewport, true, scenario.insets)
				for name, rect in pairs(layout.rects) do
					local label = (name .. " at scenario " .. index)
					TestKit.expectTrue(UIConfig.hudRectIsOutsideProtectedBand(rect, viewport), label .. " crosses the protected road band")
					TestKit.expectTrue(rect.x >= 0 and rect.y >= 0, label .. " starts off-screen")
					TestKit.expectTrue(rect.x + rect.width <= viewport.X + 0.5, label .. " exceeds the right edge")
					TestKit.expectTrue(rect.y + rect.height <= viewport.Y + 0.5, label .. " exceeds the bottom edge")
				end
				if layout.portrait then
					local guidance = layout.rects.rotateGuidance
					TestKit.expectTrue(guidance ~= nil and guidance.width > 0, "portrait rotate guidance is missing at scenario " .. index)
					TestKit.expectFalse(overlaps(guidance, layout.rects.score), "rotate guidance overlaps score at scenario " .. index)
					TestKit.expectFalse(overlaps(guidance, layout.rects.acorns), "rotate guidance overlaps acorns at scenario " .. index)
					TestKit.expectFalse(overlaps(guidance, layout.rects.combo), "rotate guidance overlaps combo at scenario " .. index)
				else
					TestKit.expectEqual(layout.rects.rotateGuidance, nil, "landscape shows portrait guidance at scenario " .. index)
				end
				TestKit.expectTrue(layout.padButtonSize * layout.scale >= 44, "touch pad target below 44 px at scenario " .. index)
				TestKit.expectTrue(layout.jumpSize * layout.scale >= 44, "jump target below 44 px at scenario " .. index)
			end
		end)

		TestKit.it("the protected-band guard rejects persistent content in the road", function()
			local viewport = Vector2.new(390, 844)
			TestKit.expectFalse(UIConfig.hudRectIsOutsideProtectedBand({ y = 844 * 0.40, height = 844 * 0.08 }, viewport), "middle overlay was accepted")
			TestKit.expectFalse(UIConfig.hudRectIsOutsideProtectedBand({ y = -1, height = 20 }, viewport), "negative top was accepted")
		end)

		TestKit.it("all seven rarity tiers have distinct non-colour shapes", function()
			local seen = {}
			local count = 0
			for rarity, shape in pairs(UIConfig.rarityShapes) do
				TestKit.expectTrue(type(shape) == "string" and shape ~= "", rarity .. " has no shape")
				TestKit.expectFalse(seen[shape] == true, rarity .. " duplicates a rarity shape")
				seen[shape] = true
				count += 1
			end
			TestKit.expectEqual(count, 7, "rarity shape count")
		end)

		TestKit.it("preview leases enforce the cap and release idempotently", function()
			local budget = PreviewBudget.new(UIConfig.preview.maxLiveModels)
			local leases = {}
			for index = 1, UIConfig.preview.maxLiveModels do
				local lease, reason = budget:acquire()
				TestKit.expectTrue(lease ~= nil, "preview lease " .. index .. " failed: " .. tostring(reason))
				leases[index] = lease
			end
			TestKit.expectEqual(budget:count(), 4, "active leases at the cap")

			local rejected, reason = budget:acquire()
			TestKit.expectEqual(rejected, nil, "lease beyond the cap")
			TestKit.expectEqual(reason, "Preview limit reached", "cap refusal reason")
			leases[1].release()
			leases[1].release()
			TestKit.expectEqual(budget:count(), 3, "idempotent release")

			local replacement = budget:acquire()
			TestKit.expectTrue(replacement ~= nil, "released capacity was not reusable")
			replacement.release()
			for _, lease in ipairs(leases) do
				lease.release()
			end
			TestKit.expectEqual(budget:count(), 0, "all leases released")
		end)
	end)

	TestKit.describe("Phase 5 catalogue foundations", function()
		TestKit.it("the roster contains exactly thirteen distinct species", function()
			TestKit.expectEqual(#AnimalConfig.ORDER, 13, "animal roster size")
			local seen = {}
			for _, animalId in ipairs(AnimalConfig.ORDER) do
				TestKit.expectTrue(AnimalConfig.animals[animalId] ~= nil, "missing roster entry " .. animalId)
				TestKit.expectFalse(seen[animalId] == true, "duplicate roster entry " .. animalId)
				seen[animalId] = true
			end
		end)

		TestKit.it("the roster split remains twelve collectables plus Moonlit Fawn as Secret", function()
			local collectable = 0
			for _, animalId in ipairs(AnimalConfig.ORDER) do
				if animalId ~= "moonlit" then
					collectable += 1
				end
			end
			TestKit.expectEqual(collectable, 12, "collectable species count")
			TestKit.expectEqual(AnimalConfig.animals.moonlit.rarity, "Secret", "intentional 13th species")
		end)

		TestKit.it("every catalogue species has preview, rarity, personality and unlock source data", function()
			for _, animalId in ipairs(AnimalConfig.ORDER) do
				local animal = AnimalConfig.animals[animalId]
				TestKit.expectTrue(type(animal.name) == "string" and animal.name ~= "", animalId .. " has no display name")
				TestKit.expectTrue(type(animal.description) == "string" and animal.description ~= "", animalId .. " has no description")
				TestKit.expectTrue(type(animal.personality) == "string" and animal.personality ~= "", animalId .. " has no personality")
				TestKit.expectTrue(animal.unlock ~= nil, animalId .. " has no authored unlock descriptor")
				TestKit.expectTrue(AnimalConfig.RARITY[animal.rarity] ~= nil, animalId .. " has no rarity data")
				TestKit.expectTrue(UIConfig.rarityShapes[animal.rarity] ~= nil, animalId .. " has no shape-safe rarity badge")
			end
		end)

		TestKit.it("world selection cards are sourced from all five configured profiles", function()
			TestKit.expectEqual(#WorldConfig.ORDER, 5, "world count")
			for _, worldId in ipairs(WorldConfig.ORDER) do
				local world = WorldConfig.get(worldId)
				TestKit.expectEqual(world.id, worldId, "world selection identity")
				TestKit.expectTrue(type(world.blurb) == "string" and world.blurb ~= "", worldId .. " has no selection description")
				TestKit.expectTrue(world.vMax > world.vMin, worldId .. " has invalid traffic profile")
				TestKit.expectTrue(world.collectible and world.collectible.label, worldId .. " has no collectible presentation")
			end
		end)
	end)

	TestKit.report()
end

return Phase5Tests
