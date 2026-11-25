--!nonstrict
-- Lobby presence visibility, as a pure rule.
--
-- Server-owned presence models replicate to every client, including the player they belong to.
-- A client must therefore render a presence model only when it is somebody else's and that somebody
-- is not currently in a run. The owning player's animal is drawn by the client itself
-- (`MovementController` + `AnimationController`), because it has to react on the same frame as the
-- input.
--
-- This lives in shared/ rather than inside the client controller so the rule can be unit-tested
-- without a Roblox client. See docs/12_STUDIO_HANDOFF.md S3 for the defect it closes.

local PresenceRules = {}

-- `ownerUserId` is the model's OwnerUserId attribute, `inRun` its InRun attribute, `localUserId` the
-- local player's UserId.
function PresenceRules.shouldRender(ownerUserId: number?, inRun: boolean?, localUserId: number?): boolean
	-- A model with no owner cannot be attributed, so it is treated as not renderable rather than
	-- risking a duplicate of whoever is looking.
	if type(ownerUserId) ~= "number" or type(localUserId) ~= "number" then
		return false
	end

	-- Never draw a second copy of yourself.
	if ownerUserId == localUserId then
		return false
	end

	-- Somebody running is not in the lobby.
	if inRun == true then
		return false
	end

	return true
end

return PresenceRules
