# 04 — Gameplay Mechanics Specification

Implementation-level specification for the run. Every number here is a default that lives in
`src/shared/Config/`. Where a formula is given, the config supplies the coefficients and the code
implements the shape.

Modules referenced: `GridMath`, `TrafficSim`, `ChunkGenerator`, `SafePathValidator`, `Rng`,
`MovementController` (client), `GameplayService` (server).

---

## 1. Space and coordinates

### 1.1 Tile space

The run is a grid. Positions are integer pairs:

```
col ∈ [-8 .. +8]        (PLAYFIELD_COLS = 17)
row ∈ [0 .. ∞)          (0 = start line)
```

World position of a tile centre, inside a zone whose origin is `O`:

```lua
function GridMath.tileToWorld(origin: Vector3, col: number, row: number): Vector3
	return origin + Vector3.new(col * TILE, TILE_HEIGHT, -row * TILE)
end
```

`TILE = 4`, `TILE_HEIGHT = 0` (the crossing surface is flat; visual elevation is scenery only).

### 1.2 Zone origin

Each player's run occupies a zone. Zone `i` (0-based) in a server has origin:

```lua
local ZONE_GRID = 4                          -- zones per row
local ZONE_SPACING_X, ZONE_SPACING_Z = 400, 620
origin = Vector3.new((i % ZONE_GRID) * ZONE_SPACING_X, 0, -math.floor(i / ZONE_GRID) * ZONE_SPACING_Z)
```

16 zones per server. With `PlayersLimit` 16 and one zone reserved per player, no two players ever
share a strip. Zone content is generated only while a run is live in it; an idle zone is emptied
(scenery and vehicles returned to pools) so a lobby of 16 costs almost nothing.

### 1.3 Direction convention

Forward is −Z, so `row` increases as the player advances. Left is −X. Row `0` is the start median;
the first corridor begins at row 2 (guarantees a safe launch).

---

## 2. Movement

### 2.1 State

The player's logical state is `(col, row, alive, airborne)`. There is no analogue velocity anywhere
in the authoritative model. Visual position is interpolated from the logical state.

```lua
type PlayerRunState = {
	col: number,
	row: number,
	alive: boolean,
	airborne: boolean,
	lastStepAt: number,     -- server clock, seconds
	lastStepDir: Vector2?,
	pendingDir: Vector2?,   -- input buffer, client-side only for prediction
}
```

### 2.2 Step rules

| Rule | Value |
|---|---|
| Step duration (animation + travel) | `STEP_TIME = 0.11 s` |
| Step cooldown (earliest next accepted step) | `STEP_COOLDOWN = 0.10 s` |
| Input buffer window | `INPUT_BUFFER = 0.18 s` |
| Minimum step interval enforced by server | `STEP_COOLDOWN` |
| Maximum accepted steps per second | 12 (token bucket, burst 6) |
| Diagonal input | Resolved to the last-pressed axis; never a diagonal step |
| Column clamp | Step into `col < -8` or `col > 8` is rejected (no penalty, no cooldown burn) |
| Backward step | Allowed, down to `row = 0`; cannot go below 0 |

Because `STEP_COOLDOWN (0.10) < STEP_TIME (0.11)`, a second input can land while the first hop is
still finishing. The step tween is retargeted rather than restarted: the incoming step begins from the
current interpolated position and uses the remaining fraction of `STEP_TIME`. This is what makes
chained movement read as *running* instead of *hopping*. It is a requirement, not an optimisation.

### 2.3 Input buffer

The client keeps exactly one buffered direction, timestamped. On cooldown expiry the buffer is
consumed if `now - bufferedAt <= INPUT_BUFFER`. Newer input overwrites older. Buffer is cleared on
death and on modal pause. Buffering prevents the classic failure where a fast swiper's second input
lands 30 ms before the cooldown expires and is silently dropped.

### 2.4 Jump

Jump is available on safe rows and road lanes alike. It does not let the player pass over a vehicle
(hazards are full-height for collision purposes); it exists for gap-crossing pacing, for the jump
animation, and for two specific hazard types (road closure cones, wildlife). A jump:

