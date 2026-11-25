--!nonstrict
-- Phase 6 balance and persistence limits. Gameplay rewards are derived by the server only.

local ProgressionConfig = {}

ProgressionConfig.MAX_LEVEL = 100
ProgressionConfig.MAX_TOTAL_XP = 2147483647
ProgressionConfig.MAX_CURRENCY = 2147483647
ProgressionConfig.LEVEL_REWARD_ACORNS = 20
ProgressionConfig.MAX_XP_PER_RUN = 1500
ProgressionConfig.MAX_DISTANCE_XP_PER_RUN = 1000
ProgressionConfig.MAX_NEAR_MISS_XP_PER_RUN = 30
ProgressionConfig.XP_PER_NEAR_MISS = 3
ProgressionConfig.XP_PER_COLLECTIBLE = 1
ProgressionConfig.MAX_COLLECTIBLE_XP_PER_RUN = 60
ProgressionConfig.SUCCESSFUL_RUN_MIN_ROWS = 50
ProgressionConfig.SUCCESSFUL_RUN_XP = 20
ProgressionConfig.MAX_RUN_ACORN_REWARD = 100000

ProgressionConfig.STORE_NAME = "FawnRush_PlayerProfiles_v2"
ProgressionConfig.STUDIO_STORE_NAME = "FawnRush_PlayerProfiles_Studio_v2"
ProgressionConfig.SESSION_LOCK_SECONDS = 300
ProgressionConfig.AUTOSAVE_SECONDS = 120
ProgressionConfig.MAX_LOAD_ATTEMPTS = 4
ProgressionConfig.MAX_SAVE_ATTEMPTS = 4
ProgressionConfig.RETRY_DELAYS = { 1, 2, 4 }
ProgressionConfig.SHUTDOWN_TIMEOUT_SECONDS = 25

return ProgressionConfig
