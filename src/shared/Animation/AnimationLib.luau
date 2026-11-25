--!nonstrict
-- Procedural pose library.
--
-- Pure functions: given a state name, a state-local time, and a species profile, fill a table of
-- joint rotations. No instances, no clock, no randomness — so the whole animation system is
-- unit-testable and identical on any machine.
--
-- Poses are authored as Euler XYZ angles in radians, applied about each joint's pivot by the
-- AnimationController. Angles are additive on top of the rig's rest pose, never a replacement for
-- it, so a species with unusual proportions still animates correctly.

local AnimationLib = {}

AnimationLib.STATES = {
	"idle",
	"alert",
	"walk",
	"run",
	"jump",
	"fall",
	"land",
	"turn",
	"fright",
	"stumble",
	"happy",
	"death",
	"victory",
}

-- Pose tables are reused between frames to keep the render loop allocation-free.
function AnimationLib.newPose()
	return {}
end

local function zero(pose, name: string)
	local rotation = pose[name]
	if not rotation then
		rotation = { 0, 0, 0 }
		pose[name] = rotation
	end
	return rotation
end

local function set(pose, name: string, x: number?, y: number?, z: number?)
	local rotation = zero(pose, name)
	rotation[1] = x or 0
	rotation[2] = y or 0
	rotation[3] = z or 0
end

local function clear(pose)
	for _, rotation in pairs(pose) do
		rotation[1] = 0
		rotation[2] = 0
		rotation[3] = 0
	end
end

AnimationLib.clear = clear

-- Shared leg cycle. Diagonal pairs move together, which is what makes a quadruped read as running
-- rather than as four independent sticks.
local function applyLegs(pose, phase: number, amplitude: number, hindScale: number)
	local swing = math.sin(phase) * amplitude
	local opposite = math.sin(phase + math.pi) * amplitude

	set(pose, "LegFL", swing, 0, 0)
	set(pose, "LegBR", swing * 1.05, 0, 0)
	set(pose, "LegFR", opposite, 0, 0)
	set(pose, "LegBL", opposite * hindScale, 0, 0)
end

local function applyEars(pose, sway: number, flick: number, depth: number)
	set(pose, "EarL", -math.abs(sway) * 0.4 - depth, 0, -flick * 0.25 - sway * 0.3)
	set(pose, "EarR", -math.abs(sway) * 0.4 - depth, 0, flick * 0.25 + sway * 0.3)
end

local function applyTail(pose, sway: number, lift: number)
	set(pose, "Tail", lift, sway * 0.5, 0)
end

