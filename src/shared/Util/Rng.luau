--!nonstrict
-- Deterministic pseudo-random generator (32-bit Lehmer LCG over float64-safe arithmetic).
--
-- math.random is deliberately not used anywhere in generation or simulation: the server and every
-- client must derive the same chunk from the same seed, and Roblox makes no cross-machine
-- guarantee about math.random. See docs/04_GAMEPLAY_MECHANICS_SPEC.md §5.2 and §12.

local Rng = {}
Rng.__index = Rng

local MOD = 2147483647 -- 2^31 - 1
local MUL = 48271

function Rng.new(seed: number)
	local self = setmetatable({}, Rng)
	local state = math.floor(math.abs(seed)) % MOD
	if state == 0 then
		state = 1
	end
	self.state = state
	return self
end

function Rng:next()
	self.state = (MUL * self.state) % MOD
	return self.state
end

function Rng:float(): number
	return self:next() / MOD
end

function Rng:int(lo: number, hi: number): number
	if hi <= lo then
		return lo
	end
	return lo + math.floor(self:float() * (hi - lo + 1))
end

function Rng:chance(probability: number): boolean
	return self:float() < probability
end

-- Stable integer mix for deriving independent streams from (run seed, chunk index, stream id).
-- Inputs are reduced before multiplying so every intermediate stays inside exact float64 range.
function Rng.mix(a: number, b: number, c: number?): number
	local x = math.floor(math.abs(a)) % 65521
	local y = math.floor(math.abs(b)) % 65521
	local z = c and (math.floor(math.abs(c)) % 65521) or 0
	local h = (x * 2654435761 + y * 40503 + z * 2654435761) % MOD
	if h == 0 then
		h = 1
	end
	return h
end

return Rng
