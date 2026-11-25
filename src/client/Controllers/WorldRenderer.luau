--!nonstrict
-- Zone rendering: the road, its markings, and one world's scenery — built from the server's ChunkDef.
--
-- Run scenery is client-built on purpose. The server never creates a Part for a run, which keeps
-- server cost flat however many players are crossing (docs/02 §8). A client that deletes its own
-- roads gains nothing: the server judges collision from the same ChunkDef.
--
-- Phase 4 makes this world-driven. Everything visual comes from `WorldConfig`:
--   * `road.surface` picks the road material (asphalt, worn asphalt, ice, wet).
--   * `road.markings` picks the markings (edge, crosswalk, dashed, glow).
--   * `style` picks the median treatment (grass, pavement, sand, snow, plating).
--   * `props` supplies the scenery band, density and weighted prop kinds.
--   * `collectible.kind` skins the pickup without changing its value.
--
-- Scenery placement is a pure hash of (row, attempt), never the server RNG: every client in a world
-- builds the same tree at the same row without a byte of network traffic, and the generator's
-- deterministic lane data is untouched.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local WorldConfig = require(Shared.Config.WorldConfig)
local HazardConfig = require(Shared.Config.HazardConfig)
local ObstacleSim = require(Shared.Simulation.ObstacleSim)
local WorldKit = require(Shared.World.WorldKit)

local SessionController = require(script.Parent.SessionController)

local WorldRenderer = {}

local ROAD_WIDTH = GameConfig.WORLD_HALF_WIDTH * 2
local EDGE_X = 32.4
local MAX_PROPS_PER_CHUNK = GameConfig.MAX_PROPS_PER_CHUNK
local BRIDGE_VARIANT = { snow = "ice" }

local root = nil
local rowsFolder = nil

local chunks = {}
local acorns = {}
local wildlife = {}
local origin = Vector3.zero
local world = WorldConfig.get(WorldConfig.DEFAULT)
local clockAccumulator = 0

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
	part.Parent = props.parent
	return part
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Surface material for a world's road. Kept tiny and explicit: a typo here is a visible hole.
local ROAD_MATERIALS = {
	asphalt = Enum.Material.Asphalt,
	asphaltWorn = Enum.Material.Asphalt,
	ice = Enum.Material.Ice,
	wet = Enum.Material.SmoothPlastic,
}

local MEDIAN_MATERIALS = {
	forest = Enum.Material.Grass,
	urban = Enum.Material.Concrete,
	desert = Enum.Material.Sand,
	snow = Enum.Material.Snow,
	neon = Enum.Material.SmoothPlastic,
}

local function medianColor(row: number): Color3
	local colors = world.colors
	if world.style == "forest" then
		return row % 2 == 0 and colors.grass or colors.grassDark
	elseif world.style == "urban" then
		return colors.concrete
	elseif world.style == "desert" then
		return row % 2 == 0 and colors.sand or colors.grassDark
	elseif world.style == "snow" then
		return row % 2 == 0 and colors.snow or colors.grassDark
	end
	return colors.grassDark
end

-- Markings -----------------------------------------------------------------------------------------

local function buildEdgeLines(parent: Instance, z: number, color: Color3, material: Enum.Material)
	for _, side in ipairs({ -1, 1 }) do
		makePart({
			name = "EdgeLine",
			size = Vector3.new(0.45, 0.1, GameConfig.TILE),
			cframe = CFrame.new(origin.X + side * EDGE_X, 0.04, z),
			color = color,
			material = material,
			parent = parent,
		})
	end
end

local function buildMarkings(parent: Instance, rowDef, z: number)
	local markings = (world.road and world.road.markings) or "edge"
	local colors = world.colors

	if markings == "glow" then
		buildEdgeLines(parent, z, colors.line, Enum.Material.Neon)
		return
	elseif markings == "edge" then
		buildEdgeLines(parent, z, colors.line, Enum.Material.SmoothPlastic)
		return
	elseif markings == "dashed" then
		buildEdgeLines(parent, z, colors.line, Enum.Material.SmoothPlastic)
		if rowDef.row % 2 == 0 then
			makePart({
				name = "CentreDash",
				size = Vector3.new(6, 0.1, 0.5),
				cframe = CFrame.new(origin.X, 0.05, z),
				color = colors.line,
				parent = parent,
			})
		end
		return
	elseif markings == "crosswalk" then
		buildEdgeLines(parent, z, colors.line, Enum.Material.SmoothPlastic)
		-- Kerb stripes across the carriageway: cheap, and unmistakably a city street.
		for bar = -3, 3 do
			makePart({
				name = "Crosswalk",
				size = Vector3.new(3.2, 0.1, 0.9),
				cframe = CFrame.new(origin.X + bar * 8, 0.05, z + 1.2),
				color = colors.line,
				parent = parent,
			})
		end
		return
	end

	buildEdgeLines(parent, z, colors.line, Enum.Material.SmoothPlastic)
end

-- Rows ---------------------------------------------------------------------------------------------