- Locks lateral/forward stepping for `JUMP_TIME = 0.34 s` (you commit to the leap).
- Moves the player forward **one tile** if forward is held at the moment of jump; otherwise it is an
  in-place hop that still counts as `airborne`.
- Grants no collision immunity except against `WILDLIFE` obstacles while airborne above 1.2 studs.
- Cancels any pending buffered direction.

### 2.5 Client-side prediction

The client applies every step immediately to its local visual state, then sends the request. If the
server rejects a step (out of cooldown, out of bounds, dead), the client reconciles by smoothly
replaying from the last server-acknowledged state over 60 ms. Rejections only ever occur on a
duplicate/desync; the acknowledgement carries `(col, row, serverTime)` at 10 Hz piggybacked on the
traffic snapshot so reconciliation almost never needs a visible correction.

---

## 3. Camera

| Parameter | Desktop | Mobile | Portrait |
|---|---|---|---|
| Offset from player | `(0, 15.5, 13.5)` | `(0, 18.5, 16.0)` | `(0, 22.0, 19.0)` |
| Look target | player + `(0, 2.2, -5.5)` | player + `(0, 2.2, -6.5)` | player + `(0, 2.2, -8.0)` |
| Field of view | 62 | 70 | 70 |
| Position damping `k` | 8.0 | 7.0 | 6.0 |
| Look damping `k` | 10.0 | 9.0 | 8.0 |

Damping is frame-rate independent: `alpha = 1 - math.exp(-k * dt)`.

The camera **leads** the player in the forward direction by 0.35 rows so the next corridor is visible
before it is entered — that is the look-target offset above. Cameras never rotate from mouse input
during a run (mouse is a step input on desktop), never shakes rotationally, and never dips below
`y = playerY + 9`.

On death the camera pulls back to `(0, 20, 20)` over 0.5 s to frame the impact site.

---

## 4. Traffic simulation

### 4.1 Model: closed-form, stateless

Traffic is not stepped. Every vehicle's position is a **pure function of time**, which makes the
server and every client bit-identical without any synchronisation of accumulated state.

A lane is:

```lua
type LaneDef = {
	row: number,          -- grid row of this lane
	dir: 1 | -1,          -- +1 travels toward +X, -1 travels toward -X
	speed: number,        -- studs per second, frozen at generation time
	headway: number,      -- seconds between consecutive vehicle spawns
	phase: number,        -- seconds, offset of vehicle #0
	vehicleType: VehicleTypeId,
	spanX: number,        -- half-length of the visible lane, studs (default 60)
}
```

Vehicle `k` of that lane occupies, at absolute sim time `t`:

```lua
local function vehicleAt(lane, k, t)
	-- entry point is fully off-screen at spawn
	local xIn = -lane.dir * (lane.spanX + VEHICLE_OVERHANG)
	local t0 = lane.phase + k * lane.headway
	local x = xIn + lane.dir * lane.speed * (t - t0)
	return {
		x = x,
		z = -lane.row * TILE,
		dir = lane.dir,
		length = VEHICLE_TYPES[lane.vehicleType].length * TILE,
		halfWidth = VEHICLE_TYPES[lane.vehicleType].halfWidth,
		alive = math.abs(x) <= lane.spanX + VEHICLE_OVERHANG + lane.speed * 0.05,
	}
end
```

The index range worth drawing at time `t`:

```lua
local travelTime = (2 * (lane.spanX + VEHICLE_OVERHANG)) / lane.speed
local kMin = math.floor((t - lane.phase - travelTime) / lane.headway)
local kMax = math.floor((t - lane.phase) / lane.headway)
```

Consequences (all of them intentional):

- **Zero drift.** Two machines evaluating the same `(lane, k, t)` get the same answer forever.
- **Zero spawner state.** No pools of timers, no catch-up logic after a server hitch.
- **Gap is derivable.** `gapStuds = lane.headway * lane.speed - vehicleLength * TILE`, so the fairness
  floor in §4.3 is a constraint on `headway`, checkable at generation time.
- **Rewind is free.** Judging a step from 150 ms ago is just `vehicleAt(lane, k, t - 0.150)`.

Sim time is a single server-wide `t` from a monotonic clock, broadcast in the zone snapshot. Clients
run `t' = t + ping/2` and clamp corrections rather than snapping.

