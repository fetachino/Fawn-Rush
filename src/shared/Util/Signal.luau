--!nonstrict
-- Minimal signal implementation. In-repo by design (see docs/00_INDEX.md decision D9: no runtime
-- packages). Handlers are invoked in registration order and a failing handler never breaks the
-- ones after it.

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(fn)
	local handlers = self._handlers
	local entry = { fn = fn }
	handlers[#handlers + 1] = entry

	return {
		Disconnect = function()
			local index = table.find(handlers, entry)
			if index then
				table.remove(handlers, index)
			end
		end,
	}
end

function Signal:Fire(...)
	local snapshot = table.clone(self._handlers)
	for _, entry in ipairs(snapshot) do
		local ok, err = pcall(entry.fn, ...)
		if not ok then
			warn("[Signal] handler error: " .. tostring(err))
		end
	end
end

function Signal:Destroy()
	self._handlers = {}
end

return Signal
