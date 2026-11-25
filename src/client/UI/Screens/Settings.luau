--!nonstrict
-- Session-local accessibility controls. Persistence and graphics services belong to later phases.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.UIConfig)

local Theme = require(script.Parent.Parent.Theme)
local Components = require(script.Parent.Parent.Components)

local Settings = {}

function Settings.create(parent: Instance, callbacks): any
	local frame = Instance.new("Frame")
	frame.Name = "SettingsScreen"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Theme.colors.bgDeep
	frame.Visible = false
	frame.Parent = parent

	local title = Components.label({ parent = frame, name = "Title", text = "SETTINGS", font = Theme.fonts.black, textSize = Theme.type.h1, color = Theme.colors.gold, position = UDim2.new(0.7, 0, 0.12, 0), anchor = Vector2.new(0.5, 0.5), size = UDim2.new(0.6, 0, 0, 48) })
	local back = Components.button({ parent = frame, name = "Back", text = "BACK", size = UDim2.fromOffset(116, 52), position = UDim2.new(0.08, 0, 0.10, 0), anchor = Vector2.new(0, 0.5), onClick = callbacks.onBack })
	local panel = Components.panel({ name = "SettingsPanel", parent = frame, size = UDim2.new(0.9, 0, 0.58, 0), position = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5), color = Theme.colors.surface1, stroke = true })
	local reducedLabel = Components.label({ parent = panel, name = "ReducedMotionLabel", text = "Reduced motion", font = Theme.fonts.bold, textSize = Theme.type.h3, color = Theme.colors.inkHigh, alignX = Enum.TextXAlignment.Left, position = UDim2.new(0.08, 0, 0.27, 0), anchor = Vector2.new(0, 0.5), size = UDim2.new(0.54, 0, 0, 46) })
	local reducedToggle = Components.toggle({ parent = panel, name = "ReducedMotion", position = UDim2.new(0.9, 0, 0.27, 0), anchor = Vector2.new(1, 0.5), value = false, onChanged = callbacks.onReducedMotion })
	local textLabel = Components.label({ parent = panel, name = "TextScaleLabel", text = "Text size", font = Theme.fonts.bold, textSize = Theme.type.h3, color = Theme.colors.inkHigh, alignX = Enum.TextXAlignment.Left, position = UDim2.new(0.08, 0, 0.53, 0), anchor = Vector2.new(0, 0.5), size = UDim2.new(0.42, 0, 0, 46) })
	local scaleValue = Components.label({ parent = panel, name = "TextScaleValue", text = "100%", font = Theme.fonts.bold, textSize = Theme.type.body, color = Theme.colors.gold, position = UDim2.new(0.72, 0, 0.53, 0), anchor = Vector2.new(0.5, 0.5), size = UDim2.fromOffset(72, 44) })
	local textScale = 1
	local function changeTextScale(delta: number)
		textScale = math.clamp(math.floor((textScale + delta) * 10 + 0.5) / 10, 0.9, 1.4)
		scaleValue.Text = ("%d%%"):format(math.floor(textScale * 100 + 0.5))
		callbacks.onTextScale(textScale)
	end
	local decrease = Components.button({ parent = panel, name = "TextScaleDown", text = "−", size = UDim2.fromOffset(48, 48), position = UDim2.new(0.56, 0, 0.53, 0), onClick = function() changeTextScale(-0.1) end })
	local increase = Components.button({ parent = panel, name = "TextScaleUp", text = "+", size = UDim2.fromOffset(48, 48), position = UDim2.new(0.88, 0, 0.53, 0), onClick = function() changeTextScale(0.1) end })
	local sessionNote = Components.label({ parent = panel, name = "SessionNote", text = "These accessibility choices apply for this session only. Audio, graphics and control services are not connected yet.", font = Theme.fonts.medium, textSize = Theme.type.small, color = Theme.colors.inkMid, wrapped = true, position = UDim2.new(0.5, 0, 0.79, 0), anchor = Vector2.new(0.5, 0.5), size = UDim2.new(0.84, 0, 0, 64) })

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
		panel.Size = UDim2.new(portrait and 0.94 or 0.90, 0, compact and 0.70 or 0.62, 0)
		panel.Position = UDim2.new(0.5, 0, compact and 0.60 or (portrait and 0.55 or 0.52), 0)
		reducedLabel.Position = UDim2.new(0.08, 0, 0.25, 0)
		reducedToggle.instance.Position = UDim2.new(0.90, 0, 0.25, 0)
		textLabel.Size = UDim2.new(portrait and 0.38 or 0.42, 0, 0, 46)
		textLabel.Position = UDim2.new(0.08, 0, 0.52, 0)
		decrease.instance.Position = UDim2.new(portrait and 0.54 or 0.56, 0, 0.52, 0)
		scaleValue.Position = UDim2.new(portrait and 0.72 or 0.72, 0, 0.52, 0)
		increase.instance.Position = UDim2.new(0.90, 0, 0.52, 0)
		sessionNote.Position = UDim2.new(0.5, 0, 0.79, 0)
		sessionNote.Size = UDim2.new(0.88, 0, 0, compact and 72 or 64)
	end

	local api = { instance = frame }
	function api.show() frame.Visible = true end
	function api.hide() frame.Visible = false end
	function api.layout(viewport: Vector2, insets)
		layout(viewport, insets)
	end
	function api.setSettings(settings)
		reducedToggle.setValue(settings.reducedMotion == true)
		textScale = math.clamp(tonumber(settings.textScale) or 1, 0.9, 1.4)
		scaleValue.Text = ("%d%%"):format(math.floor(textScale * 100 + 0.5))
	end
	_ = reducedLabel
	_ = textLabel
	_ = decrease
	_ = increase
	_ = back
	_ = title
	layout(Vector2.new(1280, 720))
	return api
end

return Settings