-- Fills `pose` for `state` at `t` seconds into that state.
-- `animal` is the AnimalConfig entry; `gait` is animal.gait.
function AnimationLib.sample(state: string, t: number, animal, pose)
	clear(pose)

	local gait = animal.gait
	local anim = animal.anim
	local cadence = gait.cadence
	local bob = gait.bobAmp

	if state == "idle" then
		local breath = math.sin(t * 2.0)
		local sway = math.sin(t * 1.3) * anim.earAmp
		set(pose, "Torso", 0, 0, 0)
		set(pose, "Belly", breath * 0.03, 0, 0)
		set(pose, "Head", breath * 0.04, math.sin(t * 0.7) * 0.16 * anim.headAmp, 0)
		applyEars(pose, sway * 0.18, 0, 0)
		applyTail(pose, math.sin(t * 1.1) * 0.25 * anim.tailAmp, 0)
	elseif state == "alert" then
		local twitch = math.sin(t * 7.0) * 0.06
		set(pose, "Torso", 0.06, 0, 0)
		set(pose, "Head", -0.12, math.sin(t * 2.4) * 0.1, twitch)
		applyEars(pose, 0, 0.08, -0.05)
		applyTail(pose, math.sin(t * 2.0) * 0.15 * anim.tailAmp, -0.08)
	elseif state == "walk" then
		local phase = t * cadence * 0.55
		applyLegs(pose, phase, 0.34, 1.0)
		set(pose, "Torso", math.sin(phase * 2) * bob * 0.6, 0, 0)
		set(pose, "Head", -math.sin(phase * 2) * bob * 0.8 + 0.04, 0, 0)
		applyEars(pose, math.sin(phase) * 0.2 * anim.earAmp, 0, 0)
		applyTail(pose, math.sin(phase * 0.8) * 0.3 * anim.tailAmp, 0)
	elseif state == "run" then
		local phase = t * cadence
		applyLegs(pose, phase, 0.62, 1.0)
		set(pose, "Torso", math.sin(phase * 2) * bob, gait.lean * 0.5, 0)
		set(pose, "Belly", math.sin(phase * 2 + 0.4) * bob * 0.5, 0, 0)
		set(pose, "Head", -math.sin(phase * 2) * bob * 1.4 - 0.08, 0, 0)
		applyEars(pose, math.sin(phase) * 0.4 * anim.earAmp, 0, -0.05)
		applyTail(pose, math.sin(phase * 1.2) * 0.5 * anim.tailAmp, -0.18)
	elseif state == "jump" then
		local tuck = math.clamp(t / 0.12, 0, 1)
		set(pose, "Torso", -0.18 * tuck, 0, 0)
		set(pose, "LegFL", -0.85 * tuck, 0, 0)
		set(pose, "LegFR", -0.85 * tuck, 0, 0)
		set(pose, "LegBL", -0.7 * tuck, 0, 0)
		set(pose, "LegBR", -0.7 * tuck, 0, 0)
		set(pose, "Head", -0.12 * tuck, 0, 0)
		applyEars(pose, 0, 0, -0.35 * tuck)
		applyTail(pose, 0, -0.3 * tuck)
	elseif state == "fall" then
		set(pose, "Torso", 0.14, 0, 0)
		set(pose, "LegFL", 0.5, 0, 0)
		set(pose, "LegFR", 0.5, 0, 0)
		set(pose, "LegBL", 0.35, 0, 0)
		set(pose, "LegBR", 0.35, 0, 0)
		set(pose, "Head", 0.1, 0, 0)
		applyEars(pose, 0, 0, -0.15)
		applyTail(pose, 0, 0.25)
	elseif state == "land" then
		local absorb = 1 - math.clamp(t / 0.14, 0, 1)
		set(pose, "Torso", 0.22 * absorb, 0, 0)
		set(pose, "LegFL", -0.45 * absorb, 0, 0)
		set(pose, "LegFR", -0.45 * absorb, 0, 0)
		set(pose, "LegBL", -0.4 * absorb, 0, 0)
		set(pose, "LegBR", -0.4 * absorb, 0, 0)
		set(pose, "Head", -0.18 * absorb, 0, 0)
		applyEars(pose, 0, 0, 0.1 * absorb)
	elseif state == "turn" then
		local lean = math.sin(math.clamp(t / 0.16, 0, 1) * math.pi)
		set(pose, "Torso", 0, lean * 0.18, -lean * 0.22)
		set(pose, "Head", 0, lean * 0.3, 0)
		applyEars(pose, lean * 0.2, 0, 0)
		applyTail(pose, lean * 0.5, 0)
	elseif state == "fright" then
		local settle = math.clamp(t / 0.09, 0, 1)
		set(pose, "Torso", 0.16 * settle, 0, 0)
		set(pose, "Belly", 0.1 * settle, 0, 0)
		set(pose, "Head", -0.28 * settle, 0, 0)
		applyEars(pose, 0, 0, -0.75 * settle)
		applyTail(pose, 0, -0.55 * settle)
		set(pose, "LegFL", 0.2 * settle, 0, 0)
		set(pose, "LegFR", 0.2 * settle, 0, 0)
	elseif state == "stumble" then
		local wobble = math.sin(t * 26) * (1 - math.clamp(t / 0.3, 0, 1))
		set(pose, "Torso", 0.12, wobble * 0.25, wobble * 0.3)
		set(pose, "Head", -0.2, wobble * 0.3, wobble * 0.2)
		set(pose, "LegFL", 0.6, 0, 0)
		set(pose, "LegBR", -0.4, 0, 0)
		applyEars(pose, wobble * 0.3, 0, -0.2)
		applyTail(pose, wobble * 0.6, 0)
	elseif state == "happy" then
		local bounce = math.abs(math.sin(t * 9.0))
		set(pose, "Torso", -0.12 - bounce * 0.12, 0, 0)
		set(pose, "Head", -0.22 - bounce * 0.1, math.sin(t * 6) * 0.2, 0)
		set(pose, "LegFL", -0.3 * bounce, 0, 0)
		set(pose, "LegFR", -0.3 * bounce, 0, 0)
		applyEars(pose, math.sin(t * 12) * 0.5, 0, -0.1)
		applyTail(pose, math.sin(t * 16) * 0.9 * anim.tailAmp, -0.2)
	elseif state == "death" then
		local fall = math.clamp(t / 0.45, 0, 1)
		local settle = math.clamp((t - 0.45) / 0.5, 0, 1)
		set(pose, "Torso", 0.2 * fall, 0, -1.35 * fall)
		set(pose, "Head", 0.5 * fall, 0.4 * fall, -0.2 * settle)
		set(pose, "LegFL", -0.9 * fall, 0, 0)
		set(pose, "LegFR", -0.5 * fall, 0, 0)
		set(pose, "LegBL", 0.6 * fall, 0, 0)
		set(pose, "LegBR", 0.9 * fall, 0, 0)
		applyEars(pose, 0, 0, -0.9 * fall)
		applyTail(pose, 0, 0.4 * fall)
	elseif state == "victory" then
		local rise = math.clamp(t / 0.5, 0, 1)
		local settle = math.clamp((t - 0.5) / 0.6, 0, 1)
		set(pose, "Torso", -0.55 * rise, math.sin(t * 3) * 0.08, 0)
		set(pose, "Head", -0.45 * rise + settle * 0.15, 0, 0)
		set(pose, "LegFL", -0.75 * rise, 0, 0)
		set(pose, "LegFR", -0.75 * rise, 0, 0)
		set(pose, "LegBL", 0.3 * rise, 0, 0)
		set(pose, "LegBR", 0.3 * rise, 0, 0)
		applyEars(pose, math.sin(t * 4) * 0.3, 0, -0.35)
		applyTail(pose, math.sin(t * 8) * 0.7 * anim.tailAmp, -0.4)
	else
		-- Unknown state falls back to idle rather than freezing mid-pose.
		AnimationLib.sample("idle", t, animal, pose)
	end

	return pose
