--!nonstrict
-- Server entry point. Boot order is explicit: remotes, lighting, lobby, services, then remote
-- binding. Nothing here yields on player input and nothing here trusts a client payload.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RobloxRunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local WorldConfig = require(Shared.Config.WorldConfig)
local Net = require(Shared.Constants.Net)
local Remotes = require(Shared.Net.Remotes)
local Logger = require(Shared.Util.Logger)

local ServiceRegistry = require(script.Parent.Services.ServiceRegistry)
local RemoteGate = require(script.Parent.Services.RemoteGate)
local EnvironmentService = require(script.Parent.Services.EnvironmentService)
local PresenceService = require(script.Parent.Services.PresenceService)
local RunService = require(script.Parent.Services.RunService)
local ZoneService = require(script.Parent.Services.ZoneService)
local PlayerDataService = require(script.Parent.Services.PlayerDataService)
local CurrencyService = require(script.Parent.Services.CurrencyService)
local ProgressionService = require(script.Parent.Services.ProgressionService)
local MissionService = require(script.Parent.Services.MissionService)
local LoginRewardService = require(script.Parent.Services.LoginRewardService)
local AnimalService = require(script.Parent.Services.AnimalService)
local AchievementService = require(script.Parent.Services.AchievementService)
local ProfileRequestRules = require(Shared.Progression.ProfileRequestRules)
local LobbyBuilder = require(script.Parent.Builders.LobbyBuilder)

Remotes.initServer()
Logger.info("Boot", "Remotes initialised")

local registry = ServiceRegistry.new()
registry:register("PlayerData", PlayerDataService, 5)
registry:register("Currency", CurrencyService, 10)
registry:register("Progression", ProgressionService, 15)
registry:register("Missions", MissionService, 25)
registry:register("LoginRewards", LoginRewardService, 35)
registry:register("Animals", AnimalService, 45)
registry:register("Achievements", AchievementService, 55)
registry:register("Environment", EnvironmentService, 60)
registry:register("Lobby", LobbyBuilder, 65)
registry:register("Presence", PresenceService, 70)
registry:register("Run", RunService, 90)
registry:initAll()
registry:startAll()

-- Validated run-end events are the only gameplay inputs to progression. The run payload remains
-- server-owned and is consumed before RunEnded is sent to that player's client.
RunService.events.runEnded:Connect(ProgressionService.processRun)
RunService.events.runEnded:Connect(MissionService.recordRun)
RunService.events.runEnded:Connect(AnimalService.processRun)
RunService.events.runEnded:Connect(AchievementService.evaluate)
RunService.events.runEnded:Connect(function(player)
	PlayerDataService.pushSync(player)
end)

-- Remote binding ---------------------------------------------------------------------------------

local stepRemote = Remotes.get(Net.REMOTES.StepRequest)
if stepRemote then
	RemoteGate.bind(stepRemote, Net.REMOTES.StepRequest, Net.RATE.StepRequest, 6, function(player, dir)
		if not RemoteGate.isDirection(dir) then
			return
		end
		RunService.acceptStep(player, dir)
	end)
end

local jumpRemote = Remotes.get(Net.REMOTES.JumpRequest)
if jumpRemote then
	RemoteGate.bind(jumpRemote, Net.REMOTES.JumpRequest, Net.RATE.JumpRequest, 3, function(player)
		RunService.acceptJump(player)
	end)
end

local startRequestResults = {}
local startRemote = Remotes.get(Net.REMOTES.StartRunRequest)
if startRemote then
	RemoteGate.bind(startRemote, Net.REMOTES.StartRunRequest, Net.RATE.StartRunRequest, 2, function(player, payload)
		if type(payload) ~= "table" then
			return
		end

		local requestId = payload.requestId
		if
			not RemoteGate.isFiniteNumber(requestId)
			or requestId < 1
			or requestId % 1 ~= 0
		then
			return
		end

		local resultRemote = Remotes.get(Net.REMOTES.StartRunResult)
		local previous = startRequestResults[player]
		if previous then
			if requestId == previous.requestId then
				if resultRemote then
					resultRemote:FireClient(player, previous.result)
				end
				return
			elseif requestId < previous.requestId then
				return
			end
		end

		local started = false
		local reason = "invalid_world"
		local worldId = payload.worldId
		if type(worldId) == "string" and WorldConfig.exists(worldId) then
			started, reason = RunService.startRun(player, worldId)
		end

		local result = {
			requestId = requestId,
			success = started == true,
			reason = reason,
		}
		startRequestResults[player] = { requestId = requestId, result = result }
		if resultRemote then
			resultRemote:FireClient(player, result)
		end
	end)
