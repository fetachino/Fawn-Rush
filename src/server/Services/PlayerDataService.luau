--!nonstrict
-- Sole profile owner: load status, validated mutations, snapshots, autosave and lock release.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProfileSchema = require(Shared.Progression.ProfileSchema)
local ProgressionConfig = require(Shared.Config.ProgressionConfig)
local Signal = require(Shared.Util.Signal)
local Logger = require(Shared.Util.Logger)
local Net = require(Shared.Constants.Net)
local Remotes = require(Shared.Net.Remotes)
local ProfileStore = require(script.Parent.Parent.Data.ProfileStore)

local PlayerDataService = {}
PlayerDataService.profileLoaded = Signal.new()
PlayerDataService.profileChanged = Signal.new()

local profiles = {}
local states = {}
local sessionIds = {}
local revisions = {}
local dirty = {}
local generations = {}
local removing = {}
local saving = {}
local sessionStartedAt = {}
local playTimeAccountedAt = {}
local nextAutosaveAt = {}
local running = false
local autosaveThread = nil

local function sendStatus(player, state, reason)
	local remote = Remotes.get(Net.REMOTES.ProfileSync)
	if remote then
		remote:FireClient(player, { status = state, reason = reason })
	end
end

function PlayerDataService.init()
	ProfileStore.init()
end

function PlayerDataService.status(player): string
	return states[player] or "loading"
end

function PlayerDataService.isLoaded(player): boolean
	return states[player] == "ready" and profiles[player] ~= nil and removing[player] ~= true
end

function PlayerDataService.get(player)
	if not PlayerDataService.isLoaded(player) then return nil end
	return ProfileSchema.clone(profiles[player])
end

function PlayerDataService.pushSync(player)
	local remote = Remotes.get(Net.REMOTES.ProfileSync)
	if not remote then return false end
	if PlayerDataService.isLoaded(player) then
		remote:FireClient(player, ProfileSchema.toClientSnapshot(profiles[player], os.time()))
	else
		remote:FireClient(player, { status = states[player] or "loading", reason = states[player] == "unavailable" and "profile_unavailable" or nil })
	end
	return true
end

function PlayerDataService.mutate(player, reason: string, mutator)
	if not PlayerDataService.isLoaded(player) then return false, "profile_unavailable" end
	local candidate = ProfileSchema.clone(profiles[player])
	local ok, result, detail = pcall(mutator, candidate)
	if not ok then
		Logger.error("Profile", ("Mutation '%s' failed: %s"):format(reason, tostring(result)))
		return false, "mutation_error"
	end
	if result == false then return false, detail or "rejected" end
	local errors = ProfileSchema.validate(candidate, player.UserId)
	if #errors > 0 then
		Logger.error("Profile", ("Rejected invalid mutation '%s': %s"):format(reason, table.concat(errors, "; ")))
		return false, "invalid_mutation"
	end
	profiles[player] = candidate
	revisions[player] = (revisions[player] or 0) + 1
	dirty[player] = true
	PlayerDataService.profileChanged:Fire(player, ProfileSchema.clone(candidate), reason)
	return true, result, detail
end

function PlayerDataService.load(player)
	if states[player] == "loading" or states[player] == "ready" then return false, "already_loading" end
	local generation = (generations[player] or 0) + 1
	generations[player] = generation
	states[player] = "loading"
	removing[player] = nil
	sendStatus(player, "loading")
	local sessionId = ProfileStore.newSessionId(player.UserId)
	local ok, profile, reason = ProfileStore.load(player.UserId, sessionId)
	if generations[player] ~= generation or player.Parent ~= Players or removing[player] then
		if ok then
			local released, releaseError = ProfileStore.release(player.UserId, sessionId)
			if not released then Logger.warn("Profile", "Late load lock release failed: " .. tostring(releaseError)) end
		end
		return false, "player_left"
	end
	if not ok then
		states[player] = "unavailable"
		Logger.error("Profile", ("Profile load refused for %d: %s"):format(player.UserId, tostring(reason)))
		sendStatus(player, "unavailable", reason)
		return false, reason
	end
	profiles[player] = profile
	sessionIds[player] = sessionId
	revisions[player] = 1
	dirty[player] = false
	states[player] = "ready"
	sessionStartedAt[player] = os.clock()
	playTimeAccountedAt[player] = os.clock()
	nextAutosaveAt[player] = os.clock() + (player.UserId % 30)
	PlayerDataService.profileLoaded:Fire(player, ProfileSchema.clone(profile))
	PlayerDataService.pushSync(player)
	return true, nil
