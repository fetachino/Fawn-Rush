--!nonstrict
-- Movement: local prediction of the authoritative grid step.
--
-- The client applies a step immediately so the animal responds on the same frame as the input,
-- interpolates with exactly the same linear formula the server uses for collision, and reconciles
-- against the server's position from RunState.
--
-- Phase 3 splits responsibility: this controller owns *where* the animal is and publishes a visual
-- state; AnimationController owns *how it looks* and poses the rig. Nothing here writes part CFrames
-- any more, so animation can never fight movement.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local WorldConfig = require(Shared.Config.WorldConfig)
local GridMath = require(Shared.Util.GridMath)
local AnimalBuilder = require(Shared.Builders.AnimalBuilder)

local SessionController = require(script.Parent.SessionController)
local InputController = require(script.Parent.InputController)

local MovementController = {}

local rig = nil
local zoneOrigin = Vector3.zero
local active = false
local frozen = true

local predicted = {
	fromCol = 0,
	fromRow = 0,
	toCol = 0,
	toRow = 0,
	stepStart = -100,
}

local visualYaw = 0
local targetYaw = 0
local lastStepAt = -100

local airborne = false
local jumpStart = -100
local lastJumpAt = -100

-- Published every frame; read by AnimationController and CameraController.
local visual = {
	rootCFrame = CFrame.new(0, 0, 0),
	col = 0,
	row = 0,
	alpha = 1,
	stepping = false,
	chaining = false,
	turning = false,
	airborne = false,
	jumpArc = 0,
	dead = false,
	active = false,
	yaw = 0,
}

function MovementController.interpolate(atTime: number): (number, number)
	local alpha = math.clamp((atTime - predicted.stepStart) / GameConfig.STEP_TIME, 0, 1)
	local col = predicted.fromCol + (predicted.toCol - predicted.fromCol) * alpha
	local row = predicted.fromRow + (predicted.toRow - predicted.fromRow) * alpha
	return col, row
end

local function jumpArc(atTime: number): number
	if not airborne then
		return 0
	end
	local t = math.clamp((atTime - jumpStart) / GameConfig.JUMP_TIME, 0, 1)
	return math.sin(t * math.pi) * GameConfig.JUMP_APEX
end

local function placeAtLobby()
	local spawn = WorldConfig.get(WorldConfig.DEFAULT).lobbySpawn
	zoneOrigin = Vector3.zero
	predicted.fromCol, predicted.fromRow = 0, 0
	predicted.toCol, predicted.toRow = 0, 0
	predicted.stepStart = -100
	visualYaw = 0
	targetYaw = 0
	active = false
	airborne = false
	visual.dead = false
	visual.rootCFrame = CFrame.new(spawn) * CFrame.Angles(0, visualYaw, 0)
end

local function onRunStarted(payload)
	zoneOrigin = payload.origin
	predicted.fromCol, predicted.fromRow = 0, 0
	predicted.toCol, predicted.toRow = 0, 0
	predicted.stepStart = -100
	visualYaw = 0
	targetYaw = 0
	frozen = false
	active = true
	airborne = false
	visual.dead = false
	lastStepAt = -100
	InputController.clear()

	local position = GridMath.tileToWorld(zoneOrigin, 0, 0)
	visual.rootCFrame = CFrame.new(position) * CFrame.Angles(0, visualYaw, 0)
end

local function onStateUpdated(payload)
	if not active then
		return
	end

	local serverCol = payload.col
	local serverRow = payload.row
	if type(serverCol) ~= "number" or type(serverRow) ~= "number" then
		return
	end

	-- Correct when standing still, or when the drift is large enough that the visual would be lying
	-- about which tile we are on. Mid-step the local prediction is ahead by design.
	local idle = (os.clock() - predicted.stepStart) > GameConfig.STEP_TIME
	local drift = math.abs(predicted.toCol - serverCol) + math.abs(predicted.toRow - serverRow)
	if (idle or drift >= 2) and (predicted.toCol ~= serverCol or predicted.toRow ~= serverRow) then
		predicted.fromCol, predicted.fromRow = serverCol, serverRow
		predicted.toCol, predicted.toRow = serverCol, serverRow
		predicted.stepStart = -100
	end
end

