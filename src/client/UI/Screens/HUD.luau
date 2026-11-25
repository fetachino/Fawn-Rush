--!nonstrict
-- In-run HUD. Persistent information stays in the top strip; touch controls stay below the road band.

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.UIConfig)

local Theme = require(script.Parent.Parent.Theme)
local Components = require(script.Parent.Parent.Components)

local HUD = {}

local function statCard(parent: Instance, opts): any
	local card = Components.panel({
		name = opts.name,
		parent = parent,
		size = opts.size or UDim2.fromOffset(142, 56),
		position = opts.position,
		anchor = opts.anchor,
		color = Theme.colors.bgDeep,
		transparency = 0.22,
		radius = Theme.radius.md,
		stroke = true,
		strokeColor = Theme.colors.inkLow,
		strokeTransparency = 0.15,
	})
	Components.label({
		name = "Caption", parent = card, text = opts.caption, font = Theme.fonts.bold,
		textSize = Theme.type.tiny, color = Theme.colors.inkLow,
		position = UDim2.fromScale(0.5, 0.24), anchor = Vector2.new(0.5, 0.5), size = UDim2.fromScale(0.9, 0.3),
	})
	local value = Components.label({
		name = "Value", parent = card, text = opts.text or "0", font = Theme.fonts.black,
		textSize = Theme.type.number, color = opts.color or Theme.colors.inkHigh,
		position = UDim2.fromScale(0.5, 0.66), anchor = Vector2.new(0.5, 0.5), size = UDim2.fromScale(0.92, 0.5),
	})
	return { frame = card, value = value }
end

