--!nonstrict
-- EnvironmentController: applies a run's world lighting, locally.
--
-- `Lighting` is shared replicated state. If the server set it per run, two players in different
-- worlds would fight over one rig. A client-side change to a replicated instance stays local, so
-- each player sees their own world and nobody else's — this is why the per-run rig lives here and
-- the server only owns the lobby baseline (`EnvironmentService`).
--
-- The actual property assignment is `shared/World/EnvironmentRig`, shared with the server so the two
-- can never drift apart.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldConfig = require(Shared.Config.WorldConfig)
local EnvironmentRig = require(Shared.World.EnvironmentRig)

local SessionController = require(script.Parent.SessionController)

local EnvironmentController = {}

-- Restored on every return to the lobby, so leaving a Neon run does not leave the lobby dark.
local lobbySpec = WorldConfig.get(WorldConfig.DEFAULT).lighting

function EnvironmentController.init() end

function EnvironmentController.start()
	SessionController.signals.runStarted:Connect(function(payload)
		local world = WorldConfig.get(payload.worldId)
		EnvironmentRig.apply(world.lighting)
	end)

	SessionController.signals.returnedToLobby:Connect(function()
		EnvironmentRig.apply(lobbySpec)
	end)
end

function EnvironmentController.update() end

-- Lets a future settings screen preview a world's lighting without starting a run.
function EnvironmentController.preview(worldId: string)
	EnvironmentRig.apply(WorldConfig.get(worldId).lighting)
end

return EnvironmentController
