--!nonstrict
-- ChunkDef wire format.
--
-- A chunk table crosses the network between the server's authoritative simulation and the client's
-- renderer, so its shape is a contract. The `v` field was written from Phase 3 onwards but never
-- read, which meant a future format change would have been silently misinterpreted by an older
-- client. This module makes the version explicit and gives both sides one place to agree on it.
--
-- Rules for changing the format:
--   1. Bump VERSION.
--   2. Add fields; never rename or repurpose one. An old reader must still find every field it uses.
--   3. Raise MIN_SUPPORTED only if an old chunk can no longer be interpreted at all.
--
-- History:
--   v1  Phase 2. `rows`, `lanes`, `collectibles`. No `obstacles`, no `v` field.
--   v2  Phase 3. Adds `obstacles` (barriers and wildlife). v1 chunks remain readable: a missing
--       `obstacles` table is treated as empty, which is exactly what a v1 chunk meant.

local ChunkFormat = {}

ChunkFormat.VERSION = 2
ChunkFormat.MIN_SUPPORTED = 1

-- Resolves a chunk's declared version. Chunks generated before versioning carry no `v` at all,
-- which is v1 by definition. A value that is present but not a number is not a version and must
-- never be silently treated as the oldest supported one.
function ChunkFormat.resolve(v: any): number
	if v == nil then
		return 1
	end

	local version = tonumber(v)
	if not version or version ~= version then
		return -1
	end

	return math.floor(version)
end

function ChunkFormat.isSupported(v: any): boolean
	local version = ChunkFormat.resolve(v)
	return version >= ChunkFormat.MIN_SUPPORTED and version <= ChunkFormat.VERSION
end

-- True when the chunk may carry obstacle data. Guards `chunk.obstacles or {}` at the call sites so
-- the intent is recorded rather than implied.
function ChunkFormat.hasObstacles(v: any): boolean
	return ChunkFormat.resolve(v) >= 2
end

return ChunkFormat
