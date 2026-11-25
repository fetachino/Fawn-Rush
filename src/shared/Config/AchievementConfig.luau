--!nonstrict
-- Thirty-four in-game achievements across six categories. Rewards are claimable once per profile.

local AchievementConfig = {}

local function add(list, category: string, prefix: string, targets: { number }, metric: string, rewardBase: number)
	for index, target in ipairs(targets) do
		list[#list + 1] = {
			id = prefix .. "_" .. tostring(target),
			category = category,
			metric = metric,
			target = target,
			description = category .. " milestone " .. tostring(target),
			reward = { xp = rewardBase + index * 5, acorns = rewardBase + index * 3 },
		}
	end
end

AchievementConfig.LIST = {}
add(AchievementConfig.LIST, "Distance", "distance", { 50, 100, 500, 1000, 3000 }, "bestDistance", 10)
add(AchievementConfig.LIST, "Near-misses", "near_misses", { 1, 10, 50, 100, 500 }, "totalNearMisses", 10)
add(AchievementConfig.LIST, "Collection", "collection", { 1, 3, 6, 9, 12 }, "standardAnimalsOwned", 15)
add(AchievementConfig.LIST, "Levels", "level", { 2, 5, 10, 20, 30, 50 }, "level", 15)
add(AchievementConfig.LIST, "Worlds", "worlds", { 1, 2, 3, 4, 5 }, "worldsUnlocked", 20)
add(AchievementConfig.LIST, "Runs", "runs", { 1, 10, 25, 50, 100, 250, 500, 1000 }, "totalRuns", 10)

function AchievementConfig.get(id: string)
	for _, achievement in ipairs(AchievementConfig.LIST) do
		if achievement.id == id then
			return achievement
		end
	end
	return nil
end

return AchievementConfig
