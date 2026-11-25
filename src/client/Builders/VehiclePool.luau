--!nonstrict
-- Vehicle model pool.
--
-- Vehicles are purely visual on the client: the server never creates a Part for traffic and the
-- client cannot gain anything by lying about one, because collision is judged server-side from
-- the same closed-form lane data. Models are built once per type and recycled by index, so a
-- steady-state frame allocates nothing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.GameConfig)

local VehiclePool = {}

local folder = nil
local pools = {} -- [type] = { Model }
local activeCount = {} -- [type] = number
local totalModels = 0

local function buildPart(props): Part
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
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CastShadow = false
	part.Parent = props.parent
	return part
end

local function buildVehicle(vehicleType: string): Model
	local def = GameConfig.VEHICLES[vehicleType]
	local length = def.lengthTiles * GameConfig.TILE
	local width = def.halfWidth * 2

	local model = Instance.new("Model")
	model.Name = "Vehicle_" .. vehicleType

	local body = buildPart({
		name = "Body",
		size = Vector3.new(length, def.height * 0.72, width),
		cframe = CFrame.new(0, def.height * 0.46, 0),
		color = def.color,
		parent = model,
	})

	buildPart({
		name = "Cabin",
		size = Vector3.new(length * 0.44, def.height * 0.5, width * 0.86),
		cframe = CFrame.new(length * 0.06, def.height * 0.95, 0),
		color = def.color:Lerp(Color3.new(0.12, 0.14, 0.18), 0.45),
		parent = model,
	})

	buildPart({
		name = "Skirt",
		size = Vector3.new(length * 0.92, def.height * 0.18, width * 0.94),
		cframe = CFrame.new(0, def.height * 0.13, 0),
		color = Color3.fromRGB(38, 40, 46),
		material = Enum.Material.SmoothPlastic,
		parent = model,
	})

	-- Per-archetype silhouette details. Each one has to be recognisable at a glance, at speed, on a
	-- phone screen, so the differences are shape and proportion rather than colour alone.
	if vehicleType == "bus" then
		buildPart({
			name = "WindowBand",
			size = Vector3.new(length * 0.86, def.height * 0.26, width * 1.02),
			cframe = CFrame.new(0, def.height * 0.86, 0),
			color = Color3.fromRGB(58, 78, 92),
			parent = model,
		})
	elseif vehicleType == "motorcycle" then
		buildPart({
			name = "Rider",
			size = Vector3.new(0.5, 1.5, 0.6),
			cframe = CFrame.new(-0.1, def.height * 1.15, 0),
			color = Color3.fromRGB(58, 58, 66),
			parent = model,
		})
	elseif vehicleType == "train" then
		for segment = 0, 2 do
			buildPart({
				name = "Segment" .. segment,
				size = Vector3.new(length * 0.26, def.height * 0.34, width * 1.04),
				cframe = CFrame.new(-length * 0.28 + segment * length * 0.28, def.height * 0.72, 0),
				color = Color3.fromRGB(200, 208, 216),
				parent = model,
			})
		end
	elseif vehicleType == "truck" then
		buildPart({
			name = "Bed",
			size = Vector3.new(length * 0.4, def.height * 0.22, width * 0.92),
			cframe = CFrame.new(length * 0.24, def.height * 0.86, 0),
			color = def.color:Lerp(Color3.new(0, 0, 0), 0.35),
			parent = model,
		})
	end

	model.PrimaryPart = body
	model.WorldPivot = CFrame.new(0, 0, 0)

	return model
end

function VehiclePool.init(parent: Instance)
	folder = Instance.new("Folder")
	folder.Name = "Traffic"
	folder.Parent = parent
	pools = {}
	activeCount = {}
	totalModels = 0
end

function VehiclePool.beginFrame()
	activeCount = {}
end

-- Place one vehicle. Builds lazily until VEHICLE_POOL_MAX models exist, then silently drops.
function VehiclePool.place(vehicleType: string, groundPosition: Vector3, dir: number)
	local pool = pools[vehicleType]
	if not pool then
		pool = {}
		pools[vehicleType] = pool
	end

	local index = (activeCount[vehicleType] or 0) + 1
	activeCount[vehicleType] = index

	local model = pool[index]
	if not model then
		if totalModels >= GameConfig.VEHICLE_POOL_MAX then
			return
		end
		model = buildVehicle(vehicleType)
		pool[index] = model
		totalModels += 1
	end

	local yaw = dir > 0 and 0 or math.pi
	model:PivotTo(CFrame.new(groundPosition) * CFrame.Angles(0, yaw, 0))

	if model.Parent ~= folder then
		model.Parent = folder
	end
end

function VehiclePool.endFrame()
	for vehicleType, pool in pairs(pools) do
		local used = activeCount[vehicleType] or 0
		for index = used + 1, #pool do
			local model = pool[index]
			if model.Parent then
				model.Parent = nil
			end
		end
	end
end

function VehiclePool.clear()
	activeCount = {}
	for _, pool in pairs(pools) do
		for _, model in ipairs(pool) do
			model.Parent = nil
		end
	end
end

return VehiclePool
