--!nonstrict
-- AnimationController: the bridge between logical movement and the visible rig.
--
-- MovementController publishes where the animal is and what it is doing. Animator decides which pose
-- is playing. AnimationLib computes the joint angles. This controller is the only thing that writes
-- part CFrames on the client.
--
-- A posed part is always:
--   rootCFrame * rotateAbout(pivot, angles) * base
-- so the rest pose, the joint pivots, and the animation are independent inputs.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local AnimationLib = require(Shared.Animation.AnimationLib)
local Animator = require(Shared.Animation.Animator)

local SessionController = require(script.Parent.SessionController)
local MovementController = require(script.Parent.MovementController)

local AnimationController = {}

local rig = nil
local animator = nil
local celebration = 0
local happy = 0
local fright = 0

-- Adopts the rig that MovementController built. Called from init and retried from update, because a
-- controller that runs one frame too early must never leave the animal permanently unposed.
local function adoptRig(): boolean
	if rig and animator then
		return true
	end
	if not rig then
		rig = MovementController.getRig()
	end
	if not rig then
		return false
	end
	animator = Animator.new(rig.profile)
	return true
end

local function applyJoint(joint, rootCFrame: CFrame, x: number, y: number, z: number)
	local pivot = joint.pivot
	joint.part.CFrame = rootCFrame
		* CFrame.new(pivot)
		* CFrame.Angles(x, y, z)
		* CFrame.new(-pivot)
		* joint.base
end

function AnimationController.init()
	adoptRig()
end

function AnimationController.start()
	SessionController.signals.nearMiss:Connect(function()
		fright = 0
		happy = math.max(happy, 0.25)
	end)

	SessionController.signals.pickup:Connect(function()
		happy = math.max(happy, 0.2)
	end)

	SessionController.signals.runEnded:Connect(function()
		celebration = 0
	end)

	SessionController.signals.returnedToLobby:Connect(function()
		celebration = 0
		happy = 0
		fright = 0
	end)
end

function AnimationController.celebrate()
	celebration = 0.4
end

function AnimationController.update(dt: number)
	if not adoptRig() then
		return
	end

	local visual = MovementController.getVisual()

	happy = math.max(0, happy - dt)
	fright = math.max(0, fright - dt)
	celebration = math.max(0, celebration - dt)

	animator:update(dt, {
		dead = visual.dead,
		airborne = visual.airborne,
		rising = visual.airborne and visual.jumpArc > 0.9,
		fright = visual.active and fright > 0,
		celebrate = celebration > 0,
		happy = visual.active and happy > 0,
		turning = visual.active and visual.turning,
		running = visual.active and visual.chaining and visual.stepping,
		walking = visual.active and visual.stepping and not visual.chaining,
		threat = visual.active and not visual.stepping,
	})

	local pose = animator:sample()
	local hop, sideLean = AnimationLib.offset(animator.state, animator.time, rig.profile, rig.profile.gait)

	local root = visual.rootCFrame
		* CFrame.new(0, hop + visual.jumpArc, 0)
		* CFrame.Angles(0, 0, sideLean)

	for name, joint in pairs(rig.joints) do
		local angles = pose[name]

		-- A follower inherits its parent joint's rotation but keeps its own pivot and offset, so a
		-- hoof, an ear tip, or a cosmetic moves with the limb it is attached to.
		if joint.follow then
			local parentAngles = pose[joint.follow]
			if parentAngles then
				angles = parentAngles
			end
		end

		if angles then
			applyJoint(joint, root, angles[1], angles[2], angles[3])
		else
			applyJoint(joint, root, 0, 0, 0)
		end
	end

	rig.root.CFrame = visual.rootCFrame
end

return AnimationController
