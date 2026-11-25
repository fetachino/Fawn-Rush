--!nonstrict
-- WorldKit: every procedural scenery primitive the worlds are built from.
--
-- One module, shared by the client's run renderer and the server's lobby builder, so a tree looks the
-- same in both places and a new kind of prop is added in exactly one file. Nothing here is a finished
-- art asset: these are the PROCEDURAL TEMPORARY geometries described in docs/06 §9, and each one
-- names the Blender asset that will eventually replace it.
--
-- Rules every builder follows:
--   * anchored, CanCollide = false, CanQuery = false, CanTouch = false — gameplay collision is AABB
--     maths on the server, never part collision (docs/04 §7).
--   * CastShadow is off: run scenery is decorative and shadow maps are the first thing to cost a
--     weak phone its frame rate.
--   * a fixed, small part count. Draw calls are the budget, not triangles.
--   * deterministic. `hash(n, salt)` is a pure integer scramble, so the same row always produces the
--     same tree on every client without a byte of network traffic.

local WorldKit = {}

local function newPropPart(props): BasePart
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

-- Pure 0..1 hash of two integers. No RNG state, so no ordering dependency between clients.
local function hash(n: number, salt: number): number
	local x = (n * 73821 + salt * 19349 + 40503) % 1000003
	x = (x * 75787 + 74317) % 1000003
	return (x % 1001) / 1000
end

WorldKit.hash = hash

-- Run scenery never casts shadows (shadow maps are the first thing to cost a weak phone a frame).
-- The lobby is a single fixed scene, so it can afford them — this is how LobbyBuilder opts back in
-- without every run prop inheriting the cost.
function WorldKit.setShadows(model: Instance, enabled: boolean)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CastShadow = enabled
		end
	end
end

-- Sorts a float in 0..1 onto an integer bucket, for "every Nth row" decisions.
function WorldKit.span(value: number, buckets: number): number
	return math.floor(value * buckets) % buckets
end

