--!nonstrict
-- Shared type declarations. Referenced for documentation and editor hints only; never read at
-- runtime, so a type error can never break a live server.

local GameTypes = {}

GameTypes.SCHEMA_VERSION = 1

export type Direction = "fwd" | "back" | "left" | "right"

export type VehicleTypeId = "compact" | "sports" | "truck" | "van"

-- One lane of traffic. All parameters are frozen at generation time so that the position of
-- every vehicle is a pure function of elapsed time (see TrafficSim).
export type LaneDef = {
	type: "vehicle" | "rail",
	row: number,
	dir: number,
	speed: number,
	headway: number,
	phase: number,
	vehicleType: VehicleTypeId,
	spanX: number,
	overhang: number,
}

export type RowDef = {
	row: number,
	kind: "median" | "road",
	lane: LaneDef?,
}

export type CollectibleDef = {
	id: string,
	row: number,
	col: number,
	kind: "acorn_safe" | "acorn_road",
	value: number,
}

export type ChunkDef = {
	v: number,
	index: number,
	startRow: number,
	rowCount: number,
	rows: { RowDef },
	lanes: { LaneDef },
	collectibles: { CollectibleDef },
	validated: boolean,
	attempts: number,
}

export type RunPhase = "idle" | "starting" | "running" | "dying" | "finished"

export type RunStatePayload = {
	rows: number,
	score: number,
	acorns: number,
	col: number,
	row: number,
	combo: number,
}

export type RunEndedPayload = {
	reason: string,
	rows: number,
	score: number,
	acorns: number,
	bestRows: number,
	deathCause: string?,
}

export type ZoneInitPayload = {
	origin: Vector3,
	startTime: number,
	worldId: string,
	runIndex: number,
}

export type RunEventPayload = {
	kind: string,
	id: string?,
	col: number?,
	row: number?,
}

return GameTypes
