--!nonstrict
-- Species-driven rig builder.
--
-- Every animal is assembled from the same joint architecture so that one animation system drives
-- all thirteen species. Proportions, colours, and species extras come from AnimalConfig — a rabbit
-- is genuinely a different skeleton from a deer, not a recolour.
--
-- These are PROCEDURAL TEMPORARY ASSETS (docs/06 §9). The joint names, pivots and follow-map are
-- the interface Phase 4's Blender meshes must satisfy; nothing downstream of this file knows
-- whether a part is a primitive or a mesh.
--
-- Rig shape:
--   rig.model    Model, PrimaryPart = invisible root at ground level, WorldPivot at origin
--   rig.joints   { name = { part, base = CFrame, pivot = Vector3, kind, follow } }
--   rig.profile  the AnimalConfig entry
--
-- A posed part CFrame is always:
--   rootCFrame * rotateAbout(pivot, angles) * base
-- which makes rotation points explicit and keeps animation purely mathematical.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local AnimalConfig = require(Shared.Config.AnimalConfig)

local AnimalBuilder = {}

local function makePart(props): Part
	local part = Instance.new("Part")
	part.Name = props.name
	part.Size = props.size
	part.CFrame = props.cframe
	part.Color = props.color
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if props.shape then
		part.Shape = props.shape
	end
	part.Parent = props.parent
	return part
end

local function addJoint(rig, name: string, part: Part, base: CFrame, pivot: Vector3, kind: string, follow: string?)
	rig.joints[name] = {
		part = part,
		base = base,
		pivot = pivot,
		kind = kind,
		follow = follow,
	}
	return rig.joints[name]
end

-- Builds an accessory that inherits a parent joint's motion.
local function addFollower(rig, name: string, part: Part, base: CFrame, follow: string, kind: string?)
	local pivot = rig.joints[follow] and rig.joints[follow].pivot or Vector3.zero
	addJoint(rig, name, part, base, pivot, kind or "extra", follow)
end

local function buildExtras(rig, animal, parent, ctx, options)
	local extras = animal.extras
	if not extras then
		return
	end

	local colors = animal.colors
	local build = animal.build

	if extras == "spikes" then
		for row = 1, 3 do
			local z = -build.bodyLength * 0.28 + (row - 1) * build.bodyLength * 0.28
			for _, side in ipairs({ -1, 0, 1 }) do
				local x = side * build.bodyWidth * 0.3
				local cframe = ctx.bodyCF
					* CFrame.new(x, build.bodyHeight * 0.52, z)
					* CFrame.Angles(-0.35, 0, side * 0.18)
				local part = makePart({
					name = "Spike" .. row .. "_" .. tostring(side),
					size = Vector3.new(0.22, 0.55, 0.22),
					cframe = cframe,
					color = colors.accent,
					parent = parent,
					shape = Enum.PartType.Ball,
				})
				addFollower(rig, "Spike" .. row .. "_" .. tostring(side), part, cframe, "Torso")
			end
		end
	elseif extras == "bill" then
		local cframe = ctx.headCF * CFrame.new(0, -build.headSize * 0.12, -build.headSize * 0.5 - 0.28)
		local part = makePart({
			name = "Bill",
			size = Vector3.new(0.5, 0.16, 0.62),
			cframe = cframe,
			color = colors.accent,
			parent = parent,
		})
		addFollower(rig, "Bill", part, cframe, "Muzzle")
	elseif extras == "mask" then
		local cframe = ctx.headCF * CFrame.new(0, build.headSize * 0.12, -build.headSize * 0.48)
		local part = makePart({
			name = "Mask",
			size = Vector3.new(build.headSize * 0.92, build.headSize * 0.26, 0.14),
			cframe = cframe,
			color = colors.accent,
			parent = parent,
		})
		addFollower(rig, "Mask", part, cframe, "Head")
	elseif extras == "rings" then
		for ring = 1, 3 do
			local cframe = ctx.tailCF * CFrame.new(0, 0, build.tailLength * (0.15 + ring * 0.2))
			local part = makePart({
				name = "TailRing" .. ring,
				size = Vector3.new(build.tailWidth * 1.06, build.tailWidth * 1.06, build.tailWidth * 0.42),
				cframe = cframe,
				color = colors.accent,
				parent = parent,
			})
			addFollower(rig, "TailRing" .. ring, part, cframe, "Tail")
		end
	elseif extras == "whiskers" then
		for _, side in ipairs({ -1, 1 }) do
			for line = 0, 1 do
				local cframe = ctx.headCF
					* CFrame.new(side * 0.2, -build.headSize * 0.1 + line * 0.1, -build.headSize * 0.55)
					* CFrame.Angles(0, side * 0.5 + (line == 0 and 0.12 or -0.12), 0)
				local part = makePart({
					name = "Whisker" .. tostring(side) .. tostring(line),
					size = Vector3.new(0.5, 0.04, 0.04),
					cframe = cframe,
					color = colors.belly,
					parent = parent,
				})
				addFollower(rig, "Whisker" .. tostring(side) .. tostring(line), part, cframe, "Muzzle")
			end
		end
	elseif extras == "glow" then
		local cframe = ctx.headCF * CFrame.new(0, build.headSize * 0.6, build.headSize * 0.4)
		local part = makePart({
			name = "Glow",
			size = Vector3.new(0.35, 0.35, 0.35),
			cframe = cframe,
			color = colors.accent,
			material = Enum.Material.Neon,
			parent = parent,
			shape = Enum.PartType.Ball,
		})
		addFollower(rig, "Glow", part, cframe, "Head")

		-- A lobby can hold sixteen of these at once. A dynamic light per rig is the one part cost that
		-- scales badly on mobile, so callers that build many decorative rigs pass { lights = false }.
		if not (options and options.lights == false) then
			local light = Instance.new("PointLight")
			light.Name = "Aura"
			light.Brightness = 1.4
			light.Range = 12
			light.Color = colors.accent
			light.Parent = part
		end
	end
