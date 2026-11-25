--!nonstrict
-- World selection is presentation-only unless progression enforcement is enabled with a real profile.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldConfig = require(Shared.Config.WorldConfig)
local GameConfig = require(Shared.Config.GameConfig)
local WorldUnlock = require(Shared.Simulation.WorldUnlock)
local UIConfig = require(Shared.Config.UIConfig)

local Theme = require(script.Parent.Parent.Theme)
local Components = require(script.Parent.Parent.Components)

local RunSelect = {}

function RunSelect.create(parent: Instance, callbacks): any
	local frame = Instance.new("Frame")
	frame.Name = "RunSelectScreen"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Theme.colors.bgDeep
	frame.BackgroundTransparency = 0.08
	frame.Visible = false
	frame.Parent = parent

	local title = Components.label({
		parent = frame,
		name = "Title",
		text = "CHOOSE A WORLD",
		font = Theme.fonts.black,
		textSize = Theme.type.h1,
		color = Theme.colors.gold,
		position = UDim2.new(0.7, 0, 0.12, 0),
		anchor = Vector2.new(0.5, 0.5),
		size = UDim2.new(0.6, 0, 0, 48),
	})

	local card = Components.panel({
		name = "WorldCard",
		parent = frame,
		size = UDim2.new(0.88, 0, 0.43, 0),
		position = UDim2.fromScale(0.5, 0.48),
		anchor = Vector2.new(0.5, 0.5),
		color = Theme.colors.surface1,
		stroke = true,
		strokeColor = Theme.colors.lineSoft,
	})
	local cardConstraint = Instance.new("UISizeConstraint")
	cardConstraint.MinSize = Vector2.new(270, 250)
	cardConstraint.MaxSize = Vector2.new(620, 360)
	cardConstraint.Parent = card

	local name = Components.label({
		name = "WorldName",
		parent = card,
		text = "",
		font = Theme.fonts.black,
		textSize = Theme.type.h2,
		color = Theme.colors.inkHigh,
		position = UDim2.new(0.5, 0, 0.18, 0),
		anchor = Vector2.new(0.5, 0.5),
		size = UDim2.new(0.92, 0, 0, 36),
	})
	local blurb = Components.label({
		name = "WorldBlurb",
		parent = card,
		text = "",
		font = Theme.fonts.medium,
		textSize = Theme.type.body,
		color = Theme.colors.inkMid,
		wrapped = true,
		position = UDim2.new(0.5, 0, 0.42, 0),
		anchor = Vector2.new(0.5, 0.5),
		size = UDim2.new(0.86, 0, 0, 74),
	})
	local details = Components.label({
		name = "WorldDetails",
		parent = card,
		text = "",
		font = Theme.fonts.bold,
		textSize = Theme.type.small,
		color = Theme.colors.gold,
		wrapped = true,
		position = UDim2.new(0.5, 0, 0.73, 0),
		anchor = Vector2.new(0.5, 0.5),
		size = UDim2.new(0.9, 0, 0, 48),
	})
	local status = Components.label({
		name = "WorldStatus",
		parent = frame,
		text = "",
		font = Theme.fonts.medium,
		textSize = Theme.type.small,
		color = Theme.colors.inkLow,
		position = UDim2.new(0.5, 0, 0.76, 0),
		anchor = Vector2.new(0.5, 0.5),
		size = UDim2.new(0.9, 0, 0, 28),
	})

	local currentIndex = 1
	local currentId = WorldConfig.DEFAULT
	local previous = Components.button({
		name = "PreviousWorld",
		parent = frame,
		text = "‹",
		size = UDim2.fromOffset(64, 64),
		position = UDim2.new(0.12, 0, 0.48, 0),
		onClick = function()
			currentIndex = (currentIndex - 2) % #WorldConfig.ORDER + 1
			currentId = WorldConfig.ORDER[currentIndex]
			callbacks.onSelect(currentId)
		end,
	})
	local nextWorld = Components.button({
		name = "NextWorld",
		parent = frame,
		text = "›",
		size = UDim2.fromOffset(64, 64),
		position = UDim2.new(0.88, 0, 0.48, 0),
		onClick = function()
			currentIndex = currentIndex % #WorldConfig.ORDER + 1
			currentId = WorldConfig.ORDER[currentIndex]
			callbacks.onSelect(currentId)
		end,
	})

	local start = Components.button({
		name = "StartRun",
		parent = frame,
		text = "START RUN",
		variant = "primary",
		size = UDim2.new(0.55, 0, 0, 66),
		position = UDim2.new(0.5, 0, 0.88, 0),
		onClick = function()
			if not start.instance.Active then
				return
			end
			callbacks.onPlay(currentId)
		end,
	})
	local back = Components.button({
		name = "Back",
		parent = frame,
		text = "BACK",
		size = UDim2.fromOffset(116, 52),
		position = UDim2.new(0.08, 0, 0.10, 0),
		anchor = Vector2.new(0, 0.5),
		onClick = callbacks.onBack,
	})

	local function refresh(worldId: string)
		local world = WorldConfig.get(worldId)
		currentId = world.id
		for index, id in ipairs(WorldConfig.ORDER) do
			if id == currentId then
				currentIndex = index
				break
			end
		end

		name.Text = world.name
		blurb.Text = world.blurb
		details.Text = ("Traffic %d–%d studs/s   ·   %d-row ramp"):format(world.vMin, world.vMax, world.rampRows)
		local unlocked = WorldUnlock.isUnlocked(world.id, WorldUnlock.EMPTY_PROGRESS)
		local playable = not GameConfig.WORLD_UNLOCK_ENFORCED or unlocked
		status.Text = playable and "World profile preview · selection is available in this build" or ("Unlock: " .. WorldUnlock.describe(world.id))
		start.setEnabled(playable)
	end

	local function layout(viewport: Vector2, insets)
		local metrics = UIConfig.safeFrameMetrics(viewport, insets)
		local compact = metrics.compact
		local portrait = metrics.portrait

		title.Position = UDim2.new(0.5, 0, portrait and (compact and 0.18 or 0.15) or (compact and 0.18 or 0.12), 0)
		title.Size = UDim2.new(portrait and 0.9 or 0.6, 0, 0, compact and 40 or 48)
		title.TextSize = Theme.resolveTextSize(compact and Theme.type.h2 or Theme.type.h1)
		title:SetAttribute("ThemeBaseTextSize", compact and Theme.type.h2 or Theme.type.h1)
		back.instance.Position = UDim2.new(0.05, 0, 0.07, 0)
		back.instance.Size = UDim2.fromOffset(compact and 100 or 116, compact and 46 or 52)
		card.Size = UDim2.new(portrait and 0.90 or 0.88, 0, compact and 0.42 or 0.43, 0)
		card.Position = UDim2.new(0.5, 0, portrait and 0.49 or 0.48, 0)
		cardConstraint.MinSize = compact and Vector2.new(220, 210) or Vector2.new(270, 250)
		cardConstraint.MaxSize = Vector2.new(620, 360)
		name.Size = UDim2.new(0.84, 0, 0, compact and 32 or 36)
		name.Position = UDim2.new(0.5, 0, 0.17, 0)
		blurb.Size = UDim2.new(0.82, 0, 0, compact and 62 or 74)
		blurb.Position = UDim2.new(0.5, 0, 0.42, 0)
		details.Size = UDim2.new(0.84, 0, 0, compact and 42 or 48)
		details.Position = UDim2.new(0.5, 0, 0.73, 0)
		status.Position = UDim2.new(0.5, 0, 0.77, 0)
		status.Size = UDim2.new(0.9, 0, 0, compact and 34 or 28)
		previous.instance.Size = UDim2.fromOffset(compact and 48 or 64, compact and 48 or 64)
		previous.instance.Position = UDim2.new(portrait and 0.08 or 0.12, 0, 0.48, 0)
		nextWorld.instance.Size = UDim2.fromOffset(compact and 48 or 64, compact and 48 or 64)
		nextWorld.instance.Position = UDim2.new(portrait and 0.92 or 0.88, 0, 0.48, 0)
		start.instance.Size = UDim2.new(portrait and 0.68 or 0.55, 0, 0, compact and 56 or 66)
		start.instance.Position = UDim2.new(0.5, 0, compact and 0.90 or 0.88, 0)
	end

	local api = { instance = frame }
	function api.show(worldId: string?)
		refresh(worldId or currentId)
		frame.Visible = true
	end
	function api.hide()
		frame.Visible = false
	end
	function api.setWorld(worldId: string)
		refresh(worldId)
	end
	function api.currentWorld(): string
		return currentId
	end
	function api.layout(viewport: Vector2, insets)
		layout(viewport, insets)
	end

	layout(Vector2.new(1280, 720))
	_ = previous
	_ = nextWorld
	_ = back
	refresh(currentId)
	return api
end

return RunSelect
