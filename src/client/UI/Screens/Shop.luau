--!nonstrict
-- Honest shop shell. No offer appears until a real shop service and configured platform ids exist.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.UIConfig)

local Theme = require(script.Parent.Parent.Theme)
local Components = require(script.Parent.Parent.Components)

local Shop = {}
local TABS = { "Acorns", "Golden", "Robux" }

function Shop.create(parent: Instance, callbacks): any
	local frame = Instance.new("Frame")
	frame.Name = "ShopScreen"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Theme.colors.bgDeep
	frame.Visible = false
	frame.Parent = parent

	local title = Components.label({ parent = frame, name = "Title", text = "SHOP", font = Theme.fonts.black, textSize = Theme.type.h1, color = Theme.colors.gold, position = UDim2.new(0.7, 0, 0.12, 0), anchor = Vector2.new(0.5, 0.5), size = UDim2.new(0.6, 0, 0, 48) })
	local back = Components.button({ parent = frame, name = "Back", text = "BACK", size = UDim2.fromOffset(116, 52), position = UDim2.new(0.08, 0, 0.10, 0), anchor = Vector2.new(0, 0.5), onClick = callbacks.onBack })

	local tabs = {}
	local selectedTab = TABS[1]
	local body = Components.panel({ name = "ShopBody", parent = frame, size = UDim2.new(0.9, 0, 0.58, 0), position = UDim2.fromScale(0.5, 0.51), anchor = Vector2.new(0.5, 0.5), color = Theme.colors.surface1, stroke = true })
	local message = Components.label({ name = "EmptyState", parent = body, text = "", font = Theme.fonts.bold, textSize = Theme.type.h2, color = Theme.colors.inkHigh, wrapped = true, position = UDim2.new(0.5, 0, 0.44, 0), anchor = Vector2.new(0.5, 0.5), size = UDim2.new(0.84, 0, 0, 100) })
	local note = Components.label({ name = "ShopNote", parent = body, text = "No purchase flow or offers are connected in this build.", font = Theme.fonts.medium, textSize = Theme.type.body, color = Theme.colors.inkMid, wrapped = true, position = UDim2.new(0.5, 0, 0.68, 0), anchor = Vector2.new(0.5, 0.5), size = UDim2.new(0.84, 0, 0, 60) })
	local tabRow = Instance.new("Frame")
	tabRow.Name = "ShopTabs"
	tabRow.BackgroundTransparency = 1
	tabRow.Size = UDim2.new(0.82, 0, 0, 60)
	tabRow.Position = UDim2.new(0.5, 0, 0.14, 0)
	tabRow.AnchorPoint = Vector2.new(0.5, 0.5)
	tabRow.Parent = body

	local function setTab(tabName: string)
		selectedTab = tabName
		message.Text = tabName == "Robux" and "Robux products are unavailable" or (tabName .. " offers are not configured")
		for name, handle in pairs(tabs) do
			handle.setSelected(name == selectedTab)
		end
	end

	for index, tabName in ipairs(TABS) do
		tabs[tabName] = Components.button({
			parent = tabRow,
			name = tabName .. "Tab",
			text = tabName,
			size = UDim2.new(0.32, 0, 1, 0),
			position = UDim2.new((index - 1) * 0.34, 0, 0, 0),
			anchor = Vector2.new(0, 0),
			onClick = function() setTab(tabName) end,
		})
	end

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
		body.Size = UDim2.new(portrait and 0.94 or 0.90, 0, compact and 0.68 or 0.62, 0)
		body.Position = UDim2.new(0.5, 0, compact and 0.60 or (portrait and 0.55 or 0.53), 0)
		tabRow.Size = UDim2.new(0.88, 0, 0, compact and 52 or 60)
		tabRow.Position = UDim2.new(0.5, 0, 0.15, 0)
		message.Position = UDim2.new(0.5, 0, compact and 0.43 or 0.44, 0)
		message.Size = UDim2.new(0.88, 0, 0, compact and 84 or 100)
		note.Position = UDim2.new(0.5, 0, compact and 0.72 or 0.70, 0)
		note.Size = UDim2.new(0.88, 0, 0, compact and 68 or 60)
	end

	local api = { instance = frame }
	function api.show() frame.Visible = true; setTab(selectedTab) end
	function api.hide() frame.Visible = false end
	function api.layout(viewport: Vector2, insets)
		layout(viewport, insets)
	end
	layout(Vector2.new(1280, 720))
	_ = note
	_ = back
	setTab(selectedTab)
	return api
end

return Shop
