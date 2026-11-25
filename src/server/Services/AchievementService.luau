--!nonstrict
-- Server-evaluated, claimable achievements. Only persisted profile counters feed these thresholds.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local AchievementConfig = require(Shared.Config.AchievementConfig)
local AchievementRules = require(Shared.Progression.AchievementRules)
local PlayerDataService = require(script.Parent.PlayerDataService)
local CurrencyService = require(script.Parent.CurrencyService)
local ProgressionService = require(script.Parent.ProgressionService)

local AchievementService = {}

function AchievementService.evaluate(player)
	local completedNow = 0
	local ok, reason = PlayerDataService.mutate(player, "achievement_evaluate", function(profile)
		for _, definition in ipairs(AchievementConfig.LIST) do
			local progress = math.min(definition.target, AchievementRules.progressFor(definition.metric, profile))
			local entry = profile.achievements[definition.id]
			if not entry then
				entry = { progress = 0, complete = false, claimed = false }
				profile.achievements[definition.id] = entry
			end
			entry.progress = math.max(entry.progress, progress)
			if not entry.complete and entry.progress >= definition.target then
				entry.complete = true
				completedNow += 1
			end
		end
	end)
	return ok, reason, completedNow
end

function AchievementService.start()
	PlayerDataService.profileLoaded:Connect(function(player)
		AchievementService.evaluate(player)
	end)
end

function AchievementService.claimReady(player)
	local total = { acorns = 0, xp = 0 }
	local count = 0
	local ok, reason = PlayerDataService.mutate(player, "achievement_claim_ready", function(profile)
		for _, definition in ipairs(AchievementConfig.LIST) do
			local entry = profile.achievements[definition.id]
			if entry and entry.complete and not entry.claimed then
				entry.claimed = true
				total.acorns += definition.reward.acorns
				total.xp += definition.reward.xp
				count += 1
			end
		end
		if count == 0 then return false, "nothing_ready" end
	end)
	if not ok then return false, reason, nil end
	local currencyOk, _, actual = true, total.acorns, 0
	if total.acorns > 0 then currencyOk, _, actual = CurrencyService.grant(player, "acorns", total.acorns, "achievement") end
	local xpOk, xpResult = true, { granted = 0 }
	if total.xp > 0 then xpOk, xpResult = ProgressionService.awardXP(player, total.xp, "achievement") end
	if not currencyOk or not xpOk then return false, "reward_apply_failed", nil end
	return true, "claimed", { count = count, acorns = actual, xp = xpResult.granted }
end

return AchievementService
