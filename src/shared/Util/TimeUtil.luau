--!nonstrict
-- UTC period keys shared by server logic and client display helpers.

local TimeUtil = {}

function TimeUtil.utcDay(timestamp: number): number
	return math.floor(timestamp / 86400)
end

-- Unix day zero was Thursday; adding three aligns period zero to Monday.
function TimeUtil.utcWeek(timestamp: number): number
	return math.floor((TimeUtil.utcDay(timestamp) + 3) / 7)
end

return TimeUtil
