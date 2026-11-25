--!nonstrict
-- Central UI tokens and pure helpers. Screens consume this through client/UI/Theme.
-- See docs/05_UI_UX_SPECIFICATION.md §2.

local UIConfig = {}

UIConfig.colors = {
	bgDeep = Color3.fromRGB(14, 26, 20),
	bgBase = Color3.fromRGB(22, 38, 29),
	surface1 = Color3.fromRGB(31, 51, 39),
	surface2 = Color3.fromRGB(41, 65, 47),
	surface3 = Color3.fromRGB(52, 81, 59),
	lineSoft = Color3.fromRGB(62, 90, 70),
	inkHigh = Color3.fromRGB(255, 246, 228),
	inkMid = Color3.fromRGB(201, 214, 196),
	inkLow = Color3.fromRGB(143, 162, 146),
	gold = Color3.fromRGB(242, 179, 61),
	moss = Color3.fromRGB(78, 122, 58),
	sky = Color3.fromRGB(127, 200, 248),
	success = Color3.fromRGB(87, 184, 90),
	warn = Color3.fromRGB(242, 163, 60),
	-- Darkened from the legacy UI red so small white labels meet the contrast lock.
	danger = Color3.fromRGB(188, 62, 47),
	scrim = Color3.fromRGB(4, 16, 10),
	bark = Color3.fromRGB(43, 33, 25),
	white = Color3.new(1, 1, 1),
}

UIConfig.type = {
	display = 44,
	h1 = 30,
	h2 = 23,
	h3 = 19,
	body = 16,
	bodyStrong = 16,
	small = 14,
	tiny = 12,
	number = 22,
}

UIConfig.spacing = { 4, 8, 12, 16, 24, 32, 48, 64 }
UIConfig.radius = { sm = 8, md = 14, lg = 22, pill = 999 }
UIConfig.stroke = { width = 1, focus = 2 }
UIConfig.elevation = {
	{ offsetY = 2, blur = 8, alpha = 0.20 },
	{ offsetY = 6, blur = 18, alpha = 0.28 },
	{ offsetY = 12, blur = 32, alpha = 0.36 },
}
UIConfig.motion = {
	instant = 0.08,
	fast = 0.12,
	base = 0.18,
	slow = 0.28,
	cinematic = 0.42,
	pressIn = 0.07,
	pressOut = 0.11,
}
UIConfig.breakpoints = { compactHeight = 420, expandedHeight = 720 }
UIConfig.preview = { maxLiveModels = 4 }
UIConfig.rarityShapes = {
	Common = "●",
	Uncommon = "◆",
	Rare = "▲",
	Epic = "■",
	Legendary = "⬟",
	Mythic = "✦",
	Secret = "◇",
}

local function linear(channel: number): number
	if channel <= 0.04045 then
		return channel / 12.92
	end
	return ((channel + 0.055) / 1.055) ^ 2.4
end

function UIConfig.contrastRatio(foreground: Color3, background: Color3): number
	local function luminance(color: Color3): number
		return 0.2126 * linear(color.R) + 0.7152 * linear(color.G) + 0.0722 * linear(color.B)
	end

	local first = luminance(foreground)
	local second = luminance(background)
	local lighter = math.max(first, second)
	local darker = math.min(first, second)
	return (lighter + 0.05) / (darker + 0.05)
end

function UIConfig.breakpointFor(viewport: Vector2): string
	if viewport.Y < UIConfig.breakpoints.compactHeight then
		return "compact"
	elseif viewport.Y < UIConfig.breakpoints.expandedHeight then
		return "regular"
	end
	return "expanded"
end

function UIConfig.scaleFor(viewport: Vector2): number
	local byHeight = math.clamp(viewport.Y / 720, 0.78, 1.5)
	local byWidth = math.clamp(viewport.X / 430, 0.78, 1.5)
	return math.min(byHeight, byWidth)
end

