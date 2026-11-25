--!nonstrict
-- Levelled logger with a dedupe path for messages that would otherwise spam (missing asset ids,
-- repeated validation failures). Every log line carries a tag so the Output window stays readable.

local Logger = {}

local seen = {}
local level = "info"

local PREFIX = "[FawnRush]"

function Logger.setLevel(newLevel: string)
	level = newLevel
end

local function emit(tag: string, message: string, sink: (string) -> ())
	sink(("%s [%s] %s"):format(PREFIX, tag, message))
end

function Logger.info(tag: string, message: string)
	if level == "warn" or level == "error" then
		return
	end
	emit(tag, message, print)
end

function Logger.warn(tag: string, message: string)
	if level == "error" then
		return
	end
	emit(tag, message, warn)
end

function Logger.error(tag: string, message: string)
	emit(tag, message, warn)
end

-- Logs at most once per key for the lifetime of the session.
function Logger.warnOnce(key: string, tag: string, message: string)
	if seen[key] then
		return
	end
	seen[key] = true
	Logger.warn(tag, message)
end

function Logger.resetOnce()
	seen = {}
end

return Logger
