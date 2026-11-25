--!nonstrict
-- The lighting rig, applied from a world's `lighting` profile.
--
-- One implementation, two callers:
--   * `server/Services/EnvironmentService` applies Greenwood at boot, which becomes the replicated
--     baseline every client starts from (the lobby).
--   * `client/Controllers/EnvironmentController` applies the run's world locally.
--
-- Why the client owns per-run lighting: `Lighting` is shared state. If the server set it per run, two
-- players in different worlds would fight over one rig and the last writer would win. A client-side
-- change to a replicated instance stays local, so each player sees their own world and nobody else's.
--
-- Everything is created or updated by name, so re-applying a world twice is free and nothing is ever
-- duplicated in the Lighting service.

local Lighting = game:GetService("Lighting")

local EnvironmentRig = {}

local ATMOSPHERE = "FawnAtmosphere"
local BLOOM = "FawnBloom"
local GRADE = "FawnGrade"
local SUNRAYS = "FawnSunRays"

local function ensure(className: string, name: string)
	local existing = Lighting:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	if existing then
		existing:Destroy()
	end

	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = Lighting
	return instance
end

-- Returns nil when the world has no sun rays configured *and* the effect should be absent.
local function applySunRays(spec)
	local sunRays = Lighting:FindFirstChild(SUNRAYS)
	if not spec then
		if sunRays then
			sunRays:Destroy()
		end
		return
	end

	local effect = ensure("SunRaysEffect", SUNRAYS)
	effect.Intensity = spec.intensity or 0.1
	effect.Spread = spec.spread or 0.5
end

function EnvironmentRig.apply(spec)
	if type(spec) ~= "table" then
		return
	end

	Lighting.ClockTime = spec.clockTime or 15.5
	Lighting.Brightness = spec.brightness or 2
	Lighting.ExposureCompensation = spec.exposure or 0
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = spec.shadowSoftness or 0.4
	Lighting.EnvironmentDiffuseScale = spec.diffuse or 0.4
	Lighting.EnvironmentSpecularScale = spec.specular or 0.3
	Lighting.Ambient = spec.ambient or Color3.fromRGB(96, 104, 78)
	Lighting.OutdoorAmbient = spec.outdoorAmbient or Color3.fromRGB(128, 140, 112)
	Lighting.FogStart = spec.fogStart or 0
	Lighting.FogEnd = spec.fogEnd or 9000
	Lighting.FogColor = spec.fogColor or Color3.fromRGB(199, 223, 236)

	local atmosphereSpec = spec.atmosphere
	if atmosphereSpec then
		local atmosphere = ensure("Atmosphere", ATMOSPHERE)
		atmosphere.Density = atmosphereSpec.density or 0.3
		atmosphere.Offset = atmosphereSpec.offset or 0.2
		atmosphere.Color = atmosphereSpec.color or Color3.fromRGB(199, 223, 236)
		atmosphere.Decay = atmosphereSpec.decay or Color3.fromRGB(106, 132, 96)
		atmosphere.Glare = atmosphereSpec.glare or 0.1
		atmosphere.Haze = atmosphereSpec.haze or 1.5
	end

	local bloomSpec = spec.bloom
	if bloomSpec then
		local bloom = ensure("BloomEffect", BLOOM)
		bloom.Intensity = bloomSpec.intensity or 0.3
		bloom.Size = bloomSpec.size or 18
		bloom.Threshold = bloomSpec.threshold or 1.6
	end

	local gradeSpec = spec.grade
	if gradeSpec then
		local grade = ensure("ColorCorrectionEffect", GRADE)
		grade.Brightness = gradeSpec.brightness or 0
		grade.Contrast = gradeSpec.contrast or 0
		grade.Saturation = gradeSpec.saturation or 0
		grade.TintColor = gradeSpec.tint or Color3.fromRGB(255, 255, 255)
	end

	applySunRays(spec.sunRays)
end

-- Every instance this rig owns, for a clean teardown in a test or a future world transition screen.
function EnvironmentRig.teardown()
	for _, name in ipairs({ ATMOSPHERE, BLOOM, GRADE, SUNRAYS }) do
		local existing = Lighting:FindFirstChild(name)
		if existing then
			existing:Destroy()
		end
	end
end

return EnvironmentRig