local function tryStep(dir: string)
	local targetCol, targetRow = GridMath.targetTile(predicted.toCol, predicted.toRow, dir)
	if not targetCol or not GridMath.isValidTile(targetCol, targetRow) then
		return false
	end

	local now = os.clock()
	local alpha = math.clamp((now - predicted.stepStart) / GameConfig.STEP_TIME, 0, 1)

	predicted.fromCol = predicted.fromCol + (predicted.toCol - predicted.fromCol) * alpha
	predicted.fromRow = predicted.fromRow + (predicted.toRow - predicted.fromRow) * alpha
	predicted.toCol = targetCol
	predicted.toRow = targetRow
	predicted.stepStart = now
	lastStepAt = now

	targetYaw = GridMath.yawForDirection(dir)
	SessionController.sendStep(dir)

	return true
end

local function tryJump()
	if airborne then
		return
	end
	local now = os.clock()
	if now - lastJumpAt < GameConfig.JUMP_COOLDOWN then
		return
	end

	airborne = true
	jumpStart = now
	lastJumpAt = now
	SessionController.sendJump()

	-- Local prediction of the one-tile carry, mirroring the server's rule.
	local targetCol, targetRow = GridMath.targetTile(predicted.toCol, predicted.toRow, "fwd")
	if targetCol and GridMath.isValidTile(targetCol, targetRow) then
		local alpha = math.clamp((now - predicted.stepStart) / GameConfig.STEP_TIME, 0, 1)
		predicted.fromCol = predicted.fromCol + (predicted.toCol - predicted.fromCol) * alpha
		predicted.fromRow = predicted.fromRow + (predicted.toRow - predicted.fromRow) * alpha
		predicted.toCol = targetCol
		predicted.toRow = targetRow
		predicted.stepStart = now
		lastStepAt = now
	end
end

function MovementController.init()
	rig = AnimalBuilder.buildRig(SessionController.selectedAnimal or "deer")
	rig.model.Parent = Workspace
	placeAtLobby()

	SessionController.signals.runStarted:Connect(onRunStarted)
	SessionController.signals.stateUpdated:Connect(onStateUpdated)
	SessionController.signals.runEnded:Connect(function()
		frozen = true
		visual.dead = true
		airborne = false
	end)
	SessionController.signals.returnedToLobby:Connect(function()
		frozen = true
		visual.dead = false
		placeAtLobby()
	end)
end

function MovementController.start() end

function MovementController.update(dt: number)
	local now = os.clock()

	if active and not frozen then
		local idleFor = now - predicted.stepStart
		if idleFor >= (GameConfig.STEP_COOLDOWN + GameConfig.CLIENT_COOLDOWN_PAD) then
			local dir = InputController.consumeBuffer() or InputController.getHeldDirection()
			if dir then
				tryStep(dir)
			end
		end

		if InputController.consumeJump() then
			tryJump()
		end
	end

	if airborne and (now - jumpStart) >= GameConfig.JUMP_TIME then
		airborne = false
	end

	local col, row = MovementController.interpolate(now)
	local worldPosition = GridMath.tileToWorld(zoneOrigin, col, row)

	local alpha = math.clamp((now - predicted.stepStart) / GameConfig.STEP_TIME, 0, 1)
	visualYaw = GridMath.lerpAngle(visualYaw, targetYaw, 1 - math.exp(-16 * dt))

	visual.rootCFrame = CFrame.new(worldPosition) * CFrame.Angles(0, visualYaw, 0)
	visual.col = col
	visual.row = row
	visual.alpha = alpha
	visual.stepping = alpha < 1
	visual.chaining = (now - lastStepAt) < 0.34
	visual.turning = math.abs((targetYaw - visualYaw + math.pi) % (math.pi * 2) - math.pi) > 0.12
	visual.airborne = airborne
	visual.jumpArc = jumpArc(now)
	visual.active = active and not frozen
	visual.yaw = visualYaw
end

function MovementController.getVisual()
	return visual
end

function MovementController.getRootCFrame(): CFrame
	return visual.rootCFrame
end

function MovementController.getPosition(): Vector3
	return visual.rootCFrame.Position
end

function MovementController.getModel(): Model?
	return rig and rig.model or nil
end

function MovementController.getRig()
	return rig
end

function MovementController.reset()
	placeAtLobby()
end

return MovementController
