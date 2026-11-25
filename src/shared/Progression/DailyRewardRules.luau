--!nonstrict
-- Pure daily eligibility and claim-slot logic; missed days do not reset or skip the schedule.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rewards = require(ReplicatedStorage:WaitForChild("Shared").Config.DailyRewardConfig).REWARDS

local DailyRewardRules = {}

function DailyRewardRules.eligible(state, utcDay: number): boolean
	return type(state) == "table" and type(utcDay) == "number" and utcDay > (state.lastClaimDay or -1)
end

function DailyRewardRules.nextReward(state): (number, number)
	local nextSlot = ((math.max(0, math.floor(tonumber(state.streak) or 0))) % #Rewards) + 1
	return nextSlot, Rewards[nextSlot]
end

function DailyRewardRules.claim(state, utcDay: number)
	if not DailyRewardRules.eligible(state, utcDay) then
		return false, nil, "already_claimed"
	end
	local nextSlot, amount = DailyRewardRules.nextReward(state)
	local updated = table.clone(state)
	updated.lastClaimDay = utcDay
	updated.streak = nextSlot
	updated.totalClaims = (tonumber(state.totalClaims) or 0) + 1
	updated.cycles = (tonumber(state.cycles) or 0) + (nextSlot == #Rewards and 1 or 0)
	return true, updated, amount
end

return DailyRewardRules
