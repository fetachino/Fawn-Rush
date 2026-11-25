--!nonstrict
-- Lighting and atmosphere baseline, applied at boot from Greenwood's profile.
--
-- This is the *lobby* rig only. Per-run lighting is applied client-side by
-- `client/Controllers/EnvironmentController`, because `Lighting` is shared replicated state and two
-- players in different worlds would otherwise fight over one rig. See `shared/World/EnvironmentRig`
-- for the single implementation both use, and docs/06 §6 for the palettes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldConfig = require(Shared.Config.WorldConfig)
local EnvironmentRig = require(Shared.World.EnvironmentRig)

local EnvironmentService = {}

function EnvironmentService.init()
	EnvironmentRig.apply(WorldConfig.get(WorldConfig.DEFAULT).lighting)
end

-- Needed if a future lobby ever shows a different world's backdrop.
function EnvironmentService.applyWorld(worldId: string)
	EnvironmentRig.apply(WorldConfig.get(worldId).lighting)
end

return EnvironmentService