local function buildRow(parent: Instance, rowDef)
	local z = origin.Z - rowDef.row * GameConfig.TILE
	local isRoad = rowDef.kind == "road"
	local isRail = rowDef.kind == "rail"
	local colors = world.colors

	local surfaceColor = medianColor(rowDef.row)
	local material = MEDIAN_MATERIALS[world.style] or Enum.Material.Grass

	if isRail then
		surfaceColor = HazardConfig.rail.colors.gravel
		material = Enum.Material.Slate
	elseif isRoad then
		surfaceColor = colors.road
		material = ROAD_MATERIALS[(world.road and world.road.surface) or "asphalt"] or Enum.Material.Asphalt
	end

	makePart({
		name = isRail and "RailBed" or (isRoad and "Road" or "Ground"),
		size = Vector3.new(ROAD_WIDTH, 0.6, GameConfig.TILE),
		cframe = CFrame.new(origin.X, -0.3, z),
		color = surfaceColor,
		material = material,
		parent = parent,
	})

	if isRoad then
		buildMarkings(parent, rowDef, z)
	elseif isRail then
		for _, side in ipairs({ -1, 1 }) do
			makePart({
				name = "Rail",
				size = Vector3.new(0.5, 0.22, GameConfig.TILE),
				cframe = CFrame.new(origin.X + side * 3.2, 0.06, z),
				color = HazardConfig.rail.colors.rail,
				material = Enum.Material.Metal,
				parent = parent,
			})
		end
		for sleeper = -1, 1 do
			makePart({
				name = "Sleeper",
				size = Vector3.new(9, 0.16, 0.9),
				cframe = CFrame.new(origin.X, 0.02, z + sleeper * 1.3),
				color = HazardConfig.rail.colors.sleeper,
				material = Enum.Material.Wood,
				parent = parent,
			})
		end
	else
		-- A kerb strip either side of a median, so the road edge reads as a road edge.
		if world.style == "urban" or world.style == "neon" then
			for _, side in ipairs({ -1, 1 }) do
				makePart({
					name = "Kerb",
					size = Vector3.new(1.2, 0.9, GameConfig.TILE),
					cframe = CFrame.new(origin.X + side * (EDGE_X + 0.9), 0.15, z),
					color = world.style == "neon" and colors.roadDark or colors.kerb,
					material = Enum.Material.Concrete,
					parent = parent,
				})
			end
		end
	end
end

-- Scenery ------------------------------------------------------------------------------------------