function UIConfig.safeFrameMetrics(viewport: Vector2, insets)
	local scale = UIConfig.scaleFor(viewport)
	local leftInset = insets and (tonumber(insets.left) or 0) or 0
	local topInset = insets and (tonumber(insets.top) or 0) or 0
	local rightInset = insets and (tonumber(insets.right) or 0) or 0
	local bottomInset = insets and (tonumber(insets.bottom) or 0) or 0
	return {
		scale = scale,
		width = math.max(0, (viewport.X - leftInset - rightInset - 24) / scale),
		height = math.max(0, (viewport.Y - topInset - bottomInset - 24) / scale),
		portrait = viewport.X < viewport.Y,
		compact = UIConfig.breakpointFor(viewport) == "compact",
	}
end

-- Coordinates are logical to the scaled safe frame. Insets are physical screen pixels supplied by
-- GuiService, followed by the UI's own 12 px safety padding.
function UIConfig.hudLayout(viewport: Vector2, hasTouch: boolean, insets)
	local frameMetrics = UIConfig.safeFrameMetrics(viewport, insets)
	local scale = frameMetrics.scale
	local leftInset = insets and (tonumber(insets.left) or 0) or 0
	local topInset = insets and (tonumber(insets.top) or 0) or 0
	local safeLeft = leftInset + 12
	local safeTop = topInset + 12
	local safeWidth = frameMetrics.width
	local safeHeight = frameMetrics.height
	local portrait = viewport.X < viewport.Y
	local compact = UIConfig.breakpointFor(viewport) == "compact"
	local compactLandscape = compact and not portrait
	local compactControls = compact
	local cardWidth = portrait and 108 or (compact and 124 or 142)
	local cardHeight = portrait and 50 or (compact and 48 or 56)
	local acornWidth = cardWidth
	local acornHeight = portrait and 42 or (compact and 42 or 46)
	local distanceY = 0.018
	local scoreY = compactLandscape and distanceY or (portrait and 0.095 or 0.105)
	local scoreX = compactLandscape and (cardWidth + 16) or 8
	local comboWidth = portrait and 104 or (compact and 120 or 154)
	local comboHeight = portrait and 42 or 48
	local layout = {
		scale = scale,
		portrait = portrait,
		compact = compact,
		compactLandscape = compactLandscape,
		cardWidth = cardWidth,
		cardHeight = cardHeight,
		acornWidth = acornWidth,
		acornHeight = acornHeight,
		distanceX = 8,
		distanceY = distanceY,
		scoreX = scoreX,
		scoreY = scoreY,
		acornRightInset = 8,
		comboWidth = comboWidth,
		comboHeight = comboHeight,
		comboY = 0.018,
	}

	local function pixelRect(x: number, y: number, width: number, height: number)
		return {
			x = safeLeft + x * scale,
			y = safeTop + y * scale,
			width = width * scale,
			height = height * scale,
		}
	end

	local rects = {
		distance = pixelRect(layout.distanceX, safeHeight * distanceY, cardWidth, cardHeight),
		score = pixelRect(scoreX, safeHeight * scoreY, cardWidth, cardHeight),
		acorns = pixelRect(safeWidth - 8 - acornWidth, safeHeight * distanceY, acornWidth, acornHeight),
		combo = pixelRect((safeWidth - comboWidth) * 0.5, safeHeight * layout.comboY, comboWidth, comboHeight),
	}

	if portrait then
		local guidanceX = scoreX + cardWidth + 8
		local guidanceRight = safeWidth - layout.acornRightInset - acornWidth - 8
		local guidanceWidth = math.max(0, guidanceRight - guidanceX)
		local guidanceY = math.max(
			safeHeight * scoreY,
			safeHeight * layout.comboY + comboHeight + 8
		)
		layout.rotateGuidanceX = guidanceX
		layout.rotateGuidanceY = guidanceY
		layout.rotateGuidanceWidth = guidanceWidth
		layout.rotateGuidanceHeight = 28
		rects.rotateGuidance = pixelRect(guidanceX, guidanceY, guidanceWidth, layout.rotateGuidanceHeight)
	end

	if hasTouch then
		local diameter = nil
		if not compactControls then
			diameter = math.max(
				math.clamp(viewport.Y * 0.14 / scale, 96, 168),
				(44 / scale) / 0.32
			)
		end
		local padHeight = compactControls and (44 / scale) or diameter
		local padWidth = compactControls and (padHeight * 4) or diameter
		local buttonSize = compactControls and padHeight or diameter * 0.32
		local padBottomInset = 0
		local jumpSize = math.clamp((diameter or (44 / scale)) * 0.38, 44 / scale, 64 / scale)
		local jumpBottomInset = 12
		layout.padMode = compactControls and "row" or "cross"
		layout.padWidth = padWidth
		layout.padHeight = padHeight
		layout.padButtonSize = buttonSize
		layout.padBottomInset = padBottomInset
		layout.jumpSize = jumpSize
		layout.jumpBottomInset = jumpBottomInset
		rects.pad = pixelRect(10, safeHeight - padBottomInset - padHeight, padWidth, padHeight)
		rects.jump = pixelRect(safeWidth - 12 - jumpSize, safeHeight - jumpBottomInset - jumpSize, jumpSize, jumpSize)
	end

	layout.rects = rects
	return layout
