--!nonstrict
-- Remote plumbing. The folder and every RemoteEvent are created at boot on the server and awaited
-- on the client, so no binary instance files are committed to the repository.
--
-- Server: Remotes.initServer() once at boot, then Remotes.get(name) anywhere.
-- Client: Remotes.await(name) yields until the event replicates.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Constants.Net)

local Remotes = {}

local cache = {}

local function findFolder(): Instance?
	return ReplicatedStorage:FindFirstChild(Net.FOLDER_NAME)
end

function Remotes.initServer()
	assert(RunService:IsServer(), "Remotes.initServer must run on the server")

	local folder = findFolder()
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = Net.FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end

	for name in pairs(Net.REMOTES) do
		local existing = folder:FindFirstChild(name)
		if not existing then
			local event = Instance.new("RemoteEvent")
			event.Name = name
			event.Parent = folder
		end
		cache[name] = nil
	end
end

function Remotes.get(name: string): RemoteEvent?
	if cache[name] then
		return cache[name]
	end

	local folder = findFolder()
	if not folder then
		return nil
	end

	local event = folder:FindFirstChild(name)
	if event and event:IsA("RemoteEvent") then
		cache[name] = event
		return event
	end

	return nil
end

-- Yields until the named remote exists. Client-only; the server creates them at boot.
function Remotes.await(name: string, timeout: number?): RemoteEvent
	local deadline = os.clock() + (timeout or 30)

	while os.clock() < deadline do
		local event = Remotes.get(name)
		if event then
			return event
		end
		task.wait(0.05)
	end

	error(("Remotes.await timed out waiting for '%s'"):format(tostring(name)))
end

return Remotes
