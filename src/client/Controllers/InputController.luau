--!nonstrict
-- Input: keyboard, gamepad, and touch all become one thing — a direction to step.
-- Held input produces a continuous run; a discrete tap or swipe goes into a one-slot buffer so a
-- press that lands during the step cooldown is not silently dropped
-- (docs/04_GAMEPLAY_MECHANICS_SPEC.md §2.3).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.GameConfig)

local InputController = {}

local KEY_DIRECTIONS = {
	[Enum.KeyCode.W] = "fwd",
	[Enum.KeyCode.Up] = "fwd",
	[Enum.KeyCode.DPadUp] = "fwd",
	[Enum.KeyCode.S] = "back",
	[Enum.KeyCode.Down] = "back",
	[Enum.KeyCode.DPadDown] = "back",
	[Enum.KeyCode.A] = "left",
	[Enum.KeyCode.Left] = "left",
	[Enum.KeyCode.DPadLeft] = "left",
	[Enum.KeyCode.D] = "right",
	[Enum.KeyCode.Right] = "right",
	[Enum.KeyCode.DPadRight] = "right",
}

local heldCount = { fwd = 0, back = 0, left = 0, right = 0 }
local heldOrder = {} -- most recently pressed last
local padHeld = { fwd = false, back = false, left = false, right = false }
local buffer = nil -- { dir: string, at: number }
local stickDir = nil
local jumpQueued = false

local JUMP_KEYS = {
	[Enum.KeyCode.Space] = true,
	[Enum.KeyCode.ButtonA] = true,
	[Enum.KeyCode.ButtonR2] = true,
}

-- Swipe tracking.
local touchStart = nil -- { x: number, y: number, at: number }
local SWIPE_MIN_PIXELS = 28
local SWIPE_MAX_SECONDS = 0.5

local function pushBuffer(dir: string)
	buffer = { dir = dir, at = os.clock() }
end

local function recomputeHeld()
	local latest = nil
	for index = #heldOrder, 1, -1 do
		local dir = heldOrder[index]
		if heldCount[dir] > 0 then
			latest = dir
			break
		end
	end

	if not latest then
		for _, dir in ipairs({ "fwd", "back", "left", "right" }) do
			if padHeld[dir] then
				latest = dir
				break
			end
		end
	end

	if not latest then
		latest = stickDir
	end

	InputController.held = latest
end

local function addHeld(dir: string)
	heldCount[dir] = (heldCount[dir] or 0) + 1
	local existing = table.find(heldOrder, dir)
	if existing then
		table.remove(heldOrder, existing)
	end
	heldOrder[#heldOrder + 1] = dir
	recomputeHeld()
end

local function removeHeld(dir: string)
	heldCount[dir] = math.max(0, (heldCount[dir] or 0) - 1)
	recomputeHeld()
end

local function onInputBegan(input, gameProcessed)
	if gameProcessed then
		return
	end

	local dir = KEY_DIRECTIONS[input.KeyCode]
	if dir then
		addHeld(dir)
		pushBuffer(dir)
		return
	end

	if JUMP_KEYS[input.KeyCode] then
		jumpQueued = true
		return
	end

	if input.UserInputType == Enum.UserInputType.Touch then
		touchStart = {
			x = input.Position.X,
			y = input.Position.Y,
			at = os.clock(),
		}
	end
end

local function onInputEnded(input, gameProcessed)
	local dir = KEY_DIRECTIONS[input.KeyCode]
	if dir then
		removeHeld(dir)
		return
	end

	if gameProcessed or input.UserInputType ~= Enum.UserInputType.Touch or not touchStart then
		return
	end

	local dx = input.Position.X - touchStart.x
	local dy = input.Position.Y - touchStart.y
	local elapsed = os.clock() - touchStart.at
	touchStart = nil

	if elapsed > SWIPE_MAX_SECONDS then
		return
	end

	local absX, absY = math.abs(dx), math.abs(dy)
	if math.max(absX, absY) < SWIPE_MIN_PIXELS then
		return
	end

	if absX > absY then
		pushBuffer(dx > 0 and "right" or "left")
	else
		pushBuffer(dy > 0 and "back" or "fwd")
	end
end

local function pollThumbstick()
	if not UserInputService.GamepadEnabled then
		return
	end

	local state = UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)
	if not state then
		return
	end

	local vector = Vector2.zero
	for _, input in ipairs(state) do
		if input.KeyCode == Enum.KeyCode.Thumbstick1 then
			vector = input.Position
		end
	end

	local dir = nil
	if vector.Magnitude > 0.55 then
		if math.abs(vector.X) > math.abs(vector.Y) then
			dir = vector.X > 0 and "right" or "left"
		else
			dir = vector.Y > 0 and "fwd" or "back"
		end
	end

	if dir ~= stickDir then
		stickDir = dir
		if dir then
			pushBuffer(dir)
		end
		recomputeHeld()
	end
end

function InputController.init()
	InputController.held = nil
end

function InputController.start()
	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputEnded:Connect(onInputEnded)
	RunService.RenderStepped:Connect(pollThumbstick)
end

-- On-screen D-pad. Pressing holds the direction; releasing clears it.
function InputController.setPad(dir: string, pressed: boolean)
	if padHeld[dir] == pressed then
		return
	end
	padHeld[dir] = pressed
	if pressed then
		pushBuffer(dir)
	end
	recomputeHeld()
end

function InputController.getHeldDirection(): string?
	return InputController.held
end

function InputController.consumeBuffer(): string?
	local entry = buffer
	buffer = nil
	if entry and (os.clock() - entry.at) <= GameConfig.INPUT_BUFFER then
		return entry.dir
	end
	return nil
end

-- One-shot jump. Cleared on read so a held key cannot produce repeated leaps.
function InputController.consumeJump(): boolean
	if not jumpQueued then
		return false
	end
	jumpQueued = false
	return true
end

-- Touch jump button.
function InputController.queueJump()
	jumpQueued = true
end

function InputController.clear()
	heldCount = { fwd = 0, back = 0, left = 0, right = 0 }
	heldOrder = {}
	padHeld = { fwd = false, back = false, left = false, right = false }
	buffer = nil
	stickDir = nil
	jumpQueued = false
	InputController.held = nil
end

return InputController
