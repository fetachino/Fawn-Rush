--!nonstrict
-- UTC daily/weekly mission rotation, trusted run-result progress and idempotent reward claims.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local MissionConfig = require(Shared.Config.MissionConfig)
local MissionRules = require(Shared.Progression.MissionRules)
local TimeUtil = require(Shared.Util.TimeUtil)
local PlayerDataService = require(script.Parent.PlayerDataService)
local CurrencyService = require(script.Parent.CurrencyService)
local ProgressionService = require(script.Parent.ProgressionService)

local MissionService = {}

local function ensurePeriods(profile, timestamp: number)
	local daily, dailyChanged = MissionRules.ensure(profile.missions.daily, MissionConfig.DAILY, TimeUtil.utcDay(timestamp))
	local weekly, weeklyChanged = MissionRules.ensure(profile.missions.weekly, MissionConfig.WEEKLY, TimeUtil.utcWeek(timestamp))
	profile.missions.daily = daily
	profile.missions.weekly = weekly
	return dailyChanged or weeklyChanged
end

function MissionService.start()
	PlayerDataService.profileLoaded:Connect(function(player)
		PlayerDataService.mutate(player, "mission_period_init", function(profile)
			ensurePeriods(profile, os.time())
		end)
	end)
end

function MissionService.recordRun(player, run, reason: string)
	local rows = math.max(0, math.floor(tonumber(run.rows) or 0))
	local event = {
		rows = rows,
		collectibles = math.max(0, math.floor(tonumber(run.collectibleCount) or 0)),
		nearMisses = math.max(0, math.floor(tonumber(run.nearMisses) or 0)),
		successful = reason == "bank" and rows >= 50,
		worldId = run.world.id,
	}
	local ok, updateReason = PlayerDataService.mutate(player, "mission_run_progress", function(profile)
		ensurePeriods(profile, os.time())
		MissionRules.apply(profile.missions.daily, event)
		MissionRules.apply(profile.missions.weekly, event)
	end)
	return ok, updateReason
end

function MissionService.claimReady(player)
	local total = { acorns = 0, xp = 0 }
	local claimed = 0
	local weeklyClaims = 0
	local ok, reason = PlayerDataService.mutate(player, "mission_claim_ready", function(profile)
		ensurePeriods(profile, os.time())
		local dailyReward, dailyCount = MissionRules.claimReady(profile.missions.daily)
		local weeklyReward, weeklyCount = MissionRules.claimReady(profile.missions.weekly)
		total.acorns = dailyReward.acorns + weeklyReward.acorns
		total.xp = dailyReward.xp + weeklyReward.xp
		claimed = dailyCount + weeklyCount
		weeklyClaims = weeklyCount
		profile.stats.weeklyMissionClaims = math.min(2147483647, profile.stats.weeklyMissionClaims + weeklyCount)
		if claimed == 0 then return false, "nothing_ready" end
	end)
	if not ok then return false, reason, nil end
	local currencyOk, _, actual = true, total.acorns, 0
	if total.acorns > 0 then currencyOk, _, actual = CurrencyService.grant(player, "acorns", total.acorns, "mission") end
	local xpOk, xpResult = true, { granted = 0 }
	if total.xp > 0 then xpOk, xpResult = ProgressionService.awardXP(player, total.xp, "mission") end
	if not currencyOk or not xpOk then return false, "reward_apply_failed", nil end
	return true, "claimed", { count = claimed, weeklyCount = weeklyClaims, acorns = actual, xp = xpResult.granted }
end

return MissionService
