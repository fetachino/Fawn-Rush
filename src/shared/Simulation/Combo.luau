--!nonstrict
-- Combo ladder and decay. Pure: no clock is read internally, the caller supplies `now`.
--
-- A combo is built by consecutive near misses and decays to ×1.0 after COMBO_DECAY seconds without
-- one. It multiplies near-miss acorns and adds score; it never multiplies XP rate, mission progress,
-- or anything purchased. See docs/04_GAMEPLAY_MECHANICS_SPEC.md §7.4.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.GameConfig)

local Combo = {}

function Combo.new()
	return {
		hits = 0,
		lastAt = -math.huge,
	}
end

function Combo.multiplierFor(hits: number): number
	if hits <= 0 then
		return GameConfig.COMBO_STEPS[1]
	end
	local index = math.min(hits, #GameConfig.COMBO_STEPS)
	return GameConfig.COMBO_STEPS[index]
end

function Combo.reset(combo)
	combo.hits = 0
	combo.lastAt = -math.huge
end

-- Registers one near miss and returns the new multiplier.
function Combo.register(combo, now: number): number
	combo.hits += 1
	combo.lastAt = now
	return Combo.multiplierFor(combo.hits)
end

-- Reads the live multiplier without mutating history: an expired combo reads as ×1.0.
function Combo.current(combo, now: number): number
	if combo.hits <= 0 then
		return GameConfig.COMBO_STEPS[1]
	end
	if now - combo.lastAt > GameConfig.COMBO_DECAY then
		return GameConfig.COMBO_STEPS[1]
	end
	return Combo.multiplierFor(combo.hits)
end

-- Seconds until the combo expires; 0 when there is none.
function Combo.timeLeft(combo, now: number): number
	if combo.hits <= 0 then
		return 0
	end
	return math.max(0, GameConfig.COMBO_DECAY - (now - combo.lastAt))
end

-- The server uses this to expire a stale chain so a new near miss starts from one, not from five.
function Combo.settle(combo, now: number)
	if combo.hits > 0 and now - combo.lastAt > GameConfig.COMBO_DECAY then
		Combo.reset(combo)
	end
end

function Combo.acornReward(multiplier: number): number
	return math.min(GameConfig.NEAR_MISS_ACORNS_CAP, math.floor(GameConfig.NEAR_MISS_ACORNS * multiplier))
end

function Combo.scoreReward(multiplier: number): number
	return math.floor(GameConfig.NEAR_MISS_SCORE * multiplier)
end

return Combo
