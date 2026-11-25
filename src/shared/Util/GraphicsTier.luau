--!nonstrict
-- Graphics tier: one of "low", "medium", "high".
--
-- Exists so a world's ambient particles and lighting can be scaled down on weak phones without any
-- world hand-tuning its own fallbacks. Every effect budget in WorldConfig is expressed against a
-- tier, and this module is the only place that decides which tier applies.
--
-- Detection is defensive. `UserSettings()` is a client-only global; on the server (where the test
-- suite runs) it does not exist, and a failing pcall must never take a frame down, so medium is the
-- fallback. A developer can force a tier with `game:SetAttribute("GraphicsTier", "low")`.

local GraphicsTier = {}

GraphicsTier.LOW = "low"
GraphicsTier.MEDIUM = "medium"
GraphicsTier.HIGH = "high"

local cached = nil

local function fromQuality(quality: number): string
	if quality <= 3 then
		return GraphicsTier.LOW
	elseif quality <= 6 then
		return GraphicsTier.MEDIUM
	end
	return GraphicsTier.HIGH
end

local function detectRaw(): string
	local ok, result = pcall(function()
		local userSettings = UserSettings()
		local gameSettings = userSettings:GetService("UserGameSettings")
		return gameSettings.SavedQualityLevel
	end)

	if not ok or result == nil then
		return GraphicsTier.MEDIUM
	end

	-- Enum.SavedQualitySetting.Automatic and the numbered levels share one enum; comparing by name
	-- avoids relying on an ordinal that Roblox could reorder.
	local name = tostring(result)
	if name == "Enum.SavedQualitySetting.Automatic" then
		return GraphicsTier.MEDIUM
	end

	local level = tonumber(name:match("(%d+)$"))
	if not level then
		return GraphicsTier.MEDIUM
	end

	return fromQuality(level)
end

function GraphicsTier.detect(): string
	local override = game:GetAttribute("GraphicsTier")
	if typeof(override) == "string" and (override == "low" or override == "medium" or override == "high") then
		return override
	end

	if cached then
		return cached
	end

	cached = detectRaw()
	return cached
end

-- Clears the memo. Called when the player changes their graphics setting, or by a test.
function GraphicsTier.refresh(): string
	cached = nil
	return GraphicsTier.detect()
end

-- Multiplier applied to an effect's configured rate. Low tier never goes fully silent — a world with
-- no atmosphere reads as unfinished — it just runs at a fraction of the rate.
function GraphicsTier.rateScale(tier: string?): number
	local resolved = tier or GraphicsTier.detect()
	if resolved == GraphicsTier.LOW then
		return 0.35
	elseif resolved == GraphicsTier.HIGH then
		return 1
	end
	return 0.65
end

-- Whether an optional second emitter (fireflies, heat shimmer) is worth its cost on this tier.
function GraphicsTier.allowAccents(tier: string?): boolean
	local resolved = tier or GraphicsTier.detect()
	return resolved ~= GraphicsTier.LOW
end

return GraphicsTier