end

-- Vertical and horizontal body offsets that are not rotate-about-pivot: bobbing and hopping.
function AnimationLib.offset(state: string, t: number, animal, gait): (number, number, number)
	local hop = 0
	local forwardLean = 0
	local sideLean = 0

	if state == "run" then
		hop = math.abs(math.sin(t * gait.cadence)) * gait.hopHeight * 0.35
		forwardLean = gait.lean * 0.15
	elseif state == "walk" then
		hop = math.abs(math.sin(t * gait.cadence * 0.55)) * gait.hopHeight * 0.2
	elseif state == "jump" then
		local k = math.clamp(t / 0.34, 0, 1)
		hop = math.sin(k * math.pi) * (2.2 * 0.5)
	elseif state == "happy" then
		hop = math.abs(math.sin(t * 9.0)) * 0.35
	elseif state == "victory" then
		hop = math.sin(math.clamp(t / 0.6, 0, 1) * math.pi) * 0.3
	elseif state == "turn" then
		sideLean = math.sin(math.clamp(t / 0.16, 0, 1) * math.pi) * 0.12
	elseif state == "death" then
		hop = -math.clamp(t / 0.5, 0, 1) * (animal.build.legLength * 0.35)
	end

	_ = forwardLean

	return hop, sideLean, 0
end

return AnimationLib
