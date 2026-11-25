--!nonstrict
-- Ordered controller registry. Mirrors the server's ServiceRegistry so both sides boot the same way.

local ControllerRegistry = {}
ControllerRegistry.__index = ControllerRegistry

function ControllerRegistry.new()
	return setmetatable({ _entries = {} }, ControllerRegistry)
end

function ControllerRegistry:register(name: string, controller, priority: number)
	self._entries[#self._entries + 1] = {
		name = name,
		controller = controller,
		priority = priority or 100,
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

function ControllerRegistry:run(phase: string)
	for _, entry in ipairs(sorted(self._entries)) do
		local fn = entry.controller[phase]
		if type(fn) == "function" then
			local ok, err = pcall(fn, entry.controller)
			if not ok then
				warn(("[UI] %s.%s failed: %s"):format(entry.name, phase, tostring(err)))
			end
		end
	end
end

function ControllerRegistry:initAll()
	self:run("init")
end

function ControllerRegistry:startAll()
	self:run("start")
end

function ControllerRegistry:updateAll(dt: number)
	for _, entry in ipairs(sorted(self._entries)) do
		local fn = entry.controller.update
		if type(fn) == "function" then
			local ok, err = pcall(fn, entry.controller, dt)
			if not ok then
				-- A failing per-frame handler must not spam the output window.
				local key = "update:" .. entry.name
				if not self._warned or not self._warned[key] then
					self._warned = self._warned or {}
					self._warned[key] = true
					warn(("[UI] %s.update failed: %s"):format(entry.name, tostring(err)))
				end
			end
		end
	end
end

return ControllerRegistry
