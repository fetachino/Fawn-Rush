--!nonstrict
-- The shared starting lobby: a small forest clearing every player stands in before a run.
-- Built once at boot from code, not authored by hand in Studio.
--
-- Phase 4 moved the scenery primitives into `shared/World/WorldKit`, so the lobby's trees are the
-- same trees Greenwood's run uses, and both inherit the same eventual Blender replacement.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldConfig = require(Shared.Config.WorldConfig)
local WorldKit = require(Shared.World.WorldKit)

local LobbyBuilder = {}

local world = WorldConfig.get(WorldConfig.DEFAULT)
local colors = world.colors

local function part(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance, shape): BasePart
	local instance = Instance.new("Part")
	instance.Name = name
	instance.Size = size
	instance.CFrame = cframe
	instance.Color = color
	instance.Anchored = true
	instance.CanCollide = false
	instance.CanQuery = false
	instance.TopSurface = Enum.SurfaceType.Smooth
	instance.BottomSurface = Enum.SurfaceType.Smooth
	instance.Material = Enum.Material.Grass
	instance.CastShadow = true
	if shape then
		instance.Shape = shape
	end
	instance.Parent = parent
	return instance
end

local function buildSign(parent: Instance)
	local board = part("LobbySign", Vector3.new(26, 9, 1.2), CFrame.new(0, 13, -14), colors.trunk, parent)
	board.Material = Enum.Material.WoodPlanks

	for _, side in ipairs({ -1, 1 }) do
		local post = part("SignPost", Vector3.new(1.2, 10, 1.2), CFrame.new(side * 9, 5, -14), colors.trunk, parent)
		post.Material = Enum.Material.Wood
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "SignText"
	gui.Size = UDim2.fromOffset(620, 190)
	gui.StudsOffset = Vector3.new(0, 0, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 300
	gui.Parent = board

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.Text = "FAWN  RUSH"
	label.TextColor3 = Color3.fromRGB(255, 246, 228)
	label.TextScaled = true
	label.Parent = gui

	local subtitle = Instance.new("TextLabel")
	subtitle.Size = UDim2.fromScale(1, 0.34)
	subtitle.Position = UDim2.fromScale(0, 0.74)
	subtitle.BackgroundTransparency = 1
	subtitle.Font = Enum.Font.GothamMedium
	subtitle.Text = "every crossing is a new adventure"
	subtitle.TextColor3 = colors.accent
	subtitle.TextScaled = true
	subtitle.Parent = gui
end

function LobbyBuilder.init()
	-- Strip the default place furniture so the lobby is the only thing in the world.
	for _, child in ipairs(Workspace:GetChildren()) do
		if child.Name == "Baseplate" or child:IsA("SpawnLocation") then
			child:Destroy()
		end
	end

	local existing = Workspace:FindFirstChild("Lobby")
	if existing then
		existing:Destroy()
	end

	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"
	lobby.Parent = Workspace

	part("Clearing", Vector3.new(200, 2, 220), CFrame.new(0, -1, 10), colors.grass, lobby)

	part("Path", Vector3.new(30, 0.4, 150), CFrame.new(0, 0.1, 10), colors.grassDark, lobby).Material =
		Enum.Material.Ground

	part("StartLine", Vector3.new(72, 0.3, 3), CFrame.new(0, 0.15, 0), colors.line, lobby).Material =
		Enum.Material.SmoothPlastic

	buildSign(lobby)

	-- A ring of trees around the clearing, at fixed positions so the lobby is identical every visit.
	local treePositions = {
		{ -34, -18, 1.0 },
		{ 34, -18, 1.05 },
		{ -46, 6, 1.2 },
		{ 46, 6, 1.15 },
		{ -38, 30, 0.9 },
		{ 38, 30, 0.95 },
		{ -22, 46, 1.1 },
		{ 22, 46, 1.08 },
		{ 0, 58, 1.25 },
		{ -54, -6, 0.85 },
		{ 54, -6, 0.88 },
	}

	for index, entry in ipairs(treePositions) do
		WorldKit.tree(lobby, Vector3.new(entry[1], 0, entry[2]), entry[3], colors, index)
	end

	-- Rocks for silhouette variety.
	local rockPositions = {
		{ -26, 12, 3.4 },
		{ 29, -4, 2.6 },
		{ 18, 40, 2.2 },
		{ -20, -2, 1.8 },
	}

	for index, entry in ipairs(rockPositions) do
		WorldKit.rock(lobby, Vector3.new(entry[1], 0, entry[2]), entry[3] * 0.6, colors, index * 7)
	end

	-- Ground cover so the clearing is not a bare plane.
	for index = 1, 14 do
		local angle = (index / 14) * math.pi * 2
		local radius = 18 + (index % 4) * 6
		local position = Vector3.new(math.cos(angle) * radius, 0, 12 + math.sin(angle) * radius)
		if index % 3 == 0 then
			WorldKit.mushroom(lobby, position, 1, colors, index)
		else
			WorldKit.bush(lobby, position, 0.7, colors, index)
		end
	end

	-- WorldKit props are shadowless by default because run scenery can number in the hundreds. The
	-- lobby is one fixed scene, so it opts back in rather than losing the depth Phase 2 established.
	WorldKit.setShadows(lobby, true)
end

return LobbyBuilder
