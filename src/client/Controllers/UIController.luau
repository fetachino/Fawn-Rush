--!nonstrict
-- UI hub: screen construction, navigation, transitions and session-local accessibility settings.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local WorldConfig = require(Shared.Config.WorldConfig)
local WorldUnlock = require(Shared.Simulation.WorldUnlock)

local Theme = require(script.Parent.Parent.UI.Theme)
local LobbyScreen = require(script.Parent.Parent.UI.Screens.Lobby)
local RunSelect = require(script.Parent.Parent.UI.Screens.RunSelect)
local Collection = require(script.Parent.Parent.UI.Screens.Collection)
local Customize = require(script.Parent.Parent.UI.Screens.Customize)
local Shop = require(script.Parent.Parent.UI.Screens.Shop)
local Settings = require(script.Parent.Parent.UI.Screens.Settings)
local HUD = require(script.Parent.Parent.UI.Screens.HUD)
local ResultsScreen = require(script.Parent.Parent.UI.Screens.Results)

local SessionController = require(script.Parent.SessionController)
local InputController = require(script.Parent.InputController)

local UIController = {}

local playerGui = nil
local screenGui = nil
local safeFrame = nil
local uiScale = nil
local lobby = nil
local runSelect = nil
local collection = nil
local customize = nil
local shop = nil
local settings = nil
local hud = nil
local results = nil
local busyToken = 0
local activeScreen = nil
local settingsState = { reducedMotion = false, textScale = 1 }
local screens = {}
local screenScales = {}
local transitionTokens = {}
local transitionTweens = {}
local sessionConnections = {}
local cameraViewportConnection = nil
local currentCameraConnection = nil
local pendingStartRequest = nil
local pendingStartAccepted = false
local gamepadConnectedConnection = nil

local function cancelTransition(frame: GuiObject)
	local running = transitionTweens[frame]
	transitionTweens[frame] = nil
	if running then
		for _, tween in ipairs(running) do
			tween:Cancel()
		end
	end
end

