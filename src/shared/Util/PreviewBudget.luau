--!nonstrict
-- Small pure lease counter shared by viewport previews and Studio tests.

local PreviewBudget = {}
PreviewBudget.__index = PreviewBudget

function PreviewBudget.new(limit: number)
	return setmetatable({ limit = math.max(0, math.floor(limit)), active = 0 }, PreviewBudget)
end

function PreviewBudget:acquire()
	if self.active >= self.limit then
		return nil, "Preview limit reached"
	end

	self.active += 1
	local released = false
	return {
		release = function()
			if released then
				return
			end
			released = true
			self.active = math.max(0, self.active - 1)
		end,
	}
end

function PreviewBudget:count(): number
	return self.active
end

return PreviewBudget
