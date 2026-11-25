--!nonstrict
-- Remote names. String constants only: no RemoteEvent instances are committed as binary assets.
-- Remotes are created at boot on the server by shared/Net/Remotes.luau.

local Net = {}

Net.FOLDER_NAME = "FawnRushNet"

Net.REMOTES = {
	-- Client -> Server
	StepRequest = "StepRequest",
	JumpRequest = "JumpRequest",
	StartRunRequest = "StartRunRequest",
	EndRun = "EndRun",

	-- Server -> Client
	StartRunResult = "StartRunResult",
	ZoneInit = "ZoneInit",
	ChunkLoaded = "ChunkLoaded",
	RunState = "RunState",
	RunEnded = "RunEnded",
	RunEvent = "RunEvent",

	-- Progression intent and private server-authored profile mirrors.
	ProfileRequest = "ProfileRequest",
	ProfileSync = "ProfileSync",
	ProgressionResult = "ProgressionResult",
}

Net.RATE = {
	StepRequest = 14, -- per second, per player
	JumpRequest = 4,
	StartRunRequest = 1,
	EndRun = 2,
	ProfileRequest = 4,
}

return Net