### 4.2 Vehicle types

| Type | Length (tiles) | Half-width (studs) | Speed multiplier | Mass feel |
|---|---|---|---|---|
| `compact` | 2.0 | 1.20 | 1.00 | Light; body tilts on turn |
| `sports` | 2.0 | 1.15 | 1.70 | Fast; engine whine layer |
| `truck` | 3.0 | 1.35 | 0.85 | Slow start, heavy |
| `bus` | 4.0 | 1.40 | 0.70 | Long; blocks two visual lanes |
| `motorcycle` | 1.0 | 0.65 | 2.00 | Pairs with 0.5 headway partner |
| `van` | 2.5 | 1.25 | 1.00 | Lane-hop telegraph (§4.5) |
| `train` | 10.0 | 1.60 | 1.35 | Only on `rail` lanes; announced |

Speed of a lane: `lane.speed = lerp(vMin, vMax, D^0.9) × VEHICLE_TYPES[type].speedMul × (1 ± jitter)`
with jitter drawn once per lane at generation from `Rng` in `[-0.08, +0.08]`, then frozen. A lane's
speed never changes mid-run (except for the Neon gust event, §4.6, which is a scheduled, telegraphed
multiplier applied identically on both sides).

### 4.3 Fairness floor on headway

```
minHeadway = (vehicleLengthStuds + TILE * 1.6 + GAP_SAFETY) / lane.speed + REACTION
```

with `GAP_SAFETY = 2.0 studs`, `REACTION = 0.22 s`.

The generator computes `minHeadway` per lane and clamps:

```lua
lane.headway = math.max(lane.headway * gapMul, minHeadway)
```

`gapMul` is the density driver from the difficulty curve (1.00 → 0.62). The clamp is what makes the
difficulty ceiling real: density can only tighten until physically survivable, then it stops. A lane
can never be spacially unsurvivable; only *timing* can make a corridor hard, and timing is solved by
§6.

### 4.4 Lane directions and multi-lane roads

Roads in the fiction are two-way. Lane direction alternates in pairs within a world-appropriate
pattern (`WorldConfig.lanePattern`, e.g. `{ -1, -1, +1, +1 }`), but **a corridor's lanes always share a
direction**. Two adjacent corridors with opposing directions are separated by a median by definition.
This keeps reading traffic unambiguous — you never have to check two directions in one block.

### 4.5 Delivery van lane-hop (telegraph)

Vans may switch lanes once per crossing. The hop is announced by:

- 0.8 s of indicator light (an emissive part toggling at 4 Hz),
- a slight body lean toward the target lane,
- a distinct audio blip.

The hop itself takes 0.4 s and moves the van 1 tile in Z. Vans never hop into the tile a player
currently occupies *and* never hop in the first 0.5 s after entering the screen. Disabled below
`D = 0.25` so it never appears in the first minute of a player's first run.

### 4.6 Train announcement and event gusts

**Train.** A `rail` lane is chosen only at corridor level (it spans the full corridor). 1.2 s before
the train's leading edge enters the playfield, the server broadcasts `TrainWarning(zoneId, atTime)`;
clients play the horn, tremble the rail parts, and flash a light bar. The train's headway is at least
`4.0 s` so a train corridor is always crossable between trains even at `D = 1`.

**Neon gust** (and the Snow/Desert analogues). A scheduled event that multiplies `lane.speed` by
`1.35` for 3.0 s, announced 1.0 s ahead with a directional particle stream. Because it is a pure
multiplier applied to a closed-form function, both sides agree exactly:

```lua
local function effectiveSpeed(lane, t)
	local gust = activeGustAt(lane.row, t)   -- nil or { from: number, to: number, mul: number }
	if gust and t >= gust.from and t <= gust.to then return lane.speed * gust.mul end
	return lane.speed
end
```

Note: this is the one place traffic is a function of a *schedule* rather than purely of constants —
the schedule is generated with the chunk and is part of the zone snapshot, so it is still shared,
exact data, never simulated independently.

---

## 5. Chunk generation

### 5.1 Chunk anatomy

A **chunk** is 12 rows generated as a unit:

