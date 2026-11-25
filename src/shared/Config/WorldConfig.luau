--!nonstrict
-- Per-world profiles: five worlds, one schema.
--
-- This file is the single source of truth for a world's identity, difficulty, palette, lighting,
-- ambient effects, scenery density, collectible skin and unlock requirement. Adding a sixth world is
-- a block here plus (optionally) a new scenery kind in WorldKit — never a change to the simulation,
-- the generator, the server or the renderer's control flow.
--
-- Two halves:
--   * gameplay keys (vMin, rampRows, corridorWeights, vehicleWeights, acornChance…) are read by
--     ChunkGenerator, which is deterministic and server-authoritative.
--   * presentation keys (palette, lighting, effects, props, road, collectible) are read by the
--     client renderer and are cosmetic only. A cheating client can change its own colours and
--     nothing else.
--
-- `BASE_PALETTE` supplies a default for every colour, so each world overrides only what makes it
-- distinct and no builder can ever meet a nil colour.

local WorldConfig = {}

WorldConfig.DEFAULT = "greenwood"

-- Display order and unlock order are the same. Greenwood is always first and always free.
WorldConfig.ORDER = {
	"greenwood",
	"city",
	"desert",
	"snow",
	"neon",
}

local BASE_PALETTE = {
	-- Ground
	grass = Color3.fromRGB(92, 138, 60),
	grassDark = Color3.fromRGB(74, 116, 48),
	sand = Color3.fromRGB(217, 188, 138),
	sandstone = Color3.fromRGB(190, 148, 104),
	snow = Color3.fromRGB(242, 246, 250),
	ice = Color3.fromRGB(190, 220, 232),
	concrete = Color3.fromRGB(150, 154, 158),
	kerb = Color3.fromRGB(196, 198, 200),

	-- Road
	road = Color3.fromRGB(58, 63, 68),
	roadDark = Color3.fromRGB(44, 48, 52),
	line = Color3.fromRGB(232, 232, 214),

	-- Nature
	trunk = Color3.fromRGB(106, 76, 52),
	leaf = Color3.fromRGB(64, 116, 56),
	leafAccent = Color3.fromRGB(120, 160, 68),
	rock = Color3.fromRGB(128, 128, 120),

	-- Accents
	accent = Color3.fromRGB(242, 179, 61),
	hazard = Color3.fromRGB(232, 118, 48),
	cone = Color3.fromRGB(238, 96, 42),

	-- Collectible skin
	collectible = Color3.fromRGB(242, 179, 61),
	collectibleAccent = Color3.fromRGB(107, 74, 46),

	-- Architecture
	buildingA = Color3.fromRGB(186, 190, 196),
	buildingB = Color3.fromRGB(158, 164, 172),
	buildingC = Color3.fromRGB(206, 208, 210),
	neonA = Color3.fromRGB(255, 63, 164),
	neonB = Color3.fromRGB(53, 224, 255),
}

WorldConfig.BASE_PALETTE = BASE_PALETTE

