--!nonstrict
-- Lobby nameplates: the player's display name plus the animal they are wearing.
--
-- Server-built because these hang above server-owned presence models, so they replicate for free
-- and cost no per-frame work.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local AnimalConfig = require(Shared.Config.AnimalConfig)

local NameplateBuilder = {}

function NameplateBuilder.build(config): BillboardGui
	local animal = AnimalConfig.get(config.animalId or "deer")
	local rarity = AnimalConfig.RARITY[animal.rarity] or AnimalConfig.RARITY.Common

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Nameplate"
	billboard.Size = UDim2.fromOffset(220, 64)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, config.height or 4, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 120
	billboard.Parent = config.parent

	local name = Instance.new("TextLabel")
	name.Name = "PlayerName"
	name.Size = UDim2.new(1, 0, 0.58, 0)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBold
	name.Text = config.displayName or "Player"
	name.TextColor3 = Color3.fromRGB(255, 246, 228)
	name.TextScaled = true
	name.Parent = billboard

	local animalLabel = Instance.new("TextLabel")
	animalLabel.Name = "AnimalName"
	animalLabel.Size = UDim2.new(1, 0, 0.4, 0)
	animalLabel.Position = UDim2.new(0, 0, 0.6, 0)
	animalLabel.BackgroundTransparency = 1
	animalLabel.Font = Enum.Font.GothamMedium
	animalLabel.Text = animal.name
	animalLabel.TextColor3 = rarity.color
	animalLabel.TextScaled = true
	animalLabel.Parent = billboard

	return billboard
end

function NameplateBuilder.update(billboard: BillboardGui, animalId: string, displayName: string?)
	local animal = AnimalConfig.get(animalId)
	local rarity = AnimalConfig.RARITY[animal.rarity] or AnimalConfig.RARITY.Common

	local animalLabel = billboard:FindFirstChild("AnimalName")
	if animalLabel and animalLabel:IsA("TextLabel") then
		animalLabel.Text = animal.name
		animalLabel.TextColor3 = rarity.color
	end

	if displayName then
		local name = billboard:FindFirstChild("PlayerName")
		if name and name:IsA("TextLabel") then
			name.Text = displayName
		end
	end
end

return NameplateBuilder
