--!nonstrict
-- Non-punitive daily login reward: one claim per UTC day, schedule advances only on a claim.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local DailyRewardRules = require(Shared.Progression.DailyRewardRules)
local TimeUtil = require(Shared.Util.TimeUtil)
local PlayerDataService = require(script.Parent.PlayerDataService)
local CurrencyService = require(script.Parent.CurrencyService)

local LoginRewardService = {}

function LoginRewardService.claim(player)
	local amount = 0
	local ok, reason = PlayerDataService.mutate(player, "daily_reward_claim", function(profile)
		local eligible, updated, result = DailyRewardRules.claim(profile.dailyReward, TimeUtil.utcDay(os.time()))
		if not eligible then return false, result end
		profile.dailyReward = updated
		amount = result
	end)
	if not ok then return false, reason, 0 end
	local granted, _, actual = CurrencyService.grant(player, "acorns", amount, "daily_reward")
	if not granted then return false, "reward_apply_failed", 0 end
	return true, "claimed", actual
end

return LoginRewardService
