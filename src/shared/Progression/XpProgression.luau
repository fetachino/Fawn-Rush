--!nonstrict
-- Pure XP curve and server reward calculation.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared").Config.ProgressionConfig)

local XpProgression = {}

-- XP from level L to L+1: 100 + 35*(L-1) + 4*(L-1)^2.
function XpProgression.xpToNextLevel(level: number): number
	local safeLevel = math.clamp(math.floor(tonumber(level) or 1), 1, Config.MAX_LEVEL)
	local step = safeLevel - 1
	return 100 + 35 * step + 4 * step * step
end

function XpProgression.levelForXP(totalXP: number): number
	local remaining = math.clamp(math.floor(tonumber(totalXP) or 0), 0, Config.MAX_TOTAL_XP)
	local level = 1
	while level < Config.MAX_LEVEL do
		local cost = XpProgression.xpToNextLevel(level)
		if remaining < cost then
			break
		end
		remaining -= cost
		level += 1
	end
	return level
end

function XpProgression.progress(totalXP: number): (number, number, number)
	local safeXP = math.clamp(math.floor(tonumber(totalXP) or 0), 0, Config.MAX_TOTAL_XP)
	local level = 1
	local remaining = safeXP
	while level < Config.MAX_LEVEL do
		local cost = XpProgression.xpToNextLevel(level)
		if remaining < cost then
			return level, remaining, cost
		end
		remaining -= cost
		level += 1
	end
	return Config.MAX_LEVEL, 0, 0
end

function XpProgression.xpForRun(totals): number
	local rows = math.max(0, math.floor(tonumber(totals.rows) or 0))
	local nearMisses = math.max(0, math.floor(tonumber(totals.nearMisses) or 0))
	local collectibles = math.max(0, math.floor(tonumber(totals.collectibles) or 0))
	local distanceXP = math.min(rows, Config.MAX_DISTANCE_XP_PER_RUN)
	local nearMissXP = math.min(nearMisses, Config.MAX_NEAR_MISS_XP_PER_RUN) * Config.XP_PER_NEAR_MISS
	local collectibleXP = math.min(collectibles, Config.MAX_COLLECTIBLE_XP_PER_RUN) * Config.XP_PER_COLLECTIBLE
	local completionXP = totals.successful == true and rows >= Config.SUCCESSFUL_RUN_MIN_ROWS
		and Config.SUCCESSFUL_RUN_XP or 0
	return math.min(Config.MAX_XP_PER_RUN, distanceXP + nearMissXP + collectibleXP + completionXP)
end

return XpProgression
