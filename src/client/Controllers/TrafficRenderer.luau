--!nonstrict
-- Traffic rendering. Lane definitions arrive with each chunk; every visible vehicle position is
-- evaluated locally from the shared closed-form simulation at the current server time, so traffic
-- costs no per-frame bandwidth and is identical on every client.
-- See docs/02_TECHNICAL_ARCHITECTURE.md §5.2.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local TrafficSim = require(Shared.Simulation.TrafficSim)

local SessionController = require(script.Parent.SessionController)
local VehiclePool = require(script.Parent.Parent.Builders.VehiclePool)

local TrafficRenderer = {}

local lanes = {}
local origin = Vector3.zero
local running = false

local MIN_ROW_OFFSET = -6
local MAX_ROW_OFFSET = 28
local MAX_PER_LANE = 7

function TrafficRenderer.init()
	VehiclePool.init(Workspace)
end

function TrafficRenderer.start()
	SessionController.signals.runStarted:Connect(function(payload)
		lanes = {}
		origin = payload.origin
		running = true
		VehiclePool.clear()
	end)

	SessionController.signals.chunkAdded:Connect(function(chunk)
		if not running then
			return
		end
		for _, lane in ipairs(chunk.lanes) do
			if lane.row >= chunk.startRow - 1 then
				lanes[#lanes + 1] = lane
			end
		end
	end)

	SessionController.signals.runEnded:Connect(function()
		running = false
		VehiclePool.clear()
	end)

	SessionController.signals.returnedToLobby:Connect(function()
		running = false
		lanes = {}
		VehiclePool.clear()
	end)
end

function TrafficRenderer.update()
	if not running then
		return
	end

	local elapsed = SessionController.elapsed()
	local focusRow = SessionController.state.row

	VehiclePool.beginFrame()

	for _, lane in ipairs(lanes) do
		local relative = lane.row - focusRow
		if relative >= MIN_ROW_OFFSET and relative <= MAX_ROW_OFFSET then
			local kMin, kMax = TrafficSim.indexRange(lane, elapsed)
			if kMax - kMin > MAX_PER_LANE then
				kMin = kMax - MAX_PER_LANE
			end

			local limit = GameConfig.LANE_SPAN_X + 24
			for k = kMin, kMax do
				local x, z, _length = TrafficSim.vehicleAt(lane, k, elapsed)
				if math.abs(x) < limit then
					VehiclePool.place(
						lane.vehicleType,
						Vector3.new(origin.X + x, 0, origin.Z + z),
						lane.dir
					)
				end
			end
		end
	end

	VehiclePool.endFrame()
end

return TrafficRenderer
