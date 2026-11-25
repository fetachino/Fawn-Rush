--!nonstrict
-- Lobby presence: every player in the server stands in the shared clearing with their animal and a
-- nameplate, while their run (if any) happens in their own private strip. This is the whole of the
-- multiplayer lobby requirement and it costs no per-frame networking: models are server-owned,
-- static, and replicate once.
--
-- Run isolation is unchanged from Phase 2 — presence is decoration plus identity, never gameplay.
--
-- The animal shown is the one the player has equipped. Equipping arrives with the collection in
-- Phase 7; until then every player wears the deer, and PresenceService.setAnimal() is the hook that
-- phase will call.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldConfig = require(Shared.Config.WorldConfig)
local AnimalBuilder = require(Shared.Builders.AnimalBuilder)

local NameplateBuilder = require(script.Parent.NameplateBuilder)
local RunService = require(script.Parent.Services.RunService)

local PresenceService = {}

local SLOT_RADIUS = 15
local SLOT_START_ANGLE = -math.pi * 0.75

local folder = nil
local entries = {} -- [player] = { rig, nameplate, slot, inRun }

local function slotPosition(slot: number): Vector3
	local lobby = WorldConfig.get(WorldConfig.DEFAULT).lobbySpawn
	local angle = SLOT_START_ANGLE + (slot - 1) * 0.55
	return lobby + Vector3.new(math.cos(angle) * SLOT_RADIUS, 0, math.sin(angle) * SLOT_RADIUS)
end

local function nextSlot(): number
	local used = {}
	for _, entry in pairs(entries) do
		used[entry.slot] = true
	end
	local slot = 1
	while used[slot] do
		slot += 1
	end
	return slot
end

-- `slot` is optional: a fresh player takes the next free ring position, while a rebuild after an
-- animal change must keep the position it already had (passing it explicitly avoids the drift the
-- old code had, where the model was pivoted to one slot and the entry recorded another).
local function buildPresence(player, slot: number?)
	local animalId = player:GetAttribute("AnimalId") or "deer"

	-- Decorative rigs may number one per player; dynamic lights are omitted so a full lobby does not
	-- pay a per-frame lighting cost. The local player's own rig is built by the client and keeps its.
	local rig = AnimalBuilder.buildRig(animalId, { lights = false })
	local assignedSlot = slot or nextSlot()
	local position = slotPosition(assignedSlot)

	rig.model:PivotTo(CFrame.new(position))
	AnimalBuilder.applyRestPose(rig)

	-- Ownership is declared as data, not implied by the model's name. Every client reads these two
	-- attributes through PresenceRules to decide whether it may draw the model (docs/12 S3).
	rig.model:SetAttribute("OwnerUserId", player.UserId)
	rig.model:SetAttribute("InRun", false)

	rig.model.Parent = folder

	local head = rig.joints.Head and rig.joints.Head.part or rig.root
	local nameplate = NameplateBuilder.build({
		parent = head,
		displayName = player.DisplayName,
		animalId = animalId,
		height = math.max(3, rig.height + 1.2),
	})

	entries[player] = {
		rig = rig,
		nameplate = nameplate,
		slot = assignedSlot,
		inRun = false,
		animalId = animalId,
	}
end

local function destroyPresence(player)
	local entry = entries[player]
	if not entry then
		return
	end
	if entry.nameplate then
		entry.nameplate:Destroy()
	end
	if entry.rig and entry.rig.model then
		entry.rig.model:Destroy()
	end
	entries[player] = nil
end

-- Hides a player's lobby double while they are running, and shows it again when they return.
--
-- This sets an attribute rather than re-parenting: the server owning the model's Parent would fight
-- the client-side hiding of the owner's own copy. Keeping Parent stable on the server is what makes
-- the ownership rule reliable.
local function setVisible(player, visible: boolean)
	local entry = entries[player]
	if not entry or not entry.rig then
		return
	end
	entry.inRun = not visible
	entry.rig.model:SetAttribute("InRun", not visible)
end

function PresenceService.init()
	local existing = Workspace:FindFirstChild("LobbyPresence")
	if existing then
		existing:Destroy()
	end

	folder = Instance.new("Folder")
	folder.Name = "LobbyPresence"
	folder.Parent = Workspace
end

function PresenceService.start()
	local function onPlayerAdded(player)
		if not entries[player] then
			buildPresence(player)
		end
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		destroyPresence(player)
	end)

	RunService.events.runStarted:Connect(function(player)
		setVisible(player, false)
	end)

	RunService.events.runEnded:Connect(function(player)
		setVisible(player, true)
	end)

	-- Phase 7 calls this when the equipped animal changes.
	game:GetService("ReplicatedStorage").SetAttribute("PresenceReady", true)
end

-- Rebuilds one player's lobby model. Safe to call before the player has presence.
function PresenceService.setAnimal(player, animalId: string)
	local entry = entries[player]
	if not entry then
		return
	end

	if entry.animalId == animalId then
		return
	end

	local wasVisible = not entry.inRun
	local slot = entry.slot
	destroyPresence(player)
	player:SetAttribute("AnimalId", animalId)
	-- Rebuilt into the same ring position rather than whatever slot is free now.
	buildPresence(player, slot)

	if not wasVisible then
		setVisible(player, false)
	end
end

function PresenceService.inRun(player): boolean
	local entry = entries[player]
	return entry ~= nil and entry.inRun
end

return PresenceService
