--!nonstrict
-- Reusable native UI primitives. Screens compose these instead of inventing local interaction styles.
-- See docs/05_UI_UX_SPECIFICATION.md §4.

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.UIConfig)

local Theme = require(script.Parent.Theme)
local Components = {}
local padReleaseFunctions = setmetatable({}, { __mode = "k" })

local function addCorner(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

local function addStroke(parent: Instance, color: Color3, thickness: number, transparency: number?)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = transparency or 0
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

Components.addCorner = addCorner
Components.addStroke = addStroke

function Components.panel(config): Frame
	local panel = Instance.new("Frame")
	panel.Name = config.name or "Panel"
	panel.Size = config.size or UDim2.fromScale(1, 1)
	panel.Position = config.position or UDim2.fromScale(0, 0)
	panel.AnchorPoint = config.anchor or Vector2.new(0, 0)
	panel.BackgroundColor3 = config.color or Theme.colors.surface1
	panel.BackgroundTransparency = config.transparency or 0
	panel.BorderSizePixel = 0
	panel.Parent = config.parent

	addCorner(panel, config.radius or Theme.radius.md)
	if config.stroke then
		addStroke(panel, config.strokeColor or Theme.colors.lineSoft, config.strokeWidth or 1, config.strokeTransparency)
	end
	return panel
end

function Components.label(config): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = config.name or "Label"
	label.Size = config.size or UDim2.fromScale(1, 1)
	label.Position = config.position or UDim2.fromScale(0, 0)
	label.AnchorPoint = config.anchor or Vector2.new(0, 0)
	label.BackgroundTransparency = 1
	label.Font = config.font or Theme.fonts.medium
	label.Text = config.text or ""
	label.TextColor3 = config.color or Theme.colors.inkHigh
	local baseTextSize = config.textSize or Theme.type.body
	label:SetAttribute("ThemeBaseTextSize", baseTextSize)
	label.TextSize = Theme.resolveTextSize(baseTextSize)
	label.TextXAlignment = config.alignX or Enum.TextXAlignment.Center
	label.TextYAlignment = config.alignY or Enum.TextYAlignment.Center
	label.TextWrapped = config.wrapped or false
	label.TextScaled = false
	if not config.wrapped then
		label.TextTruncate = Enum.TextTruncate.AtEnd
	end
	label.Parent = config.parent
	return label
end

export type ButtonHandle = {
	instance: TextButton,
	setText: (text: string) -> (),
	setEnabled: (enabled: boolean) -> (),
	setBusy: (busy: boolean) -> (),
	setState: (state: string, message: string?) -> (),
	setSelected: (selected: boolean) -> (),
}

local BUTTON_STATES = { default = true, hover = true, pressed = true, disabled = true, loading = true, success = true, failure = true, selected = true }

function Components.button(config): ButtonHandle
	local primary = config.variant == "primary"
	local baseColor = primary and Theme.colors.gold or Theme.colors.surface2
	local idleColor = baseColor
	local hoverColor = primary and Theme.colors.gold:Lerp(Color3.new(1, 1, 1), 0.12) or Theme.colors.surface3
	local textColor = primary and Theme.colors.bark or Theme.colors.inkHigh
	local baseText = config.text or ""

	local button = Instance.new("TextButton")
	button.Name = config.name or "Button"
	button.Size = config.size or UDim2.fromOffset(220, 64)
	button.Position = config.position or UDim2.fromScale(0.5, 0.5)
	button.AnchorPoint = config.anchor or Vector2.new(0.5, 0.5)
	button.BackgroundColor3 = baseColor
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Selectable = true
	button.Text = ""
	button.ClipsDescendants = false
	button.Parent = config.parent

	addCorner(button, config.radius or Theme.radius.md)
	local stroke = addStroke(button, primary and Theme.colors.gold or Theme.colors.lineSoft, config.strokeWidth or 1, primary and 1 or 0)
	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = button

	local label = Components.label({
		name = "Label",
		parent = button,
		text = baseText,
		font = primary and Theme.fonts.black or Theme.fonts.bold,
		textSize = config.textSize or (primary and Theme.type.h2 or Theme.type.h3),
		color = config.textColor or textColor,
		wrapped = config.wrapped or false,
	})
	if config.subtitle then
		label.Position = UDim2.fromScale(0, 0.30)
		label.Size = UDim2.fromScale(1, 0.42)
		Components.label({
			name = "Subtitle",
			parent = button,
			text = config.subtitle,
			font = Theme.fonts.medium,
			textSize = Theme.type.small,
			color = primary and Theme.colors.bark or Theme.colors.inkMid,
			position = UDim2.fromScale(0, 0.64),
			size = UDim2.fromScale(1, 0.26),
		})
	end
	local helper = Components.label({
		name = "StateMessage",
		parent = button,
		text = "",
		font = Theme.fonts.medium,
		textSize = Theme.type.tiny,
		color = Theme.colors.danger,
		position = UDim2.new(0.5, 0, 1, 1),
		anchor = Vector2.new(0.5, 0),
		size = UDim2.new(1, 0, 0, 22),
	})
	helper.Visible = false

	local state = "default"
	local hovered = false
	local selected = false
	local stateToken = 0

	local function tweenScale(target: number, duration: number)
		Theme.tween(scale, duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Scale = target })
	end
	local function paint(color: Color3)
		Theme.tween(button, Theme.duration("fast"), Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { BackgroundColor3 = color })
	end
	local function applyState(nextState: string, message: string?)
		if not BUTTON_STATES[nextState] then
			return
		end
		state = nextState
		stateToken += 1
		local token = stateToken
		helper.Visible = nextState == "failure" and message ~= nil and message ~= ""
		helper.Text = message or ""
		button.Active = nextState ~= "disabled" and nextState ~= "loading"
		button.Selectable = button.Active

		if nextState == "disabled" then
			button.BackgroundTransparency = 0.45
			label.TextColor3 = Theme.colors.inkLow
			stroke.Transparency = 0.8
			label.Text = baseText
			tweenScale(1, Theme.duration("fast"))
		elseif nextState == "loading" then
			button.BackgroundTransparency = 0
			label.TextColor3 = textColor
			stroke.Transparency = 0.2
			label.Text = "…  " .. baseText
			tweenScale(1, Theme.duration("fast"))
			paint(baseColor)
		elseif nextState == "success" then
			button.BackgroundTransparency = 0
			label.TextColor3 = textColor
			stroke.Color = Theme.colors.success
			stroke.Thickness = Theme.config.stroke.focus
			stroke.Transparency = 0
			label.Text = "✓  " .. baseText
			paint(baseColor)
			task.delay(0.7, function()
				if stateToken == token and state == "success" then
					applyState("default")
				end
			end)
		elseif nextState == "failure" then
			button.BackgroundTransparency = 0
			label.TextColor3 = textColor
			stroke.Color = Theme.colors.danger
			stroke.Thickness = Theme.config.stroke.focus
			stroke.Transparency = 0
			label.Text = "!  " .. baseText
			paint(baseColor)
			task.delay(0.8, function()
				if stateToken == token and state == "failure" then
					applyState(selected and "selected" or (hovered and "hover" or "default"))
				end
			end)
		elseif nextState == "selected" then
			button.BackgroundTransparency = 0
			label.TextColor3 = config.textColor or textColor
			stroke.Color = Theme.colors.gold
			stroke.Thickness = Theme.config.stroke.focus
			stroke.Transparency = 0
			label.Text = baseText
			paint(hoverColor)
			tweenScale(1, Theme.duration("fast"))
		else
			button.BackgroundTransparency = 0
			label.TextColor3 = config.textColor or textColor
			stroke.Color = primary and Theme.colors.gold or Theme.colors.inkLow
			stroke.Thickness = config.strokeWidth or 1
			stroke.Transparency = primary and 1 or 0
			label.Text = baseText
			paint(nextState == "hover" and hoverColor or idleColor)
			if nextState == "pressed" then
				tweenScale(0.96, Theme.duration("pressIn"))
			elseif nextState == "hover" then
				tweenScale(1.03, Theme.duration("fast"))
			else
				tweenScale(1, Theme.duration("pressOut"))
			end
		end
	end

	button.MouseEnter:Connect(function()
		hovered = true
		if not button.Active or selected or (UserInputService.TouchEnabled and not UserInputService.MouseEnabled) then
			return
		end
		applyState("hover")
	end)
	button.MouseLeave:Connect(function()
		hovered = false
		if state == "hover" or state == "pressed" then
			applyState(selected and "selected" or "default")
		end
	end)
	button.SelectionGained:Connect(function()
		if button.Active and not selected then
			applyState("hover")
		end
	end)
	button.SelectionLost:Connect(function()
		if state == "hover" or state == "pressed" then
			applyState(selected and "selected" or "default")
		end
	end)
	button.InputBegan:Connect(function(input)
		if not button.Active then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			applyState("pressed")
		end
	end)
	button.InputEnded:Connect(function(input)
		if not button.Active then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			applyState(selected and "selected" or (hovered and "hover" or "default"))
		end
	end)
	button.Activated:Connect(function()
		if not button.Active then
			return
		end
		applyState(selected and "selected" or (hovered and "hover" or "default"))
		if config.onClick then
			config.onClick()
		end
	end)

	local handle: ButtonHandle = {
		instance = button,
		setText = function(text: string)
			baseText = text
			label.Text = text
		end,
		setEnabled = function(enabled: boolean)
			applyState(enabled and "default" or "disabled")
		end,
		setBusy = function(busy: boolean)
			applyState(busy and "loading" or "default")
		end,
		setState = function(nextState: string, message: string?)
			applyState(nextState, message)
		end,
		setSelected = function(isSelected: boolean)
			selected = isSelected == true
			applyState(selected and "selected" or "default")
		end,
	}
	return handle
