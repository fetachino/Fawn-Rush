--!nonstrict
-- PresenceController: decides which of the server's lobby models this client draws.
--
-- The server builds one stationary animal per player into `Workspace.LobbyPresence` and tags it with
-- two attributes: `OwnerUserId` and `InRun`. It never re-parents anything, so a client that hides a
-- model locally keeps it hidden.
--
-- This controller applies `PresenceRules` to every child of that folder. Its only job is to stop the
-- owning player from seeing their own model twice — once from the server, once from their own
-- locally-built rig. See docs/12_STUDIO_HANDOFF.md S3.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PresenceRules = require(Shared.Simulation.PresenceRules)
local Logger = require(Shared.Util.Logger)

local PresenceController = {}

local FOLDER_NAME = "LobbyPresence"
local OWNER_ATTRIBUTE = "OwnerUserId"
local IN_RUN_ATTRIBUTE = "InRun"
local FOLDER_TIMEOUT = 15

local folder = nil
local localUserId = 0
local watched = {} -- [model] = true

-- Puts a model in the folder, or takes it out of the DataModel on this client only.
local function applyVisibility(model: Instance)
	if not folder or not model:IsA("Model") then
		return
	end

	local show = PresenceRules.shouldRender(
		model:GetAttribute(OWNER_ATTRIBUTE),
		model:GetAttribute(IN_RUN_ATTRIBUTE),
		localUserId
	)

	local target = show and folder or nil
	if model.Parent ~= target then
		model.Parent = target
	end
end

local function watch(model: Instance)
	if not model:IsA("Model") or watched[model] then
		return
	end
	watched[model] = true

	-- The server changes only these two attributes, so these are the only signals worth connecting.
	model:GetAttributeChangedSignal(OWNER_ATTRIBUTE):Connect(function()
		applyVisibility(model)
	end)
	model:GetAttributeChangedSignal(IN_RUN_ATTRIBUTE):Connect(function()
		applyVisibility(model)
	end)

	model.Destroying:Connect(function()
		watched[model] = nil
	end)

	applyVisibility(model)
end

function PresenceController.init()
	local player = Players.LocalPlayer
	localUserId = player and player.UserId or 0
end

function PresenceController.start()
	task.spawn(function()
		local found = Workspace:WaitForChild(FOLDER_NAME, FOLDER_TIMEOUT)
		if not found then
			Logger.warn("Presence", "LobbyPresence never appeared; presence filtering is inactive")
			return
		end

		folder = found

		-- Models that replicated before this controller started.
		for _, child in ipairs(folder:GetChildren()) do
			watch(child)
		end

		folder.ChildAdded:Connect(watch)
	end)
end

function PresenceController.update() end

return PresenceController
