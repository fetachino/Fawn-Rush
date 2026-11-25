--!nonstrict
-- Server-owned animal ownership and selection validation; no asset/model is fabricated here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local AnimalConfig = require(Shared.Config.AnimalConfig)
local AnimalUnlockRules = require(script.Parent.AnimalUnlockRules)
local PlayerDataService = require(script.Parent.PlayerDataService)
local CurrencyService = require(script.Parent.CurrencyService)

local AnimalService = {}

local CHALLENGE_ANIMALS = { duck = true, hedgehog = true, otter = true, bearcub = true, moonlit = true }

local function grantToProfile(profile, animalId: string, now: number)
	if not AnimalConfig.animals[animalId] then return false, "unknown_animal" end
	if profile.animals.owned[animalId] then return false, "already_owned" end
	profile.animals.owned[animalId] = true
	profile.animals.unlockedAt[animalId] = now
	return true
end

function AnimalService.unlockPurchase(player, animalId: string)
	local profile = PlayerDataService.get(player)
	if not profile then return false, "profile_unavailable" end
	local animal = AnimalConfig.animals[animalId]
	if not animal then return false, "unknown_animal" end
	local allowed, reason = AnimalUnlockRules.canPurchase(animalId, profile.animals.owned, profile.currencies.acorns)
	if not allowed then return false, reason end
	local success, result = CurrencyService.trySpend(player, "acorns", animal.unlock.price, "animal_unlock", function(draft)
		return grantToProfile(draft, animalId, os.time())
	end)
	return success, success and "unlocked" or result
end

function AnimalService.grantChallenge(player, animalId: string)
	if not CHALLENGE_ANIMALS[animalId] then return false, "not_challenge_animal" end
	local granted = false
	local ok, reason = PlayerDataService.mutate(player, "animal_challenge_unlock", function(profile)
		local success, unlockReason = grantToProfile(profile, animalId, os.time())
		if not success then return false, unlockReason end
		granted = true
	end)
	return ok and granted, reason
end

function AnimalService.processRun(player, run)
	local profile = PlayerDataService.get(player)
	if not profile then return false, "profile_unavailable" end
	local newlyUnlocked = {}
	for animalId in pairs(CHALLENGE_ANIMALS) do
		if not profile.animals.owned[animalId]
			and AnimalUnlockRules.challengeSatisfied(animalId, run, profile.stats.weeklyMissionClaims) then
			local granted = AnimalService.grantChallenge(player, animalId)
			if granted then newlyUnlocked[#newlyUnlocked + 1] = animalId end
		end
	end
	run.unlockedAnimals = newlyUnlocked
	return true, newlyUnlocked
end

function AnimalService.select(player, animalId: string)
	local selected = false
	local ok, reason = PlayerDataService.mutate(player, "animal_select", function(profile)
		if not AnimalUnlockRules.validSelection(animalId, profile.animals.owned) then
			return false, "animal_not_owned"
		end
		profile.animals.selected = animalId
		selected = true
	end)
	return ok and selected, reason
end

function AnimalService.evaluatePersistent(player)
	local profile = PlayerDataService.get(player)
	if not profile or profile.stats.weeklyMissionClaims < 7 or profile.animals.owned.bearcub then
		return false, "not_ready"
	end
	return AnimalService.grantChallenge(player, "bearcub")
end

function AnimalService.isOwned(player, animalId: string): boolean
	local profile = PlayerDataService.get(player)
	return profile ~= nil and profile.animals.owned[animalId] == true
end

return AnimalService