local function container(parent: Instance, name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

-- Broadleaf tree. Replaces ENV_Tree_Broadleaf_A/B. ------------------------------------------------
function WorldKit.tree(parent: Instance, position: Vector3, scale: number, colors, seed: number)
	local model = container(parent, "Tree")
	local lean = (hash(seed, 3) - 0.5) * 0.16
	local trunkHeight = 9 * scale

	newPropPart({
		name = "Trunk",
		size = Vector3.new(1.5 * scale, trunkHeight, 1.5 * scale),
		cframe = CFrame.new(position + Vector3.new(0, trunkHeight * 0.5, 0)) * CFrame.Angles(0, hash(seed, 1) * math.pi, lean),
		color = colors.trunk,
		material = Enum.Material.Wood,
		parent = model,
	})

	newPropPart({
		name = "FoliageLow",
		size = Vector3.new(10 * scale, 6.5 * scale, 10 * scale),
		cframe = CFrame.new(position + Vector3.new(0, trunkHeight + 2 * scale, 0)),
		color = colors.leaf,
		material = Enum.Material.Grass,
		parent = model,
		shape = Enum.PartType.Ball,
	})

	newPropPart({
		name = "FoliageHigh",
		size = Vector3.new(7.5 * scale, 5.5 * scale, 7.5 * scale),
		cframe = CFrame.new(position + Vector3.new(0.5 * scale, trunkHeight + 6 * scale, -0.4 * scale)),
		color = colors.leafAccent,
		material = Enum.Material.Grass,
		parent = model,
		shape = Enum.PartType.Ball,
	})

	return model
end

-- Conifer. Replaces ENV_Tree_Pine_A/B. Three stacked discs read as a pine at any distance. --------
function WorldKit.pine(parent: Instance, position: Vector3, scale: number, colors, seed: number)
	local model = container(parent, "Pine")
	local trunkHeight = 10 * scale

	newPropPart({
		name = "Trunk",
		size = Vector3.new(1.2 * scale, trunkHeight, 1.2 * scale),
		cframe = CFrame.new(position + Vector3.new(0, trunkHeight * 0.5, 0)),
		color = colors.trunk,
		material = Enum.Material.Wood,
		parent = model,
	})

	for tier = 1, 3 do
		local width = (8.5 - tier * 1.9) * scale
		local height = (4.2 - tier * 0.5) * scale
		local y = trunkHeight + (tier - 1) * 3.1 * scale

		newPropPart({
			name = "Tier" .. tier,
			size = Vector3.new(width, height, width),
			cframe = CFrame.new(position + Vector3.new(0, y, 0)) * CFrame.Angles(0, hash(seed, tier) * math.pi, 0),
			color = tier % 2 == 0 and colors.leafAccent or colors.leaf,
			material = Enum.Material.Grass,
			parent = model,
			shape = Enum.PartType.Ball,
		})
	end

	-- Snow load. Only the snow world uses `pine`, so the cap is unconditional rather than gated on a
	-- colour that every palette defines.
	newPropPart({
		name = "SnowCap",
		size = Vector3.new(6.4 * scale, 1.5 * scale, 6.4 * scale),
		cframe = CFrame.new(position + Vector3.new(0, trunkHeight + 3.4 * scale, 0)),
		color = colors.snow,
		material = Enum.Material.Snow,
		parent = model,
		shape = Enum.PartType.Ball,
	})

	return model
end

-- Bush. Replaces ENV_Bush_A/B. ------------------------------------------------------------------
function WorldKit.bush(parent: Instance, position: Vector3, scale: number, colors, seed: number)
	local model = container(parent, "Bush")

	newPropPart({
		name = "Bush",
		size = Vector3.new(4.2 * scale, 3.0 * scale, 4.2 * scale),
		cframe = CFrame.new(position + Vector3.new(0, 1.5 * scale, 0)) * CFrame.Angles(0, hash(seed, 2) * math.pi, 0),
		color = hash(seed, 5) > 0.5 and colors.leaf or colors.leafAccent,
		material = Enum.Material.Grass,
		parent = model,
		shape = Enum.PartType.Ball,
	})

	return model
end

-- Rock. Replaces ENV_Rock_A/B/C. -----------------------------------------------------------------
function WorldKit.rock(parent: Instance, position: Vector3, scale: number, colors, seed: number)
	local model = container(parent, "Rock")
	local width = (2.4 + hash(seed, 7) * 1.8) * scale
	local height = (1.6 + hash(seed, 8) * 1.4) * scale

	newPropPart({
		name = "Rock",
		size = Vector3.new(width, height, width * 0.9),
		cframe = CFrame.new(position + Vector3.new(0, height * 0.35, 0))
			* CFrame.Angles(hash(seed, 9) * 0.3, hash(seed, 10) * math.pi, hash(seed, 11) * 0.3),
		color = colors.rock,
		material = Enum.Material.Slate,
		parent = model,
		shape = Enum.PartType.Ball,
	})

	return model
end

-- Mushroom. Replaces ENV_Mushroom_A/B. -------------------------------------------------------------
function WorldKit.mushroom(parent: Instance, position: Vector3, scale: number, colors, seed: number)
	local model = container(parent, "Mushroom")

	newPropPart({
		name = "Stem",
		size = Vector3.new(0.5 * scale, 1.0 * scale, 0.5 * scale),
		cframe = CFrame.new(position + Vector3.new(0, 0.5 * scale, 0)),
		color = Color3.fromRGB(238, 230, 214),
		parent = model,
	})

	newPropPart({
		name = "Cap",
		size = Vector3.new(1.5 * scale, 0.7 * scale, 1.5 * scale),
		cframe = CFrame.new(position + Vector3.new(0, 1.05 * scale, 0)) * CFrame.Angles(0, hash(seed, 12) * math.pi, 0),
		color = hash(seed, 13) > 0.5 and colors.hazard or colors.cone,
		material = Enum.Material.SmoothPlastic,
		parent = model,
		shape = Enum.PartType.Ball,
	})

	return model
end

-- Cactus. Replaces ENV_Cactus_A/B. ----------------------------------------------------------------
function WorldKit.cactus(parent: Instance, position: Vector3, scale: number, colors, seed: number)
	local model = container(parent, "Cactus")
	local height = (5.5 + hash(seed, 14) * 2.5) * scale

	newPropPart({
		name = "Body",
		size = Vector3.new(1.1 * scale, height, 1.1 * scale),
		cframe = CFrame.new(position + Vector3.new(0, height * 0.5, 0)),
		color = colors.leaf,
		material = Enum.Material.Grass,
		parent = model,
	})

	local armCount = hash(seed, 15) > 0.45 and 2 or 1
	for arm = 1, armCount do
		local side = arm == 1 and -1 or 1
		local y = height * (0.45 + arm * 0.12)

		newPropPart({
			name = "Arm" .. arm,
			size = Vector3.new(2.0 * scale, 0.75 * scale, 0.75 * scale),
			cframe = CFrame.new(position + Vector3.new(side * 1.0 * scale, y, 0)),
			color = colors.leaf,
			material = Enum.Material.Grass,
			parent = model,
		})

		newPropPart({
			name = "ArmUp" .. arm,
			size = Vector3.new(0.75 * scale, 2.0 * scale, 0.75 * scale),
			cframe = CFrame.new(position + Vector3.new(side * 1.85 * scale, y + 0.8 * scale, 0)),
			color = colors.leaf,
			material = Enum.Material.Grass,
			parent = model,
		})
	end

	return model
end

-- Mesa / sandstone formation. Replaces ENV_Mesa_A/B. -----------------------------------------------
function WorldKit.mesa(parent: Instance, position: Vector3, scale: number, colors, seed: number)
	local model = container(parent, "Mesa")
	local height = (7 + hash(seed, 16) * 9) * scale
	local width = (9 + hash(seed, 17) * 8) * scale

	newPropPart({
		name = "Base",
		size = Vector3.new(width, height, width * 0.8),
		cframe = CFrame.new(position + Vector3.new(0, height * 0.42, 0)) * CFrame.Angles(0, hash(seed, 18) * math.pi * 0.25, 0),
		color = colors.sandstone,
		material = Enum.Material.Sandstone,
		parent = model,
	})

	newPropPart({
		name = "Cap",
		size = Vector3.new(width * 0.82, height * 0.24, width * 0.7),
		cframe = CFrame.new(position + Vector3.new(0, height * 0.94, 0)),
		color = colors.sand,
		material = Enum.Material.Sand,
		parent = model,
	})

	return model
end

-- City building. Replaces ENV_Building_A–F. Body, roof, two window bands. ---------------------------
function WorldKit.building(parent: Instance, position: Vector3, scale: number, colors, seed: number)
	local model = container(parent, "Building")
	local height = (18 + hash(seed, 19) * 34) * scale
	local depth = (10 + hash(seed, 20) * 8) * scale
	local width = (8 + hash(seed, 21) * 8) * scale
	local tint = colors.buildingA
	if hash(seed, 22) > 0.66 then
		tint = colors.buildingB
	elseif hash(seed, 22) > 0.33 then
		tint = colors.buildingC
	end

	newPropPart({
		name = "Body",
		size = Vector3.new(width, height, depth),
		cframe = CFrame.new(position + Vector3.new(0, height * 0.5, 0)),
		color = tint,
		material = Enum.Material.Concrete,
		parent = model,
	})

	newPropPart({
		name = "Roof",
		size = Vector3.new(width * 1.04, 0.9 * scale, depth * 1.04),
		cframe = CFrame.new(position + Vector3.new(0, height + 0.45 * scale, 0)),
		color = colors.kerb,
		material = Enum.Material.Concrete,
		parent = model,
	})

	-- Two lit window bands instead of a real facade: one draw call each, and it reads at speed.
	for band = 1, 2 do
		local y = height * (0.35 + band * 0.22)
		newPropPart({
			name = "Windows" .. band,
			size = Vector3.new(width * 0.86, 0.7 * scale, depth * 1.02),
			cframe = CFrame.new(position + Vector3.new(0, y, 0)),
			color = band == 1 and colors.accent or colors.line,
			material = Enum.Material.Neon,
			parent = model,
		})
	end

	return model
end

-- Street light. Replaces ENV_StreetLight_01. No light source: a light per prop is unaffordable. ----
function WorldKit.streetLight(parent: Instance, position: Vector3, scale: number, colors, seed: number)
	local model = container(parent, "StreetLight")
	local height = 12 * scale

	newPropPart({
		name = "Pole",
		size = Vector3.new(0.4 * scale, height, 0.4 * scale),
		cframe = CFrame.new(position + Vector3.new(0, height * 0.5, 0)),
		color = colors.kerb,
		material = Enum.Material.Metal,
		parent = model,
	})

	newPropPart({
		name = "Head",
		size = Vector3.new(2.6 * scale, 0.5 * scale, 1.0 * scale),
		cframe = CFrame.new(position + Vector3.new(1.1 * scale, height - 0.3 * scale, 0)),
		color = hash(seed, 23) > 0.5 and colors.accent or colors.line,
		material = Enum.Material.Neon,
		parent = model,
	})

	return model
end

-- Roadside billboard. Replaces ENV_Billboard_01. ---------------------------------------------------
function WorldKit.billboard(parent: Instance, position: Vector3, scale: number, colors, seed: number)
	local model = container(parent, "Billboard")
	local height = 9 * scale
	local panelColor = hash(seed, 24) > 0.5 and colors.accent or colors.hazard

	newPropPart({
		name = "Post",
		size = Vector3.new(0.6 * scale, height, 0.6 * scale),
		cframe = CFrame.new(position + Vector3.new(0, height * 0.5, 0)),
		color = colors.kerb,
		material = Enum.Material.Metal,
		parent = model,
	})

	newPropPart({
		name = "Panel",
		size = Vector3.new(7.5 * scale, 4.2 * scale, 0.35 * scale),
		cframe = CFrame.new(position + Vector3.new(0, height + 2.0 * scale, 0)) * CFrame.Angles(0, hash(seed, 25) * 0.6 - 0.3, 0),
		color = panelColor,
		material = Enum.Material.Neon,
		parent = model,
	})

	return model
end

-- Snow bank. Replaces ENV_SnowBank_A/B. ------------------------------------------------------------
function WorldKit.snowBank(parent: Instance, position: Vector3, scale: number, colors, seed: number)
	local model = container(parent, "SnowBank")

	newPropPart({
		name = "Bank",
		size = Vector3.new((6 + hash(seed, 26) * 6) * scale, (1.4 + hash(seed, 27) * 1.2) * scale, (4 + hash(seed, 28) * 3) * scale),
		cframe = CFrame.new(position + Vector3.new(0, 0.35 * scale, 0)) * CFrame.Angles(0, hash(seed, 29) * math.pi, 0),
		color = colors.snow,
		material = Enum.Material.Snow,
		parent = model,
		shape = Enum.PartType.Ball,
	})

	return model
end

-- Ice sheet. Replaces ENV_IceSheet_01. -------------------------------------------------------------
function WorldKit.iceSheet(parent: Instance, position: Vector3, scale: number, colors, seed: number)
	local model = container(parent, "IceSheet")

	newPropPart({
		name = "Sheet",
		size = Vector3.new(7 * scale, 0.35 * scale, 5 * scale),
		cframe = CFrame.new(position + Vector3.new(0, 0.16 * scale, 0)) * CFrame.Angles(0, hash(seed, 30) * math.pi, 0),
		color = colors.ice,
		material = Enum.Material.Ice,
		parent = model,
	})

	return model
end

-- Neon tower. Replaces ENV_NeonTower (new in Phase 4). --------------------------------------------
function WorldKit.neonTower(parent: Instance, position: Vector3, scale: number, colors, seed: number)
	local model = container(parent, "NeonTower")
	local height = (24 + hash(seed, 31) * 40) * scale
	local width = (7 + hash(seed, 32) * 6) * scale

	newPropPart({
		name = "Body",
		size = Vector3.new(width, height, width * 0.85),
		cframe = CFrame.new(position + Vector3.new(0, height * 0.5, 0)),
		color = colors.buildingB,
		material = Enum.Material.Concrete,
		parent = model,
	})

	for strip = 1, 2 do
		local color = strip == 1 and colors.neonA or colors.neonB
		local y = height * (0.4 + strip * 0.2)
		newPropPart({
			name = "Strip" .. strip,
			size = Vector3.new(width * 1.02, 0.55 * scale, width * 0.88),
			cframe = CFrame.new(position + Vector3.new(0, y, 0)),
			color = color,
			material = Enum.Material.Neon,
			parent = model,
		})
	end

	return model
end

-- Neon sign. Replaces ENV_NeonSign_A–D. ------------------------------------------------------------
function WorldKit.neonSign(parent: Instance, position: Vector3, scale: number, colors, seed: number)
	local model = container(parent, "NeonSign")
	local height = 10 * scale
	local color = hash(seed, 33) > 0.5 and colors.neonB or colors.neonA

	newPropPart({
		name = "Post",
		size = Vector3.new(0.5 * scale, height, 0.5 * scale),
		cframe = CFrame.new(position + Vector3.new(0, height * 0.5, 0)),
		color = colors.trunk,
		material = Enum.Material.Metal,
		parent = model,
	})

	newPropPart({
		name = "Panel",
		size = Vector3.new(5.5 * scale, 3.4 * scale, 0.3 * scale),
		cframe = CFrame.new(position + Vector3.new(0, height + 1.6 * scale, 0)),
		color = color,
		material = Enum.Material.Neon,
		parent = model,
	})

	return model
end

-- Holo pylon. Replaces ENV_HoloPylon_01. -----------------------------------------------------------
function WorldKit.holoPylon(parent: Instance, position: Vector3, scale: number, colors, seed: number)
	local model = container(parent, "HoloPylon")
	local height = 7 * scale

	newPropPart({
		name = "Base",
		size = Vector3.new(1.8 * scale, 0.6 * scale, 1.8 * scale),
		cframe = CFrame.new(position + Vector3.new(0, 0.3 * scale, 0)),
		color = colors.rock,
		material = Enum.Material.Metal,
		parent = model,
	})

	newPropPart({
		name = "Field",
		size = Vector3.new(1.1 * scale, height, 1.1 * scale),
		cframe = CFrame.new(position + Vector3.new(0, height * 0.5 + 0.6 * scale, 0)),
		color = hash(seed, 34) > 0.5 and colors.neonB or colors.neonA,
		material = Enum.Material.ForceField,
		parent = model,
	})

	return model
end

-- Collectible, skinned per world. Values never change — only the model does (docs/01 §8). ----------
local COLLECTIBLE_SHAPES = {
	acorn = { nut = Vector3.new(1.15, 1.35, 1.15), cap = Vector3.new(0.75, 0.3, 0.75), shape = Enum.PartType.Ball },
	coin = { nut = Vector3.new(0.3, 1.4, 1.4), cap = Vector3.new(0.34, 0.4, 0.4), shape = Enum.PartType.Cylinder },
	cactusNut = { nut = Vector3.new(1.1, 1.2, 1.1), cap = Vector3.new(0.5, 0.5, 0.5), shape = Enum.PartType.Ball },
	iceGem = { nut = Vector3.new(1.0, 1.6, 1.0), cap = Vector3.new(0.6, 0.3, 0.6), shape = Enum.PartType.Block },
	shard = { nut = Vector3.new(0.8, 1.9, 0.8), cap = Vector3.new(0.5, 0.3, 0.5), shape = Enum.PartType.Block },
}

function WorldKit.collectible(parent: Instance, kind: string, colors)
	local model = container(parent, "Collectible")
	local skin = COLLECTIBLE_SHAPES[kind] or COLLECTIBLE_SHAPES.acorn

	-- `x == "a" or x == "b" and y or z` binds as `x == "a" or (x == "b" and y) or z`, which made a
	-- shard's material the boolean `true`. Both glow worlds are resolved first, explicitly.
	local glowing = kind == "shard" or kind == "iceGem"
	local material = glowing and Enum.Material.Neon or Enum.Material.SmoothPlastic

	local nut = newPropPart({
		name = "Nut",
		size = skin.nut,
		cframe = CFrame.new(0, 0, 0),
		color = colors.collectible,
		material = material,
		parent = model,
		shape = skin.shape,
	})

	newPropPart({
		name = "Cap",
		size = skin.cap,
		cframe = CFrame.new(0, skin.nut.Y * 0.5, 0),
		color = colors.collectibleAccent,
		material = Enum.Material.SmoothPlastic,
		parent = model,
	})

	model.PrimaryPart = nut
	model.WorldPivot = CFrame.new(0, 0, 0)
	return model
end

-- Road closure. Replaces ENV_Barrier_01/ENV_Cone_01, tinted per world. -----------------------------
function WorldKit.barrier(parent: Instance, position: Vector3, colors)
	local model = container(parent, "Closure")

	newPropPart({
		name = "Panel",
		size = Vector3.new(3.4, 2.0, 0.6),
		cframe = CFrame.new(position + Vector3.new(0, 1.1, 0)),
		color = colors.hazard,
		parent = model,
	})

	for _, side in ipairs({ -1, 1 }) do
		newPropPart({
			name = "Cone",
			size = Vector3.new(0.9, 0.22, 0.9),
			cframe = CFrame.new(position + Vector3.new(side * 1.5, 0.11, 0.9)),
			color = colors.cone,
			parent = model,
		})
	end

	return model
end

-- Wildlife crosser. Replaces WL_Squirrel/Pigeon/Lizard/SnowHare/Drone. -----------------------------
function WorldKit.wildlife(parent: Instance, obstacle, color: Color3)
	local model = container(parent, "Wildlife_" .. tostring(obstacle.row))

	local body = newPropPart({
		name = "Body",
		size = Vector3.new(1.8, 1.0, 1.1),
		cframe = CFrame.new(0, 0.7, 0),
		color = color,
		parent = model,
	})

	newPropPart({
		name = "Head",
		size = Vector3.new(0.8, 0.8, 0.8),
		cframe = CFrame.new(0.8, 1.1, 0),
		color = color:Lerp(Color3.new(1, 1, 1), 0.15),
		parent = model,
	})

	model.PrimaryPart = body
	model.WorldPivot = CFrame.new(0, 0, 0)
	return model
end

-- Pond. Replaces ENV_Pond_01, used sideways in Greenwood. ------------------------------------------
function WorldKit.pond(parent: Instance, position: Vector3, scale: number, colors, seed: number)
	local model = container(parent, "Pond")

	newPropPart({
		name = "Water",
		size = Vector3.new(14 * scale, 0.25 * scale, 10 * scale),
		cframe = CFrame.new(position + Vector3.new(0, 0.14, 0)),
		color = colors.accent:Lerp(colors.leaf, 0.55),
		material = Enum.Material.Glass,
		parent = model,
	})

	for rim = 1, 3 do
		local angle = hash(seed, 35 + rim) * math.pi * 2
		newPropPart({
			name = "Rim" .. rim,
			size = Vector3.new(2.4 * scale, 0.6 * scale, 1.8 * scale),
			cframe = CFrame.new(position + Vector3.new(math.cos(angle) * 7 * scale, 0.2 * scale, math.sin(angle) * 5 * scale)),
			color = colors.rock,
			material = Enum.Material.Slate,
			parent = model,
			shape = Enum.PartType.Ball,
		})
	end

	return model
end

-- Footbridge. Replaces ENV_Bridge_Wood_01 / ENV_Bridge_Ice_01.
--
-- Scenery only: the playfield never routes the player across one, so a bridge costs nothing in the
-- simulation and cannot affect fairness. The variant is passed explicitly because every palette
-- defines an `ice` colour, so gating on the colour would make every bridge frozen.
function WorldKit.bridge(parent: Instance, position: Vector3, scale: number, colors, seed: number, variant: string?)
	local model = container(parent, "Bridge")
	local icy = variant == "ice"

	newPropPart({
		name = "Deck",
		size = Vector3.new(3.4 * scale, 0.5 * scale, 18 * scale),
		cframe = CFrame.new(position + Vector3.new(0, 0.4 * scale, 0)),
		color = icy and colors.ice or colors.trunk,
		material = icy and Enum.Material.Ice or Enum.Material.WoodPlanks,
		parent = model,
	})

	for _, side in ipairs({ -1, 1 }) do
		newPropPart({
			name = "Rail",
			size = Vector3.new(0.3 * scale, 1.6 * scale, 18 * scale),
			cframe = CFrame.new(position + Vector3.new(side * 1.6 * scale, 1.4 * scale, 0)),
			color = icy and colors.ice or colors.trunk,
			material = icy and Enum.Material.Ice or Enum.Material.Wood,
			parent = model,
		})
	end

	return model
end

-- Dispatch: the renderer names a kind, the kit builds it. Adding a prop is one entry here. --------
local BUILDERS = {
	tree = WorldKit.tree,
	pine = WorldKit.pine,
	bush = WorldKit.bush,
	rock = WorldKit.rock,
	mushroom = WorldKit.mushroom,
	cactus = WorldKit.cactus,
	mesa = WorldKit.mesa,
	building = WorldKit.building,
	streetLight = WorldKit.streetLight,
	billboard = WorldKit.billboard,
	snowBank = WorldKit.snowBank,
	iceSheet = WorldKit.iceSheet,
	neonTower = WorldKit.neonTower,
	neonSign = WorldKit.neonSign,
	holoPylon = WorldKit.holoPylon,
	pond = WorldKit.pond,
	bridge = WorldKit.bridge,
}

function WorldKit.has(kind: string): boolean
	return BUILDERS[kind] ~= nil
end

function WorldKit.kinds(): { string }
	local list = {}
	for kind in pairs(BUILDERS) do
		list[#list + 1] = kind
	end
	table.sort(list)
	return list
end

function WorldKit.prop(parent: Instance, kind: string, position: Vector3, scale: number, colors, seed: number)
	local builder = BUILDERS[kind]
	if not builder then
		return nil
	end
	return builder(parent, position, scale, colors, seed)
end

return WorldKit