WorldConfig.worlds = {
	-- 1 ----------------------------------------------------------------------------------------
	greenwood = {
		id = "greenwood",
		name = "Greenwood Crossing",
		tagline = "Sunlight through the leaves. Watch the road.",
		blurb = "A wide, patient forest highway. The gentlest place to learn to cross.",

		unlock = { level = 1, lifetimeRows = 0 },

		-- Traffic ---------------------------------------------------------------
		vMin = 9,
		vMax = 18,
		speedRamp = 0.9,
		rampRows = 500,
		corridorWeightsStart = { 80, 20, 0 },
		corridorWeightsEnd = { 15, 45, 40 },
		headwayScaleStart = 1.7,
		headwayScaleEnd = 1.05,
		vehicleWeights = {
			{ id = "compact", weight = 50 },
			{ id = "sports", weight = 18 },
			{ id = "truck", weight = 18 },
			{ id = "van", weight = 14 },
		},

		-- Collectibles ----------------------------------------------------------
		acornChanceMedian = 0.60,
		acornChanceRoad = 0.22,
		collectible = { kind = "acorn", label = "Acorn" },

		-- Presentation ----------------------------------------------------------
		style = "forest",
		road = { surface = "asphalt", markings = "edge" },
		colors = {
			grass = Color3.fromRGB(92, 138, 60),
			grassDark = Color3.fromRGB(74, 116, 48),
			road = Color3.fromRGB(58, 63, 68),
			line = Color3.fromRGB(232, 232, 214),
			trunk = Color3.fromRGB(106, 76, 52),
			leaf = Color3.fromRGB(64, 116, 56),
			leafAccent = Color3.fromRGB(120, 160, 68),
			rock = Color3.fromRGB(128, 128, 120),
			accent = Color3.fromRGB(242, 179, 61),
		},

		props = {
			bandMin = 38,
			bandMax = 62,
			perRow = 2,
			density = 0.80,
			kinds = {
				{ id = "tree", weight = 58, scaleMin = 0.85, scaleMax = 1.30 },
				{ id = "bush", weight = 20, scaleMin = 0.70, scaleMax = 1.20 },
				{ id = "rock", weight = 12, scaleMin = 0.60, scaleMax = 1.40 },
				{ id = "mushroom", weight = 10, scaleMin = 0.80, scaleMax = 1.30 },
			},
		},

		lighting = {
			clockTime = 15.5,
			brightness = 2.4,
			exposure = 0.1,
			ambient = Color3.fromRGB(96, 104, 78),
			outdoorAmbient = Color3.fromRGB(128, 140, 112),
			fogStart = 0,
			fogEnd = 9000,
			fogColor = Color3.fromRGB(199, 223, 236),
			atmosphere = {
				density = 0.32,
				offset = 0.2,
				color = Color3.fromRGB(199, 223, 236),
				decay = Color3.fromRGB(106, 132, 96),
				glare = 0.15,
				haze = 1.6,
			},
			bloom = { intensity = 0.35, size = 18, threshold = 1.6 },
			grade = { brightness = 0.02, contrast = 0.08, saturation = 0.12, tint = Color3.fromRGB(255, 248, 238) },
			sunRays = { intensity = 0.12, spread = 0.6 },
		},

		effects = {
			ambient = { kind = "leaves", rate = 14, size = 0.7, color = Color3.fromRGB(150, 196, 92), speed = 2.4 },
			accent = { kind = "fireflies", rate = 5, size = 0.28, color = Color3.fromRGB(246, 232, 132) },
		},

		lobbySpawn = Vector3.new(0, 0, 18),
	},

	-- 2 ----------------------------------------------------------------------------------------
	city = {
		id = "city",
		name = "City Chaos",
		tagline = "Downtown does not slow down for anyone.",
		blurb = "Narrow medians, buses, taxis and crossings. Busy in every direction.",

		unlock = { level = 5, lifetimeRows = 0 },

		vMin = 12,
		vMax = 21,
		speedRamp = 1.0,
		rampRows = 560,
		corridorWeightsStart = { 60, 35, 5 },
		corridorWeightsEnd = { 10, 40, 50 },
		headwayScaleStart = 1.55,
		headwayScaleEnd = 1.00,
		vehicleWeights = {
			{ id = "compact", weight = 32 },
			{ id = "sports", weight = 20 },
			{ id = "truck", weight = 14 },
			{ id = "van", weight = 14 },
			{ id = "bus", weight = 14 },
			{ id = "motorcycle", weight = 6 },
		},

		acornChanceMedian = 0.40,
		acornChanceRoad = 0.26,
		collectible = { kind = "coin", label = "Token" },

		style = "urban",
		road = { surface = "asphalt", markings = "crosswalk" },
		colors = {
			grass = Color3.fromRGB(126, 128, 126),
			grassDark = Color3.fromRGB(108, 110, 110),
			road = Color3.fromRGB(58, 62, 68),
			line = Color3.fromRGB(240, 240, 232),
			trunk = Color3.fromRGB(92, 92, 96),
			leaf = Color3.fromRGB(96, 132, 92),
			leafAccent = Color3.fromRGB(128, 168, 108),
			rock = Color3.fromRGB(140, 142, 146),
			accent = Color3.fromRGB(242, 196, 70),
			concrete = Color3.fromRGB(150, 154, 158),
			kerb = Color3.fromRGB(196, 198, 200),
			buildingA = Color3.fromRGB(186, 190, 196),
			buildingB = Color3.fromRGB(150, 158, 168),
			buildingC = Color3.fromRGB(206, 200, 190),
			hazard = Color3.fromRGB(224, 96, 64),
			cone = Color3.fromRGB(242, 122, 48),
			collectible = Color3.fromRGB(246, 198, 74),
			collectibleAccent = Color3.fromRGB(160, 120, 48),
		},

		props = {
			bandMin = 38,
			bandMax = 56,
			perRow = 2,
			density = 0.90,
			kinds = {
				{ id = "building", weight = 52, scaleMin = 0.90, scaleMax = 1.60 },
				{ id = "streetLight", weight = 18, scaleMin = 0.90, scaleMax = 1.10 },
				{ id = "billboard", weight = 12, scaleMin = 0.85, scaleMax = 1.20 },
				{ id = "bush", weight = 18, scaleMin = 0.60, scaleMax = 0.90 },
			},
		},

		lighting = {
			clockTime = 16.8,
			brightness = 2.0,
			exposure = 0.0,
			ambient = Color3.fromRGB(108, 116, 128),
			outdoorAmbient = Color3.fromRGB(148, 156, 166),
			fogStart = 200,
			fogEnd = 6000,
			fogColor = Color3.fromRGB(201, 214, 224),
			atmosphere = {
				density = 0.38,
				offset = 0.25,
				color = Color3.fromRGB(201, 214, 224),
				decay = Color3.fromRGB(120, 128, 140),
				glare = 0.05,
				haze = 2.2,
			},
			bloom = { intensity = 0.45, size = 20, threshold = 1.4 },
			grade = { brightness = -0.01, contrast = 0.12, saturation = 0.02, tint = Color3.fromRGB(238, 242, 248) },
		},

		effects = {
			ambient = { kind = "dust", rate = 10, size = 0.5, color = Color3.fromRGB(214, 220, 228), speed = 1.6 },
		},

		lobbySpawn = Vector3.new(0, 0, 18),
	},

	-- 3 ----------------------------------------------------------------------------------------
	desert = {
		id = "desert",
		name = "Desert Dash",
		tagline = "Nothing out here but heat and horsepower.",
		blurb = "Sparse traffic at speed, wide lanes, and a horizon that shimmers.",

		unlock = { level = 12, lifetimeRows = 3000 },

		vMin = 13,
		vMax = 23,
		speedRamp = 1.05,
		rampRows = 600,
		corridorWeightsStart = { 55, 35, 10 },
		corridorWeightsEnd = { 12, 38, 50 },
		headwayScaleStart = 1.55,
		headwayScaleEnd = 1.02,
		vehicleWeights = {
			{ id = "compact", weight = 26 },
			{ id = "sports", weight = 30 },
			{ id = "truck", weight = 16 },
			{ id = "van", weight = 12 },
			{ id = "motorcycle", weight = 16 },
		},

		acornChanceMedian = 0.30,
		acornChanceRoad = 0.20,
		collectible = { kind = "cactusNut", label = "Cactus Nut" },

		style = "desert",
		road = { surface = "asphaltWorn", markings = "dashed" },
		colors = {
			grass = Color3.fromRGB(217, 188, 138),
			grassDark = Color3.fromRGB(198, 168, 120),
			sand = Color3.fromRGB(217, 188, 138),
			sandstone = Color3.fromRGB(190, 148, 104),
			road = Color3.fromRGB(74, 70, 64),
			line = Color3.fromRGB(228, 214, 180),
			trunk = Color3.fromRGB(140, 122, 92),
			leaf = Color3.fromRGB(112, 146, 92),
			leafAccent = Color3.fromRGB(146, 176, 108),
			rock = Color3.fromRGB(178, 138, 98),
			accent = Color3.fromRGB(238, 148, 76),
			hazard = Color3.fromRGB(210, 110, 60),
			cone = Color3.fromRGB(232, 128, 60),
			collectible = Color3.fromRGB(168, 206, 118),
			collectibleAccent = Color3.fromRGB(96, 132, 72),
		},

		props = {
			bandMin = 42,
			bandMax = 74,
			perRow = 2,
			density = 0.68,
			kinds = {
				{ id = "cactus", weight = 38, scaleMin = 0.80, scaleMax = 1.40 },
				{ id = "mesa", weight = 26, scaleMin = 1.10, scaleMax = 2.20 },
				{ id = "rock", weight = 22, scaleMin = 0.60, scaleMax = 1.60 },
				{ id = "bush", weight = 14, scaleMin = 0.50, scaleMax = 0.85 },
			},
		},

		lighting = {
			clockTime = 12.4,
			brightness = 3.0,
			exposure = 0.15,
			ambient = Color3.fromRGB(150, 132, 108),
			outdoorAmbient = Color3.fromRGB(186, 164, 136),
			fogStart = 300,
			fogEnd = 8000,
			fogColor = Color3.fromRGB(246, 227, 192),
			atmosphere = {
				density = 0.42,
				offset = 0.35,
				color = Color3.fromRGB(246, 227, 192),
				decay = Color3.fromRGB(196, 158, 118),
				glare = 0.28,
				haze = 2.6,
			},
			bloom = { intensity = 0.30, size = 22, threshold = 1.8 },
			grade = { brightness = 0.03, contrast = 0.14, saturation = 0.06, tint = Color3.fromRGB(255, 240, 214) },
			sunRays = { intensity = 0.2, spread = 0.8 },
		},

		effects = {
			ambient = { kind = "sand", rate = 22, size = 0.55, color = Color3.fromRGB(224, 198, 152), speed = 9.0 },
		},

		lobbySpawn = Vector3.new(0, 0, 18),
	},

	-- 4 ----------------------------------------------------------------------------------------
	snow = {
		id = "snow",
		name = "Snowy Summit",
		tagline = "Quiet, cold, and still coming through.",
		blurb = "A frozen mountain pass. Slower vehicles, longer slides, no grip.",

		unlock = { level = 20, lifetimeRows = 0 },

		vMin = 8,
		vMax = 16,
		speedRamp = 0.85,
		rampRows = 640,
		corridorWeightsStart = { 70, 28, 2 },
		corridorWeightsEnd = { 18, 44, 38 },
		headwayScaleStart = 1.65,
		headwayScaleEnd = 1.08,
		vehicleWeights = {
			{ id = "compact", weight = 28 },
			{ id = "sports", weight = 14 },
			{ id = "truck", weight = 24 },
			{ id = "van", weight = 20 },
			{ id = "bus", weight = 14 },
		},

		acornChanceMedian = 0.50,
		acornChanceRoad = 0.24,
		collectible = { kind = "iceGem", label = "Ice Gem" },

		style = "snow",
		road = { surface = "ice", markings = "edge" },
		colors = {
			grass = Color3.fromRGB(242, 246, 250),
			grassDark = Color3.fromRGB(226, 234, 242),
			snow = Color3.fromRGB(242, 246, 250),
			ice = Color3.fromRGB(190, 220, 232),
			road = Color3.fromRGB(148, 164, 178),
			line = Color3.fromRGB(252, 252, 255),
			trunk = Color3.fromRGB(96, 82, 74),
			leaf = Color3.fromRGB(58, 96, 84),
			leafAccent = Color3.fromRGB(92, 132, 116),
			rock = Color3.fromRGB(150, 160, 170),
			accent = Color3.fromRGB(150, 214, 240),
			hazard = Color3.fromRGB(226, 128, 84),
			cone = Color3.fromRGB(236, 140, 90),
			collectible = Color3.fromRGB(176, 226, 246),
			collectibleAccent = Color3.fromRGB(96, 162, 196),
		},

		props = {
			bandMin = 38,
			bandMax = 66,
			perRow = 2,
			density = 0.78,
			kinds = {
				{ id = "pine", weight = 52, scaleMin = 0.85, scaleMax = 1.35 },
				{ id = "snowBank", weight = 24, scaleMin = 0.80, scaleMax = 1.50 },
				{ id = "rock", weight = 14, scaleMin = 0.60, scaleMax = 1.20 },
				{ id = "iceSheet", weight = 10, scaleMin = 0.90, scaleMax = 1.40 },
			},
		},

		lighting = {
			clockTime = 9.2,
			brightness = 2.2,
			exposure = 0.05,
			ambient = Color3.fromRGB(118, 132, 150),
			outdoorAmbient = Color3.fromRGB(168, 186, 204),
			fogStart = 100,
			fogEnd = 5200,
			fogColor = Color3.fromRGB(220, 232, 242),
			atmosphere = {
				density = 0.46,
				offset = 0.3,
				color = Color3.fromRGB(220, 232, 242),
				decay = Color3.fromRGB(150, 172, 196),
				glare = 0.12,
				haze = 2.4,
			},
			bloom = { intensity = 0.40, size = 20, threshold = 1.5 },
			grade = { brightness = 0.02, contrast = 0.06, saturation = -0.06, tint = Color3.fromRGB(236, 246, 255) },
		},

		effects = {
			ambient = { kind = "snow", rate = 26, size = 0.5, color = Color3.fromRGB(252, 254, 255), speed = 5.0 },
		},

		lobbySpawn = Vector3.new(0, 0, 18),
	},

	-- 5 ----------------------------------------------------------------------------------------
	neon = {
		id = "neon",
		name = "Neon Night",
		tagline = "The whole boulevard is a light show. It does not stop.",
		blurb = "Rain-slick asphalt, holographic signage, and the fastest traffic in the game.",

		unlock = { level = 30, lifetimeRows = 8000 },

		vMin = 15,
		vMax = 25,
		speedRamp = 1.10,
		rampRows = 700,
		corridorWeightsStart = { 45, 38, 17 },
		corridorWeightsEnd = { 8, 34, 58 },
		headwayScaleStart = 1.45,
		headwayScaleEnd = 0.98,
		vehicleWeights = {
			{ id = "compact", weight = 24 },
			{ id = "sports", weight = 34 },
			{ id = "truck", weight = 10 },
			{ id = "van", weight = 10 },
			{ id = "motorcycle", weight = 22 },
		},

		acornChanceMedian = 0.36,
		acornChanceRoad = 0.28,
		collectible = { kind = "shard", label = "Light Shard" },

		style = "neon",
		road = { surface = "wet", markings = "glow" },
		colors = {
			grass = Color3.fromRGB(20, 18, 38),
			grassDark = Color3.fromRGB(14, 12, 30),
			road = Color3.fromRGB(26, 24, 40),
			roadDark = Color3.fromRGB(18, 16, 30),
			line = Color3.fromRGB(78, 226, 246),
			trunk = Color3.fromRGB(48, 44, 70),
			leaf = Color3.fromRGB(52, 46, 92),
			leafAccent = Color3.fromRGB(104, 70, 160),
			rock = Color3.fromRGB(46, 42, 66),
			accent = Color3.fromRGB(255, 63, 164),
			buildingA = Color3.fromRGB(38, 34, 62),
			buildingB = Color3.fromRGB(30, 28, 54),
			buildingC = Color3.fromRGB(46, 40, 74),
			neonA = Color3.fromRGB(255, 63, 164),
			neonB = Color3.fromRGB(53, 224, 255),
			hazard = Color3.fromRGB(255, 96, 132),
			cone = Color3.fromRGB(255, 126, 88),
			collectible = Color3.fromRGB(112, 246, 236),
			collectibleAccent = Color3.fromRGB(140, 78, 220),
		},

		props = {
			bandMin = 38,
			bandMax = 62,
			perRow = 2,
			density = 0.92,
			kinds = {
				{ id = "neonTower", weight = 44, scaleMin = 1.00, scaleMax = 1.90 },
				{ id = "neonSign", weight = 24, scaleMin = 0.85, scaleMax = 1.30 },
				{ id = "holoPylon", weight = 18, scaleMin = 0.80, scaleMax = 1.20 },
				{ id = "streetLight", weight = 14, scaleMin = 0.90, scaleMax = 1.10 },
			},
		},

		lighting = {
			clockTime = 0.2,
			brightness = 1.5,
			exposure = 0.25,
			ambient = Color3.fromRGB(46, 40, 86),
			outdoorAmbient = Color3.fromRGB(70, 60, 120),
			fogStart = 80,
			fogEnd = 4200,
			fogColor = Color3.fromRGB(40, 34, 78),
			atmosphere = {
				density = 0.50,
				offset = 0.4,
				color = Color3.fromRGB(40, 34, 78),
				decay = Color3.fromRGB(90, 50, 130),
				glare = 0.35,
				haze = 1.8,
			},
			bloom = { intensity = 0.95, size = 26, threshold = 1.1 },
			grade = { brightness = -0.02, contrast = 0.18, saturation = 0.20, tint = Color3.fromRGB(226, 226, 255) },
		},

		effects = {
			ambient = { kind = "motes", rate = 18, size = 0.4, color = Color3.fromRGB(120, 232, 246), speed = 3.0 },
		},

		lobbySpawn = Vector3.new(0, 0, 18),
	},
}

