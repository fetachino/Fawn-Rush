--!nonstrict
-- Score and reward formulas. Shared so the UI can predict a number for display while the server
-- remains the only authority that commits one.
-- See docs/04_GAMEPLAY_MECHANICS_SPEC.md §8.

local Scoring = {}

Scoring.ROWS_MULTIPLIER = 10

export type RunTotals = {
	rows: number,
	nearMissPoints: number?,
	collectiblePoints: number?,
	worldMul: number?,
}

function Scoring.compute(totals: RunTotals): number
	local rows = totals.rows or 0
	local nearMiss = totals.nearMissPoints or 0
	local collectible = totals.collectiblePoints or 0
	local worldMul = totals.worldMul or 1

	return math.floor(rows * Scoring.ROWS_MULTIPLIER * worldMul + nearMiss + collectible)
end

function Scoring.xpForRun(totals: RunTotals): number
	local rows = totals.rows or 0
	local nearMiss = totals.nearMissPoints or 0
	return rows + nearMiss
end

return Scoring
