--!nonstrict
-- EffectsController: the player-facing feedback for rewards and danger.
--
-- Deliberately small and allocating nothing per frame. Everything is either a tween on a single
-- full-screen frame or a short-lived particle emitter. Screen shake is an offset, never a rotation,
-- and its intensity is capped so a near miss cannot make the road unreadable.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)

local SessionController = require(script.Parent.SessionController)
local CameraController = require(script.Parent.CameraController)
local Theme = require(script.Parent.Parent.UI.Theme)

local EffectsController = {}

local gui = nil
local vignette = nil
local flashFrame = nil

function EffectsController.init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	gui = Instance.new("ScreenGui")
	gui.Name = "FawnRushEffects"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5
	gui.Parent = playerGui

	-- Danger vignette: a soft border flash, not a full-screen strobe.
	vignette = Instance.new("Frame")
	vignette.Name = "Vignette"
	vignette.Size = UDim2.fromScale(1, 1)
	vignette.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	vignette.BackgroundTransparency = 1
	vignette.BorderSizePixel = 0
	vignette.Parent = gui

	flashFrame = Instance.new("Frame")
	flashFrame.Name = "Flash"
	flashFrame.Size = UDim2.fromScale(1, 1)
	flashFrame.BackgroundColor3 = Color3.fromRGB(255, 246, 228)
	flashFrame.BackgroundTransparency = 1
	flashFrame.BorderSizePixel = 0
	flashFrame.Parent = gui
end

local function flash(color: Color3, alpha: number, duration: number)
	if not flashFrame or Theme.reducedMotion then
		return
	end
	flashFrame.BackgroundColor3 = color
	flashFrame.BackgroundTransparency = 1 - alpha
	TweenService:Create(flashFrame, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	}):Play()
end

local function sparkleAt(position: Vector3, color: Color3)
	if Theme.reducedMotion then
		return
	end
	local part = Instance.new("Part")
	part.Name = "PickupSparkle"
	part.Size = Vector3.new(0.4, 0.4, 0.4)
	part.CFrame = CFrame.new(position)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Parent = Workspace

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.Lifetime = NumberRange.new(0.25, 0.5)
	emitter.Speed = NumberRange.new(4, 9)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 0
	emitter.LightEmission = 0.6
	emitter.Size = NumberSequence.new(0.45, 0)
	emitter.Parent = part

	emitter:Emit(10)

	task.delay(1, function()
		part:Destroy()
	end)
end

function EffectsController.start()
	SessionController.signals.nearMiss:Connect(function(payload)
		local multiplier = tonumber(payload.combo) or 1
		flash(Color3.fromRGB(255, 246, 228), 0.10 + math.min(0.12, multiplier * 0.02), 0.22)
		CameraController.addShake(0.12 + math.min(0.2, multiplier * 0.03), 0.16)
	end)

	SessionController.signals.pickup:Connect(function(payload)
		local col = payload.col
		local row = payload.row
		if type(col) ~= "number" or type(row) ~= "number" then
			return
		end
		local origin = SessionController.state.zoneOrigin
		local position = origin + Vector3.new(col * GameConfig.TILE, 1.6, -row * GameConfig.TILE)
		sparkleAt(position, Color3.fromRGB(242, 179, 61))
	end)

	SessionController.signals.runEnded:Connect(function()
		flash(Color3.fromRGB(229, 83, 61), 0.35, 0.5)
		CameraController.addShake(0.35, 0.35)
	end)

	SessionController.signals.runStarted:Connect(function()
		vignette.BackgroundTransparency = 1
	end)
end

function EffectsController.update() end

return EffectsController