local function cleanup()
	if pendingStartRequest then
		SessionController.cancelStartRequest(pendingStartRequest)
		pendingStartRequest = nil
	end
	pendingStartAccepted = false

	for _, connection in ipairs(sessionConnections) do
		connection:Disconnect()
	end
	table.clear(sessionConnections)

	local frames = {}
	for frame in pairs(transitionTweens) do
		frames[#frames + 1] = frame
	end
	for _, frame in ipairs(frames) do
		cancelTransition(frame)
	end
	table.clear(transitionTokens)

	if cameraViewportConnection then
		cameraViewportConnection:Disconnect()
		cameraViewportConnection = nil
	end
	if currentCameraConnection then
		currentCameraConnection:Disconnect()
		currentCameraConnection = nil
	end
	if gamepadConnectedConnection then
		gamepadConnectedConnection:Disconnect()
		gamepadConnectedConnection = nil
	end

	local selected = GuiService.SelectedObject
	if selected and screenGui and selected:IsDescendantOf(screenGui) then
		GuiService.SelectedObject = nil
	end
	activeScreen = nil
end

local function isVisibleInScreen(instance: Instance, frame: GuiObject): boolean
	local current = instance
	while current and current ~= frame do
		if current:IsA("GuiObject") and not current.Visible then
			return false
		end
		current = current.Parent
	end
	return current == frame
end

local function focusScreen(api)
	if not UserInputService.GamepadEnabled then
		GuiService.SelectedObject = nil
		return
	end

	local frame = api and api.instance
	if not frame then
		GuiService.SelectedObject = nil
		return
	end

	local priorities = {
		LobbyScreen = { "PlayButton" },
		RunSelectScreen = { "StartRun", "PreviousWorld", "NextWorld", "Back" },
		CollectionScreen = { "Back", "Species_deer" },
		CustomizeScreen = { "Back" },
		ShopScreen = { "Back", "AcornsTab" },
		SettingsScreen = { "Back", "ReducedMotion", "TextScaleDown" },
		ResultsScreen = { "RetryButton", "LobbyButton" },
	}

	local function canSelect(instance: Instance?): boolean
		return instance ~= nil
			and instance:IsA("GuiButton")
			and instance.Active
			and instance.Selectable
			and isVisibleInScreen(instance, frame)
	end

	for _, name in ipairs(priorities[frame.Name] or {}) do
		local candidate = frame:FindFirstChild(name, true)
		if canSelect(candidate) then
			GuiService.SelectedObject = candidate
			return
		end
	end
	for _, candidate in ipairs(frame:GetDescendants()) do
		if canSelect(candidate) then
			GuiService.SelectedObject = candidate
			return
		end
	end
	GuiService.SelectedObject = nil
end

local function originOf(frame: GuiObject): UDim2
	return UDim2.new(frame.Position.X.Scale, frame.Position.X.Offset, frame.Position.Y.Scale, frame.Position.Y.Offset)
end

local function animateScreen(api, visible: boolean, payload)
	if not api then return end
	local frame = api.instance
	if not frame then
		if visible then api.show(payload) else api.hide() end
		return
	end
	transitionTokens[frame] = (transitionTokens[frame] or 0) + 1
	local token = transitionTokens[frame]
	cancelTransition(frame)
	local origin = originOf(frame)
	if frame:GetAttribute("HomePositionSet") ~= true then
		frame:SetAttribute("HomePositionXScale", origin.X.Scale)
		frame:SetAttribute("HomePositionXOffset", origin.X.Offset)
		frame:SetAttribute("HomePositionYScale", origin.Y.Scale)
		frame:SetAttribute("HomePositionYOffset", origin.Y.Offset)
		frame:SetAttribute("HomePositionSet", true)
	end
	local home = UDim2.new(
		frame:GetAttribute("HomePositionXScale") or 0,
		frame:GetAttribute("HomePositionXOffset") or 0,
		frame:GetAttribute("HomePositionYScale") or 0,
		frame:GetAttribute("HomePositionYOffset") or 0
	)
	local scale = screenScales[frame]

	if visible then
		api.show(payload)
		frame.Visible = true
		if Theme.reducedMotion then
			frame.Position = home
			if scale then scale.Scale = 1 end
			return
		end
		frame.Position = home + UDim2.fromOffset(0, 14)
		if scale then scale.Scale = 0.98 end
		local tween = TweenService:Create(frame, TweenInfo.new(Theme.duration("base"), Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = home })
		local running = { tween }
		if scale then
			local scaleTween = TweenService:Create(scale, TweenInfo.new(Theme.duration("base"), Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 })
			running[#running + 1] = scaleTween
		scaleTween:Play()
		end
		transitionTweens[frame] = running
		tween.Completed:Connect(function()
			if transitionTokens[frame] == token and transitionTweens[frame] == running then
				transitionTweens[frame] = nil
			end
		end)
		tween:Play()
	else
		if not frame.Visible then
			api.hide()
			frame.Position = home
			if scale then scale.Scale = 1 end
			return
		end
		if Theme.reducedMotion then
			api.hide()
			frame.Position = home
			if scale then scale.Scale = 1 end
			return
		end
		local tween = TweenService:Create(frame, TweenInfo.new(Theme.duration("fast"), Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = home + UDim2.fromOffset(0, 10) })
		local running = { tween }
		if scale then
			local scaleTween = TweenService:Create(scale, TweenInfo.new(Theme.duration("fast"), Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.99 })
			running[#running + 1] = scaleTween
			scaleTween:Play()
		end
		transitionTweens[frame] = running
		tween.Completed:Connect(function(playbackState)
			if transitionTokens[frame] == token and playbackState == Enum.PlaybackState.Completed then
				transitionTweens[frame] = nil
				api.hide()
				frame.Position = home
				if scale then scale.Scale = 1 end
			end
		end)
		tween:Play()
	end
end

local function changeScreen(api, payload)
	for _, screen in ipairs(screens) do
		if screen ~= api then
			animateScreen(screen, false)
		end
	end
	activeScreen = api
	animateScreen(api, true, payload)
	focusScreen(api)
end

local function updateScale()
	local camera = Workspace.CurrentCamera
	if not camera or not uiScale or not safeFrame then return end
	local viewport = camera.ViewportSize
	local scale = Theme.scaleFor(viewport)
	local topLeftInset, bottomRightInset = GuiService:GetGuiInset()
	local insets = {
		left = topLeftInset.X,
		top = topLeftInset.Y,
		right = bottomRightInset.X,
		bottom = bottomRightInset.Y,
	}

	uiScale.Scale = scale
	safeFrame.Position = UDim2.fromOffset(insets.left + 12, insets.top + 12)
	safeFrame.Size = UDim2.fromOffset(
		math.max(0, viewport.X - insets.left - insets.right - 24) / scale,
		math.max(0, viewport.Y - insets.top - insets.bottom - 24) / scale
	)
	if lobby then lobby.layout(viewport, insets) end
	if runSelect then runSelect.layout(viewport, insets) end
	if collection then collection.layout(viewport, insets) end
	if customize then customize.layout(viewport, insets) end
	if shop then shop.layout(viewport, insets) end
	if settings then settings.layout(viewport, insets) end
	if hud then hud.layout(viewport, insets) end
	if results then results.layout(viewport, insets) end
end

local function applyWorldChip()
	if not lobby then return end
	local world = WorldConfig.get(SessionController.selectedWorld)
	local unlocked = WorldUnlock.isUnlocked(world.id, WorldUnlock.EMPTY_PROGRESS)
	local playable = (not GameConfig.WORLD_UNLOCK_ENFORCED) or unlocked
	lobby.setWorld(world, playable, WorldUnlock.describe(world.id))
end

local function goHome()
	lobby.setStatus(nil)
	changeScreen(lobby)
	applyWorldChip()
end

local function startRun(worldId: string?)
	if pendingStartRequest ~= nil then
		return
	end
	if worldId and WorldConfig.exists(worldId) then
		SessionController.selectedWorld = worldId
	end
	if activeScreen == runSelect then
		changeScreen(lobby)
	end
	busyToken += 1
	local token = busyToken
	lobby.setStatus(nil)
	lobby.setBusy(true)
	local requestId, requestError = SessionController.requestStart(worldId or SessionController.selectedWorld)
	if not requestId then
		busyToken += 1
		lobby.setBusy(false)
		local message = requestError == "invalid_world"
			and "That world is unavailable. Choose another world."
			or "A run is already in progress."
		lobby.setStatus(message)
		lobby.setStartState("failure")
		return
	end
	pendingStartRequest = requestId
	pendingStartAccepted = false

	-- A missing server response must never leave the primary action permanently loading.
	task.delay(4, function()
		if token ~= busyToken or pendingStartRequest ~= requestId then
			return
		end
		SessionController.cancelStartRequest(requestId)
		pendingStartRequest = nil
		local accepted = pendingStartAccepted
		pendingStartAccepted = false
		lobby.setBusy(false)
		if lobby.visible() then
			local message = accepted
				and "The server accepted the run, but the course has not loaded. Check your connection."
				or "The server has not confirmed the run. Check your connection and try again."
			lobby.setStatus(message)
			lobby.setStartState("failure")
		end
	end)
end

local function buildRoot()
	playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "FawnRushUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 10
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	safeFrame = Instance.new("Frame")
	safeFrame.Name = "SafeFrame"
	safeFrame.BackgroundTransparency = 1
	safeFrame.Position = UDim2.fromOffset(12, 12)
	safeFrame.Size = UDim2.new(1, -24, 1, -24)
	safeFrame.Parent = screenGui

	uiScale = Instance.new("UIScale")
	uiScale.Parent = safeFrame
	screenGui.Destroying:Connect(cleanup)
end

function UIController.init()
	buildRoot()

	lobby = LobbyScreen.create(safeFrame, {
		onPlay = function() startRun(SessionController.selectedWorld) end,
		onWorlds = function() changeScreen(runSelect, SessionController.selectedWorld) end,
		onCollection = function() changeScreen(collection) end,
		onCustomize = function() changeScreen(customize) end,
		onShop = function() changeScreen(shop) end,
		onSettings = function() settings.setSettings(settingsState); changeScreen(settings) end,
	})

	runSelect = RunSelect.create(safeFrame, {
		onSelect = function(worldId: string)
			SessionController.selectedWorld = worldId
			applyWorldChip()
			runSelect.setWorld(worldId)
		end,
		onPlay = startRun,
		onBack = goHome,
	})
	collection = Collection.create(safeFrame, { onBack = goHome })
	customize = Customize.create(safeFrame, { onBack = goHome })
	shop = Shop.create(safeFrame, { onBack = goHome })
	settings = Settings.create(safeFrame, {
		onBack = goHome,
		onReducedMotion = function(enabled: boolean)
			settingsState.reducedMotion = enabled
			Theme.setReducedMotion(enabled)
		end,
		onTextScale = function(scale: number)
			settingsState.textScale = scale
			Theme.setTextScale(scale)
			Theme.applyTextScale(screenGui)
			updateScale()
		end,
	})
	settings.setSettings(settingsState)

	hud = HUD.create(safeFrame, {
		onPad = function(dir, pressed) InputController.setPad(dir, pressed) end,
		onJump = function() InputController.queueJump() end,
	})
	results = ResultsScreen.create(safeFrame, {
		onRetry = function()
			changeScreen(lobby)
			startRun(SessionController.selectedWorld)
		end,
		onLobby = function()
			SessionController.returnToLobby()
		end,
	})

	screens = { lobby, runSelect, collection, customize, shop, settings, hud, results }
	for _, screen in ipairs(screens) do
		local frame = screen.instance
		if frame then
			local scale = Instance.new("UIScale")
			scale.Scale = 1
			scale.Parent = frame
			screenScales[frame] = scale
			frame.Visible = false
		end
	end
	changeScreen(lobby)
	applyWorldChip()
	updateScale()

	local function watchCamera(camera)
		if cameraViewportConnection then
			cameraViewportConnection:Disconnect()
			cameraViewportConnection = nil
		end
		if camera then
			cameraViewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
		end
	end
	watchCamera(Workspace.CurrentCamera)
	if gamepadConnectedConnection then
		gamepadConnectedConnection:Disconnect()
	end
	gamepadConnectedConnection = UserInputService.GamepadConnected:Connect(function()
		if activeScreen then
			focusScreen(activeScreen)
		end
	end)
	if currentCameraConnection then
		currentCameraConnection:Disconnect()
	end
	currentCameraConnection = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		watchCamera(Workspace.CurrentCamera)
		updateScale()
	end)
end

function UIController.start()
	sessionConnections[#sessionConnections + 1] = SessionController.signals.startResult:Connect(function(payload)
		if pendingStartRequest ~= payload.requestId then
			return
		end
		if payload.success then
			pendingStartAccepted = true
			if lobby.visible() then
				lobby.setStatus("Run accepted. Loading the course…")
			end
			return
		end

		pendingStartRequest = nil
		pendingStartAccepted = false
		busyToken += 1
		lobby.setBusy(false)
		local message
		if payload.reason == "locked" then
			message = "That world is locked. Choose another world."
		elseif payload.reason == "already_running" then
			message = "A run is already in progress."
		elseif payload.reason == "invalid_world" then
			message = "That world is unavailable. Choose another world."
		else
			message = "The run could not start. Please try again."
		end
		lobby.setStatus(message)
		if lobby.visible() then
			lobby.setStartState("failure")
		end
	end)

	sessionConnections[#sessionConnections + 1] = SessionController.signals.runStarted:Connect(function()
		busyToken += 1
		pendingStartRequest = nil
		pendingStartAccepted = false
		changeScreen(hud)
	end)

	sessionConnections[#sessionConnections + 1] = SessionController.signals.stateUpdated:Connect(function(payload)
		hud.update(payload)
	end)

	sessionConnections[#sessionConnections + 1] = SessionController.signals.runEnded:Connect(function(payload)
		changeScreen(results, payload)
	end)

	sessionConnections[#sessionConnections + 1] = SessionController.signals.returnedToLobby:Connect(function()
		busyToken += 1
		pendingStartRequest = nil
		pendingStartAccepted = false
		changeScreen(lobby)
		applyWorldChip()
	end)
end

function UIController.update() end

function UIController.getScreenGui(): ScreenGui?
	return screenGui
end

return UIController
