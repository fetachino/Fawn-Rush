--!nonstrict
-- Sole currency mutation gateway. Clients never provide amounts, balances, sources or sinks.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.ProgressionConfig)
local CurrencyRules = require(Shared.Progression.CurrencyRules)
local PlayerDataService = require(script.Parent.PlayerDataService)
local Logger = require(Shared.Util.Logger)

local CurrencyService = {}

local GRANT_SOURCES = {
	run_reward = true,
	mission = true,
	achievement = true,
	daily_reward = true,
	level_reward = true,
}
local SPEND_SINKS = { animal_unlock = true }

local function fieldNames(currency: string)
	if currency == "acorns" then return "acorns", "acornsEarned", "acornsSpent" end
	return nil
end

function CurrencyService.grant(player, currency: string, amount: number, source: string)
	if currency ~= "acorns" or not GRANT_SOURCES[source] or not CurrencyRules.isAmount(amount) then
		return false, "invalid_grant", 0
	end
	local balanceKey, earnedKey = fieldNames(currency)
	local actual = 0
	local newBalance = 0
	local ok, reason = PlayerDataService.mutate(player, "currency_grant:" .. source, function(profile)
		local balance, granted = CurrencyRules.grant(profile.currencies[balanceKey], amount, Config.MAX_CURRENCY)
		actual = granted
		newBalance = balance
		profile.currencies[balanceKey] = balance
		profile.currencies[earnedKey] = math.min(Config.MAX_CURRENCY, profile.currencies[earnedKey] + granted)
	end)
	if not ok then return false, reason, 0 end
	if actual < amount then Logger.warn("Economy", ("Currency cap clipped %d acorn(s) for %d"):format(amount - actual, player.UserId)) end
	return true, newBalance, actual
end

-- afterSpend is a server-only transaction hook used to atomically grant the purchased animal.
function CurrencyService.trySpend(player, currency: string, amount: number, sink: string, afterSpend)
	if currency ~= "acorns" or not SPEND_SINKS[sink] or not CurrencyRules.isAmount(amount) then
		return false, "invalid_spend", nil
	end
	local balanceKey, _, spentKey = fieldNames(currency)
	local newBalance
	local ok, result, detail = PlayerDataService.mutate(player, "currency_spend:" .. sink, function(profile)
		local allowed, balance, reason = CurrencyRules.spend(profile.currencies[balanceKey], amount, Config.MAX_CURRENCY)
		if not allowed then return false, reason end
		profile.currencies[balanceKey] = balance
		profile.currencies[spentKey] = math.min(Config.MAX_CURRENCY, profile.currencies[spentKey] + amount)
		newBalance = balance
		if afterSpend then
			local committed, commitReason = afterSpend(profile)
			if committed == false then return false, commitReason or "transaction_rejected" end
		end
	end)
	if not ok then return false, result, nil end
	return true, newBalance, detail
end

return CurrencyService
