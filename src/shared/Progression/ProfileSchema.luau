--!nonstrict
-- Canonical versioned player progression document. Only plain, validated data is persisted.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProgressionConfig = require(Shared.Config.ProgressionConfig)
local AnimalConfig = require(Shared.Config.AnimalConfig)
local WorldConfig = require(Shared.Config.WorldConfig)
local MissionConfig = require(Shared.Config.MissionConfig)
local AchievementConfig = require(Shared.Config.AchievementConfig)
local XpProgression = require(Shared.Progression.XpProgression)
local TimeUtil = require(Shared.Util.TimeUtil)
local DailyRewardConfig = require(Shared.Config.DailyRewardConfig)

local ProfileSchema = {}
ProfileSchema.CURRENT_VERSION = 2

local function isFinite(value): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function isInteger(value, minimum: number, maximum: number): boolean
	return isFinite(value) and value % 1 == 0 and value >= minimum and value <= maximum
end

local function countKeys(value, maximum: number): boolean
	if type(value) ~= "table" then return false end
	local count = 0
	for _ in pairs(value) do
		count += 1
		if count > maximum then return false end
	end
	return true
end

local function newStats()
	local perWorld = {}
	for _, worldId in ipairs(WorldConfig.ORDER) do
		perWorld[worldId] = { bestDistance = 0, runs = 0 }
	end
	return {
		bestDistance = 0,
		totalDistance = 0,
		totalRuns = 0,
		totalDeaths = 0,
		totalCollectibles = 0,
		totalNearMisses = 0,
		totalTimePlayed = 0,
		weeklyMissionClaims = 0,
		perWorld = perWorld,
	}
end

function ProfileSchema.defaults(userId: number, now: number?)
	local timestamp = math.max(0, math.floor(tonumber(now) or os.time()))
	return {
		schemaVersion = ProfileSchema.CURRENT_VERSION,
		userId = userId,
		createdAt = timestamp,
		currencies = {
			acorns = 0,
			goldenAcorns = 0,
			acornsEarned = 0,
			acornsSpent = 0,
			goldenAcornsEarned = 0,
			goldenAcornsSpent = 0,
		},
		totalXP = 0,
		level = 1,
		animals = { owned = { deer = true }, selected = "deer", unlockedAt = { deer = timestamp } },
		worlds = { unlocked = { greenwood = true } },
		achievements = {},
		missions = {
			daily = { period = -1, entries = {}, pending = {} },
			weekly = { period = -1, entries = {}, pending = {} },
		},
		stats = newStats(),
		dailyReward = { lastClaimDay = -1, streak = 0, cycles = 0, totalClaims = 0 },
		cosmetics = { owned = {}, selected = {} },
	}
end

function ProfileSchema.clone(value)
	if type(value) ~= "table" then return value end
	local copy = {}
	for key, child in pairs(value) do
		copy[ProfileSchema.clone(key)] = ProfileSchema.clone(child)
	end
	return copy
end