end

-- Builds a complete rig for one species.
function AnimalBuilder.buildRig(animalId: string, options): any
	local animal = AnimalConfig.get(animalId)
	local build = animal.build
	local colors = animal.colors

	local model = Instance.new("Model")
	model.Name = "Animal_" .. animal.id

	local root = makePart({
		name = "Root",
		size = Vector3.new(0.4, 0.4, 0.4),
		cframe = CFrame.new(0, 0, 0),
		color = Color3.new(0, 0, 0),
		parent = model,
	})
	root.Transparency = 1
	model.PrimaryPart = root

	local rig = {
		model = model,
		root = root,
		joints = {},
		profile = animal,
		animalId = animal.id,
		height = 0,
	}

	local frontLeg = build.legLength
	local backLeg = build.legLength * build.hindLegScale
	local torsoY = frontLeg + build.bodyHeight * 0.5 - build.stance * frontLeg * 0.5

	-- A hind-leg scale above 1 tilts the body up at the back: that is what makes a rabbit read as a
	-- rabbit and a fox read as a fox.
	local tilt = math.clamp(math.atan((backLeg - frontLeg) / math.max(1, build.bodyLength)), -0.4, 0.4)
	local bodyCF = CFrame.new(0, torsoY, 0) * CFrame.Angles(tilt, 0, 0)

	local torso = makePart({
		name = "Torso",
		size = Vector3.new(build.bodyWidth, build.bodyHeight, build.bodyLength),
		cframe = bodyCF,
		color = colors.body,
		parent = model,
	})
	addJoint(rig, "Torso", torso, bodyCF, bodyCF.Position, "body")

	local bellyCF = bodyCF * CFrame.new(0, -build.bodyHeight * 0.32, 0)
	local belly = makePart({
		name = "Belly",
		size = Vector3.new(build.bodyWidth * 0.88, build.bodyHeight * 0.42, build.bodyLength * 0.9),
		cframe = bellyCF,
		color = colors.belly,
		parent = model,
	})
	addJoint(rig, "Belly", belly, bellyCF, bellyCF.Position, "body")

	local headCF = bodyCF
		* CFrame.new(
			0,
			build.bodyHeight * 0.34 + build.neckLength + build.headSize * 0.5,
			-(build.bodyLength * 0.5 + build.headSize * 0.35)
		)

	-- The head pivots about the neck, not its own centre, so nodding reads as a nod.
	local neckPivot = Vector3.new(
		0,
		torsoY + build.bodyHeight * 0.25,
		-(build.bodyLength * 0.5 + build.headSize * 0.1)
	)

	local head = makePart({
		name = "Head",
		size = Vector3.new(build.headSize, build.headSize, build.headSize),
		cframe = headCF,
		color = colors.body,
		parent = model,
	})
	addJoint(rig, "Head", head, headCF, neckPivot, "head")

	local ctx = {
		bodyCF = bodyCF,
		headCF = headCF,
		tailCF = bodyCF,
	}

	local muzzleCF = headCF * CFrame.new(0, -build.headSize * 0.16, -(build.headSize * 0.5 + build.snoutLength * 0.5))
	local muzzle = makePart({
		name = "Muzzle",
		size = Vector3.new(build.headSize * 0.58, build.headSize * 0.42, math.max(0.1, build.snoutLength)),
		cframe = muzzleCF,
		color = colors.belly,
		parent = model,
	})
	addFollower(rig, "Muzzle", muzzle, muzzleCF, "Head", "head")

	local noseCF = muzzleCF * CFrame.new(0, build.headSize * 0.04, -(build.snoutLength * 0.5 + 0.04))
	local nose = makePart({
		name = "Nose",
		size = Vector3.new(build.headSize * 0.26, build.headSize * 0.18, 0.14),
		cframe = noseCF,
		color = colors.hoof,
		parent = model,
	})
	addFollower(rig, "Nose", nose, noseCF, "Muzzle", "head")

	for _, side in ipairs({ -1, 1 }) do
		local eyeName = side < 0 and "EyeL" or "EyeR"
		local eyeCF = headCF
			* CFrame.new(side * build.headSize * 0.32, build.headSize * 0.1, -(build.headSize * 0.5 - 0.02))
		local eye = makePart({
			name = eyeName,
			size = Vector3.new(build.eyeSize, build.eyeSize * 1.2, build.eyeSize * 0.45),
			cframe = eyeCF,
			color = colors.eye,
			parent = model,
		})
		addFollower(rig, eyeName, eye, eyeCF, "Head", "head")

		if build.earLength > 0.05 then
			local earName = side < 0 and "EarL" or "EarR"
			local earBase = headCF * CFrame.new(side * build.headSize * 0.3, build.headSize * 0.5, 0)
			local earCF = earBase * CFrame.new(0, build.earLength * 0.5, 0)
			local ear = makePart({
				name = earName,
				size = Vector3.new(build.earWidth, build.earLength, build.earWidth * 0.55),
				cframe = earCF,
				color = colors.body,
				parent = model,
			})
			addJoint(rig, earName, ear, earCF, earBase.Position, "ear")

			local innerName = side < 0 and "EarInnerL" or "EarInnerR"
			local innerCF = earCF * CFrame.new(0, 0, build.earWidth * 0.3)
			local inner = makePart({
				name = innerName,
				size = Vector3.new(build.earWidth * 0.6, build.earLength * 0.72, build.earWidth * 0.18),
				cframe = innerCF,
				color = colors.accent,
				parent = model,
			})
			addFollower(rig, innerName, inner, innerCF, earName, "ear")
		end
	end

	-- Legs live in root space so their pivots stay vertical regardless of body tilt.
	local legPlan = {
		{ suffix = "FL", x = -1, z = -1, length = frontLeg },
		{ suffix = "FR", x = 1, z = -1, length = frontLeg },
		{ suffix = "BL", x = -1, z = 1, length = backLeg },
		{ suffix = "BR", x = 1, z = 1, length = backLeg },
	}

	local legHalfWidth = build.bodyWidth * 0.34
	local legHalfLength = build.bodyLength * 0.3

	for _, plan in ipairs(legPlan) do
		local hipX = plan.x * legHalfWidth
		local hipZ = plan.z * legHalfLength
		local hipPivot = Vector3.new(hipX, plan.length, hipZ)

		local legCF = CFrame.new(hipX, plan.length * 0.5, hipZ)
		local leg = makePart({
			name = "Leg" .. plan.suffix,
			size = Vector3.new(build.legThickness, plan.length, build.legThickness),
			cframe = legCF,
			color = colors.body,
			parent = model,
		})
		addJoint(rig, "Leg" .. plan.suffix, leg, legCF, hipPivot, "leg")

		local hoofCF = CFrame.new(hipX, 0.12, hipZ)
		local hoof = makePart({
			name = "Hoof" .. plan.suffix,
			size = Vector3.new(build.legThickness * 1.15, 0.24, build.legThickness * 1.15),
			cframe = hoofCF,
			color = colors.hoof,
			parent = model,
		})
		addJoint(rig, "Hoof" .. plan.suffix, hoof, hoofCF, hipPivot, "hoof", "Leg" .. plan.suffix)
	end

	local tailBaseCF = bodyCF * CFrame.new(0, build.bodyHeight * 0.2, build.bodyLength * 0.5)
	local tailCF = tailBaseCF * CFrame.new(0, 0, build.tailLength * 0.5)
	local tail = makePart({
		name = "Tail",
		size = Vector3.new(build.tailWidth, build.tailWidth, math.max(0.1, build.tailLength)),
		cframe = tailCF,
		color = colors.belly,
		parent = model,
	})
	addJoint(rig, "Tail", tail, tailCF, tailBaseCF.Position, "tail")
	ctx.tailCF = tailBaseCF

	buildExtras(rig, animal, model, ctx, options)

	model.WorldPivot = CFrame.new(0, 0, 0)
	rig.height = torsoY + build.bodyHeight * 0.5 + build.earLength
	rig.scale = options and options.scale or 1

	return rig
end

-- Static rest pose. Used for server-side lobby models, which do not animate.
function AnimalBuilder.applyRestPose(rig)
	local rootCF = rig.model:GetPivot()
	for _, joint in pairs(rig.joints) do
		joint.part.CFrame = rootCF * joint.base
	end
end

-- Backwards-compatible entry point used by Phase 2 code and tests.
function AnimalBuilder.buildDeer(): Model
	return AnimalBuilder.buildRig("deer").model
end

return AnimalBuilder