end

local endRemote = Remotes.get(Net.REMOTES.EndRun)
if endRemote then
	RemoteGate.bind(endRemote, Net.REMOTES.EndRun, Net.RATE.EndRun, 2, function(player)
		RunService.finish(player, "bank")
	end)
end

local function sendProgressionResult(player, payload)
	local remote = Remotes.get(Net.REMOTES.ProgressionResult)
	if remote then remote:FireClient(player, payload) end
end

local profileRequest = Remotes.get(Net.REMOTES.ProfileRequest)
if profileRequest then
	RemoteGate.bind(profileRequest, Net.REMOTES.ProfileRequest, Net.RATE.ProfileRequest, 6, function(player, payload)
		local valid, request = ProfileRequestRules.validate(payload)
		if not valid then return end
		if request.action == "sync" then
			PlayerDataService.pushSync(player)
			return
		end
		if not PlayerDataService.isLoaded(player) then
			sendProgressionResult(player, {
				requestId = request.requestId, action = request.action,
				success = false, reason = "profile_unavailable",
			})
			PlayerDataService.pushSync(player)
			return
		end

		local success, reason
		if request.action == "claim_daily" then
			success, reason = LoginRewardService.claim(player)
		elseif request.action == "claim_missions_ready" then
			success, reason = MissionService.claimReady(player)
			if success then AnimalService.evaluatePersistent(player) end
		elseif request.action == "claim_achievements_ready" then
			success, reason = AchievementService.claimReady(player)
		end
		if request.action == "unlock_animal" then
			success, reason = AnimalService.unlockPurchase(player, request.id)
		end
		sendProgressionResult(player, {
			requestId = request.requestId, action = request.action,
			success = success == true, reason = reason,
		})
		AchievementService.evaluate(player)
		PlayerDataService.pushSync(player)
	end)
end

-- Player lifecycle -------------------------------------------------------------------------------

local function onPlayerAdded(player)
	ZoneService.allocate(player)
end

if Players.PlayerAdded then
	Players.PlayerAdded:Connect(onPlayerAdded)
end

for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
	task.defer(function() PlayerDataService.load(player) end)
end

Players.PlayerRemoving:Connect(function(player)
	RunService.playerRemoving(player)
	PlayerDataService.playerRemoving(player)
	ZoneService.release(player)
	RemoteGate.clear(player)
	startRequestResults[player] = nil
end)

game:BindToClose(function()
	RunService.stop()
	PlayerDataService.shutdown(25)
end)

-- Test suite (Studio only) -----------------------------------------------------------------------

if GameConfig.RUN_TESTS_ON_BOOT and RobloxRunService:IsStudio() then
	task.spawn(function()
		local phase2 = require(script.Parent.Tests.Phase2Tests)
		phase2.run()

		local phase3 = require(script.Parent.Tests.Phase3Tests)
		phase3.run()

		local phase4 = require(script.Parent.Tests.Phase4Tests)
		phase4.run()

		local phase5 = require(script.Parent.Tests.Phase5Tests)
		phase5.run()

		local phase6 = require(script.Parent.Tests.Phase6Tests)
		phase6.run()

		local problems = require(Shared.Config.AnimalConfig).validate()
		if #problems > 0 then
			for _, problem in ipairs(problems) do
				warn("[Config] " .. problem)
			end
		else
			print("[Config] AnimalConfig validated: 13 animals, no problems")
		end

		local worldProblems = require(Shared.Config.WorldConfig).validate()
		if #worldProblems > 0 then
			for _, problem in ipairs(worldProblems) do
				warn("[Config] " .. problem)
			end
		else
			print("[Config] WorldConfig validated: 5 worlds, no problems")
		end
	end)
end

Logger.info("Boot", "Fawn Rush server ready")
