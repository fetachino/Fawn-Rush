--!nonstrict
-- Client entry point. Boots controllers in a deterministic order, then runs one shared frame loop.

local RunService = game:GetService("RunService")

local Controllers = script.Parent.Controllers

local ControllerRegistry = require(Controllers.ControllerRegistry)
local SessionController = require(Controllers.SessionController)
local InputController = require(Controllers.InputController)
local WorldRenderer = require(Controllers.WorldRenderer)
local TrafficRenderer = require(Controllers.TrafficRenderer)
local PresenceController = require(Controllers.PresenceController)
local MovementController = require(Controllers.MovementController)
local AnimationController = require(Controllers.AnimationController)
local EnvironmentController = require(Controllers.EnvironmentController)
local CameraController = require(Controllers.CameraController)
local EffectsController = require(Controllers.EffectsController)
local WorldEffectsController = require(Controllers.WorldEffectsController)
local UIController = require(Controllers.UIController)

local registry = ControllerRegistry.new()

registry:register("Session", SessionController, 10)
registry:register("Input", InputController, 20)
registry:register("World", WorldRenderer, 30)
registry:register("Traffic", TrafficRenderer, 40)
-- Hides the server's lobby copy of the local player before the client's own rig exists.
registry:register("Presence", PresenceController, 45)
registry:register("Movement", MovementController, 50)
registry:register("Animation", AnimationController, 55)
-- Local lighting: applied before the camera frames the new world.
registry:register("Environment", EnvironmentController, 58)
registry:register("Camera", CameraController, 60)
registry:register("Effects", EffectsController, 65)
-- Ambient weather: runs until the first frame is drawn, so it is last of the visual controllers.
registry:register("WorldEffects", WorldEffectsController, 68)
registry:register("UI", UIController, 70)

registry:initAll()
registry:startAll()

RunService.RenderStepped:Connect(function(dt)
	registry:updateAll(dt)
end)

print("[FawnRush] Client ready.")