```
[ median 1..3 rows ] [ corridor 1..3 lanes ] [ median 1..3 rows ] ...
```

Row budget: 12 rows exactly. Corridors 1–3 lanes, medians 1–3 rows, and the constraint that every
corridor is followed by at least one median row. A chunk may contain 2–4 corridors.

Generation happens 3 chunks ahead of the player. Chunks behind more than 12 rows are recycled.

### 5.2 Determinism and RNG streams

`math.random` is not used anywhere in generation. `Rng` is a 32-bit LCG over `bit32` ops:

```lua
local M = 2147483647  -- 2^31 - 1
local A = 1103515245
local C = 12345

function Rng.next(state: number): number, number
	local nextState = (A * state + C) % M
	return nextState, nextState / M          -- integer state, float in [0,1)
end
```

Seed derivation: `seed(worldId, runId, chunkIndex)`, mixed with a SplitMix-style avalanche so adjacent
chunk indices do not correlate. Separate streams are derived from the same seed for
`scenery / vehicles / collectibles / hazards`, so adding a prop never shifts traffic.

### 5.3 Corridor construction

For a corridor at rows `[r0, r0 + n - 1]`:

1. Choose `n` from the difficulty-weighted corridor table in `01` §7.3.
2. Choose road style from `WorldConfig.roadStyles` (asphalt, gravel, highway, ice, neon).
3. Choose lane direction per the world's lane pattern.
4. For each lane: choose vehicle type from the world's availability table (weighted), choose
   `speedBase = lerp(vMin, vMax, D^0.9)`, add jitter, compute `minHeadway`, choose a target
   `gapMul` from `D`, compute `headway`.
5. Choose phases: candidate offsets from `{0, ±0.133, ±0.20}` relative to the corridor's base phase,
   tested in order; each is validated by §6. First candidate that passes wins.
6. Emit the `CorridorDef` (lanes with frozen `speed`/`headway`/`phase`/`type`).

### 5.4 Medians, safe rows, and collectibles

Medians carry world scenery and the collectibles that make risk-free play viable: 60% of median rows
spawn 1–2 acorns at seeded columns. Road lanes spawn an acorn with 22% probability per lane-row at a
seeded column; the row must be free of that column's traffic for at least 0.6 s at the crossing
window — this is checked in §6 by the solver (a collectible is never bait on an unsurvivable tile).

### 5.5 Static obstacles

Road closures (`barrier` tiles) are placed only on road rows, never on the only free column of a
row, and never more than 2 per row. Wildlife paths are seeded with a period and phase and move in the
lateral (X) axis at 5–9 studs/s. Both are part of the `ChunkDef` handed to the validator.

### 5.6 Output

```lua
type ChunkDef = {
	index: number,
	startRow: number,
	rowCount: number,
	corridors: { CorridorDef },
	medians: { { row: number, rows: number } },
	collectibles: { { row: number, col: number, kind: CollectibleKind, value: number } },
	obstacles: { { row: number, col: number, kind: ObstacleKind, def: any } },
	gusts: { { row: number, from: number, to: number, mul: number } },
	validated: boolean,
}
```

---

## 6. Safe-path validation (the fairness guarantee)

This is the load-bearing system. It is not a heuristic; it is a search that must succeed before a
chunk is allowed to exist.

### 6.1 Solver

Time-indexed A* over `(row, col)` with a discrete time axis at `SOLVER_DT = 0.05 s`, depth
`SOLVER_HORIZON = 6.0 s`, columns `[-6 .. +6]`.

**Node.** `(row, col, tIndex)`. Reached by:
- **Wait:** `(row, col, t + SOLVER_DT)` — always allowed, costs 1 node.
- **Move:** to an adjacent tile, at `t + STEP_COOLDOWN`, only if legal.

**Edge legality for a move into tile `(r, c)` at time `tMove`:** the target tile must be hazard-free
for the window `[tMove, tMove + SOLVER_MARGIN]` where `SOLVER_MARGIN = 0.25 s` (the reaction buffer).
"hazard-free" means no vehicle, obstacle, or wildlife overlaps the player collision box at any of the
sampled instants `tMove + k * 0.025` for `k in 0..10`.

