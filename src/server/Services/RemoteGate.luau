--!nonstrict
-- The single gate every client-originated remote passes through: token-bucket rate limiting,
-- shape validation, and error containment. Nothing downstream of this module trusts a payload.
-- See docs/02_TECHNICAL_ARCHITECTURE.md §5.4 and §6.

local Logger = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Util.Logger)

local RemoteGate = {}

local buckets = {}
local trips = {}

local VALID_DIRECTIONS = {
	fwd = true,
	back = true,
	left = true,
	right = true,
}

function RemoteGate.isDirection(value): boolean
	return type(value) == "string" and VALID_DIRECTIONS[value] == true
end

function RemoteGate.isFiniteNumber(value): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function bucketFor(player, name: string, rate: number, burst: number)
	local playerBuckets = buckets[player.UserId]
	if not playerBuckets then
		playerBuckets = {}
		buckets[player.UserId] = playerBuckets
	end

	local bucket = playerBuckets[name]
	if not bucket then
		bucket = { tokens = burst, at = os.clock() }
		playerBuckets[name] = bucket
	end

	return bucket
end

-- Token bucket: `rate` tokens per second, capacity `burst`. Returns false when exhausted.
function RemoteGate.allow(player, name: string, rate: number, burst: number?): boolean
	local capacity = burst or rate
	local bucket = bucketFor(player, name, rate, capacity)
	local now = os.clock()
	local elapsed = math.max(0, now - bucket.at)
	bucket.at = now
	bucket.tokens = math.min(capacity, bucket.tokens + elapsed * rate)

	if bucket.tokens < 1 then
		trips[player.UserId] = (trips[player.UserId] or 0) + 1
		return false
	end

	bucket.tokens -= 1
	return true
end

function RemoteGate.tripCount(player): number
	return trips[player.UserId] or 0
end

function RemoteGate.clear(player)
	buckets[player.UserId] = nil
	trips[player.UserId] = nil
end

-- Bind a handler with the standard guard in front of it.
function RemoteGate.bind(remote: RemoteEvent, name: string, rate: number, burst: number, handler)
	remote.OnServerEvent:Connect(function(player, ...)
		if not RemoteGate.allow(player, name, rate, burst) then
			return
		end

		local ok, err = pcall(handler, player, ...)
		if not ok then
			Logger.error("Remote", ("%s handler error: %s"):format(name, tostring(err)))
		end
	end)
end

return RemoteGate
