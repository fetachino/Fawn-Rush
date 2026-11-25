--!nonstrict
-- Pure bounded integer arithmetic for server-owned currency transactions.

local CurrencyRules = {}

function CurrencyRules.isAmount(amount): boolean
	return type(amount) == "number" and amount == amount and amount ~= math.huge and amount ~= -math.huge
		and amount > 0 and amount % 1 == 0
end

function CurrencyRules.grant(balance: number, amount: number, cap: number): (number, number, number)
	local current = math.clamp(math.floor(tonumber(balance) or 0), 0, cap)
	if not CurrencyRules.isAmount(amount) then
		return current, 0, 0
	end
	local granted = math.min(amount, cap - current)
	return current + granted, granted, amount - granted
end

function CurrencyRules.spend(balance: number, amount: number, cap: number): (boolean, number, string?)
	local current = math.clamp(math.floor(tonumber(balance) or 0), 0, cap)
	if not CurrencyRules.isAmount(amount) then
		return false, current, "invalid_amount"
	end
	if current < amount then
		return false, current, "insufficient_funds"
	end
	return true, current - amount, nil
end

return CurrencyRules