local function pickKind(row: number, attempt: number, kinds)
	local total = 0
	for _, kind in ipairs(kinds) do
		total += kind.weight
	end
	if total <= 0 then
		return nil
	end

	local roll = WorldKit.hash(row * 3 + attempt, 41) * total
	local accumulator = 0
	for _, kind in ipairs(kinds) do
		accumulator += kind.weight
		if roll <= accumulator then
			return kind
		end
	end
	return kinds[#kinds]
end

local function buildProps(parent: Instance, chunk)
	local props = world.props
	if not props or props.perRow <= 0 then
		return
	end

	local built = 0

	for _, rowDef in ipairs(chunk.rows) do
		if built >= MAX_PROPS_PER_CHUNK then
			break
		end

		for attempt = 1, props.perRow do
			if built >= MAX_PROPS_PER_CHUNK then
				break
			end

			local densityRoll = WorldKit.hash(rowDef.row * 7 + attempt, 11)
			if densityRoll < props.density then
				local kind = pickKind(rowDef.row, attempt, props.kinds)
				if kind and WorldKit.has(kind.id) then
					local side = WorldKit.hash(rowDef.row, attempt * 3) > 0.5 and 1 or -1
					-- A bridge only reads where there is ground to span, so it is kept off road rows.
					local allowed = kind.id ~= "bridge" or rowDef.kind == "median"

					if allowed then
						local distance = lerp(props.bandMin, props.bandMax, WorldKit.hash(rowDef.row * 13 + attempt, 17))
						local jitter = (WorldKit.hash(rowDef.row, attempt) - 0.5) * GameConfig.TILE * 1.6
						local scale = lerp(kind.scaleMin or 1, kind.scaleMax or 1, WorldKit.hash(rowDef.row, attempt * 5))
						local position = Vector3.new(origin.X + side * distance, 0, origin.Z - rowDef.row * GameConfig.TILE + jitter)

						local model
						if kind.id == "bridge" then
							model = WorldKit.bridge(parent, position, scale, world.colors, rowDef.row, BRIDGE_VARIANT[world.style])
						else
							model = WorldKit.prop(parent, kind.id, position, scale, world.colors, rowDef.row * 31 + attempt)
						end

						if model then
							model.Name = kind.id .. "_" .. tostring(rowDef.row)
							built += 1
						end
					end
				end
			end
		end
	end
end

-- Obstacles and collectibles -----------------------------------------------------------------------

local function buildBarrier(parent: Instance, obstacle)
	local position = Vector3.new(
		origin.X + obstacle.col * GameConfig.TILE,
		0,
		origin.Z - obstacle.row * GameConfig.TILE
	)
	WorldKit.barrier(parent, position, world.colors)
end

local function buildWildlife(parent: Instance, obstacle)
	local position = Vector3.new(
		origin.X + ObstacleSim.wildlifeX(obstacle, 0),
		0,
		origin.Z - obstacle.row * GameConfig.TILE
	)

	local color = HazardConfig.wildlife.colors[obstacle.species] or Color3.fromRGB(150, 120, 90)
	local model = WorldKit.wildlife(parent, obstacle, color)
	model:PivotTo(CFrame.new(position))
	model.Parent = parent

	return model
end

local function buildAcorn(parent: Instance, collectible)
	local z = origin.Z - collectible.row * GameConfig.TILE
	local x = origin.X + collectible.col * GameConfig.TILE

	local kind = (world.collectible and world.collectible.kind) or "acorn"
	local model = WorldKit.collectible(parent, kind, world.colors)
	model.Name = "Collectible_" .. collectible.id

	local base = CFrame.new(x, 1.7, z)
	model:PivotTo(base)
	-- Parented to the chunk folder so recycling a chunk disposes of its collectibles with it.
	model.Parent = parent

	acorns[collectible.id] = { model = model, base = base }
end

local function ensureRoot()
	if root then
		root:Destroy()
	end

	root = Instance.new("Folder")
	root.Name = "RunZone"
	root.Parent = Workspace

	rowsFolder = Instance.new("Folder")
	rowsFolder.Name = "Rows"
	rowsFolder.Parent = root
end

function WorldRenderer.init() end

function WorldRenderer.start()
	SessionController.signals.runStarted:Connect(function(payload)
		origin = payload.origin
		world = WorldConfig.get(payload.worldId)
		chunks = {}
		acorns = {}
		wildlife = {}
		clockAccumulator = 0
		ensureRoot()
	end)

	SessionController.signals.chunkAdded:Connect(function(chunk)
		if not root then
			return
		end

		local chunkFolder = Instance.new("Folder")
		chunkFolder.Name = "Chunk_" .. tostring(chunk.index)
		chunkFolder.Parent = rowsFolder

		for _, rowDef in ipairs(chunk.rows) do
			buildRow(chunkFolder, rowDef)
		end

		buildProps(chunkFolder, chunk)

		for _, obstacle in ipairs(chunk.obstacles or {}) do
			if obstacle.kind == "barrier" then
				buildBarrier(chunkFolder, obstacle)
			elseif obstacle.kind == "wildlife" then
				local model = buildWildlife(chunkFolder, obstacle)
				wildlife[#wildlife + 1] = { obstacle = obstacle, model = model }
			end
		end

		for _, collectible in ipairs(chunk.collectibles) do
			buildAcorn(chunkFolder, collectible)
		end

		chunks[chunk.index] = {
			folder = chunkFolder,
			startRow = chunk.startRow,
			rowCount = chunk.rowCount,
		}
	end)

	SessionController.signals.pickup:Connect(function(payload)
		if payload.id then
			WorldRenderer.removeCollectible(payload.id)
		end
	end)

	SessionController.signals.returnedToLobby:Connect(function()
		chunks = {}
		acorns = {}
		wildlife = {}
		if root then
			root:Destroy()
			root = nil
		end
	end)
end

function WorldRenderer.removeCollectible(id: string)
	local entry = acorns[id]
	if not entry then
		return
	end
	acorns[id] = nil
	entry.model:Destroy()
end

function WorldRenderer.update(dt: number)
	if not root then
		return
	end

	clockAccumulator += dt
	local bob = math.sin(clockAccumulator * 2.2) * 0.22

	for id, entry in pairs(acorns) do
		if not entry.model.Parent then
			acorns[id] = nil
		else
			entry.model:PivotTo(entry.base * CFrame.Angles(0, clockAccumulator * 2.1, 0) * CFrame.new(0, bob, 0))
		end
	end

	-- Wildlife positions are a closed-form function of elapsed time, exactly as on the server.
	local elapsed = SessionController.elapsed()
	local kept = {}
	for _, entry in ipairs(wildlife) do
		if entry.model.Parent then
			local x = origin.X + ObstacleSim.wildlifeX(entry.obstacle, elapsed)
			local z = origin.Z - entry.obstacle.row * GameConfig.TILE
			entry.model:PivotTo(CFrame.new(x, 0, z) * CFrame.Angles(0, entry.obstacle.dir > 0 and 0 or math.pi, 0))
			kept[#kept + 1] = entry
		end
	end
	wildlife = kept

	-- Recycle chunks that are well behind the player.
	local playerRow = SessionController.state.row
	for index, entry in pairs(chunks) do
		if entry.startRow + entry.rowCount < playerRow - GameConfig.CHUNK_RECYCLE_BEHIND then
			entry.folder:Destroy()
			chunks[index] = nil
		end
	end
end

-- The world currently being rendered. Read by the environment and effects controllers so lighting,
-- ambience and scenery can never disagree about which world is on screen.
function WorldRenderer.getWorld()
	return world
end

return WorldRenderer
