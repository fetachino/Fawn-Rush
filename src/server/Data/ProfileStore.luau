--!nonstrict
-- DataStore adapter with session leases, migration-on-load, retries and refusal on uncertainty.
-- A failed, locked, corrupt or future-version load never writes a default over the stored record.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RobloxRunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProgressionConfig = require(Shared.Config.ProgressionConfig)
local ProfileSchema = require(Shared.Progression.ProfileSchema)
local ProfileMigration = require(Shared.Progression.ProfileMigration)

local ProfileStore = {}
local store = nil

function ProfileStore.newSessionId(userId: number): string
	return tostring(game.JobId) .. ":" .. tostring(userId) .. ":" .. HttpService:GenerateGUID(false)
end

function ProfileStore.init()
	local storeName = RobloxRunService:IsStudio()
		and ProgressionConfig.STUDIO_STORE_NAME
		or ProgressionConfig.STORE_NAME
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(storeName)
	end)
	if ok then
		store = result
	else
		store = nil
	end
end

function ProfileStore.makeLoadTransform(userId: number, sessionId: string, now: number)
	local outcome = { kind = "unattempted" }
	local function transform(old)
		outcome = { kind = "blocked" }
		if old ~= nil and type(old) ~= "table" then
			outcome = { kind = "invalid_record" }
			return nil
		end
		local current = old
		if current and current.lock ~= nil then
			local lock = current.lock
			if type(lock) ~= "table" or type(lock.sessionId) ~= "string"
				or type(lock.expiresAt) ~= "number" or lock.expiresAt ~= lock.expiresAt then
				outcome = { kind = "invalid_lock" }
				return nil
			end
			if lock.sessionId ~= sessionId and lock.expiresAt > now then
				outcome = { kind = "locked" }
				return nil
			end
		end

		local profile
		local migrated = false
		if current == nil then
			profile = ProfileSchema.defaults(userId, now)
		else
			if type(current.profile) ~= "table" then
				outcome = { kind = "invalid_record" }
				return nil
			end
			local reason
			profile, reason, migrated = ProfileMigration.migrate(current.profile, userId, now)
			if not profile then
				outcome = { kind = "invalid_profile", reason = reason }
				return nil
			end
		end

		outcome = { kind = "loaded", profile = ProfileSchema.clone(profile), migrated = migrated }
		return {
			profile = profile,
			lock = {
				sessionId = sessionId,
				expiresAt = now + ProgressionConfig.SESSION_LOCK_SECONDS,
			},
		}
	end
	return transform, function() return outcome end
end

function ProfileStore.makeSaveTransform(profile, sessionId: string, now: number)
	local outcome = { kind = "unattempted" }
	local function transform(old)
		outcome = { kind = "lock_lost" }
		if type(old) ~= "table" or type(old.profile) ~= "table" or type(old.lock) ~= "table"
			or old.lock.sessionId ~= sessionId then
			return nil
		end
		local errors = ProfileSchema.validate(profile, profile.userId)
		if #errors > 0 then
			outcome = { kind = "invalid_profile", reason = table.concat(errors, "; ") }
			return nil
		end
		outcome = { kind = "saved" }
		return {
			profile = ProfileSchema.clone(profile),
			lock = { sessionId = sessionId, expiresAt = now + ProgressionConfig.SESSION_LOCK_SECONDS },
		}
	end
	return transform, function() return outcome end
end

function ProfileStore.makeReleaseTransform(sessionId: string)
	local outcome = { kind = "unattempted" }
	local function transform(old)
		outcome = { kind = "lock_lost" }
		if type(old) ~= "table" or type(old.profile) ~= "table" or type(old.lock) ~= "table"
			or old.lock.sessionId ~= sessionId then
			return nil
		end
		outcome = { kind = "released" }
		return { profile = old.profile, lock = nil }
	end
	return transform, function() return outcome end
end

local function performUpdate(userId: number, transform)
	if not store then return false, nil, "datastore_unavailable" end
	local key = "player_" .. tostring(userId)
	local ok, result = pcall(function()
		return store:UpdateAsync(key, transform)
	end)
	if not ok then return false, nil, tostring(result) end
	return true, result, nil
end

local function waitBeforeRetry(attempt: number)
	local delay = ProgressionConfig.RETRY_DELAYS[attempt]
	if delay then task.wait(delay) end
end

function ProfileStore.load(userId: number, sessionId: string)
	if not store then return false, nil, "datastore_unavailable" end
	local lastError = "load_failed"
	for attempt = 1, ProgressionConfig.MAX_LOAD_ATTEMPTS do
		local transform, getOutcome = ProfileStore.makeLoadTransform(userId, sessionId, os.time())
		local ok, record, err = performUpdate(userId, transform)
		local outcome = getOutcome()
		if ok and outcome.kind == "loaded" then
			return true, outcome.profile, nil
		end
		if ok and outcome.kind ~= "locked" then
			return false, nil, outcome.reason or outcome.kind
		end
		lastError = ok and "session_locked" or err
		if attempt < ProgressionConfig.MAX_LOAD_ATTEMPTS then waitBeforeRetry(attempt) end
	end
	return false, nil, lastError
end

function ProfileStore.save(userId: number, profile, sessionId: string)
	local lastError = "save_failed"
	for attempt = 1, ProgressionConfig.MAX_SAVE_ATTEMPTS do
		local transform, getOutcome = ProfileStore.makeSaveTransform(profile, sessionId, os.time())
		local ok, _, err = performUpdate(userId, transform)
		local outcome = getOutcome()
		if ok and outcome.kind == "saved" then return true, nil end
		if ok and outcome.kind ~= "unattempted" then
			return false, outcome.reason or outcome.kind
		end
		lastError = err or outcome.kind
		if attempt < ProgressionConfig.MAX_SAVE_ATTEMPTS then waitBeforeRetry(attempt) end
	end
	return false, lastError
end

function ProfileStore.release(userId: number, sessionId: string)
	local transform, getOutcome = ProfileStore.makeReleaseTransform(sessionId)
	local ok, _, err = performUpdate(userId, transform)
	local outcome = getOutcome()
	if ok and outcome.kind == "released" then return true, nil end
	return false, err or outcome.kind
end

return ProfileStore