**Goal.** Reach `row == chunkStartRow + chunkRowCount` (i.e. a safe row past the last corridor).
Wait-only solutions count: a corridor that can be survived by waiting is valid, which is the correct
reading of "fair".

**Heuristic.** `(goalRow - row) * STEP_COOLDOWN` — admissible, keeps the search greedy toward
progress without preferring recklessness.

**Budgets.** Node cap 6,000 expansions, wall-clock cap 4 ms. Exceeding either is a **failure**, not a
success. In practice a valid chunk solves in 200–900 expansions.

### 6.2 Failure handling

If a chunk fails validation, `ChunkGenerator` retries with progressively gentler parameters:

| Attempt | Adjustment |
|---|---|
| 1 | As generated |
| 2 | `gapMul += 0.15` (more spacing), same corridors |
| 3 | Cap corridor width at 2 lanes, `gapMul += 0.25` |
| 4 | Cap corridor width at 1 lane, `gapMul = 1.0`, drop vans and wildlife |

If attempt 4 fails, the chunk falls back to a **guaranteed template**: alternating single-lane
corridors and 2-row medians with `gapMul = 1.0` and no obstacles. This template is validated once at
unit-test time and can never fail at runtime. Shipping a template is logged and counted as a metric
(`gen.fallback`) — a rising fallback rate means a world's parameters are wrong, not that a player should
die.

### 6.3 Runtime cost

The solver runs on the server thread that owns the zone, but it is scheduled: one chunk per
`Heartbeat` per zone maximum, and only when 3 chunks are not already buffered. Worst case 4 ms every
~2.5 s of gameplay. Budgeted in `09` §5.3.

### 6.4 Why not just per-lane gaps

Because per-lane spacing can still produce a wall: three lanes whose gaps each satisfy §4.3 but whose
phases interleave so that lane 2's gap arrives exactly when lane 1's gap has closed. Only a solver
over the corridor as a whole catches that. This is the specific bug this system exists to prevent, and
`SafePathValidator.spec.luau` includes a hand-built wall case that must be rejected.

---

## 7. Collision and death resolution

### 7.1 Bodies

| Body | Extent |
|---|---|
| Player | half-extent 0.9 studs in X and Z, height 3.0 studs |
| Vehicle | `length/2` in X, `VEHICLE_TYPES[..].halfWidth` in Z |
| Obstacle | per-kind box in `ObstacleConfig` |

Contact requires overlap in X **and** Z. In Z, the sum of half-extents for a car is `0.9 + 1.2 = 2.1`
studs, i.e. 0.525 tiles. A player is therefore only in danger once their interpolated position is
within roughly half a tile of the lane centre — the moment they commit. Leaving a lane is forgiving
by the same amount. This asymmetry in the player's favour is deliberate and documented in `01` §7.

### 7.2 Evaluation point

The server evaluates collisions on every tick (20 Hz) for each live run:

```lua
-- authoritative evaluation
local function isHit(lane, playerState, t)
	local kStart = math.floor((t - lane.phase - travelTime(lane)) / lane.headway) - 1
	local kEnd   = math.floor((t - lane.phase) / lane.headway) + 1
	for k = kStart, kEnd do
		local v = vehicleAt(lane, k, t)
		if v.alive
			and math.abs(v.x - playerX) < (v.length * 0.5 + PLAYER_HALF_X + 0.15)
			and math.abs(v.z - playerZ) < (v.halfWidth + PLAYER_HALF_Z) then
			return true, k
		end
	end
	return false, nil
end
```

`+0.15` studs is a contact-lenience pad on the X axis only (never makes the player die earlier).

### 7.3 Favour-the-player window (lag compensation)

When resolving a **step** (not a stationary tick), the server evaluates the hazard state at two times
and takes the more favourable result:

```
tA = now                                   -- strict truth
tB = clamp(stepReceivedAt - ping/2, now - REWIND_MAX_MS, now)
survives if isHit(tA) == false OR isHit(tB) == false
```

`REWIND_MAX_MS = 200`, `ping` measured by the heartbeat every 5 s. This does two things: it removes
"but I moved!" complaints on 120 ms mobile connections, and it bounds the exploit surface — a player
cannot gain more than 200 ms of immunity, cannot extend it, and cannot influence `ping` beyond real
latency (measured as round-trip, and clamped).

