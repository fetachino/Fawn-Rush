--!nonstrict
-- WorldEffectsController: the world's ambient particle bed.
--
-- One emitter per world, attached to a single anchored part that follows the camera, plus an optional
-- accent emitter (fireflies in Greenwood) on tiers that can afford it. Nothing is simulated per frame
-- beyond moving one part, and everything is rate-capped by `GraphicsTier` so a weak phone gets the
-- same world with a quarter of the particles rather than no atmosphere at all.
--
-- Kinds: leaves, dust, sand, snow, motes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldConfig = require(Shared.Config.WorldConfig)
local GraphicsTier = require(Shared.Util.GraphicsTier)

local SessionController = require(script.Parent.SessionController)

local WorldEffectsController = {}

local RIG_NAME = "FawnWorldEffects"
local FOLLOW_HEIGHT = 26
local FOLLOW_BEHIND = 40

-- Per-kind emitter shape. Everything that can be baked into the config is; only the motion differs.
local KIND_PRESETS = {
	leaves = {
		texture = "",
		lifetime = NumberRange.new(4, 7),
		speed = NumberRange.new(0.6, 1.6),
		acceleration = Vector3.new(0.6, -1.4, 0.2),
		rotation = NumberRange.new(0, 360),
		rotationSpeed = NumberRange.new(-40, 40),
		emissionDirection = Enum.NormalId.Top,
		spread = Vector2.new(70, 70),
		transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.15),
			NumberSequenceKeypoint.new(0.85, 0.25),
			NumberSequenceKeypoint.new(1, 1),
		}),
	},
	dust = {
		lifetime = NumberRange.new(3, 5),
		speed = NumberRange.new(0.2, 0.8),
		acceleration = Vector3.new(0.2, 0.15, 0),
		rotation = NumberRange.new(0, 360),
		rotationSpeed = NumberRange.new(-10, 10),
		emissionDirection = Enum.NormalId.Top,
		spread = Vector2.new(90, 90),
		transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.45),
			NumberSequenceKeypoint.new(1, 1),
		}),
	},
	sand = {
		lifetime = NumberRange.new(1.6, 2.8),
		speed = NumberRange.new(7, 12),
		acceleration = Vector3.new(6, 0, 0),
		rotation = NumberRange.new(0, 360),
		rotationSpeed = NumberRange.new(0, 0),
		emissionDirection = Enum.NormalId.Right,
		spread = Vector2.new(14, 14),
		transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.55),
			NumberSequenceKeypoint.new(1, 1),
		}),
	},
	snow = {
		lifetime = NumberRange.new(5, 8),
		speed = NumberRange.new(2.5, 4.5),
		acceleration = Vector3.new(1.2, -2.4, 0.4),
		rotation = NumberRange.new(0, 360),
		rotationSpeed = NumberRange.new(-25, 25),
		emissionDirection = Enum.NormalId.Top,
		spread = Vector2.new(60, 60),
		transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(1, 0.75),
		}),
	},
	motes = {
		lifetime = NumberRange.new(3, 5),
		speed = NumberRange.new(0.8, 2.0),
		acceleration = Vector3.new(0, 1.6, 0),
		rotation = NumberRange.new(0, 360),
		rotationSpeed = NumberRange.new(-60, 60),
		emissionDirection = Enum.NormalId.Bottom,
		spread = Vector2.new(40, 40),
		transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		}),
	},
}

local rig = nil
local anchor = nil
local ambient = nil
local accent = nil

local function ensureRig()
	if rig and anchor then
		return
	end

	local existing = Workspace:FindFirstChild(RIG_NAME)
	if existing then
		existing:Destroy()
	end

	rig = Instance.new("Folder")
	rig.Name = RIG_NAME
	rig.Parent = Workspace

	anchor = Instance.new("Part")
	anchor.Name = "Anchor"
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	anchor.Parent = rig
end

local function configure(emitter, spec, rateScale)
	local preset = KIND_PRESETS[spec.kind]
	if not preset then
		return false
	end

	-- Only overwrite the texture when a preset actually names one: assigning nil to a string
	-- property raises, and every preset currently wants Roblox's default particle.
	if type(preset.texture) == "string" and preset.texture ~= "" then
		emitter.Texture = preset.texture
	end

	emitter.Color = ColorSequence.new(spec.color or Color3.fromRGB(255, 255, 255))
	emitter.Lifetime = preset.lifetime
	emitter.Speed = NumberRange.new(
		(preset.speed.Min) * (spec.speed and math.min(1, spec.speed / 5) or 1),
		(preset.speed.Max) * (spec.speed and math.min(1, spec.speed / 5) or 1)
	)
	emitter.Acceleration = preset.acceleration
	emitter.Rotation = preset.rotation
	emitter.RotSpeed = preset.rotationSpeed
	emitter.EmissionDirection = preset.emissionDirection
	emitter.SpreadAngle = preset.spread
	emitter.Transparency = preset.transparency
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, spec.size or 0.5),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.LightEmission = spec.kind == "motes" and 0.8 or 0.15
	emitter.Rate = math.max(0, (spec.rate or 10) * rateScale)
	emitter.Enabled = emitter.Rate > 0

	return true
end

local function makeEmitter(name: string): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = name
	emitter.Parent = anchor
	return emitter
end

function WorldEffectsController.init()
	ensureRig()
	ambient = makeEmitter("Ambient")
	accent = makeEmitter("Accent")
	ambient.Enabled = false
	accent.Enabled = false
end

function WorldEffectsController.start()
	SessionController.signals.runStarted:Connect(function(payload)
		if not anchor or not ambient or not accent then
			return
		end

		local world = WorldConfig.get(payload.worldId)
		local effects = world.effects or {}
		-- Re-read the tier per run rather than trusting a value memoised at join: a player can change
		-- their quality setting between runs, and the next run should honour it.
		local tier = GraphicsTier.refresh()
		local rateScale = GraphicsTier.rateScale(tier)

		if effects.ambient and configure(ambient, effects.ambient, rateScale) then
			ambient.Enabled = ambient.Rate > 0
		else
			ambient.Enabled = false
		end

		if effects.accent and GraphicsTier.allowAccents(tier) and configure(accent, effects.accent, rateScale) then
			accent.Enabled = accent.Rate > 0
		else
			accent.Enabled = false
		end
	end)

	SessionController.signals.returnedToLobby:Connect(function()
		if ambient then
			ambient.Enabled = false
		end
		if accent then
			accent.Enabled = false
		end
	end)
end

function WorldEffectsController.update()
	if not anchor then
		return
	end

	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	-- The emitter volume follows the camera so the player is always inside the weather, without a
	-- single particle being simulated for the whole map.
	anchor.CFrame = camera.CFrame * CFrame.new(0, FOLLOW_HEIGHT, -FOLLOW_BEHIND)
end

return WorldEffectsController
