--!nonstrict
-- Follow camera. Frame-locked, damped, and pulled in when something is between the camera and the
-- animal so it never ends up inside a tree or under the ground.
-- See docs/04_GAMEPLAY_MECHANICS_SPEC.md §3.

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)

local SessionController = require(script.Parent.SessionController)
local MovementController = require(script.Parent.MovementController)
local Theme = require(script.Parent.Parent.UI.Theme)

local CameraController = {}

local camera = nil
local rayParams = nil
local camPos = nil
local lookPos = nil
local mode = "lobby"

local shakeIntensity = 0
local shakeRemaining = 0
local shakeClock = 0

-- Screen shake is an offset, never a rotation, and it is capped so the road stays readable.
function CameraController.addShake(intensity: number, duration: number)
	if Theme.reducedMotion then
		shakeIntensity = 0
		shakeRemaining = 0
		return
	end
	shakeIntensity = math.max(shakeIntensity, math.min(0.5, intensity))
	shakeRemaining = math.max(shakeRemaining, duration)
end

local function activePreset()
	if mode == "dead" then
		return GameConfig.CAMERA_DEATH
	elseif SessionController.isTouch() then
		return GameConfig.CAMERA_TOUCH
	end
	return GameConfig.CAMERA_DESKTOP
end

local function computeDesired(): (Vector3, Vector3, number, number)
	local preset = activePreset()
	local target = MovementController.getRootCFrame().Position
	local lookAt = target + preset.look
	local desired = target + preset.offset

	local direction = desired - lookAt
	if direction.Magnitude > 0.1 then
		local result = Workspace:Raycast(lookAt, direction, rayParams)
		if result then
			local allowed = (result.Position - lookAt).Magnitude - 2.5
			if allowed < direction.Magnitude then
				local clamped = math.max(6, allowed)
				desired = lookAt + direction.Unit * clamped
			end
		end
	end

	return desired, lookAt, preset.fov, preset.damp
end

function CameraController.init()
	camera = Workspace.CurrentCamera
	while not camera do
		task.wait(0.05)
		camera = Workspace.CurrentCamera
	end
	camera.CameraType = Enum.CameraType.Scriptable

	rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {}
end

function CameraController.start()
	local excluded = {}

	local animal = MovementController.getModel()
	if animal then
		excluded[#excluded + 1] = animal
	end

	for _, name in ipairs({ "Traffic", "RunZone", "FawnRushClient" }) do
		local folder = Workspace:FindFirstChild(name)
		if folder then
			excluded[#excluded + 1] = folder
		end
	end

	rayParams.FilterDescendantsInstances = excluded

	SessionController.signals.runStarted:Connect(function()
		mode = "run"
		CameraController.snap()
	end)

	SessionController.signals.runEnded:Connect(function()
		mode = "dead"
	end)

	SessionController.signals.returnedToLobby:Connect(function()
		mode = "lobby"
		CameraController.snap()
	end)

	CameraController.snap()
end

function CameraController.snap()
	local desired, lookAt = computeDesired()
	camPos = desired
	lookPos = lookAt
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(camPos, lookPos)
end

function CameraController.update(dt: number)
	if not camera then
		return
	end

	camera.CameraType = Enum.CameraType.Scriptable

	local desired, lookAt, fov, damp = computeDesired()
	camPos = camPos or desired
	lookPos = lookPos or lookAt

	local positionAlpha = 1 - math.exp(-damp * dt)
	local lookAlpha = 1 - math.exp(-(damp * 1.25) * dt)

	camPos = camPos:Lerp(desired, positionAlpha)
	lookPos = lookPos:Lerp(lookAt, lookAlpha)

	-- Shake decays over its duration and is applied only to the final camera transform.
	shakeClock += dt
	if shakeRemaining > 0 then
		shakeRemaining = math.max(0, shakeRemaining - dt)
	else
		shakeIntensity = 0
	end

	local shakeOffset = Vector3.zero
	if Theme.reducedMotion then
		shakeIntensity = 0
		shakeRemaining = 0
	elseif shakeIntensity > 0 then
		local falloff = shakeRemaining / 0.35
		shakeOffset = Vector3.new(
			math.sin(shakeClock * 92) * shakeIntensity * falloff,
			math.cos(shakeClock * 71) * shakeIntensity * 0.6 * falloff,
			0
		)
	end

	camera.CFrame = CFrame.lookAt(camPos + shakeOffset, lookPos)
	camera.FieldOfView = fov
end

return CameraController
