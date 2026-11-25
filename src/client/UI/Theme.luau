--!nonstrict
-- UI facade for central tokens and responsive/accessibility helpers.
-- See docs/05_UI_UX_SPECIFICATION.md §2.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UIConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.UIConfig)

local Theme = {}
Theme.config = UIConfig
Theme.colors = UIConfig.colors
Theme.type = table.clone(UIConfig.type)
Theme.radius = UIConfig.radius
Theme.spacing = UIConfig.spacing
Theme.motion = UIConfig.motion
Theme.breakpoints = UIConfig.breakpoints
Theme.fonts = {
	black = Enum.Font.GothamBlack,
	bold = Enum.Font.GothamBold,
	medium = Enum.Font.GothamMedium,
	regular = Enum.Font.Gotham,
}

Theme.reducedMotion = false
Theme.textScale = 1

function Theme.scaleFor(viewport: Vector2 | number, viewportWidth: number?): number
	local size = typeof(viewport) == "Vector2" and viewport or Vector2.new(viewportWidth or viewport, viewport)
	return UIConfig.scaleFor(size)
end

function Theme.breakpointFor(viewport: Vector2): string
	return UIConfig.breakpointFor(viewport)
end

function Theme.duration(name: string): number
	local duration = UIConfig.motion[name] or UIConfig.motion.base
	if Theme.reducedMotion then
		return UIConfig.motion.instant
	end
	return duration
end

function Theme.tween(instance: Instance, duration: number, easingStyle, easingDirection, goals)
	if Theme.reducedMotion or duration <= 0 then
		for property, value in pairs(goals) do
			instance[property] = value
		end
		return nil
	end

	local tween = TweenService:Create(instance, TweenInfo.new(duration, easingStyle, easingDirection), goals)
	tween:Play()
	return tween
end

function Theme.setReducedMotion(enabled: boolean)
	Theme.reducedMotion = enabled == true
end

function Theme.setTextScale(scale: number)
	Theme.textScale = math.clamp(tonumber(scale) or 1, 0.9, 1.4)
end

function Theme.resolveTextSize(size: number): number
	return math.max(10, math.floor(size * Theme.textScale + 0.5))
end

function Theme.applyTextScale(root: Instance)
	for _, instance in ipairs(root:GetDescendants()) do
		if instance:IsA("TextLabel") or instance:IsA("TextButton") then
			local baseSize = instance:GetAttribute("ThemeBaseTextSize")
			if type(baseSize) == "number" then
				instance.TextSize = Theme.resolveTextSize(baseSize)
			end
		end
	end
end

return Theme