end

function Components.currencyPill(config): any
	local button = Instance.new(config.onClick and "TextButton" or "Frame")
	button.Name = config.name or "CurrencyPill"
	button.Size = config.size or UDim2.fromOffset(148, 48)
	button.Position = config.position or UDim2.fromScale(0, 0)
	button.AnchorPoint = config.anchor or Vector2.new(0, 0)
	button.BackgroundColor3 = Theme.colors.bgDeep
	button.BackgroundTransparency = 0.16
	button.BorderSizePixel = 0
	if button:IsA("TextButton") then
		button.AutoButtonColor = false
		button.Text = ""
	end
	button.Parent = config.parent
	addCorner(button, Theme.radius.pill)
	local stroke = addStroke(button, Theme.colors.inkLow, 1, 0.15)
	Components.label({ parent = button, name = "Icon", text = config.icon or "A", font = Theme.fonts.black, textSize = Theme.type.h3, color = config.color or Theme.colors.gold, position = UDim2.new(0, 14, 0.5, 0), anchor = Vector2.new(0, 0.5), size = UDim2.fromOffset(28, 32) })
	local valueLabel = Components.label({ parent = button, name = "Value", text = UIConfig.formatNumber(config.value or 0), font = Theme.fonts.black, textSize = Theme.type.number, color = config.color or Theme.colors.gold, alignX = Enum.TextXAlignment.Right, position = UDim2.new(1, -14, 0.5, 0), anchor = Vector2.new(1, 0.5), size = UDim2.new(1, -52, 0, 34) })
	local value = Instance.new("NumberValue")
	value.Name = "AnimatedValue"
	value.Value = config.value or 0
	value.Parent = button
	local valueConnection = value.Changed:Connect(function(nextValue)
		valueLabel.Text = UIConfig.formatNumber(nextValue)
	end)
	local previous = value.Value
	local api = { instance = button }
	function api.setValue(nextValue: number, animate: boolean?)
		nextValue = math.max(0, tonumber(nextValue) or 0)
		if nextValue == previous then
			return
		end
		local gained = nextValue > previous
		previous = nextValue
		if animate == false then
			value.Value = nextValue
			stroke.Color = Theme.colors.inkLow
			stroke.Transparency = 0.25
			return
		end
		stroke.Color = gained and Theme.colors.success or Theme.colors.danger
		stroke.Transparency = 0
		Theme.tween(value, 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Value = nextValue })
		task.delay(0.55, function()
			if button.Parent then
				stroke.Color = Theme.colors.inkLow
				stroke.Transparency = 0.25
			end
		end)
	end
	function api.destroy()
		valueConnection:Disconnect()
		button:Destroy()
	end
	if button:IsA("TextButton") then
		button.Activated:Connect(config.onClick)
	end
	return api
