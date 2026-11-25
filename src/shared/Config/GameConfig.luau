--!nonstrict
-- Gameplay constants for Fawn Rush.
-- Single source of truth for tuning. Docs describe the shape; this file owns the numbers.
-- See docs/04_GAMEPLAY_MECHANICS_SPEC.md §13.
--
-- All positions in gameplay code are expressed in TILE SPACE (integer col/row) and converted
-- to studs only at the render and collision boundaries.

local GameConfig = {}

-- Grid -----------------------------------------------------------------------------------------

GameConfig.TILE = 4
GameConfig.PLAYFIELD_MIN_COL = -8
GameConfig.PLAYFIELD_MAX_COL = 8

-- Movement -------------------------------------------------------------------------------------

GameConfig.STEP_TIME = 0.11
GameConfig.STEP_COOLDOWN = 0.10
-- The client waits slightly longer than the server's floor so its steps are never rejected as
-- "too early" by a few milliseconds of clock skew. See docs/04 §2.2.
GameConfig.CLIENT_COOLDOWN_PAD = 0.012
GameConfig.INPUT_BUFFER = 0.18
GameConfig.MAX_STEPS_PER_SECOND = 12

-- Collision ------------------------------------------------------------------------------------

GameConfig.PLAYER_HALF_X = 0.9
GameConfig.PLAYER_HALF_Z = 0.9
GameConfig.CONTACT_PAD_X = 0.15

-- Simulation -----------------------------------------------------------------------------------

GameConfig.TICK_HZ = 20
GameConfig.TICK_DT = 1 / 20
GameConfig.REWIND_MAX = 0.20

-- Generation -----------------------------------------------------------------------------------

GameConfig.CHUNK_ROWS = 12
GameConfig.CHUNK_LOOKAHEAD = 2
GameConfig.CHUNK_RECYCLE_BEHIND = 36
GameConfig.MAX_CORRIDOR_LANES = 3
GameConfig.MEDIAN_MIN_ROWS = 1
GameConfig.MEDIAN_MAX_ROWS = 3
GameConfig.GENERATION_ATTEMPTS = 4

-- Fairness -------------------------------------------------------------------------------------

GameConfig.GAP_SAFETY = 2.0
GameConfig.REACTION = 0.22
GameConfig.SOLVER_DT = 0.05
GameConfig.SOLVER_HORIZON = 6.0
GameConfig.SOLVER_MARGIN = 0.25
GameConfig.SOLVER_NODE_CAP = 12000
GameConfig.SOLVER_SAMPLES = 4

-- Traffic --------------------------------------------------------------------------------------

GameConfig.LANE_SPAN_X = 60
GameConfig.VEHICLE_OVERHANG = 14
GameConfig.LANE_PHASE_STEP = 0.133

-- Vehicle archetypes. lengthTiles is gameplay data; height/colour are presentation only.
GameConfig.VEHICLES = {
	compact = {
		lengthTiles = 2.0,
		halfWidth = 1.20,
		speedMul = 1.00,
		height = 2.6,
		color = Color3.fromRGB(214, 92, 78),
	},
	sports = {
		lengthTiles = 2.0,
		halfWidth = 1.15,
		speedMul = 1.70,
		height = 2.0,
		color = Color3.fromRGB(240, 196, 70),
	},
	truck = {
		lengthTiles = 3.0,
		halfWidth = 1.35,
		speedMul = 0.85,
		height = 3.2,
		color = Color3.fromRGB(96, 132, 176),
	},
	van = {
		lengthTiles = 2.5,
		halfWidth = 1.25,
		speedMul = 1.00,
		height = 3.0,
		color = Color3.fromRGB(232, 232, 226),
	},
	bus = {
		lengthTiles = 4.0,
		halfWidth = 1.40,
		speedMul = 0.70,
		height = 3.6,
		color = Color3.fromRGB(214, 138, 52),
	},
	motorcycle = {
		lengthTiles = 1.0,
		halfWidth = 0.65,
		speedMul = 2.00,
		height = 1.9,
		color = Color3.fromRGB(72, 74, 86),
	},
	train = {
		lengthTiles = 10.0,
		halfWidth = 1.60,
		speedMul = 1.35,
		height = 4.2,
		color = Color3.fromRGB(96, 104, 118),
	},
}

