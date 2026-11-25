--!nonstrict
-- Hazard parameters beyond plain vehicles: rail corridors, static closures, and wildlife.
-- Vehicles themselves live in GameConfig.VEHICLES because their dimensions are collision data.
-- See docs/01_GAME_DESIGN_DOCUMENT.md §7.1 and docs/04 §4.5.

local HazardConfig = {}

-- Trains -----------------------------------------------------------------------------------------

HazardConfig.rail = {
	-- Probability that a corridor becomes a railway at difficulty 0 and at difficulty 1.
	chanceStart = 0.0,
	chanceEnd = 0.12,
	-- A train corridor must be crossable between trains: 4 s minimum headway at the speed cap.
	headwayMin = 4.0,
	headwayScale = 1.6,
	speedMul = 1.0,
	announceLead = 1.2,
	colors = {
		sleeper = Color3.fromRGB(92, 78, 62),
		rail = Color3.fromRGB(158, 162, 168),
		gravel = Color3.fromRGB(74, 72, 70),
		warning = Color3.fromRGB(226, 68, 56),
	},
}

-- Static closures --------------------------------------------------------------------------------

HazardConfig.closure = {
	chanceStart = 0.0,
	chanceEnd = 0.22,
	-- The playfield is 17 columns wide; two blockers can never seal it.
	maxPerRow = 2,
	-- A closure needs visible detour space on either side.
	minClearColumns = 9,
	colors = {
		panel = Color3.fromRGB(232, 118, 48),
		stripe = Color3.fromRGB(244, 244, 238),
		cone = Color3.fromRGB(238, 96, 42),
	},
}

-- Wildlife ---------------------------------------------------------------------------------------

HazardConfig.wildlife = {
	chanceStart = 0.0,
	chanceEnd = 0.24,
	-- Speed is the authoritative number. A crosser's cycle time is derived from it
	-- (2 * spanX / speed) by ChunkGenerator.makeWildlife, so a crosser can never move faster than
	-- this range allows. Phase 3 originally configured a period range and left these two unused,
	-- which let a crosser travel at ~12 studs/s against a stated 5-9.
	speedMin = 5,
	speedMax = 9,
	spanX = 40,
	halfWidth = 0.9,
	halfLength = 1.1,
	-- A crosser is never placed within this many rows of a chunk's first row. The player has just
	-- arrived there and has no reaction time, so an immediately arriving hazard is unfair even when
	-- a survivable path technically exists. Nor on the chunk's final row (the junction median).
	entryGraceRows = 3,
	-- Per-world animal used as the crosser.
	kinds = {
		greenwood = "squirrel",
		city = "pigeon",
		desert = "lizard",
		snow = "snowhare",
		neon = "drone",
	},
	colors = {
		squirrel = Color3.fromRGB(150, 106, 64),
		pigeon = Color3.fromRGB(140, 146, 158),
		lizard = Color3.fromRGB(150, 138, 84),
		snowhare = Color3.fromRGB(238, 242, 248),
		drone = Color3.fromRGB(96, 226, 220),
	},
}

-- Difficulty gate: hazards of a given kind do not appear below this difficulty value.
HazardConfig.unlockDifficulty = {
	rail = 0.18,
	closure = 0.12,
	wildlife = 0.08,
}

return HazardConfig
