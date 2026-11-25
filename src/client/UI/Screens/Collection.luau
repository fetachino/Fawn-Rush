--!nonstrict
-- Roster catalogue: all species are previewable; ownership/equip state is intentionally not implied.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local AnimalConfig = require(Shared.Config.AnimalConfig)
local UIConfig = require(Shared.Config.UIConfig)

local Theme = require(script.Parent.Parent.Theme)
local Components = require(script.Parent.Parent.Components)
local ViewportPreview = require(script.Parent.Parent.ViewportPreview)

local Collection = {}

local function unlockText(animal): string
	local unlock = animal.unlock or {}
	if unlock.kind == "starter" then
		return "Starter species"
	elseif unlock.kind == "acorns" then
		return ("Catalog requirement: %s acorns"):format(UIConfig.formatNumber(unlock.price or 0))
	end
	return unlock.text or "Unlock details are not available"
end

function Collection.create(parent: Instance, callbacks): any
	local frame = Instance.new("Frame")
	frame.Name = "CollectionScreen"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Theme.colors.bgDeep
	frame.Visible = false
	frame.Parent = parent

	local title = Components.label({ parent = frame, name = "Title", text = "ANIMAL ROSTER", font = Theme.fonts.black, textSize = Theme.type.h1, color = Theme.colors.gold, position = UDim2.new(0.7, 0, 0.1, 0), anchor = Vector2.new(0.5, 0.5), size = UDim2.new(0.6, 0, 0, 44) })
	local back = Components.button({ parent = frame, name = "Back", text = "BACK", size = UDim2.fromOffset(116, 52), position = UDim2.new(0.08, 0, 0.09, 0), anchor = Vector2.new(0, 0.5), onClick = callbacks.onBack })
	local notice = Components.label({ parent = frame, name = "CatalogueNotice", text = "13 species · catalogue preview only · ownership is not active", font = Theme.fonts.medium, textSize = Theme.type.small, color = Theme.colors.inkMid, position = UDim2.new(0.5, 0, 0.17, 0), anchor = Vector2.new(0.5, 0.5), size = UDim2.new(0.92, 0, 0, 26) })

	local grid = Instance.new("ScrollingFrame")
	grid.Name = "RosterGrid"
	grid.Size = UDim2.new(0.92, 0, 0.70, 0)
	grid.Position = UDim2.new(0.5, 0, 0.60, 0)
	grid.AnchorPoint = Vector2.new(0.5, 0.5)
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.CanvasSize = UDim2.new(0, 0, 0, 0)
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.ScrollingDirection = Enum.ScrollingDirection.Y
	grid.ScrollBarThickness = 6
	grid.Parent = frame
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, Theme.spacing[2])
	padding.PaddingRight = UDim.new(0, Theme.spacing[2])
	padding.PaddingTop = UDim.new(0, Theme.spacing[2])
	padding.PaddingBottom = UDim.new(0, Theme.spacing[2])
	padding.Parent = grid
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.fromOffset(148, 112)
	gridLayout.CellPadding = UDim2.fromOffset(Theme.spacing[2], Theme.spacing[2])
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid

	local detail = Components.panel({ name = "SpeciesDetail", parent = frame, size = UDim2.new(0.90, 0, 0.82, 0), position = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5), color = Theme.colors.bgBase, stroke = true, strokeColor = Theme.colors.gold })
	detail.Visible = false
	local detailConstraint = Instance.new("UISizeConstraint")
	detailConstraint.MinSize = Vector2.new(280, 340)
	detailConstraint.MaxSize = Vector2.new(560, 600)
	detailConstraint.Parent = detail
	local detailName = Components.label({ parent = detail, name = "Name", text = "", font = Theme.fonts.black, textSize = Theme.type.h2, color = Theme.colors.inkHigh, position = UDim2.new(0.5, 0, 0.08, 0), anchor = Vector2.new(0.5, 0.5), size = UDim2.new(0.86, 0, 0, 40) })
	local previewHost = Instance.new("Frame")
	previewHost.Name = "PreviewHost"
	previewHost.Size = UDim2.new(0.72, 0, 0.34, 0)
	previewHost.Position = UDim2.new(0.5, 0, 0.33, 0)
	previewHost.AnchorPoint = Vector2.new(0.5, 0.5)
	previewHost.BackgroundTransparency = 1
	previewHost.Parent = detail
	local rarity = Components.label({ parent = detail, name = "Rarity", text = "", font = Theme.fonts.bold, textSize = Theme.type.small, color = Theme.colors.gold, position = UDim2.new(0.5, 0, 0.56, 0), anchor = Vector2.new(0.5, 0.5), size = UDim2.new(0.86, 0, 0, 26) })
	local description = Components.label({ parent = detail, name = "Description", text = "", font = Theme.fonts.medium, textSize = Theme.type.body, color = Theme.colors.inkMid, wrapped = true, position = UDim2.new(0.5, 0, 0.67, 0), anchor = Vector2.new(0.5, 0.5), size = UDim2.new(0.86, 0, 0, 52) })
	local unlock = Components.label({ parent = detail, name = "UnlockInfo", text = "", font = Theme.fonts.medium, textSize = Theme.type.small, color = Theme.colors.inkLow, wrapped = true, position = UDim2.new(0.5, 0, 0.79, 0), anchor = Vector2.new(0.5, 0.5), size = UDim2.new(0.86, 0, 0, 42) })
	local preview = nil
	local unavailableMessage = nil
	local selectedSpeciesId = nil
	local speciesButtons = {}
	local detailBack = Components.button({
		parent = detail, name = "CloseDetail", text = "CLOSE", size = UDim2.fromOffset(140, 48),
		position = UDim2.new(0.5, 0, 0.93, 0),
		onClick = function()
			detail.Visible = false
			if preview then preview.release(); preview = nil end
			if unavailableMessage then unavailableMessage:Destroy(); unavailableMessage = nil end
			local speciesButton = selectedSpeciesId and speciesButtons[selectedSpeciesId]
			if UserInputService.GamepadEnabled and speciesButton then
				GuiService.SelectedObject = speciesButton.instance
			end
		end,
	})

	local function showAnimal(animalId: string)
		local animal = AnimalConfig.animals[animalId]
		if not animal then
			return
		end
		selectedSpeciesId = animalId
		if preview then
			preview.release()
			preview = nil
		end
		if unavailableMessage then
			unavailableMessage:Destroy()
			unavailableMessage = nil
		end
		detailName.Text = animal.name
		rarity.Text = (UIConfig.rarityShapes[animal.rarity] or "●") .. "  " .. animal.rarity
		description.Text = animal.description .. "\n" .. animal.personality
		unlock.Text = unlockText(animal) .. " · Equipping is not connected yet"
		detail.Visible = true
		if UserInputService.GamepadEnabled then
			GuiService.SelectedObject = detailBack.instance
		end
		local previewError
		preview, previewError = ViewportPreview.create(previewHost, animalId)
		if not preview then
			local message = previewError == "Preview limit reached"
				and "Preview capacity reached. Close another preview to continue."
				or "This animal preview is temporarily unavailable."
			unavailableMessage = Components.label({ parent = previewHost, name = "PreviewUnavailable", text = message, font = Theme.fonts.medium, textSize = Theme.type.small, color = Theme.colors.inkLow, wrapped = true })
		end
	end

	for index, animalId in ipairs(AnimalConfig.ORDER) do
		local animal = AnimalConfig.animals[animalId]
		local badgeColor = AnimalConfig.RARITY[animal.rarity].color
		local button = Components.button({
			parent = grid,
			name = "Species_" .. animalId,
			text = animal.name .. "\n" .. (UIConfig.rarityShapes[animal.rarity] or "●") .. "  " .. animal.rarity,
			textSize = Theme.type.small,
			textColor = badgeColor,
			wrapped = true,
			size = UDim2.fromOffset(148, 112),
			onClick = function() showAnimal(animalId) end,
		})
		button.instance.LayoutOrder = index
		speciesButtons[animalId] = button
	end

	local function layout(viewport: Vector2, insets)
		local metrics = UIConfig.safeFrameMetrics(viewport, insets)
		local portrait = metrics.portrait
		local compact = metrics.compact
		local columns = not compact and metrics.width >= 900 and 4 or 2
		local gridWidth = metrics.width * 0.94
		local cellWidth = math.floor((gridWidth - 16 - (columns - 1) * 8) / columns)
		cellWidth = math.clamp(cellWidth, 112, 250)

		title.Position = UDim2.new(0.5, 0, compact and 0.18 or 0.14, 0)
		title.Size = UDim2.new(portrait and 0.78 or 0.62, 0, 0, compact and 38 or 44)
		title.TextSize = Theme.resolveTextSize(compact and Theme.type.h2 or Theme.type.h1)
		title:SetAttribute("ThemeBaseTextSize", compact and Theme.type.h2 or Theme.type.h1)
		back.instance.Position = UDim2.new(0.04, 0, 0.07, 0)
		back.instance.Size = UDim2.fromOffset(compact and 96 or 116, compact and 44 or 52)
		notice.Position = UDim2.new(0.5, 0, compact and 0.26 or 0.20, 0)
		notice.Size = UDim2.new(0.94, 0, 0, compact and 30 or 26)
		grid.Size = UDim2.new(0.94, 0, compact and 0.66 or 0.72, 0)
		grid.Position = UDim2.new(0.5, 0, compact and 0.63 or 0.60, 0)
		gridLayout.CellSize = UDim2.fromOffset(cellWidth, math.floor(cellWidth * 0.76))
		gridLayout.CellPadding = UDim2.fromOffset(8, 8)
		gridLayout.FillDirectionMaxCells = columns
		gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		detail.Size = UDim2.new(portrait and 0.96 or 0.88, 0, compact and 0.92 or 0.86, 0)
		detailConstraint.MinSize = compact and Vector2.new(260, 320) or Vector2.new(280, 340)
		detailConstraint.MaxSize = Vector2.new(560, 600)
		previewHost.Size = UDim2.new(portrait and 0.70 or 0.58, 0, compact and 0.30 or 0.34, 0)
		previewHost.Position = UDim2.new(0.5, 0, compact and 0.32 or 0.33, 0)
	end

	local api = { instance = frame }
	function api.show()
		detail.Visible = false
		frame.Visible = true
	end
	function api.hide()
		frame.Visible = false
		detail.Visible = false
		if preview then
			preview.release()
			preview = nil
		end
		if unavailableMessage then
			unavailableMessage:Destroy()
			unavailableMessage = nil
		end
	end
	function api.layout(viewport: Vector2, insets)
		layout(viewport, insets)
	end

	layout(Vector2.new(1280, 720))
	_ = description
	_ = unlock
	_ = detailBack
	_ = back
	_ = title
	_ = notice
	return api
end

return Collection
