--!nonstrict
-- Validated run accounting, XP awards, level transitions and persistent world unlock flags.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldConfig = require(Shared.Config.WorldConfig)
local WorldUnlock = require(Shared.Simulation.WorldUnlock)
local ProgressionConfig = require(Shared.Config.ProgressionConfig)
local XpProgression = require(Shared.Progression.XpProgression)
local PlayerDataService = require(script.Parent.PlayerDataService)
local CurrencyService = require(script.Parent.CurrencyService)

local PlayerDataService = require(script.Parent.PlayerDataService)
local ProgressionService = {}

local XP_SOURCES = { run = true, mission = true, achievement = true }

local function updateWorldFlags(profile)
	local unlocked = {}
	for _, world in ipairs(WorldConfig.list()) do
		local meetsRequirements = WorldUnlock.isUnlocked(world.id, {
			level = profile.level,
			lifetimeRows = profile.stats.totalDistance,
		})
		if meetsRequirements and profile.worlds.unlocked[world.id] ~= true then
			profile.worlds.unlocked[world.id] = true
			unlocked[#unlocked + 1] = world.id
		end
	end
	return unlocked
end

function ProgressionService.start()
	PlayerDataService.profileLoaded:Connect(function(player)
		ProgressionService.reconcileWorlds(player)
	end)
end

function ProgressionService.reconcileWorlds(player)
	local newlyUnlocked = {}
	local ok, reason = PlayerDataService.mutate(player, "world_unlock_reconcile", function(profile)
		newlyUnlocked = updateWorldFlags(profile)
	end)
	return ok, reason, newlyUnlocked
end

function ProgressionService.awardXP(player, amount: number, source: string)
	if not XP_SOURCES[source] or type(amount) ~= "number" or amount ~= amount
		or amount == math.huge or amount == -math.huge or amount < 0 or amount % 1 ~= 0 then
		return false, "invalid_xp", 0
	end
	local granted = 0
	local oldLevel = 1
	local newLevel = 1
	local unlockedWorlds = {}
	local ok, reason = PlayerDataService.mutate(player, "xp_award:" .. source, function(profile)
		oldLevel = profile.level
		local newXP = math.min(ProgressionConfig.MAX_TOTAL_XP, profile.totalXP + amount)
		granted = newXP - profile.totalXP
		profile.totalXP = newXP
		profile.level = XpProgression.levelForXP(newXP)
		newLevel = profile.level
		unlockedWorlds = updateWorldFlags(profile)
	end)
	if not ok then return false, reason, 0 end
	local levelCount = math.max(0, newLevel - oldLevel)
	if levelCount > 0 then
		CurrencyService.grant(player, "acorns", levelCount * ProgressionConfig.LEVEL_REWARD_ACORNS, "level_reward")
	end
	return true, { granted = granted, oldLevel = oldLevel, newLevel = newLevel, unlockedWorlds = unlockedWorlds }
end

function ProgressionService.processRun(player, run, reason: string)
	local rows = math.max(0, math.floor(tonumber(run.rows) or 0))
	local collectibles = math.max(0, math.floor(tonumber(run.collectibleCount) or 0))
	local nearMisses = math.max(0, math.floor(tonumber(run.nearMisses) or 0))
	local successful = reason == "bank" and rows >= ProgressionConfig.SUCCESSFUL_RUN_MIN_ROWS
	local profile = PlayerDataService.get(player)
	if not profile then return false, "profile_unavailable" end
	local oldLevel = profile.level
	local previousBest = profile.stats.bestDistance
	local perWorld = profile.stats.perWorld[run.world.id]
	local isNewBest = rows > previousBest
	local runXP = XpProgression.xpForRun({
		rows = rows,
		nearMisses = nearMisses,
		collectibles = collectibles,
		successful = successful,
	})

	local ok, updateReason = PlayerDataService.mutate(player, "run_record", function(draft)
		local stats = draft.stats
		stats.totalDistance = math.min(ProgressionConfig.MAX_TOTAL_XP, stats.totalDistance + rows)
		stats.bestDistance = math.max(stats.bestDistance, rows)
		stats.totalRuns = math.min(ProgressionConfig.MAX_TOTAL_XP, stats.totalRuns + 1)
		stats.totalCollectibles = math.min(ProgressionConfig.MAX_TOTAL_XP, stats.totalCollectibles + collectibles)
		stats.totalNearMisses = math.min(ProgressionConfig.MAX_TOTAL_XP, stats.totalNearMisses + nearMisses)
		if reason == "death" then stats.totalDeaths = math.min(ProgressionConfig.MAX_TOTAL_XP, stats.totalDeaths + 1) end
		local record = stats.perWorld[run.world.id]
		record.runs = math.min(ProgressionConfig.MAX_TOTAL_XP, record.runs + 1)
		record.bestDistance = math.max(record.bestDistance, rows)
		updateWorldFlags(draft)
	end)
	if not ok then return false, updateReason end

	local xpOk, xpResult = ProgressionService.awardXP(player, runXP, "run")
	if not xpOk then return false, xpResult end
	local runAcorns = math.clamp(math.floor(tonumber(run.acorns) or 0), 0, ProgressionConfig.MAX_RUN_ACORN_REWARD)
	local currencyEarned = 0
	if runAcorns > 0 then
		local currencyOk, _, granted = CurrencyService.grant(player, "acorns", runAcorns, "run_reward")
		if currencyOk then currencyEarned = granted end
	end
	local updated = PlayerDataService.get(player)
	run.persistentBestRows = updated and updated.stats.bestDistance or previousBest
	run.progressionSummary = {
		xpEarned = xpResult.granted,
		accountAcornsEarned = currencyEarned,
		accountAcorns = updated and updated.currencies.acorns or 0,
		levelBefore = oldLevel,
		levelAfter = updated and updated.level or oldLevel,
		newBest = isNewBest,
		world = run.world.id,
	}
	return true, run.progressionSummary
end

return ProgressionService
