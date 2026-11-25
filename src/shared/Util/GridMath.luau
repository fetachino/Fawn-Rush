--!nonstrict
-- Tile-space maths. The whole game reasons in integer (col, row); this module is the single place
-- that converts to studs. Keeping the conversion here means a change to TILE or to the forward
-- axis cannot silently desync the server and the client.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.GameConfig)

local GridMath = {}

local TILE = GameConfig.TILE

-- Direction name -> { deltaCol, deltaRow }. Forward is -Z, so forward increases row.
GridMath.DIR_OFFSETS = {
	fwd = { 0, 1 },
	back = { 0, -1 },
	left = { -1, 0 },
	right = { 1, 0 },
}

GridMath.DIRECTIONS = { "fwd", "back", "left", "right" }

function GridMath.colToX(col: number): number
	return col * TILE
end

function GridMath.rowToZ(row: number): number
	return -row * TILE
end

function GridMath.tileToLocal(col: number, row: number): Vector3
	return Vector3.new(col * TILE, 0, -row * TILE)
end

function GridMath.tileToWorld(origin: Vector3, col: number, row: number): Vector3
	return origin + Vector3.new(col * TILE, 0, -row * TILE)
end

function GridMath.isValidCol(col: number): boolean
	return col >= GameConfig.PLAYFIELD_MIN_COL and col <= GameConfig.PLAYFIELD_MAX_COL
end

function GridMath.isValidTile(col: number, row: number): boolean
	return GridMath.isValidCol(col) and row >= 0
end

-- Returns the tile reached by stepping one cell in `dir`, or nil if the direction is unknown.
function GridMath.targetTile(col: number, row: number, dir: string): (number?, number?)
	local offset = GridMath.DIR_OFFSETS[dir]
	if not offset then
		return nil, nil
	end
	return col + offset[1], row + offset[2]
end

-- Yaw that makes a model authored facing -Z point along `dir`.
function GridMath.yawForDirection(dir: string?): number
	if dir == "left" then
		return math.pi * 0.5
	elseif dir == "right" then
		return -math.pi * 0.5
	elseif dir == "back" then
		return math.pi
	end
	return 0
end

-- Shortest-arc angle interpolation, used for smooth turning without a 359-degree spin.
function GridMath.lerpAngle(from: number, to: number, alpha: number): number
	local delta = (to - from + math.pi) % (math.pi * 2) - math.pi
	return from + delta * alpha
end

return GridMath
