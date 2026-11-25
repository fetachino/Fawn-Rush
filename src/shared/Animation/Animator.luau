--!nonstrict
-- Animation state machine.
--
-- Pure logic: no instances, no clock, no randomness. It decides which state should be playing,
-- enforces priorities and minimum durations, and cross-fades between the previous and current pose.
-- The AnimationController feeds it input and applies the result to a rig.
--
-- Priority order (lowest to highest): idle < alert < walk < run < turn < land < fall < jump
-- < fright < stumble < happy < victory < death.
--
-- The rule that matters most: a sticky state (fright, stumble, death, victory, happy, land) cannot
-- be interrupted by a lower-priority request until its duration has elapsed, and movement input is
-- never blocked by an animation state — the state machine only decides how the animal looks.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local AnimationLib = require(Shared.Animation.AnimationLib)

local Animator = {}
Animator.__index = Animator

Animator.PRIORITY = {
	idle = 10,
	alert = 15,
	walk = 20,
	run = 30,
	turn = 35,
	land = 40,
	fall = 45,
	jump = 50,
	fright = 60,
	stumble = 70,
	happy = 80,
	victory = 90,
	death = 100,
}

-- States that hold the machine until their duration expires.
Animator.STICKY = {
	land = true,
	fright = true,
	stumble = true,
	happy = true,
	victory = true,
	death = true,
	jump = true,
	fall = true,
}

Animator.DEFAULT_DURATION = {
	land = GameConfig.LAND_TIME,
	fright = GameConfig.FRIGHT_TIME,
	stumble = GameConfig.STUMBLE_TIME,
	happy = GameConfig.HAPPY_TIME,
	victory = GameConfig.VICTORY_TIME,
	death = GameConfig.DEATH_TIME,
	jump = GameConfig.JUMP_TIME,
	fall = GameConfig.JUMP_TIME,
	turn = GameConfig.TURN_TIME,
}

function Animator.new(animal)
	local self = setmetatable({
		animal = animal,
		state = "idle",
		time = 0,
		previousState = "idle",
		previousTime = 0,
		blend = 1,
		lockedUntil = 0,
		currentPose = AnimationLib.newPose(),
		previousPose = AnimationLib.newPose(),
		outputPose = AnimationLib.newPose(),
	}, Animator)
	return self
end

function Animator.priority(state: string): number
	return Animator.PRIORITY[state] or 0
end

-- Requests a state. Returns true if it took effect.
function Animator:request(state: string, duration: number?)
	if self.state == state then
		return false
	end

	if self.time < self.lockedUntil and Animator.priority(state) <= Animator.priority(self.state) then
		return false
	end

	self.previousState = self.state
	self.previousTime = self.time
	self.previousPose = self.currentPose
	self.currentPose = AnimationLib.newPose()
	self.state = state
	self.time = 0
	self.blend = 0

	local hold = duration or Animator.DEFAULT_DURATION[state]
	if Animator.STICKY[state] and hold then
		self.lockedUntil = hold
	else
		self.lockedUntil = 0
	end

	return true
end

-- Advances time. `input` carries the movement facts; it never blocks the machine, it only suggests.
function Animator:update(dt: number, input)
	self.time += dt
	self.previousTime += dt

	if self.blend < 1 then
		self.blend = math.min(1, self.blend + dt / math.max(0.01, GameConfig.ANIM_BLEND))
	end

	if input then
		if input.dead then
			self:request("death")
		elseif input.stumble then
			self:request("stumble")
		elseif input.fright then
			self:request("fright")
		elseif input.airborne then
			if input.rising then
				self:request("jump")
			else
				self:request("fall")
			end
		elseif input.landed then
			self:request("land")
		elseif input.celebrate then
			self:request("victory")
		elseif input.happy then
			self:request("happy")
		elseif input.turning then
			self:request("turn")
		elseif input.running then
			self:request("run")
		elseif input.walking then
			self:request("walk")
		elseif input.threat then
			self:request("alert")
		else
			self:request("idle")
		end
	end
end

-- Produces the blended pose for this frame. Writes into self.outputPose and returns it.
function Animator:sample()
	AnimationLib.sample(self.state, self.time, self.animal, self.currentPose)

	if self.blend >= 1 or self.previousState == self.state then
		local output = self.outputPose
		for name, rotation in pairs(self.currentPose) do
			local target = output[name]
			if not target then
				target = { 0, 0, 0 }
				output[name] = target
			end
			target[1] = rotation[1]
			target[2] = rotation[2]
			target[3] = rotation[3]
		end
		return output
	end

	AnimationLib.sample(self.previousState, self.previousTime, self.animal, self.previousPose)

	local alpha = self.blend
	local output = self.outputPose

	for name, rotation in pairs(self.currentPose) do
		local previous = self.previousPose[name]
		local target = output[name]
		if not target then
			target = { 0, 0, 0 }
			output[name] = target
		end
		local px = previous and previous[1] or 0
		local py = previous and previous[2] or 0
		local pz = previous and previous[3] or 0
		target[1] = px + (rotation[1] - px) * alpha
		target[2] = py + (rotation[2] - py) * alpha
		target[3] = pz + (rotation[3] - pz) * alpha
	end

	for name, previous in pairs(self.previousPose) do
		if not self.currentPose[name] then
			local target = output[name]
			if not target then
				target = { 0, 0, 0 }
				output[name] = target
			end
			local weight = 1 - alpha
			target[1] = previous[1] * weight
			target[2] = previous[2] * weight
			target[3] = previous[3] * weight
		end
	end

	return output
end

return Animator
