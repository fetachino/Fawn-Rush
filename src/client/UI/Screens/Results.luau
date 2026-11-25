--!nonstrict
-- Run summary. Retry is the primary action and the card remains responsive on narrow screens.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.UIConfig)

local Theme = require(script.Parent.Parent.Theme)
local Components = require(script.Parent.Parent.Components)

local ResultsScreen = {}

local function statRow(parent: Instance, y: number, caption: string, valueColor: Color3?): TextLabel
	Components.label({
		name = caption .. "Caption", parent = parent, text = caption, font = Theme.fonts.medium,
		textSize = Theme.type.body, color = Theme.colors.inkMid, alignX = Enum.TextXAlignment.Left,
		position = UDim2.fromOffset(26, y), size = UDim2.new(0.5, -26, 0, 24),
	})
	return Components.label({
		name = caption .. "Value", parent = parent, text = "0", font = Theme.fonts.bold,
		textSize = Theme.type.h3, color = valueColor or Theme.colors.inkHigh,
		alignX = Enum.TextXAlignment.Right, position = UDim2.new(0.5, 0, 0, y), size = UDim2.new(0.5, -26, 0, 24),
	})
end

function ResultsScreen.create(parent: Instance, callbacks): any
	local scrim = Instance.new("Frame")
	scrim.Name = "ResultsScreen"
	scrim.Size = UDim2.fromScale(1, 1)
	scrim.BackgroundColor3 = Theme.colors.scrim
	scrim.BackgroundTransparency = 0.28
	scrim.BorderSizePixel = 0
	scrim.Visible = false
	scrim.Parent = parent

	local panel = Components.panel({
		name = "Card", parent = scrim, size = UDim2.new(0.88, 0, 0.82, 0),
		position = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5),
		color = Theme.colors.bgBase, radius = Theme.radius.lg, stroke = true, strokeColor = Theme.colors.lineSoft,
	})
	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(290, 360)
	constraint.MaxSize = Vector2.new(520, 520)
	constraint.Parent = panel

	Components.label({ parent = panel, name = "Header", text = "RUN OVER", font = Theme.fonts.bold, textSize = Theme.type.small, color = Theme.colors.inkLow, position = UDim2.fromOffset(0, 20), size = UDim2.new(1, 0, 0, 20) })
	local headline = Components.label({ parent = panel, name = "Headline", text = "0 m", font = Theme.fonts.black, textSize = Theme.type.display, color = Theme.colors.gold, position = UDim2.fromOffset(0, 43), size = UDim2.new(1, 0, 0, 52) })
	local cause = Components.label({ parent = panel, name = "Cause", text = "", font = Theme.fonts.medium, textSize = Theme.type.body, color = Theme.colors.inkMid, position = UDim2.fromOffset(20, 94), size = UDim2.new(1, -40, 0, 24) })
	local best = Components.label({ parent = panel, name = "Best", text = "", font = Theme.fonts.bold, textSize = Theme.type.small, color = Theme.colors.success, position = UDim2.fromOffset(0, 120), size = UDim2.new(1, 0, 0, 20) })
	local rowsValue = statRow(panel, 154, "Distance")
	local scoreValue = statRow(panel, 184, "Score")
	local acornValue = statRow(panel, 214, "Run acorns", Theme.colors.gold)
	local retry = Components.button({
		name = "RetryButton", parent = panel, text = "RETRY", variant = "primary",
		size = UDim2.new(0.43, 0, 0, 58), position = UDim2.new(0.06, 0, 1, -78), anchor = Vector2.new(0, 0.5),
		onClick = callbacks.onRetry,
	})
	local lobby = Components.button({
		name = "LobbyButton", parent = panel, text = "LOBBY",
		size = UDim2.new(0.43, 0, 0, 58), position = UDim2.new(0.94, 0, 1, -78), anchor = Vector2.new(1, 0.5),
		onClick = callbacks.onLobby,
	})

	local function layout(viewport: Vector2, insets)
		local metrics = UIConfig.safeFrameMetrics(viewport, insets)
		local compact = metrics.compact
		local portrait = metrics.portrait
		panel.Size = UDim2.new(portrait and 0.96 or 0.88, 0, compact and 0.92 or 0.82, 0)
		constraint.MinSize = compact and Vector2.new(260, 320) or Vector2.new(290, 360)
		constraint.MaxSize = Vector2.new(520, 520)
		headline.TextSize = Theme.resolveTextSize(compact and Theme.type.h1 or Theme.type.display)
		headline:SetAttribute("ThemeBaseTextSize", compact and Theme.type.h1 or Theme.type.display)
		if compact then
			cause.Position = UDim2.fromOffset(14, 92)
			cause.Size = UDim2.new(1, -28, 0, 32)
			best.Position = UDim2.fromOffset(0, 124)
		else
			cause.Position = UDim2.fromOffset(20, 94)
			cause.Size = UDim2.new(1, -40, 0, 24)
			best.Position = UDim2.fromOffset(0, 120)
		end
	end

	local api = { instance = scrim }
	function api.show(payload)
		local metres = math.floor((payload.rows or 0) * 1.12)
		headline.Text = ("%d m"):format(metres)
		rowsValue.Text = ("%d m"):format(metres)
		scoreValue.Text = tostring(payload.score or 0)
		acornValue.Text = "+" .. tostring(payload.acorns or 0)
		cause.Text = payload.deathCause and ("Hit by " .. payload.deathCause) or "Run complete"
		if payload.bestRows and payload.rows and payload.rows >= payload.bestRows and metres > 0 then
			best.Text = "NEW PERSONAL BEST"
			best.Visible = true
		else
			best.Visible = false
		end
		scrim.Visible = true
	end
	function api.hide()
		scrim.Visible = false
	end
	function api.layout(viewport: Vector2, insets)
		layout(viewport, insets)
	end
	function api.visible(): boolean
		return scrim.Visible
	end
	_ = retry
	_ = lobby
	layout(Vector2.new(1280, 720))
	return api
end

return ResultsScreen
