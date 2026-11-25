--!nonstrict
-- Pure, trusted-event mission progress, period rotation and idempotent bulk claiming.

local MissionRules = {}

local function copyReward(reward)
	return { acorns = reward.acorns, xp = reward.xp }
end

function MissionRules.newState(definitions, period: number)
	local entries = {}
	for _, definition in ipairs(definitions) do
		entries[definition.id] = {
			id = definition.id,
			objective = definition.objective,
			worldId = definition.worldId,
			target = definition.target,
			progress = 0,
			complete = false,
			claimed = false,
			reward = copyReward(definition.reward),
		}
	end
	return { period = period, entries = entries, pending = {} }
end

function MissionRules.ensure(state, definitions, period: number)
	if type(state) ~= "table" then
		return MissionRules.newState(definitions, period), true
	end
	if state.period == period and type(state.entries) == "table" and type(state.pending) == "table" then
		return state, false
	end
	local pending = type(state.pending) == "table" and state.pending or {}
	for _, entry in pairs(type(state.entries) == "table" and state.entries or {}) do
		if entry.complete == true and entry.claimed ~= true then
			local archived = table.clone(entry)
			archived.period = state.period
			pending[#pending + 1] = archived
		end
	end
	local fresh = MissionRules.newState(definitions, period)
	fresh.pending = pending
	return fresh, true
end

local function eventDelta(entry, event): number
	if entry.objective == "distance" then
		return math.max(0, math.floor(tonumber(event.rows) or 0))
	elseif entry.objective == "collectibles" then
		return math.max(0, math.floor(tonumber(event.collectibles) or 0))
	elseif entry.objective == "near_misses" then
		return math.max(0, math.floor(tonumber(event.nearMisses) or 0))
	elseif entry.objective == "successful_runs" then
		return event.successful == true and 1 or 0
	elseif entry.objective == "world_distance" then
		return event.worldId == entry.worldId and math.max(0, math.floor(tonumber(event.rows) or 0)) or 0
	end
	return 0
end

function MissionRules.apply(state, event): boolean
	local changed = false
	for _, entry in pairs(state.entries) do
		if entry.complete ~= true then
			local delta = eventDelta(entry, event)
			if delta > 0 then
				entry.progress = math.min(entry.target, entry.progress + delta)
				entry.complete = entry.progress >= entry.target
				changed = true
			end
		end
	end
	return changed
end

function MissionRules.claimReady(state)
	local reward = { acorns = 0, xp = 0 }
	local count = 0
	for _, entry in pairs(state.entries) do
		if entry.complete == true and entry.claimed ~= true then
			entry.claimed = true
			reward.acorns += entry.reward.acorns
			reward.xp += entry.reward.xp
			count += 1
		end
	end
	local pending = {}
	for _, entry in ipairs(state.pending) do
		reward.acorns += entry.reward.acorns
		reward.xp += entry.reward.xp
		count += 1
	end
	state.pending = pending
	return reward, count
end

function MissionRules.readyCount(state): number
	local count = #state.pending
	for _, entry in pairs(state.entries) do
		if entry.complete == true and entry.claimed ~= true then
			count += 1
		end
	end
	return count
end

return MissionRules
