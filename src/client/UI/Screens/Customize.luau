--!nonstrict
-- Cosmetic inventory foundation. Slot names are the design spec; no unbuilt item catalog is fabricated.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.UIConfig)

local Theme = require(script.Parent.Parent.Theme)
local Components = require(script.Parent.Parent.Components)

local Customize = {}
local SLOTS = { "Hat", "Face", "Neck", "Back", "Feet", "Trail", "Aura", "Victory", "Emote", "Colour" }

function Customize.create(parent: Instance, callbacks): any
	local frame = Instance.new("Frame")
	frame.Name = "CustomizeScreen"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Theme.colors.bgDeep
	frame.Visible = false
	frame.Parent = parent

	local title = Components.label({ parent = frame, name = "Title", text = "CUSTOMISE", font = Theme.fonts.black, textSize = Theme.type.h1, color = Theme.colors.gold, position = UDim2.new(0.7, 0, 0.12, 0), anchor = Vector2.new(0.5, 0.5), size = UDim2.new(0.6, 0, 0, 48) })
	local back = Components.button({ parent = frame, name = "Back", text = "BACK", size = UDim2.fromOffset(116, 52), position = UDim2.new(0.08, 0, 0.10, 0), anchor = Vector2.new(0, 0.5), onClick = callbacks.onBack })
	local panel = Components.panel({ name = "SlotPanel", parent = frame, size = UDim2.new(0.9, 0, 0.60, 0), position = UDim2.fromScale(0.5, 0.51), anchor = Vector2.new(0.5, 0.5), color = Theme.colors.surface1, stroke = true })
	local slots = Components.label({ parent = panel, name = "Slots", text = table.concat(SLOTS, "   ·   "), font = Theme.fonts.bold, textSize = Theme.type.body, color = Theme.colors.inkHigh, wrapped = true, position = UDim2.new(0.5, 0, 0.28, 0), anchor = Vector2.new(0.5, 0.5), size = UDim2.new(0.88, 0, 0.42, 0) })
	local emptyState = Components.label({ parent = panel, name = "EmptyState", text = "Cosmetic ownership and equipping are not active yet. Your animal and loadouts are unchanged.", font = Theme.fonts.medium, textSize = Theme.type.body, color = Theme.colors.inkMid, wrapped = true, position = UDim2.new(0.5, 0, 0.68, 0), anchor = Vector2.new(0.5, 0.5), size = UDim2.new(0.84, 0, 0, 74) })

	local function layout(viewport: Vector2, insets)
		local metrics = UIConfig.safeFrameMetrics(viewport, insets)
		local compact = metrics.compact
		local portrait = metrics.portrait
		title.Position = UDim2.new(0.5, 0, compact and 0.18 or (portrait and 0.15 or 0.12), 0)
		title.Size = UDim2.new(portrait and 0.78 or 0.62, 0, 0, compact and 40 or 48)
		title.TextSize = Theme.resolveTextSize(compact and Theme.type.h2 or Theme.type.h1)
		title:SetAttribute("ThemeBaseTextSize", compact and Theme.type.h2 or Theme.type.h1)
		back.instance.Position = UDim2.new(0.04, 0, 0.07, 0)
		back.instance.Size = UDim2.fromOffset(compact and 96 or 116, compact and 44 or 52)
		panel.Size = UDim2.new(portrait and 0.94 or 0.90, 0, compact and 0.72 or 0.62, 0)
		panel.Position = UDim2.new(0.5, 0, compact and 0.61 or (portrait and 0.55 or 0.52), 0)
		slots.Position = UDim2.new(0.5, 0, compact and 0.30 or 0.28, 0)
		slots.Size = UDim2.new(0.90, 0, compact and 0.48 or 0.42, 0)
		emptyState.Position = UDim2.new(0.5, 0, compact and 0.73 or 0.70, 0)
		emptyState.Size = UDim2.new(0.86, 0, 0, compact and 82 or 74)
	end

	local api = { instance = frame }
	function api.show() frame.Visible = true end
	function api.hide() frame.Visible = false end
	function api.layout(viewport: Vector2, insets)
		layout(viewport, insets)
	end
	layout(Vector2.new(1280, 720))
	_ = back
	return api
end

return Customize
