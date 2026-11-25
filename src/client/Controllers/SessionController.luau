--!nonstrict
-- Session: the one place that talks to the server about runs. Other controllers observe its
-- signals instead of listening to remotes themselves, so there is exactly one interpretation of
-- the server's messages in the client.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Constants.Net)
local Remotes = require(Shared.Net.Remotes)
local WorldConfig = require(Shared.Config.WorldConfig)
local ChunkFormat = require(Shared.Simulation.ChunkFormat)
local Signal = require(Shared.Util.Signal)
local Logger = require(Shared.Util.Logger)

local SessionController = {}

SessionController.signals = {
	runStarted = Signal.new(),
	startResult = Signal.new(),
	chunkAdded = Signal.new(),
	stateUpdated = Signal.new(),
	runEnded = Signal.new(),
	pickup = Signal.new(),
	nearMiss = Signal.new(),
	returnedToLobby = Signal.new(),
}

SessionController.state = {
	active = false,
	zoneOrigin = Vector3.zero,
	startTime = 0,
	worldId = WorldConfig.DEFAULT,
	runIndex = 0,
	row = 0,
	combo = 1,
	comboTime = 0,
}

-- Which animal this client wears. Equipping is Phase 7; until then the deer is the default and this
-- field is the single place the rest of the client reads it from.
SessionController.selectedAnimal = "deer"

-- Which world the PLAY button will start. Set by the lobby's world chip; the server validates the id
-- again and refuses anything it does not recognise (Bootstrap.server, StartRunRequest).
SessionController.selectedWorld = WorldConfig.DEFAULT

local ready = false
local nextStartRequestId = 0
local pendingStartRequestId = nil
local queuedStartRequest = nil

local remotes = {}

local function flushStartRequest()
	if not queuedStartRequest or not ready then
		return
	end
	local request = queuedStartRequest
	queuedStartRequest = nil
	remotes.startRun:FireServer(request)
end

local function onZoneInit(payload)
	if type(payload) ~= "table" then
		Logger.warn("Session", "Ignored malformed ZoneInit payload")
		return
	end

	local origin = payload.origin
	if typeof(origin) ~= "Vector3" then
		Logger.warn("Session", "ZoneInit without a valid origin")
		return
	end

	pendingStartRequestId = nil
	queuedStartRequest = nil
	SessionController.state.active = true
	SessionController.state.zoneOrigin = origin
	SessionController.state.startTime = tonumber(payload.startTime) or workspace:GetServerTimeNow()
	SessionController.state.worldId = payload.worldId or WorldConfig.DEFAULT
	SessionController.state.runIndex = tonumber(payload.runIndex) or 0
	SessionController.state.row = 0

	SessionController.signals.runStarted:Fire({
		origin = origin,
		startTime = SessionController.state.startTime,
		worldId = SessionController.state.worldId,
		runIndex = SessionController.state.runIndex,
	})
end

function SessionController.init()
	-- Nothing yields here: the lobby must render even if remotes are slow to replicate.
end

