--!nonstrict
-- Responsive home screen: one clear Play action, an actual roster preview and honest navigation shells.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldConfig = require(Shared.Config.WorldConfig)
local AnimalConfig = require(Shared.Config.AnimalConfig)

local Theme = require(script.Parent.Parent.Theme)
local Components = require(script.Parent.Parent.Components)
local ViewportPreview = require(script.Parent.Parent.ViewportPreview)

local LobbyScreen = {}

function LobbyScreen.create(parent: Instance, callbacks): any
	local frame = Instance.new("Frame")
	frame.Name = "LobbyScreen"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.Visible = false
	frame.Parent = parent

	local title = Components.label({
		name = "Title", parent = frame, text = "FAWN RUSH", font = Theme.fonts.black,
		textSize = Theme.type.display, color = Theme.colors.gold,
		position = UDim2.new(0.5, 0, 0.13, 0), anchor = Vector2.new(0.5, 0.5), size = UDim2.new(0.92, 0, 0, 64),
	})
	local subtitle = Components.label({
		name = "Subtitle", parent = frame, text = "Every crossing is a new adventure.", font = Theme.fonts.medium,
		textSize = Theme.type.body, color = Theme.colors.inkMid,
		position = UDim2.new(0.5, 0, 0.21, 0), anchor = Vector2.new(0.5, 0.5), size = UDim2.new(0.92, 0, 0, 32),
	})
	local previewHost = Instance.new("Frame")
	previewHost.Name = "PreviewHost"
	previewHost.Size = UDim2.new(0.42, 0, 0.36, 0)
	previewHost.Position = UDim2.new(0.5, 0, 0.43, 0)
	previewHost.AnchorPoint = Vector2.new(0.5, 0.5)
	previewHost.BackgroundTransparency = 1
	previewHost.Parent = frame
	local preview = nil
	local previewStatus = Components.label({
		name = "PreviewStatus", parent = previewHost, text = "", font = Theme.fonts.medium,
		textSize = Theme.type.small, color = Theme.colors.inkMid, wrapped = true,
		size = UDim2.fromScale(1, 1),
	})
	previewStatus.ZIndex = 2
	previewStatus.Visible = false
	local function ensurePreview()
		if not preview then
			local created, reason = ViewportPreview.create(previewHost, "deer")
			preview = created
			previewStatus.Visible = preview == nil
			previewStatus.Text = reason == "Preview limit reached"
				and "Close another preview to see the lobby animal."
				or "The lobby animal preview is temporarily unavailable."
		end
	end
	ensurePreview()
	local animal = AnimalConfig.get("deer")
	local nameplate = Components.label({
		name = "AnimalName", parent = frame, text = animal.name .. "  ·  " .. animal.personality,
		font = Theme.fonts.bold, textSize = Theme.type.small, color = Theme.colors.inkHigh,
		position = UDim2.new(0.5, 0, 0.64, 0), anchor = Vector2.new(0.5, 0.5), size = UDim2.new(0.92, 0, 0, 28),
	})
	local rarity = Components.rarityBadge({
		name = "AnimalRarity", parent = frame, rarity = animal.rarity,
		size = UDim2.fromOffset(132, 32), position = UDim2.new(0.5, 0, 0.69, 0), anchor = Vector2.new(0.5, 0.5),
	})

	local play = Components.button({
		name = "PlayButton", parent = frame, text = "P L A Y", variant = "primary",
		size = UDim2.new(0.64, 0, 0, 68), position = UDim2.new(0.5, 0, 0.82, 0), anchor = Vector2.new(0.5, 0.5),
		onClick = callbacks.onPlay,
	})
	local world = Components.button({
		name = "WorldSelectButton", parent = frame, text = "WORLDS", size = UDim2.new(0.25, 0, 0, 54),
		position = UDim2.new(0.18, 0, 0.94, 0), anchor = Vector2.new(0.5, 0.5), onClick = callbacks.onWorlds,
	})
	local collection = Components.button({
		name = "CollectionButton", parent = frame, text = "ANIMALS", size = UDim2.new(0.25, 0, 0, 54),
		position = UDim2.new(0.40, 0, 0.94, 0), anchor = Vector2.new(0.5, 0.5), onClick = callbacks.onCollection,
	})
	local customize = Components.button({
		name = "CustomizeButton", parent = frame, text = "STYLE", size = UDim2.new(0.20, 0, 0, 54),
		position = UDim2.new(0.62, 0, 0.94, 0), anchor = Vector2.new(0.5, 0.5), onClick = callbacks.onCustomize,
	})
	local shop = Components.button({
		name = "ShopButton", parent = frame, text = "SHOP", size = UDim2.new(0.20, 0, 0, 54),
		position = UDim2.new(0.82, 0, 0.94, 0), anchor = Vector2.new(0.5, 0.5), onClick = callbacks.onShop,
	})
	local settings = Components.button({
		name = "SettingsButton", parent = frame, text = "⚙", size = UDim2.fromOffset(48, 48),
		position = UDim2.new(0.95, 0, 0.07, 0), anchor = Vector2.new(1, 0.5), onClick = callbacks.onSettings,
	})
	local worldLine = Components.label({
		name = "WorldLine", parent = frame, text = WorldConfig.get(WorldConfig.DEFAULT).name,
		font = Theme.fonts.medium, textSize = Theme.type.small, color = Theme.colors.inkLow,
		position = UDim2.new(0.5, 0, 0.76, 0), anchor = Vector2.new(0.5, 0.5), size = UDim2.new(0.92, 0, 0, 24),
	})
	local startStatus = Components.label({
		name = "StartStatus", parent = frame, text = "", font = Theme.fonts.medium,
		textSize = Theme.type.small, color = Theme.colors.warn,
		position = UDim2.new(0.5, 0, 0.865, 0), anchor = Vector2.new(0.5, 0), size = UDim2.new(0.90, 0, 0, 24),
	})
	startStatus.Visible = false

	local function layout(viewport: Vector2)
		local portrait = viewport.X < viewport.Y
		local compact = Theme.breakpointFor(viewport) == "compact"
		if portrait then
			previewHost.Size = UDim2.new(0.54, 0, 0.31, 0)
			previewHost.Position = UDim2.new(0.5, 0, 0.42, 0)
			title.Position = UDim2.new(0.5, 0, 0.11, 0)
			subtitle.Position = UDim2.new(0.5, 0, 0.18, 0)
			nameplate.Position = UDim2.new(0.5, 0, 0.60, 0)
			rarity.Position = UDim2.new(0.5, 0, 0.65, 0)
			worldLine.Position = UDim2.new(0.5, 0, 0.72, 0)
			play.Position = UDim2.new(0.5, 0, 0.81, 0)
			world.Position = UDim2.new(0.14, 0, 0.94, 0)
			collection.Position = UDim2.new(0.38, 0, 0.94, 0)
			customize.Position = UDim2.new(0.62, 0, 0.94, 0)
			shop.Position = UDim2.new(0.86, 0, 0.94, 0)
		else
			previewHost.Size = UDim2.new(0.30, 0, 0.42, 0)
			previewHost.Position = UDim2.new(0.32, 0, 0.46, 0)
			title.Position = UDim2.new(0.32, 0, 0.17, 0)
			subtitle.Position = UDim2.new(0.32, 0, 0.24, 0)
			nameplate.Position = UDim2.new(0.32, 0, 0.72, 0)
			rarity.Position = UDim2.new(0.32, 0, 0.78, 0)
			worldLine.Position = UDim2.new(0.70, 0, 0.45, 0)
			play.Position = UDim2.new(0.70, 0, 0.59, 0)
			world.Position = UDim2.new(0.14, 0, 0.94, 0)
			collection.Position = UDim2.new(0.38, 0, 0.94, 0)
			customize.Position = UDim2.new(0.62, 0, 0.94, 0)
			shop.Position = UDim2.new(0.86, 0, 0.94, 0)
		end
		if compact then
			play.Size = UDim2.new(portrait and 0.64 or 0.42, 0, 0, 56)
			settings.Size = UDim2.fromOffset(48, 48)
			world.instance.Size = UDim2.new(0.20, 0, 0, 48)
			collection.instance.Size = UDim2.new(0.20, 0, 0, 48)
			customize.instance.Size = UDim2.new(0.20, 0, 0, 48)
			shop.instance.Size = UDim2.new(0.20, 0, 0, 48)
		else
			play.Size = UDim2.new(portrait and 0.64 or 0.42, 0, 0, 68)
			settings.Size = UDim2.fromOffset(48, 48)
			world.instance.Size = UDim2.new(0.20, 0, 0, 54)
			collection.instance.Size = UDim2.new(0.20, 0, 0, 54)
			customize.instance.Size = UDim2.new(0.20, 0, 0, 54)
			shop.instance.Size = UDim2.new(0.20, 0, 0, 54)
		end
	end

	local api = { instance = frame }
	function api.show()
		ensurePreview()
		frame.Visible = true
		startStatus.Visible = false
		play.setBusy(false)
	end
	function api.hide()
		frame.Visible = false
		previewStatus.Visible = false
		if preview then
			preview.release()
			preview = nil
		end
	end
	function api.setBusy(busy: boolean)
		play.setBusy(busy)
		play.setText(busy and "STARTING…" or "P L A Y")
	end
	function api.setStatus(message: string?)
		startStatus.Text = message or ""
		startStatus.Visible = message ~= nil and message ~= ""
	end
	function api.setStartState(state: string, message: string?)
		play.setState(state, message)
	end
	function api.setWorld(world, playable: boolean, requirement: string)
		worldLine.Text = playable and world.name or ("Locked · " .. requirement)
		worldLine.TextColor3 = playable and Theme.colors.inkLow or Theme.colors.warn
	end
	function api.layout(viewport: Vector2)
		layout(viewport)
	end
	function api.visible(): boolean
		return frame.Visible
	end
	function api.destroy()
		previewStatus.Visible = false
		if preview then
			preview.release()
			preview = nil
		end
	end
	layout(Vector2.new(1280, 720))
	_ = world
	_ = collection
	_ = customize
	_ = shop
	_ = settings
	_ = nameplate
	_ = rarity
	return api
end

return LobbyScreen