function HUD.create(parent: Instance, callbacks): any
	local frame = Instance.new("Frame")
	frame.Name = "HUD"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.Visible = false
	frame.Parent = parent

	local distance = statCard(frame, { name = "DistanceCard", caption = "DISTANCE", text = "0 m" })
	local score = statCard(frame, { name = "ScoreCard", caption = "SCORE", text = "0" })
	local acorns = Components.currencyPill({
		name = "AcornCard", parent = frame, icon = "A", value = 0,
		size = UDim2.fromOffset(142, 48), color = Theme.colors.gold,
	})
	local rotateGuidance = Components.label({
		name = "RotateGuidance", parent = frame, text = "Rotate to landscape",
		font = Theme.fonts.medium, textSize = Theme.type.tiny, color = Theme.colors.inkMid,
		alignX = Enum.TextXAlignment.Left, wrapped = false,
	})
	rotateGuidance.Visible = false

	local combo = Components.panel({
		name = "ComboCard", parent = frame, size = UDim2.fromOffset(154, 48),
		position = UDim2.new(0.5, 0, 0.018, 0), anchor = Vector2.new(0.5, 0),
		color = Theme.colors.bgDeep, transparency = 0.18, radius = Theme.radius.pill,
		stroke = true, strokeColor = Theme.colors.gold, strokeTransparency = 0.4,
	})
	combo.Visible = false
	local comboValue = Components.label({
		name = "ComboValue", parent = combo, text = "×1.0", font = Theme.fonts.black,
		textSize = Theme.type.h3, color = Theme.colors.gold,
		position = UDim2.fromScale(0.5, 0.38), anchor = Vector2.new(0.5, 0.5), size = UDim2.fromScale(0.9, 0.62),
	})
	local comboBarBack = Instance.new("Frame")
	comboBarBack.Name = "ComboBar"
	comboBarBack.Size = UDim2.new(0.8, 0, 0, 4)
	comboBarBack.Position = UDim2.new(0.5, 0, 0.78, 0)
	comboBarBack.AnchorPoint = Vector2.new(0.5, 0)
	comboBarBack.BackgroundColor3 = Theme.colors.surface2
	comboBarBack.BorderSizePixel = 0
	comboBarBack.Parent = combo
	local comboFill = Instance.new("Frame")
	comboFill.Name = "Fill"
	comboFill.Size = UDim2.fromScale(1, 1)
	comboFill.BackgroundColor3 = Theme.colors.gold
	comboFill.BorderSizePixel = 0
	comboFill.Parent = comboBarBack

	local pad = nil
	local padButtons = {}
	local jumpButton = nil
	if UserInputService.TouchEnabled then
		pad = Instance.new("Frame")
		pad.Name = "TouchPad"
		pad.BackgroundTransparency = 1
		pad.Parent = frame

		local function makePadButton(text: string, dir: string)
			local button = Components.padButton({
				parent = pad, text = text, size = UDim2.fromOffset(48, 48),
				anchor = Vector2.new(0.5, 0.5),
				onPress = function() callbacks.onPad(dir, true) end,
				onRelease = function() callbacks.onPad(dir, false) end,
			})
			padButtons[#padButtons + 1] = { instance = button, dir = dir }
		end
		makePadButton("▲", "fwd")
		makePadButton("▼", "back")
		makePadButton("◀", "left")
		makePadButton("▶", "right")
		jumpButton = Components.padButton({
			parent = frame, name = "JumpButton", text = "JUMP", textSize = 16,
			size = UDim2.fromOffset(58, 58), position = UDim2.new(1, -14, 1, -14), anchor = Vector2.new(1, 1),
			onPress = callbacks.onJump,
		})
	end

	local function layout(viewport: Vector2, insets)
		local metrics = UIConfig.hudLayout(viewport, pad ~= nil, insets)
		distance.frame.Size = UDim2.fromOffset(metrics.cardWidth, metrics.cardHeight)
		distance.frame.Position = UDim2.new(0, metrics.distanceX, metrics.distanceY, 0)
		score.frame.Size = UDim2.fromOffset(metrics.cardWidth, metrics.cardHeight)
		score.frame.Position = UDim2.new(0, metrics.scoreX, metrics.scoreY, 0)
		acorns.instance.Size = UDim2.fromOffset(metrics.acornWidth, metrics.acornHeight)
		acorns.instance.Position = UDim2.new(1, -metrics.acornRightInset, metrics.distanceY, 0)
		acorns.instance.AnchorPoint = Vector2.new(1, 0)
		rotateGuidance.Visible = metrics.portrait and metrics.rotateGuidanceWidth > 0
		if rotateGuidance.Visible then
			rotateGuidance.Position = UDim2.fromOffset(metrics.rotateGuidanceX, metrics.rotateGuidanceY)
			rotateGuidance.Size = UDim2.fromOffset(metrics.rotateGuidanceWidth, metrics.rotateGuidanceHeight)
		end
		combo.Size = UDim2.fromOffset(metrics.comboWidth, metrics.comboHeight)
		combo.Position = UDim2.new(0.5, 0, metrics.comboY, 0)

		if pad then
			pad.Size = UDim2.fromOffset(metrics.padWidth, metrics.padHeight)
			pad.Position = UDim2.new(0, 10, 1, -metrics.padBottomInset)
			pad.AnchorPoint = Vector2.new(0, 1)
			for index, entry in ipairs(padButtons) do
				local button = entry.instance
				button.Size = UDim2.fromOffset(metrics.padButtonSize, metrics.padButtonSize)
				if metrics.padMode == "row" then
					local text = entry.dir == "left" and "◀" or (entry.dir == "right" and "▶" or (entry.dir == "fwd" and "▲" or "▼"))
					button.Text = text
					button.AnchorPoint = Vector2.new(0.5, 0.5)
					button.Position = UDim2.new((index - 0.5) / 4, 0, 0.5, 0)
				else
					local positions = {
						fwd = UDim2.fromScale(0.5, 0.16),
						back = UDim2.fromScale(0.5, 0.84),
						left = UDim2.fromScale(0.16, 0.5),
						right = UDim2.fromScale(0.84, 0.5),
					}
					button.Text = entry.dir == "fwd" and "▲" or (entry.dir == "back" and "▼" or (entry.dir == "left" and "◀" or "▶"))
					button.AnchorPoint = Vector2.new(0.5, 0.5)
					button.Position = positions[entry.dir]
				end
			end
			if jumpButton then
				jumpButton.Size = UDim2.fromOffset(metrics.jumpSize, metrics.jumpSize)
				jumpButton.Position = UDim2.new(1, -12, 1, -metrics.jumpBottomInset)
				jumpButton.TextSize = Theme.resolveTextSize(16)
				jumpButton:SetAttribute("ThemeBaseTextSize", 16)
			end
		end
	end

	local api = { instance = frame }
	function api.show()
		frame.Visible = true
		api.reset()
	end
	function api.hide()
		frame.Visible = false
		for _, entry in ipairs(padButtons) do
			Components.releasePadButton(entry.instance)
		end
		for _, direction in ipairs({ "fwd", "back", "left", "right" }) do
			callbacks.onPad(direction, false)
		end
	end
	function api.reset()
		distance.value.Text = "0 m"
		score.value.Text = "0"
		acorns.setValue(0, false)
		combo.Visible = false
		comboFill.Size = UDim2.fromScale(1, 1)
	end
	function api.update(payload)
		local rows = tonumber(payload.rows) or 0
		local scoreValueNumber = tonumber(payload.score) or 0
		local acornCount = tonumber(payload.acorns) or 0
		distance.value.Text = ("%d m"):format(math.floor(rows * 1.12))
		score.value.Text = tostring(scoreValueNumber)
		acorns.setValue(acornCount)
		local multiplier = tonumber(payload.combo) or 1
		if multiplier > 1.001 then
			combo.Visible = true
			comboValue.Text = ("×%.1f"):format(multiplier)
			local timeFraction = math.clamp(tonumber(payload.comboTime) or 0, 0, 1)
			comboFill.Size = UDim2.fromScale(timeFraction, 1)
			comboFill.BackgroundColor3 = multiplier >= 3 and Theme.colors.danger or Theme.colors.gold
		else
			combo.Visible = false
		end
	end
	function api.layout(viewport: Vector2, insets)
		layout(viewport, insets)
	end

	layout(Vector2.new(1280, 720))
	return api
end

return HUD