Stationary ticks are never rewound. Standing still in a live lane and being hit is always a death.

### 7.4 Grace and hit reaction

- A vehicle hit produces `Stumble` (state 7) only when the contact is in the outer 0.25 studs of the Z
  window; the player survives with a 0.35 s control lockout and a "-stumble" penalty to combo (combo
  resets). This is a rare, forgiving edge case and reads as a dramatic escape.
- A true overlap is a death. `alive = false` immediately, then:
  1. `0.12 s` impact freeze (client renders the frozen frame),
  2. death animation `1.1 s`,
  3. server finalises the run, pays rewards, writes stats,
  4. client shows results.

### 7.5 Wildlife and closure obstacles

Wildlife boxes are evaluated the same way but are ignored while `airborne` and above 1.2 studs (§2.4).
Closure barriers are static AABBs; walking into one is a soft block (movement rejected, no death) — it
never kills.

---

## 8. Scoring

```
score = floor(rows × 10 × worldScoreMul) + nearMissPoints + collectiblePoints
nearMissPoints     = Σ over events of (25 × comboStep)
collectiblePoints  = Σ over pickups of (kind.baseValue × comboMultiplier)
```

- `worldScoreMul` = 1.0 for every world at launch (no world scores better; this is checked in a test).
- `rows` is the only exported "distance" metric. Leaderboards sort on `rows`, then `score`.
- Score is computed **entirely on the server** from accepted steps and server-detected events. The
  client never sends a score, a row count, or an acorn total; it may *display* its own prediction,
  which is overwritten by the authoritative value at run end.
- A run that is abandoned (player leaves) is finalised with its current values and no completion
  bonus.

---

## 9. Collectibles

| Kind | Value (acorns) | Spawn |
|---|---|---|
| `acorn_safe` | 1 | Median rows, 60% chance of 1–2 |
| `acorn_road` | 3 | Road lanes, 22% per lane-row, must be solvable |
| `golden_acorn` | 0 (grants 1 Golden) | 1 per run, at a seeded row ≥ 250, always on a median |
| `event_collectible` | 5 | Only during events, replaces `acorn_safe` |

Pickup is resolved server-side when the player's `(col, row)` equals the collectible's tile and the
player is alive. The collectible is removed from the zone's active set and a `CollectiblePicked`
remote is sent to its owner only (particles are spawned locally by the owner; other players cannot
see or take it — namespacing per zone guarantees this).

Golden acorns are also awarded at run end: `1 + floor(rows / 250)` capped at 2, only if the run
reached at least 250 rows.

---

## 10. Run lifecycle

```lua
type RunPhase = "idle" | "starting" | "running" | "dying" | "finished" | "closed"
```

| Transition | Trigger | Server work |
|---|---|---|
| `idle → starting` | `StartRunRequest(worldId, mode)` | Validate world unlock + level; allocate zone; seed run; generate 3 chunks; warm pools |
| `starting → running` | Countdown 0.9 s elapsed and chunks ready | Enable step validation; start broadcast snapshots |
| `running → dying` | Collision confirmed | Freeze input validation; start 0.12 s impact timer |
| `dying → finished` | 1.1 s death anim elapsed | Compute rewards; write stats & missions; emit analytics; award badges |
| `finished → closed` | Client calls `EndRun` or 20 s idle | Despawn zone; return props and vehicles to pools |
| any → `closed` | `PlayerRemoving`, `BindToClose` | Finalise as abandoned; persist |

Re-entrancy rules: a second `StartRunRequest` while `starting` or `running` is ignored. `EndRun`
before `dying` finalises as abandoned. Nothing may transition a run twice; the service holds a
per-player generation counter and every deferred callback checks it before mutating state.

---

## 11. Remote contract (client → server)

All of these are validated per `02` §6. Payload shapes are in `src/shared/Types/ApiTypes.luau`.