end

local function accountSessionTime(player)
	local current = os.clock()
	local previous = playTimeAccountedAt[player] or current
	local seconds = math.max(0, math.floor(current - previous))
	if seconds > 0 then
		local ok = PlayerDataService.mutate(player, "session_time", function(profile)
			profile.stats.totalTimePlayed = math.min(2147483647, profile.stats.totalTimePlayed + seconds)
		end)
		if ok then playTimeAccountedAt[player] = previous + seconds end
	end
end

local function savePlayer(player, releaseLock: boolean)
	while saving[player] do task.wait(0.05) end
	if not profiles[player] or not sessionIds[player] then return false, "profile_unavailable" end
	saving[player] = true
	accountSessionTime(player)
	local success = false
	local saveError = nil
	local attempts = releaseLock and 3 or 1
	for _ = 1, attempts do
		local revision = revisions[player]
		local snapshot = ProfileSchema.clone(profiles[player])
		success, saveError = ProfileStore.save(player.UserId, snapshot, sessionIds[player])
		if not success or revisions[player] == revision then break end
	end
	if success then dirty[player] = false end
	if releaseLock then
		if not success then
			Logger.error("Profile", ("Final save failed for %d: %s"):format(player.UserId, tostring(saveError)))
		end
		local released, releaseError = ProfileStore.release(player.UserId, sessionIds[player])
		if not released then Logger.warn("Profile", ("Lock release failed for %d: %s"):format(player.UserId, tostring(releaseError))) end
		profiles[player] = nil
		sessionIds[player] = nil
		revisions[player] = nil
		dirty[player] = nil
		sessionStartedAt[player] = nil
		playTimeAccountedAt[player] = nil
		nextAutosaveAt[player] = nil
		states[player] = nil
		removing[player] = nil
	end
	saving[player] = nil
	return success, saveError
end

function PlayerDataService.playerRemoving(player)
	if profiles[player] then accountSessionTime(player) end
	removing[player] = true
	generations[player] = (generations[player] or 0) + 1
	if profiles[player] then
		states[player] = "releasing"
		return savePlayer(player, true)
	end
	states[player] = nil
	removing[player] = nil
	return true
end

function PlayerDataService.start()
	running = true
	Players.PlayerAdded:Connect(function(player)
		task.defer(function() PlayerDataService.load(player) end)
	end)
	if autosaveThread then task.cancel(autosaveThread) end
	autosaveThread = task.spawn(function()
		while running do
			task.wait(5)
			local now = os.clock()
			for player, profile in pairs(profiles) do
				if profile and not removing[player] and now >= (nextAutosaveAt[player] or math.huge) then
					nextAutosaveAt[player] = now + ProgressionConfig.AUTOSAVE_SECONDS
					task.spawn(savePlayer, player, false)
				end
			end
		end
	end)
end

function PlayerDataService.shutdown(timeoutSeconds: number?)
	running = false
	if autosaveThread then task.cancel(autosaveThread); autosaveThread = nil end
	local pending = 0
	for player, state in pairs(states) do
		if state == "loading" then
			generations[player] = (generations[player] or 0) + 1
			removing[player] = true
		end
	end
	for player in pairs(profiles) do
		accountSessionTime(player)
		removing[player] = true
		states[player] = "releasing"
		pending += 1
		task.spawn(function()
			savePlayer(player, true)
			pending -= 1
		end)
	end
	local deadline = os.clock() + (timeoutSeconds or ProgressionConfig.SHUTDOWN_TIMEOUT_SECONDS)
	while pending > 0 and os.clock() < deadline do task.wait(0.1) end
	if pending > 0 then Logger.warn("Profile", ("Shutdown save timeout with %d profile(s) pending"):format(pending)) end
end

return PlayerDataService
