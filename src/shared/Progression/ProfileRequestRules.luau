--!nonstrict
-- Strict, small client-intent envelope. No progression values are accepted from clients.

local ProfileRequestRules = {}

local ACTIONS = {
	sync = true,
	claim_daily = true,
	claim_missions_ready = true,
	claim_achievements_ready = true,
	unlock_animal = true,
}

function ProfileRequestRules.validate(payload)
	if type(payload) ~= "table" then
		return false, "payload"
	end
	local count = 0
	for key in pairs(payload) do
		count += 1
		if key ~= "action" and key ~= "id" and key ~= "requestId" then
			return false, "unexpected_field"
		end
	end
	if count < 2 or count > 3 then
		return false, "shape"
	end
	if type(payload.action) ~= "string" or not ACTIONS[payload.action] then
		return false, "action"
	end
	if type(payload.requestId) ~= "number" or payload.requestId ~= payload.requestId
		or payload.requestId == math.huge or payload.requestId == -math.huge
		or payload.requestId < 1 or payload.requestId > 2147483647 or payload.requestId % 1 ~= 0 then
		return false, "request_id"
	end
	if payload.action == "unlock_animal" then
		if type(payload.id) ~= "string" or #payload.id > 24 then
			return false, "id"
		end
	elseif payload.id ~= nil then
		return false, "unexpected_id"
	end
	return true, { action = payload.action, id = payload.id, requestId = payload.requestId }
end

return ProfileRequestRules