| Remote | Direction | Payload | Validation |
|---|---|---|---|
| `StepRequest` | C→S | `{ dir: "fwd"｜"back"｜"left"｜"right", clientTick: number }` | Phase is `running`; cooldown vs `lastStepAt`; target in bounds; token bucket; not airborne |
| `JumpRequest` | C→S | `{ clientTick }` | Cooldown; not airborne; phase `running` |
| `StartRunRequest` | C→S | `{ worldId: string, mode: "classified"｜"practice" }` | World unlocked; level gate; phase `idle`; rate limit 1 / 2 s |
| `EndRun` | C→S | `{}` | Phase `running` or `dying`; idempotent |
| `Heartbeat` | C→S | `{ clientTick, pingMark }` | Rate limit 4 Hz; used for ping estimate only |
| `EquipAnimal` | C→S | `{ animalId: string }` | Ownership check |
| `EquipCosmetics` | C→S | `{ loadout: { slot: string, itemId: string? } }` | Ownership; slot validity; compatibility tags |
| `ClaimDaily` | C→S | `{}` | Cooldown; day index matches server calendar |
| `ClaimMission` | C→S | `{ missionId: string }` | Completed and unclaimed |
| `PurchaseItem` | C→S | `{ itemId: string, currency: "acorns"｜"golden" }` | Price from config, balance, ownership |
| `RerollMission` | C→S | `{ missionId: string }` | One free reroll/day; acorn cost after |

Server → client uses one **snapshot** channel per zone plus low-frequency UI channels; see
`02` §5.2. The client never receives a currency value it may spend — it receives a display mirror,
and every spend is a request.

---

## 12. Determinism rules

Checklist that must stay true, or server and client will disagree:

1. No `math.random` in simulation or generation. `Rng` only.
2. No `os.clock`, `tick`, `DateTime`, or `workspace:GetServerTimeNow` inside a pure function — time is
   passed in as a parameter.
3. No iteration over a hash table where order matters. Ordered arrays only.
4. No floating accumulation: positions come from `t`, never from `p = p + v * dt`.
5. `TrafficSim`, `ChunkGenerator`, and `SafePathValidator` live in `ReplicatedStorage.Shared.Simulation`
   and are only addressable through their public functions — no globals, no state.
6. Unit tests run the generator 10,000 seeds and assert that client and server code paths produce
   identical `ChunkDef` tables (same module, so this mostly guards against accidental divergence).

---

## 13. Constants reference (defaults)

| Constant | Value | Module |
|---|---|---|
| `TILE` | 4 | `GameConfig` |
| `TICK_HZ` | 20 | `GameConfig` |
| `STEP_TIME` | 0.11 | `GameConfig` |
| `STEP_COOLDOWN` | 0.10 | `GameConfig` |
| `INPUT_BUFFER` | 0.18 | `GameConfig` |
| `JUMP_TIME` | 0.34 | `GameConfig` |
| `PLAYFIELD_COLS` | 17 | `GameConfig` |
| `PLAYER_HALF_X/Z` | 0.9 | `GameConfig` |
| `NEAR_MISS_TILES` | 0.75 | `GameConfig` |
| `COMBO_DECAY` | 6.0 | `GameConfig` |
| `COMBO_STEPS` | `{1.0, 1.25, 1.6, 2.1, 3.0}` (×5.0 at 5+) | `GameConfig` |
| `REWIND_MAX_MS` | 200 | `GameConfig` |
| `CORRIDOR_MAX_LANES` | 3 | `GameConfig` |
| `MEDIAN_MIN/MAX_ROWS` | 1 / 3 | `GameConfig` |
| `CHUNK_ROWS` | 12 | `GameConfig` |
| `CHUNK_LOOKAHEAD` | 3 | `GameConfig` |
| `SOLVER_DT` | 0.05 | `GameConfig` |
| `SOLVER_HORIZON` | 6.0 | `GameConfig` |
| `SOLVER_MARGIN` | 0.25 | `GameConfig` |
| `GAP_SAFETY` | 2.0 | `GameConfig` |
| `REACTION` | 0.22 | `GameConfig` |
| `ACORN_SAFE/ROAD` | 1 / 3 | `EconomyConfig` |
| `NEAR_MISS_ACORNS` | 2 | `EconomyConfig` |
| `XP_PER_ROW` / `XP_NEAR_MISS` | 1 / 5 | `EconomyConfig` |
