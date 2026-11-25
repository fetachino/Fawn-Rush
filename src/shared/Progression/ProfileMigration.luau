--!nonstrict
-- Pure, ordered save migrations. Invalid and future records are refused, never replaced by defaults.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProfileSchema = require(Shared.Progression.ProfileSchema)
local XpProgression = require(Shared.Progression.XpProgression)
local WorldConfig = require(Shared.Config.WorldConfig)
local AnimalConfig = require(Shared.Config.AnimalConfig)

local ProfileMigration = {}

local function copyKnownSet(source, allowed)
	local result = {}
	if type(source) == "table" then
		for key, value in pairs(source) do
			if allowed[key] and value == true then result[key] = true end
		end
	end
	return result
end

local function migrateV1(old, userId: number, now: number)
	local profile = ProfileSchema.defaults(userId, now)
	local oldCurrencies = type(old.currencies) == "table" and old.currencies or {}
	profile.currencies.acorns = math.max(0, math.floor(tonumber(oldCurrencies.acorns or old.acorns) or 0))
	profile.currencies.goldenAcorns = math.max(0, math.floor(tonumber(oldCurrencies.goldenAcorns or old.goldenAcorns) or 0))
	profile.currencies.acornsEarned = math.max(profile.currencies.acorns, math.floor(tonumber(oldCurrencies.acornsEarned) or 0))
	profile.currencies.acornsSpent = math.max(0, math.floor(tonumber(oldCurrencies.acornsSpent) or 0))
	profile.currencies.goldenAcornsEarned = math.max(profile.currencies.goldenAcorns, math.floor(tonumber(oldCurrencies.goldenAcornsEarned) or 0))
	profile.currencies.goldenAcornsSpent = math.max(0, math.floor(tonumber(oldCurrencies.goldenAcornsSpent) or 0))
	for key, value in pairs(profile.currencies) do
		profile.currencies[key] = math.min(value, 2147483647)
	end

	profile.totalXP = math.clamp(math.floor(tonumber(old.totalXP or old.xp) or 0), 0, 2147483647)
	profile.level = XpProgression.levelForXP(profile.totalXP)
	profile.createdAt = math.max(0, math.floor(tonumber(old.createdAt) or now))

	local ownedSource = old.ownedAnimals or (type(old.animals) == "table" and old.animals.owned) or {}
	local allowedAnimals = {}
	for _, id in ipairs(AnimalConfig.ORDER) do allowedAnimals[id] = true end
	profile.animals.owned = copyKnownSet(ownedSource, allowedAnimals)
	profile.animals.owned.deer = true
	local selected = old.selectedAnimal or (type(old.animals) == "table" and old.animals.selected)
	if type(selected) == "string" and profile.animals.owned[selected] then profile.animals.selected = selected end
	profile.animals.unlockedAt.deer = profile.createdAt
	local oldUnlockedAt = type(old.animals) == "table" and old.animals.unlockedAt or {}
	for id in pairs(profile.animals.owned) do
		profile.animals.unlockedAt[id] = math.max(0, math.floor(tonumber(oldUnlockedAt[id]) or profile.createdAt))
	end

	local allowedWorlds = {}
	for _, id in ipairs(WorldConfig.ORDER) do allowedWorlds[id] = true end
	local worldsSource = old.unlockedWorlds or (type(old.worlds) == "table" and old.worlds.unlocked) or { greenwood = true }
	profile.worlds.unlocked = copyKnownSet(worldsSource, allowedWorlds)
	profile.worlds.unlocked.greenwood = true

	local oldStats = type(old.stats) == "table" and old.stats or {}
	for key, field in pairs({
		bestDistance = "bestDistance", totalDistance = "totalDistance", totalRuns = "totalRuns",
		totalDeaths = "totalDeaths", totalCollectibles = "totalCollectibles",
		totalNearMisses = "totalNearMisses", totalTimePlayed = "totalTimePlayed",
		weeklyMissionClaims = "weeklyMissionClaims",
	}) do
		profile.stats[key] = math.clamp(math.floor(tonumber(oldStats[field]) or 0), 0, 2147483647)
	end
	local oldPerWorld = type(oldStats.perWorld) == "table" and oldStats.perWorld or {}
	for worldId in pairs(profile.stats.perWorld) do
		local record = oldPerWorld[worldId]
		if type(record) == "table" then
			profile.stats.perWorld[worldId] = {
				bestDistance = math.clamp(math.floor(tonumber(record.bestDistance) or 0), 0, 2147483647),
				runs = math.clamp(math.floor(tonumber(record.runs) or 0), 0, 2147483647),
			}
		end
	end

	profile.dailyReward = type(old.dailyReward) == "table" and ProfileSchema.clone(old.dailyReward)
		or type(old.login) == "table" and {
			lastClaimDay = tonumber(old.login.lastClaimDay) or -1,
			streak = tonumber(old.login.streak) or 0,
			cycles = tonumber(old.login.cycles) or 0,
			totalClaims = tonumber(old.login.totalClaims) or 0,
		} or profile.dailyReward
	profile.cosmetics = type(old.cosmetics) == "table" and ProfileSchema.clone(old.cosmetics) or profile.cosmetics
	profile.achievements = type(old.achievements) == "table" and ProfileSchema.clone(old.achievements) or {}
	profile.schemaVersion = ProfileSchema.CURRENT_VERSION
	return profile
end

function ProfileMigration.migrate(old, userId: number, now: number)
	if type(old) ~= "table" then return nil, "invalid_profile" end
	local version = tonumber(old.schemaVersion or old._v or old.version)
	if version == ProfileSchema.CURRENT_VERSION then
		local profile = ProfileSchema.clone(old)
		local errors = ProfileSchema.validate(profile, userId)
		if #errors > 0 then return nil, "invalid_profile:" .. table.concat(errors, "; ") end
		return profile, nil, false
	end
	if version == 1 then
		local profile = migrateV1(old, userId, now)
		local errors = ProfileSchema.validate(profile, userId)
		if #errors > 0 then return nil, "migration_invalid:" .. table.concat(errors, "; ") end
		return profile, nil, true
	end
	if version and version > ProfileSchema.CURRENT_VERSION then
		return nil, "future_schema"
	end
	return nil, "unsupported_schema"
end

return ProfileMigration
