--!nonstrict
-- Pure achievement progress and exactly-once completion transitions.

local AchievementRules = {}

function AchievementRules.progressFor(metric: string, profile): number
	local stats = profile.stats or {}
	if metric == "bestDistance" then
		return stats.bestDistance or 0
	elseif metric == "totalNearMisses" then
		return stats.totalNearMisses or 0
	elseif metric == "standardAnimalsOwned" then
		local count = 0
		for animalId, owned in pairs(profile.animals.owned) do
			if owned and animalId ~= "moonlit" then
				count += 1
			end
		end
		return count
	elseif metric == "level" then
		return profile.level or 1
	elseif metric == "worldsUnlocked" then
		local count = 0
		for _, unlocked in pairs(profile.worlds.unlocked) do
			if unlocked then count += 1 end
		end
		return count
	elseif metric == "totalRuns" then
		return stats.totalRuns or 0
	end
	return 0
end

function AchievementRules.complete(entry, target): boolean
	return entry ~= nil and entry.complete == true or (entry == nil and target <= 0)
end

return AchievementRules
