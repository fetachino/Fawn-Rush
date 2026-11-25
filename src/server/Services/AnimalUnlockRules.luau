--!nonstrict
-- Server-only animal challenge and purchase validation. Secret criteria never arrive from clients.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnimalConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.AnimalConfig)

local AnimalUnlockRules = {}

function AnimalUnlockRules.canPurchase(animalId: string, owned, balance: number): (boolean, string?)
	local animal = AnimalConfig.animals[animalId]
	if not animal then return false, "unknown_animal" end
	if owned[animalId] then return false, "already_owned" end
	if animal.unlock.kind ~= "acorns" then return false, "not_purchasable" end
	local price = animal.unlock.price
	if type(price) ~= "number" or price < 1 or price % 1 ~= 0 then return false, "invalid_price" end
	if balance < price then return false, "insufficient_funds" end
	return true, nil
end

function AnimalUnlockRules.challengeSatisfied(animalId: string, run, weeklyMissionClaims: number): boolean
	if animalId == "duck" then return run.nearMisses >= 3 end
	if animalId == "hedgehog" then return run.rows >= 200 end
	if animalId == "otter" then return run.acornValue >= 40 end
	if animalId == "bearcub" then return weeklyMissionClaims >= 7 end
	if animalId == "moonlit" then return run.rows >= 150 and run.secretHazardClear == true end
	return false
end

function AnimalUnlockRules.validSelection(animalId: string, owned): boolean
	return type(animalId) == "string" and AnimalConfig.animals[animalId] ~= nil and owned[animalId] == true
end

return AnimalUnlockRules