end

-- Layout guard shared by the design checks and Studio verification. Rect coordinates are pixels.
function UIConfig.hudRectIsOutsideProtectedBand(rect, viewport: Vector2): boolean
	if viewport.Y <= 0 or rect.height < 0 or rect.y < 0 then
		return false
	end
	local top = rect.y / viewport.Y
	local bottom = (rect.y + rect.height) / viewport.Y
	return bottom <= 0.22 or top >= 0.78
end

function UIConfig.formatNumber(value: number): string
	local amount = math.floor(tonumber(value) or 0)
	local sign = amount < 0 and "-" or ""
	local absolute = math.abs(amount)
	if absolute >= 1000000 then
		return ("%s%.1fM"):format(sign, absolute / 1000000)
	elseif absolute >= 10000 then
		return ("%s%.1fK"):format(sign, absolute / 1000)
	end

	local digits = tostring(absolute)
	local formatted = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return sign .. formatted
end

function UIConfig.validate(): { string }
	local problems = {}
	local colors = UIConfig.colors
	local contrastLocks = {
		{ "inkHigh on bgBase", colors.inkHigh, colors.bgBase, 7 },
		{ "inkMid on surface1", colors.inkMid, colors.surface1, 4.5 },
		{ "bark on gold", colors.bark, colors.gold, 4.5 },
		{ "white on danger", colors.white, colors.danger, 4.5 },
		{ "inkLow on surface2 control border", colors.inkLow, colors.surface2, 3 },
	}

	for _, lock in ipairs(contrastLocks) do
		if UIConfig.contrastRatio(lock[2], lock[3]) < lock[4] then
			problems[#problems + 1] = ("contrast lock '%s' is below %.1f:1"):format(lock[1], lock[4])
		end
	end

	for index, value in ipairs(UIConfig.spacing) do
		if type(value) ~= "number" or value <= 0 then
			problems[#problems + 1] = ("spacing token %d is not positive"):format(index)
		end
	end
	for name, size in pairs(UIConfig.type) do
		if type(size) ~= "number" or size < 12 then
			problems[#problems + 1] = ("type token '%s' is below the 12 px minimum"):format(name)
		end
	end

	for rarity, shape in pairs(UIConfig.rarityShapes) do
		if type(shape) ~= "string" or shape == "" then
			problems[#problems + 1] = ("rarity '%s' has no non-colour shape"):format(rarity)
		end
	end

	if UIConfig.preview.maxLiveModels ~= 4 then
		problems[#problems + 1] = "viewport preview budget must remain at four live models"
	end

	return problems
end

return UIConfig