end

function Components.progressBar(config): any
	local back = Instance.new("Frame")
	back.Name = config.name or "ProgressBar"
	back.Size = config.size or UDim2.new(1, 0, 0, 12)
	back.Position = config.position or UDim2.fromScale(0, 0)
	back.AnchorPoint = config.anchor or Vector2.new(0, 0)
	back.BackgroundColor3 = config.backgroundColor or Theme.colors.surface2
	back.BorderSizePixel = 0
	back.Parent = config.parent
	addCorner(back, Theme.radius.pill)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = config.fillColor or Theme.colors.gold
	fill.BorderSizePixel = 0
	fill.Parent = back
	addCorner(fill, Theme.radius.pill)
	local api = { instance = back }
	function api.setProgress(value: number)
		fill.Size = UDim2.fromScale(math.clamp(tonumber(value) or 0, 0, 1), 1)
	end
	return api
end

function Components.rarityBadge(config): Frame
	local rarity = config.rarity or "Common"
	local animalConfig = require(ReplicatedStorage.Shared.Config.AnimalConfig)
	local rarityInfo = animalConfig.RARITY[rarity]
	local badge = Instance.new("Frame")
	badge.Name = config.name or "RarityBadge"
	badge.Size = config.size or UDim2.fromOffset(132, 32)
	badge.Position = config.position or UDim2.fromScale(0, 0)
	badge.AnchorPoint = config.anchor or Vector2.new(0, 0)
	badge.BackgroundColor3 = Theme.colors.surface1
	badge.BorderSizePixel = 0
	badge.Parent = config.parent
	addCorner(badge, Theme.radius.pill)
	addStroke(badge, rarityInfo and rarityInfo.color or Theme.colors.lineSoft, 1, 0.2)
	Components.label({ parent = badge, name = "Shape", text = UIConfig.rarityShapes[rarity] or "●", font = Theme.fonts.black, textSize = Theme.type.small, color = rarityInfo and rarityInfo.color or Theme.colors.inkHigh, position = UDim2.new(0, 10, 0.5, 0), anchor = Vector2.new(0, 0.5), size = UDim2.fromOffset(24, 24) })
	Components.label({ parent = badge, name = "Name", text = rarity, font = Theme.fonts.bold, textSize = Theme.type.small, color = Theme.colors.inkHigh, alignX = Enum.TextXAlignment.Left, position = UDim2.new(0, 36, 0.5, 0), anchor = Vector2.new(0, 0.5), size = UDim2.new(1, -42, 0, 24) })
	return badge
