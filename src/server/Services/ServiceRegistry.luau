--!nonstrict
-- Ordered service registry. Explicit registration, deterministic boot order, and a failed Init
-- disables that service instead of taking the whole server down with it.
-- See docs/02_TECHNICAL_ARCHITECTURE.md §3.1.

local Logger = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Util.Logger)

local ServiceRegistry = {}
ServiceRegistry.__index = ServiceRegistry

function ServiceRegistry.new()
	return setmetatable({ _entries = {} }, ServiceRegistry)
end

function ServiceRegistry:register(name: string, service, priority: number)
	self._entries[#self._entries + 1] = {
		name = name,
		service = service,
		priority = priority or 100,
		disabled = false,
	}
end

local function sorted(entries)
	local copy = table.clone(entries)
	table.sort(copy, function(a, b)
		if a.priority == b.priority then
			return a.name < b.name
		end
		return a.priority < b.priority
	end)
	return copy
end

function ServiceRegistry:run(phase: string)
	for _, entry in ipairs(sorted(self._entries)) do
		if not entry.disabled then
			local fn = entry.service[phase]
			if type(fn) == "function" then
				local ok, err = pcall(fn, entry.service)
				if not ok then
					Logger.error("Registry", ("%s.%s failed: %s"):format(entry.name, phase, tostring(err)))
					if phase == "init" then
						entry.disabled = true
					end
				end
			end
		end
	end
end

function ServiceRegistry:initAll()
	self:run("init")
end

function ServiceRegistry:startAll()
	self:run("start")
end

function ServiceRegistry:stopAll()
	for _, entry in ipairs(sorted(self._entries)) do
		if not entry.disabled and type(entry.service.stop) == "function" then
			pcall(entry.service.stop, entry.service)
		end
	end
end

return ServiceRegistry