function SessionController.start()
	task.spawn(function()
		remotes.step = Remotes.await(Net.REMOTES.StepRequest)
		remotes.jump = Remotes.await(Net.REMOTES.JumpRequest)
		remotes.startRun = Remotes.await(Net.REMOTES.StartRunRequest)
		remotes.startRunResult = Remotes.await(Net.REMOTES.StartRunResult)
		remotes.endRun = Remotes.await(Net.REMOTES.EndRun)
		remotes.zoneInit = Remotes.await(Net.REMOTES.ZoneInit)
		remotes.chunkLoaded = Remotes.await(Net.REMOTES.ChunkLoaded)
		remotes.runState = Remotes.await(Net.REMOTES.RunState)
		remotes.runEnded = Remotes.await(Net.REMOTES.RunEnded)
		remotes.runEvent = Remotes.await(Net.REMOTES.RunEvent)

		remotes.zoneInit.OnClientEvent:Connect(onZoneInit)
		remotes.startRunResult.OnClientEvent:Connect(function(payload)
			if type(payload) ~= "table" or type(payload.requestId) ~= "number" or type(payload.success) ~= "boolean" then
				Logger.warn("Session", "Ignored malformed StartRunResult payload")
				return
			end
			if not payload.success and pendingStartRequestId == payload.requestId then
				pendingStartRequestId = nil
				if queuedStartRequest and queuedStartRequest.requestId == payload.requestId then
					queuedStartRequest = nil
				end
			end
			SessionController.signals.startResult:Fire(payload)
		end)

		remotes.chunkLoaded.OnClientEvent:Connect(function(chunk)
			if type(chunk) ~= "table" then
				return
			end

			-- A chunk newer than this client understands would be silently mis-rendered: the road
			-- would look clear while the server judged it from data the client ignored. Refuse it
			-- loudly instead. Older formats stay readable — see ChunkFormat for the history.
			if not ChunkFormat.isSupported(chunk.v) then
				Logger.warn(
					"Session",
					("Ignored chunk v%s (client supports v%d..v%d)"):format(
						tostring(chunk.v),
						ChunkFormat.MIN_SUPPORTED,
						ChunkFormat.VERSION
					)
				)
				return
			end

			SessionController.signals.chunkAdded:Fire(chunk)
		end)

		remotes.runState.OnClientEvent:Connect(function(payload)
			if type(payload) ~= "table" then
				return
			end
			SessionController.state.row = payload.row or SessionController.state.row
			SessionController.state.combo = tonumber(payload.combo) or 1
			SessionController.state.comboTime = tonumber(payload.comboTime) or 0
			SessionController.signals.stateUpdated:Fire(payload)
		end)

		remotes.runEnded.OnClientEvent:Connect(function(payload)
			if type(payload) ~= "table" then
				return
			end
			SessionController.state.active = false
			SessionController.signals.runEnded:Fire(payload)
		end)

		remotes.runEvent.OnClientEvent:Connect(function(payload)
			if type(payload) ~= "table" then
				return
			end
			if payload.kind == "near_miss" then
				SessionController.signals.nearMiss:Fire(payload)
			else
				SessionController.signals.pickup:Fire(payload)
			end
		end)

		ready = true
		flushStartRequest()
	end)
end

function SessionController.requestStart(worldId: string?)
	if SessionController.state.active or pendingStartRequestId ~= nil then
		return nil, "already_running"
	end

	if worldId ~= nil then
		if type(worldId) ~= "string" or not WorldConfig.exists(worldId) then
			return nil, "invalid_world"
		end
		SessionController.selectedWorld = worldId
	end

	nextStartRequestId += 1
	local request = {
		worldId = SessionController.selectedWorld,
		requestId = nextStartRequestId,
	}
	pendingStartRequestId = request.requestId
	queuedStartRequest = request
	flushStartRequest()
	return request.requestId
end

function SessionController.cancelStartRequest(requestId: number)
	if pendingStartRequestId ~= requestId then
		return false
	end
	pendingStartRequestId = nil
	if queuedStartRequest and queuedStartRequest.requestId == requestId then
		queuedStartRequest = nil
	end
	return true
end

function SessionController.sendStep(dir: string)
	if not ready or not SessionController.state.active then
		return
	end
	remotes.step:FireServer(dir)
end

function SessionController.sendJump()
	if not ready or not SessionController.state.active then
		return
	end
	if remotes.jump then
		remotes.jump:FireServer()
	end
end

function SessionController.returnToLobby()
	pendingStartRequestId = nil
	queuedStartRequest = nil
	SessionController.state.active = false
	if ready then
		remotes.endRun:FireServer()
	end
	SessionController.signals.returnedToLobby:Fire()
end

-- Elapsed simulated seconds for this run, shared with the traffic renderer.
function SessionController.elapsed(): number
	return workspace:GetServerTimeNow() - SessionController.state.startTime
end

function SessionController.isTouch(): boolean
	return UserInputService.TouchEnabled
end

return SessionController
