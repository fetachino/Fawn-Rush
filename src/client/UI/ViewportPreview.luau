--!nonstrict
-- One reusable, budgeted ViewportFrame preview. Models come from the shared procedural rig builder;
-- no uploaded mesh or image id is assumed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AnimalBuilder = require(Shared.Builders.AnimalBuilder)
local AnimalConfig = require(Shared.Config.AnimalConfig)
local UIConfig = require(Shared.Config.UIConfig)
local PreviewBudget = require(Shared.Util.PreviewBudget)
local Theme = require(script.Parent.Theme)

local ViewportPreview = {}
local previewBudget = PreviewBudget.new(UIConfig.preview.maxLiveModels)
ViewportPreview.activeCount = 0
ViewportPreview.MAX_LIVE_MODELS = UIConfig.preview.maxLiveModels

local function buildRig(animalId: string)
	local rig = nil
	local ok = pcall(function()
		rig = AnimalBuilder.buildRig(animalId, { lights = false })
		AnimalBuilder.applyRestPose(rig)
	end)
	if not ok then
		if rig and rig.model then
			rig.model:Destroy()
		end
		return nil
	end
	return rig
end

local function frameCamera(camera: Camera, model: Model)
	local bounds, size = model:GetBoundingBox()
	local centerY = bounds.Position.Y + size.Y * 0.42
	local distance = math.max(size.X, size.Y, size.Z) * 2.2 + 1.5
	camera.CFrame = CFrame.lookAt(
		Vector3.new(0, centerY + size.Y * 0.05, -distance),
		Vector3.new(0, centerY, 0)
	)
end

function ViewportPreview.create(parent: Instance, animalId: string, options): any
	if not AnimalConfig.animals[animalId] then
		return nil, "Unknown animal"
	end

	local lease, budgetError = previewBudget:acquire()
	if not lease then
		return nil, budgetError
	end

	local rig = buildRig(animalId)
	if not rig then
		lease.release()
		return nil, "Animal preview unavailable"
	end

	local viewport = nil
	local worldModel = nil
	local camera = nil
	local setupOk = pcall(function()
		viewport = Instance.new("ViewportFrame")
		viewport.Name = options and options.name or "AnimalPreview"
		viewport.Size = options and options.size or UDim2.fromScale(1, 1)
		viewport.Position = options and options.position or UDim2.fromScale(0, 0)
		viewport.BackgroundColor3 = Theme.colors.surface1
		viewport.BackgroundTransparency = 0
		viewport.BorderSizePixel = 0
		viewport.Active = true
		viewport.Ambient = Theme.colors.inkMid
		viewport.LightColor = Theme.colors.white
		viewport.LightDirection = Vector3.new(-1, -1, -1)
		viewport.Parent = parent
		Instance.new("UICorner", viewport).CornerRadius = UDim.new(0, Theme.radius.md)

		worldModel = Instance.new("WorldModel")
		worldModel.Parent = viewport
		rig.model.Parent = worldModel

		camera = Instance.new("Camera")
		camera.FieldOfView = 32
		camera.Parent = viewport
		viewport.CurrentCamera = camera
		frameCamera(camera, rig.model)
	end)
	if not setupOk then
		if viewport then
			viewport:Destroy()
		end
		rig.model:Destroy()
		lease.release()
		ViewportPreview.activeCount = previewBudget:count()
		return nil, "Animal preview unavailable"
	end

	ViewportPreview.activeCount = previewBudget:count()
	local released = false
	local dragInput = nil
	local lastX = nil
	local rotation = 0
	local connections = {}

	local function rotateTo(inputX: number)
		if lastX then
			rotation += (inputX - lastX) * 0.012
			rig.model:PivotTo(CFrame.new(0, 0, 0) * CFrame.Angles(0, rotation, 0))
		end
		lastX = inputX
	end

	local inputSetupOk = pcall(function()
		connections[#connections + 1] = viewport.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragInput = input
				lastX = input.Position.X
			end
		end)
		connections[#connections + 1] = viewport.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement and dragInput then
				rotateTo(input.Position.X)
			end
		end)
		connections[#connections + 1] = UserInputService.InputChanged:Connect(function(input)
			if input == dragInput and input.UserInputType == Enum.UserInputType.Touch then
				rotateTo(input.Position.X)
			end
		end)
		connections[#connections + 1] = UserInputService.InputEnded:Connect(function(input)
			if input == dragInput or input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragInput = nil
				lastX = nil
			end
		end)
	end)
	if not inputSetupOk then
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
		viewport:Destroy()
		lease.release()
		ViewportPreview.activeCount = previewBudget:count()
		return nil, "Animal preview unavailable"
	end

	local api = {
		instance = viewport,
		animalId = animalId,
		released = false,
	}

	function api.setAnimal(nextAnimalId: string): boolean
		if released or not AnimalConfig.animals[nextAnimalId] then
			return false
		end
		if nextAnimalId == api.animalId then
			return true
		end

		local nextRig = buildRig(nextAnimalId)
		if not nextRig then
			return false
		end
		local framed = pcall(function()
			nextRig.model.Parent = worldModel
			frameCamera(camera, nextRig.model)
		end)
		if not framed then
			nextRig.model:Destroy()
			return false
		end
		rig.model:Destroy()
		rig = nextRig
		api.animalId = nextAnimalId
		rotation = 0
		return true
	end

	function api.release()
		if released then
			return
		end
		released = true
		api.released = true
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
		table.clear(connections)
		viewport:Destroy()
		lease.release()
		ViewportPreview.activeCount = previewBudget:count()
	end

	connections[#connections + 1] = viewport.AncestryChanged:Connect(function(_, newParent)
		if newParent == nil then
			api.release()
		end
	end)

	return api
end

function ViewportPreview.getActiveCount(): number
	return previewBudget:count()
end

return ViewportPreview
