--!nonstrict
-- Stable, server-evaluated daily and weekly objectives. No client may submit progress.

local MissionConfig = {}

MissionConfig.DAILY = {
	{
		id = "daily_distance",
		description = "Travel 100 rows across your completed runs",
		objective = "distance",
		target = 100,
		reward = { acorns = 30, xp = 40 },
	},
	{
		id = "daily_collectibles",
		description = "Collect 12 run collectibles",
		objective = "collectibles",
		target = 12,
		reward = { acorns = 35, xp = 35 },
	},
	{
		id = "daily_near_misses",
		description = "Earn 5 server-confirmed near-misses",
		objective = "near_misses",
		target = 5,
		reward = { acorns = 40, xp = 45 },
	},
}

MissionConfig.WEEKLY = {
	{
		id = "weekly_distance",
		description = "Travel 1,000 rows across completed runs",
		objective = "distance",
		target = 1000,
		reward = { acorns = 140, xp = 180 },
	},
	{
		id = "weekly_collectibles",
		description = "Collect 120 run collectibles",
		objective = "collectibles",
		target = 120,
		reward = { acorns = 130, xp = 160 },
	},
	{
		id = "weekly_near_misses",
		description = "Earn 40 server-confirmed near-misses",
		objective = "near_misses",
		target = 40,
		reward = { acorns = 150, xp = 180 },
	},
	{
		id = "weekly_successful_runs",
		description = "Bank 5 runs after reaching at least 50 rows",
		objective = "successful_runs",
		target = 5,
		reward = { acorns = 170, xp = 200 },
	},
	{
		id = "weekly_greenwood",
		description = "Travel 200 rows in Greenwood Crossing",
		objective = "world_distance",
		worldId = "greenwood",
		target = 200,
		reward = { acorns = 160, xp = 190 },
	},
}

return MissionConfig
