--!nonstrict
-- World unlock rules, as a pure function of a validated profile or compact progress snapshot.
-- The server refuses to start a run until PlayerDataService has a successfully loaded profile.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WorldConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.WorldConfig)

local WorldUnlock = {}

WorldUnlock.EMPTY_PROGRESS = { level = 1, lifetimeRows = 0 }

function WorldUnlock.progressOf(progress)
	if type(progress) ~= "table" then
		return WorldUnlock.EMPTY_PROGRESS
	end
	local level = progress.level
	local lifetimeRows = progress.lifetimeRows
	if type(progress.stats) == "table" then lifetimeRows = progress.stats.totalDistance or lifetimeRows end
	return {
		level = math.max(1, math.floor(tonumber(level) or 1)),
		lifetimeRows = math.max(0, math.floor(tonumber(lifetimeRows) or 0)),
	}
end

-- Returns (unlocked: boolean, missingLevel: number, missingRows: number).
function WorldUnlock.evaluate(worldId: string, progress): (boolean, number, number)
	local world = WorldConfig.worlds[worldId]
	if not world then
		return false, 0, 0
	end
	if type(progress) == "table" and type(progress.worlds) == "table"
		and type(progress.worlds.unlocked) == "table" and progress.worlds.unlocked[worldId] == true then
		return true, 0, 0
	end

	local snapshot = WorldUnlock.progressOf(progress)
	local requirement = world.unlock or { level = 1, lifetimeRows = 0 }

	local missingLevel = math.max(0, (requirement.level or 1) - snapshot.level)
	local missingRows = math.max(0, (requirement.lifetimeRows or 0) - snapshot.lifetimeRows)

	return missingLevel <= 0 and missingRows <= 0, missingLevel, missingRows
end

function WorldUnlock.isUnlocked(worldId: string, progress): boolean
	local unlocked = WorldUnlock.evaluate(worldId, progress)
	return unlocked
end

-- A single short line for a UI card or a refusal message.
function WorldUnlock.describe(worldId: string): string
	local world = WorldConfig.worlds[worldId]
	if not world then
		return "Unknown world"
	end

	local requirement = world.unlock or { level = 1 }
	local parts = {}
	if (requirement.level or 1) > 1 then
		parts[#parts + 1] = ("Level %d"):format(requirement.level)
	end
	if (requirement.lifetimeRows or 0) > 0 then
		parts[#parts + 1] = ("%d lifetime rows"):format(requirement.lifetimeRows)
	end

	if #parts == 0 then
		return "Unlocked"
	end
	return table.concat(parts, " + ")
end

-- Every world with its state, in display order. Used by the world chip and, later, the world select.
function WorldUnlock.snapshot(progress)
	local list = {}
	for _, world in ipairs(WorldConfig.list()) do
		local unlocked, missingLevel, missingRows = WorldUnlock.evaluate(world.id, progress)
		list[#list + 1] = {
			id = world.id,
			name = world.name,
			tagline = world.tagline,
			unlocked = unlocked,
			missingLevel = missingLevel,
			missingRows = missingRows,
			requirement = WorldUnlock.describe(world.id),
		}
	end
	return list
end

return WorldUnlock