-- Merge the base palette under every world so no builder ever meets a nil colour.
local function mergePalette(overrides)
	local merged = {}
	for key, value in pairs(BASE_PALETTE) do
		merged[key] = value
	end
	for key, value in pairs(overrides or {}) do
		merged[key] = value
	end
	return merged
end

for _, worldId in ipairs(WorldConfig.ORDER) do
	local world = WorldConfig.worlds[worldId]
	if world then
		world.colors = mergePalette(world.colors)
	end
end

function WorldConfig.get(worldId: string)
	local world = WorldConfig.worlds[worldId]
	if world then
		return world
	end

	warn(("[WorldConfig] Unknown world '%s'; falling back to '%s'."):format(tostring(worldId), WorldConfig.DEFAULT))
	return WorldConfig.worlds[WorldConfig.DEFAULT]
end

function WorldConfig.exists(worldId: string): boolean
	return WorldConfig.worlds[worldId] ~= nil
end

-- Worlds in display order, ready to iterate.
function WorldConfig.list()
	local list = {}
	for _, worldId in ipairs(WorldConfig.ORDER) do
		local world = WorldConfig.worlds[worldId]
		if world then
			list[#list + 1] = world
		end
	end
	return list
end

function WorldConfig.next(worldId: string): string
	for index, candidate in ipairs(WorldConfig.ORDER) do
		if candidate == worldId then
			return WorldConfig.ORDER[(index % #WorldConfig.ORDER) + 1]
		end
	end
	return WorldConfig.DEFAULT
end

local REQUIRED_PALETTE = { "grass", "road", "line", "rock", "accent", "hazard" }

-- Boot-time validation. A broken world here means a nil colour or a division by zero deep inside the
-- generator, so it is loud and it runs before anything else touches a world.
function WorldConfig.validate(): { string }
	local problems = {}
	local seen = {}

	for _, worldId in ipairs(WorldConfig.ORDER) do
		if seen[worldId] then
			problems[#problems + 1] = ("ORDER lists '%s' twice"):format(worldId)
		end
		seen[worldId] = true

		local world = WorldConfig.worlds[worldId]
		if not world then
			problems[#problems + 1] = ("ORDER references missing world '%s'"):format(worldId)
			continue
		end

		if world.id ~= worldId then
			problems[#problems + 1] = ("world '%s' has mismatched id '%s'"):format(worldId, tostring(world.id))
		end

		if world.vMax <= world.vMin then
			problems[#problems + 1] = ("world '%s' has vMax <= vMin"):format(worldId)
		end
		if world.rampRows <= 0 then
			problems[#problems + 1] = ("world '%s' has rampRows <= 0"):format(worldId)
		end
		if world.speedRamp <= 0 then
			problems[#problems + 1] = ("world '%s' has speedRamp <= 0"):format(worldId)
		end

		for index = 1, 3 do
			if (world.corridorWeightsStart[index] or -1) < 0 or (world.corridorWeightsEnd[index] or -1) < 0 then
				problems[#problems + 1] = ("world '%s' has a negative corridor weight"):format(worldId)
			end
		end

		if #(world.vehicleWeights or {}) == 0 then
			problems[#problems + 1] = ("world '%s' has no vehicle weights"):format(worldId)
		end

		for _, entry in ipairs(world.vehicleWeights or {}) do
			if not entry.id or entry.weight <= 0 then
				problems[#problems + 1] = ("world '%s' has an invalid vehicle weight entry"):format(worldId)
			end
		end

		for _, key in ipairs(REQUIRED_PALETTE) do
			if typeof(world.colors[key]) ~= "Color3" then
				problems[#problems + 1] = ("world '%s' is missing colour '%s'"):format(worldId, key)
			end
		end

		if not world.lighting then
			problems[#problems + 1] = ("world '%s' has no lighting profile"):format(worldId)
		end

		local props = world.props
		if not props then
			problems[#problems + 1] = ("world '%s' has no prop profile"):format(worldId)
		else
			if props.bandMax <= props.bandMin then
				problems[#problems + 1] = ("world '%s' has bandMax <= bandMin"):format(worldId)
			end
			if props.perRow < 0 then
				problems[#problems + 1] = ("world '%s' has a negative perRow"):format(worldId)
			end
			if props.density < 0 or props.density > 1 then
				problems[#problems + 1] = ("world '%s' has density outside 0..1"):format(worldId)
			end
			if #(props.kinds or {}) == 0 then
				problems[#problems + 1] = ("world '%s' has no prop kinds"):format(worldId)
			end
			for _, kind in ipairs(props.kinds or {}) do
				if not kind.id or kind.weight <= 0 then
					problems[#problems + 1] = ("world '%s' has an invalid prop kind"):format(worldId)
				end
			end
		end

		local effects = world.effects and world.effects.ambient
		if effects then
			if effects.rate < 0 or effects.rate > 60 then
				problems[#problems + 1] = ("world '%s' has an ambient rate outside 0..60"):format(worldId)
			end
		end

		if not world.unlock or world.unlock.level < 1 then
			problems[#problems + 1] = ("world '%s' has no valid unlock requirement"):format(worldId)
		end
	end

	-- The first world must be free, or a new player has nowhere to play.
	local first = WorldConfig.worlds[WorldConfig.ORDER[1]]
	if first and (first.unlock.level > 1 or (first.unlock.lifetimeRows or 0) > 0) then
		problems[#problems + 1] = "the first world is not unlocked by default"
	end

	return problems
end

return WorldConfig