end

function Components.toggle(config): any
	local control = Instance.new("TextButton")
	control.Name = config.name or "Toggle"
	control.Size = config.size or UDim2.fromOffset(60, 36)
	control.Position = config.position or UDim2.fromScale(0, 0)
	control.AnchorPoint = config.anchor or Vector2.new(0, 0)
	control.BackgroundTransparency = 1
	control.BorderSizePixel = 0
	control.Selectable = true
	control.Text = ""
	control.Parent = config.parent
	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, 0, 0, 30)
	track.Position = UDim2.new(0.5, 0, 0.5, 0)
	track.AnchorPoint = Vector2.new(0.5, 0.5)
	track.BackgroundColor3 = Theme.colors.surface2
	track.BorderSizePixel = 0
	track.Parent = control
	addCorner(track, Theme.radius.pill)
	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(24, 24)
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.BackgroundColor3 = Theme.colors.inkHigh
	knob.BorderSizePixel = 0
	knob.Parent = track
	addCorner(knob, Theme.radius.pill)
	local value = config.value == true
	local function paint(animate: boolean)
		local goal = value and UDim2.new(1, -16, 0.5, 0) or UDim2.new(0, 16, 0.5, 0)
		track.BackgroundColor3 = value and Theme.colors.moss or Theme.colors.surface2
		if animate then
			Theme.tween(knob, Theme.duration("base"), Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Position = goal })
		else
			knob.Position = goal
		end
	end
	local api = { instance = control }
	function api.setValue(nextValue: boolean, notify: boolean?)
		value = nextValue == true
		paint(true)
		if notify and config.onChanged then
			config.onChanged(value)
		end
	end
	function api.getValue(): boolean
		return value
	end
	control.Activated:Connect(function()
		api.setValue(not value, true)
	end)
	paint(false)
	return api
end

-- Four-way touch pad. Input-down feedback is immediate; held state clears on release.
function Components.releasePadButton(button: TextButton)
	local release = padReleaseFunctions[button]
	if release then
		release()
	end
end

function Components.padButton(config): TextButton
	local button = Instance.new("TextButton")
	button.Name = config.name or "Pad"
	button.Size = config.size or UDim2.fromOffset(78, 78)
	button.Position = config.position
	button.AnchorPoint = config.anchor or Vector2.new(0.5, 0.5)
	button.BackgroundColor3 = Theme.colors.surface1
	button.BackgroundTransparency = 0.18
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Text = config.text or ""
	button.Font = Theme.fonts.black
	button.TextSize = Theme.resolveTextSize(config.textSize or 26)
	button:SetAttribute("ThemeBaseTextSize", config.textSize or 26)
	button.TextColor3 = Theme.colors.inkHigh
	button.Parent = config.parent
	addCorner(button, Theme.radius.md)
	addStroke(button, Theme.colors.inkLow, 1, 0.15)
	local scale = Instance.new("UIScale")
	scale.Parent = button
	local held = false
	local function release()
		if not held then return end
		held = false
		Theme.tween(scale, Theme.duration("pressOut"), Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Scale = 1 })
		button.BackgroundColor3 = Theme.colors.surface1
		if config.onRelease then config.onRelease() end
	end
	padReleaseFunctions[button] = release
	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			if held then return end
			held = true
			Theme.tween(scale, Theme.duration("pressIn"), Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Scale = 0.92 })
			button.BackgroundColor3 = Theme.colors.surface3
			if config.onPress then config.onPress() end
		end
	end)
	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			release()
		end
	end)
	button.MouseLeave:Connect(release)
	return button
end

return Components
