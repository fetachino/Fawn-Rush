--!nonstrict
-- Zone allocation. Every player owns one isolated strip of the world so that no run can ever
-- interfere with another (docs/00_INDEX.md decision D4).
--
-- Zone strips are separated on the X axis only and run indefinitely toward -Z, so they never
-- intersect regardless of how far a player travels.

local ZoneService = {}

ZoneService.SPACING_X = 520
ZoneService.ORIGIN_Z = -400
ZoneService.MAX_ZONES = 16

local assigned = {} -- [userId] = index
local used = {} -- [index] = userId

function ZoneService.allocate(player): number
	local existing = assigned[player.UserId]
	if existing then
		return existing
	end

	local index = 1
	while used[index] do
		index += 1
	end

	used[index] = player.UserId
	assigned[player.UserId] = index
	return index
end

function ZoneService.release(player)
	local index = assigned[player.UserId]
	if index then
		used[index] = nil
		assigned[player.UserId] = nil
	end
end

function ZoneService.indexFor(player): number?
	return assigned[player.UserId]
end

function ZoneService.originFor(index: number): Vector3
	return Vector3.new(index * ZoneService.SPACING_X, 0, ZoneService.ORIGIN_Z)
end

return ZoneService
