--!nonstrict
-- Earn-only, non-punitive daily claim schedule. Missing a day never resets the schedule slot.

local DailyRewardConfig = {}

DailyRewardConfig.REWARDS = { 25, 35, 45, 60, 75, 100, 150 }

return DailyRewardConfig