local function validateMissionState(state, expectedCount: number, path: string, errors)
	if type(state) ~= "table" or not isInteger(state.period, -1, 1000000)
		or not countKeys(state.entries, expectedCount + 8) or type(state.pending) ~= "table" then
		errors[#errors + 1] = path .. " has an invalid shape"
		return
	end
	local pendingCount = 0
	for _, entry in ipairs(state.pending) do
		pendingCount += 1
		if pendingCount > 500 or type(entry) ~= "table" or type(entry.id) ~= "string"
			or not isInteger(entry.progress, 0, 100000000) or not isInteger(entry.target, 1, 100000000)
			or entry.progress < entry.target or entry.complete ~= true or entry.claimed == true
			or type(entry.reward) ~= "table" or not isInteger(entry.reward.acorns, 0, ProgressionConfig.MAX_CURRENCY)
			or not isInteger(entry.reward.xp, 0, ProgressionConfig.MAX_TOTAL_XP) then
			errors[#errors + 1] = path .. ".pending contains an invalid record"
			return
		end
	end
	for id, entry in pairs(state.entries) do
		if type(id) ~= "string" or type(entry) ~= "table" or entry.id ~= id
			or not isInteger(entry.target, 1, 100000000) or not isInteger(entry.progress, 0, entry.target)
			or type(entry.complete) ~= "boolean" or type(entry.claimed) ~= "boolean"
			or type(entry.reward) ~= "table" or not isInteger(entry.reward.acorns, 0, ProgressionConfig.MAX_CURRENCY)
			or not isInteger(entry.reward.xp, 0, ProgressionConfig.MAX_TOTAL_XP)
			or (entry.complete and entry.progress < entry.target) then
			errors[#errors + 1] = path .. ".entries contains an invalid record"
			return
		end
	end
end

function ProfileSchema.validate(profile, expectedUserId: number?): { string }
	local errors = {}
	if type(profile) ~= "table" then return { "profile is not a table" } end
	if profile.schemaVersion ~= ProfileSchema.CURRENT_VERSION then errors[#errors + 1] = "schemaVersion is not current" end
	if not isInteger(profile.userId, 1, 9007199254740991) then errors[#errors + 1] = "userId is invalid" end
	if expectedUserId and profile.userId ~= expectedUserId then errors[#errors + 1] = "userId does not match the datastore key" end
	if not isInteger(profile.createdAt, 0, 9007199254740991) then errors[#errors + 1] = "createdAt is invalid" end
	if not isInteger(profile.totalXP, 0, ProgressionConfig.MAX_TOTAL_XP) then errors[#errors + 1] = "totalXP is invalid" end
	if not isInteger(profile.level, 1, ProgressionConfig.MAX_LEVEL) then errors[#errors + 1] = "level is invalid" end
	if isInteger(profile.totalXP, 0, ProgressionConfig.MAX_TOTAL_XP)
		and profile.level ~= XpProgression.levelForXP(profile.totalXP) then
		errors[#errors + 1] = "level does not match totalXP"
	end

	local currencies = profile.currencies
	if type(currencies) ~= "table" then
		errors[#errors + 1] = "currencies is missing"
	else
		for _, key in ipairs({ "acorns", "goldenAcorns", "acornsEarned", "acornsSpent", "goldenAcornsEarned", "goldenAcornsSpent" }) do
			if not isInteger(currencies[key], 0, ProgressionConfig.MAX_CURRENCY) then errors[#errors + 1] = "currencies." .. key .. " is invalid" end
		end
	end

	local animals = profile.animals
	if type(animals) ~= "table" or not countKeys(animals.owned, #AnimalConfig.ORDER)
		or not countKeys(animals.unlockedAt, #AnimalConfig.ORDER) or type(animals.selected) ~= "string" then
		errors[#errors + 1] = "animals is invalid"
	else
		for animalId, owned in pairs(animals.owned) do
			if not AnimalConfig.animals[animalId] or owned ~= true then errors[#errors + 1] = "animals.owned contains an invalid entry"; break end
		end
		for animalId, timestamp in pairs(animals.unlockedAt) do
			if not animals.owned[animalId] or not isInteger(timestamp, 0, 9007199254740991) then errors[#errors + 1] = "animals.unlockedAt contains an invalid entry"; break end
		end
		if animals.owned.deer ~= true or animals.owned[animals.selected] ~= true then errors[#errors + 1] = "starter or selected animal is not owned" end
	end

	local worlds = profile.worlds
	if type(worlds) ~= "table" or not countKeys(worlds.unlocked, #WorldConfig.ORDER) or worlds.unlocked.greenwood ~= true then
		errors[#errors + 1] = "worlds is invalid"
	else
		for worldId, unlocked in pairs(worlds.unlocked) do
			if not WorldConfig.exists(worldId) or unlocked ~= true then errors[#errors + 1] = "worlds.unlocked contains an invalid entry"; break end
		end
	end

	local stats = profile.stats
	if type(stats) ~= "table" then
		errors[#errors + 1] = "stats is missing"
	else
		for _, key in ipairs({ "bestDistance", "totalDistance", "totalRuns", "totalDeaths", "totalCollectibles", "totalNearMisses", "totalTimePlayed", "weeklyMissionClaims" }) do
			if not isInteger(stats[key], 0, ProgressionConfig.MAX_TOTAL_XP) then errors[#errors + 1] = "stats." .. key .. " is invalid" end
		end
		if type(stats.perWorld) ~= "table" then
			errors[#errors + 1] = "stats.perWorld is missing"
		else
			for worldId, record in pairs(stats.perWorld) do
				if not WorldConfig.exists(worldId) or type(record) ~= "table"
					or not isInteger(record.bestDistance, 0, ProgressionConfig.MAX_TOTAL_XP)
					or not isInteger(record.runs, 0, ProgressionConfig.MAX_TOTAL_XP) then
					errors[#errors + 1] = "stats.perWorld contains an invalid entry"
					break
				end
			end
		end
	end

	if type(profile.missions) ~= "table" then
		errors[#errors + 1] = "missions is missing"
	else
		validateMissionState(profile.missions.daily, #MissionConfig.DAILY, "missions.daily", errors)
		validateMissionState(profile.missions.weekly, #MissionConfig.WEEKLY, "missions.weekly", errors)
	end
	if type(profile.achievements) ~= "table" or not countKeys(profile.achievements, #AchievementConfig.LIST) then
		errors[#errors + 1] = "achievements is invalid"
	else
		for id, entry in pairs(profile.achievements) do
			if not AchievementConfig.get(id) or type(entry) ~= "table"
				or not isInteger(entry.progress, 0, ProgressionConfig.MAX_TOTAL_XP)
				or type(entry.complete) ~= "boolean" or type(entry.claimed) ~= "boolean"
				or (entry.complete and entry.progress < AchievementConfig.get(id).target) then
				errors[#errors + 1] = "achievements contains an invalid entry"
				break
			end
		end
	end

	local daily = profile.dailyReward
	if type(daily) ~= "table" or not isInteger(daily.lastClaimDay, -1, 1000000)
		or not isInteger(daily.streak, 0, #DailyRewardConfig.REWARDS - 1)
		or not isInteger(daily.cycles, 0, ProgressionConfig.MAX_TOTAL_XP)
		or not isInteger(daily.totalClaims, 0, ProgressionConfig.MAX_TOTAL_XP) then
		errors[#errors + 1] = "dailyReward is invalid"
	end

	local cosmetics = profile.cosmetics
	if type(cosmetics) ~= "table" or not countKeys(cosmetics.owned, 100)
		or not countKeys(cosmetics.selected, 20) then
		errors[#errors + 1] = "cosmetics is invalid"
	end
	if type(profile.cosmetics) == "table" then
		for id, owned in pairs(profile.cosmetics.owned or {}) do
			if type(id) ~= "string" or owned ~= true then errors[#errors + 1] = "cosmetics.owned contains an invalid entry"; break end
		end
		for slot, id in pairs(profile.cosmetics.selected or {}) do
			if type(slot) ~= "string" or (id ~= nil and type(id) ~= "string") then errors[#errors + 1] = "cosmetics.selected contains an invalid entry"; break end
		end
	end

	return errors
end

function ProfileSchema.toClientSnapshot(profile, serverNow: number)
	local level, xpIntoLevel, xpNeeded = XpProgression.progress(profile.totalXP)
	local day = TimeUtil.utcDay(serverNow)
	local nextSlot = (profile.dailyReward.streak % #DailyRewardConfig.REWARDS) + 1
	local ownedStandard = 0
	for animalId, owned in pairs(profile.animals.owned) do
		if owned and animalId ~= "moonlit" then ownedStandard += 1 end
	end
	local completedAchievements, readyAchievements = 0, 0
	for _, achievement in pairs(profile.achievements) do
		if achievement.complete then completedAchievements += 1 end
		if achievement.complete and not achievement.claimed then readyAchievements += 1 end
	end
	local dailyReady, weeklyReady = 0, 0
	for _, entry in pairs(profile.missions.daily.entries) do
		if entry.complete and not entry.claimed then dailyReady += 1 end
	end
	for _, entry in pairs(profile.missions.weekly.entries) do
		if entry.complete and not entry.claimed then weeklyReady += 1 end
	end
	dailyReady += #profile.missions.daily.pending
	weeklyReady += #profile.missions.weekly.pending
	return {
		status = "ready",
		level = level,
		totalXP = profile.totalXP,
		xpIntoLevel = xpIntoLevel,
		xpNeeded = xpNeeded,
		currencies = { acorns = profile.currencies.acorns, goldenAcorns = profile.currencies.goldenAcorns },
		animals = {
			owned = ProfileSchema.clone(profile.animals.owned),
			selected = profile.animals.selected,
			standardOwned = ownedStandard,
		},
		worlds = { unlocked = ProfileSchema.clone(profile.worlds.unlocked) },
		missions = ProfileSchema.clone(profile.missions),
		missionReadyCount = dailyReady + weeklyReady,
		achievements = {
			entries = ProfileSchema.clone(profile.achievements),
			completed = completedAchievements,
			ready = readyAchievements,
		},
		stats = {
			bestDistance = profile.stats.bestDistance,
			totalDistance = profile.stats.totalDistance,
			totalRuns = profile.stats.totalRuns,
			totalCollectibles = profile.stats.totalCollectibles,
			totalNearMisses = profile.stats.totalNearMisses,
			totalTimePlayed = profile.stats.totalTimePlayed,
			perWorld = ProfileSchema.clone(profile.stats.perWorld),
		},
		dailyReward = {
			eligible = profile.dailyReward.lastClaimDay < day,
			claimedToday = profile.dailyReward.lastClaimDay == day,
			streak = profile.dailyReward.streak,
			nextSlot = nextSlot,
			nextReward = DailyRewardConfig.REWARDS[nextSlot],
			totalClaims = profile.dailyReward.totalClaims,
		},
	}
end

return ProfileSchema