-- Camera ---------------------------------------------------------------------------------------

GameConfig.CAMERA_DESKTOP = {
	offset = Vector3.new(0, 15.5, 13.5),
	look = Vector3.new(0, 2.2, -5.5),
	fov = 62,
	damp = 8,
}

GameConfig.CAMERA_TOUCH = {
	offset = Vector3.new(0, 18.5, 16.0),
	look = Vector3.new(0, 2.2, -6.5),
	fov = 70,
	damp = 7,
}

GameConfig.CAMERA_DEATH = {
	offset = Vector3.new(0, 20, 20),
	look = Vector3.new(0, 2.2, 0),
	fov = 66,
	damp = 3.5,
}

-- Presentation ---------------------------------------------------------------------------------

GameConfig.VEHICLE_POOL_MAX = 44
GameConfig.ACORN_VALUE_SAFE = 1
GameConfig.ACORN_VALUE_ROAD = 3
GameConfig.WORLD_HALF_WIDTH = 38
-- Hard ceiling on scenery built per chunk, whatever a world's prop profile asks for. A world is
-- config data, and config data must never be able to blow the mobile draw-call budget.
GameConfig.MAX_PROPS_PER_CHUNK = 40

-- Jump (docs/04 §2.4) ---------------------------------------------------------------------------

GameConfig.JUMP_TIME = 0.34
GameConfig.JUMP_COOLDOWN = 0.46
GameConfig.JUMP_APEX = 2.2
GameConfig.JUMP_SAFE_HEIGHT = 1.2 -- above this, wildlife cannot reach the player

-- Near miss and combo (docs/04 §7.4) ------------------------------------------------------------

GameConfig.NEAR_MISS_TILES = 0.75
GameConfig.NEAR_MISS_ACORNS = 2
GameConfig.NEAR_MISS_ACORNS_CAP = 12
GameConfig.NEAR_MISS_SCORE = 25
GameConfig.NEAR_MISS_DEDUPE = 1.2 -- seconds before the same vehicle can award again
GameConfig.COMBO_DECAY = 6.0
-- Multiplier per consecutive near miss: index = hits, clamped to the last entry.
GameConfig.COMBO_STEPS = { 1.0, 1.25, 1.6, 2.1, 3.0, 5.0 }

-- Animation state durations (docs/01 §6.2) ------------------------------------------------------

GameConfig.ANIM_BLEND = 0.12
GameConfig.FRIGHT_TIME = 0.45
GameConfig.STUMBLE_TIME = 0.30
GameConfig.HAPPY_TIME = 1.20
GameConfig.DEATH_TIME = 1.10
GameConfig.VICTORY_TIME = 1.60
GameConfig.LAND_TIME = 0.14
GameConfig.TURN_TIME = 0.16

-- Hazard warnings -------------------------------------------------------------------------------

GameConfig.TRAIN_ANNOUNCE = 1.2
GameConfig.WILDLIFE_AIRBORNE_CLEARANCE = 1.2

-- World unlock -----------------------------------------------------------------------------------

-- Unlock enforcement is enabled only after the server profile loader is wired to fail closed:
-- an unavailable profile cannot receive defaults or enter a locked world.
GameConfig.WORLD_UNLOCK_ENFORCED = true

-- Developer ------------------------------------------------------------------------------------

-- Runs the in-repo Luau test suite on server boot when opened in Studio. Never runs live.
GameConfig.RUN_TESTS_ON_BOOT = true
GameConfig.TEST_CHUNK_SAMPLES = 50

return GameConfig
