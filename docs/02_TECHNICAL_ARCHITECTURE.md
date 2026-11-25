# 02 — Technical Architecture

Owner: Senior Luau Engineer / Networking Engineer. Constrains every later phase.

---

## 1. Principles

**1.1 One-way dependencies.** `Shared` never requires `Server` or `Client`. `Server` never requires
`Client`. `Client` requires `Shared` only. A violation is a review rejection.

**1.2 The server is the only source of truth.** The client predicts; the server decides. Any value
that costs anything (acorns, XP, rows, unlocks, purchases) crosses the boundary only in the server →
client direction. Client → server messages carry *intent*, never *results*.

**1.3 Model replication, not state replication.** Traffic is a closed-form function of time
(`04` §4). The server therefore sends *definitions* (lane parameters, seeds), not vehicle positions.
This is the single largest bandwidth and fairness win in the design and it is why the simulation
modules live in `Shared`.

**1.4 Every module has one job and is named for it.** If a file's purpose needs "and" to describe, it
is two files.

**1.5 No silent failure.** Every fallible operation returns a `Result` (`{ ok: true, value }` or
`{ ok: false, err: string, detail: any? }`). Unhandled failures are logged with context and counted
against a per-session error budget that surfaces in the developer overlay.

**1.6 Config is data, not code.** Balance numbers never appear inside a service; they are read from
`Shared.Config`, which is a plain table of primitives so it can be diffed, hot-tuned, and unit-tested.

---

## 2. Runtime topology

```
                        ┌──────────────────────────────────────────┐
                        │              SERVER (authority)          │
                        │                                          │
   PlayerDataService ◄──┤  Bootstrap → ServiceRegistry             │
   CurrencyService   ◄──┤    ├─ Data      (load/save/lock)         │
   InventoryService  ◄──┤    ├─ Economy   (currency, purchases)    │
   MissionService    ◄──┤    ├─ Run       (lifecycle, validation)  │
   AchievementService◄──┤    ├─ Zone      (allocation, cleaning)   │
                        │    ├─ Chunk     (generation, validation) │
                        │    ├─ Traffic   (time + gust schedule)   │
                        │    ├─ Social    (leaderboards, presence) │
                        │    └─ Telemetry (analytics, badges)      │
                        └───────────────┬──────────────────────────┘
                                        │  RemoteEvents / UnreliableRemoteEvent
                        ┌───────────────┴──────────────────────────┐
                        │              CLIENT (prediction)         │
                        │  Bootstrap → ControllerRegistry          │
                        │    InputController   (device → intent)   │
                        │    MovementController(step prediction)   │
                        │    TrafficViewController (interpolation) │
                        │    CameraController  (frame-locked)      │
                        │    UIController      (screens/router)    │
                        │    EffectsController (pooled VFX)        │
                        │    AudioController   (3 buses)           │
                        └───────────────┬──────────────────────────┘
                                        │
                        ┌───────────────┴──────────────────────────┐
                        │   SHARED (pure, deterministic, no I/O)   │
                        │  Config · Types · Constants · Util · Net │
                        │  Simulation: TrafficSim, ChunkGenerator, │
                        │              SafePathValidator, Rng      │
                        └──────────────────────────────────────────┘
```

---

## 3. Server: service layer

### 3.1 Registry and lifecycle

`ServiceRegistry` gives each service a stable interface and ordered start-up:

```lua
export type Service = {
	Name: string,
	Priority: number,                        -- start order, ascending
	Init: ((self: Service) -> ())?,          -- create remotes, read config; no player data
	Start: ((self: Service) -> ())?,         -- bind events, start loops
	Stop: ((self: Service) -> ())?,          -- unbind, final save
}
```

`Bootstrap.server.luau`:

1. `Players.CharacterAutoLoads = false` (characters are cosmetic in the lobby; we manage them).
2. Register every service in `Services/` (explicit list — no dynamic discovery, for determinism).
3. Call `Init` in priority order inside `pcall`; a service that fails `Init` is disabled and logged,
   and the boot continues in a degraded mode rather than failing the whole server.
4. Call `Start` in priority order.
5. Bind `Players.PlayerAdded`, `PlayerRemoving`, `game:BindToClose`.

Priority order: `Logger(0) → Data(10) → Economy(20) → Inventory(30) → Mission(40) →
Achievement(50) → Zone(60) → Chunk(70) → Traffic(80) → Run(90) → Social(100) → Telemetry(110) →
Monetization(120)`.

### 3.2 Service contracts (the boundary that matters most)

```lua
-- PlayerDataService
Load(player: Player): (Result<Profile>)
Get(player: Player): (Profile?)          -- never fabricates; nil if not loaded
Save(player: Player, reason: string): (boolean)
IsLoaded(player: Player): boolean
OnProfileLoaded: Signal<(Player, Profile)>
OnProfileReleasing: Signal<(Player, Profile)>

-- EconomyService  (all mutations funnel through here)
Grant(player, currency: "acorns"|"golden", amount: number, source: string): (Result<number>)
                                                            -- returns new balance
TrySpend(player, currency, amount, sink: string): (Result<number>)
GetBalance(player): { acorns: number, golden: number }
-- Every call appends to an in-memory ring buffer (last 100) surfaced in the dev overlay:
--   { t, currency, delta, source, balanceBefore, balanceAfter }

-- InventoryService
OwnsAnimal(player, animalId): boolean
GrantAnimal(player, animalId, source): (Result<boolean>)
EquipAnimal(player, animalId): (Result<boolean>)
OwnsCosmetic(player, itemId): boolean
EquipLoadout(player, loadout): (Result<boolean>)

-- RunService
StartRun(player, worldId, mode): (Result<RunHandle>)
AcceptStep(player, dir, clientTick): (boolean, string?)   -- true = accepted
FinishRun(handle, reason: "death"|"bank"|"abandon"): ()
GetRun(player): (RunHandle?)
```

Services call each other only through these methods. `RunService` does not save data; it calls
`PlayerDataService:Get` and mutates the profile, and `PlayerDataService` persists. One owner per
concern.

### 3.3 Dependency direction inside the server

`Run` may call `Economy`, `Inventory`, `Mission`, `Achievement`, `Telemetry`.
`Economy` may call `Data`. `Data` calls nobody. `Telemetry` is a sink — nothing calls it for a
result. There are no cycles; a cycle means the split is wrong.

---

## 4. Shared: simulation

| Module | Job | Purity |
|---|---|---|
| `TrafficSim` | `vehicleAt`, `laneVehiclesAt`, `effectiveSpeed`, `isHit`, `nearestClearance` | Pure; time passed in |
| `ChunkGenerator` | `generate(seed, worldProfile, startRow, difficulty) -> ChunkDef` | Pure; deterministic |
| `SafePathValidator` | `validate(chunk, profile) -> (ok, path)` | Pure; bounded node budget |
| `Rng` | LCG state and stream derivation | Pure; no globals |
| `GridMath` | tile ↔ world conversion, bounds, adjacency | Pure |

These four modules are the game. They are the first thing written in Phase 2 and the most heavily
tested in Phase 10.

**Interface stability rule.** `ChunkDef` and `LaneDef` are the wire format. Any change to them breaks
every client on an older version *and* the replay tests. They are versioned: `ChunkDef.v` and a
client that receives a chunk version it does not understand requests a full run restart rather than
guessing.

---

## 5. Networking

### 5.1 Remote inventory

`Shared/Net/Remotes.luau` creates the folder and every remote on the server at boot and yields on the
client until they exist. No binary `.rbxm` remotes are committed. Names are constants in
`Shared/Constants/Net.luau`.

| Remote | Class | Rate | Direction | Purpose |
|---|---|---|---|---|
| `StepRequest` | RemoteEvent | ≤ 12/s | C→S | A step intent |
| `JumpRequest` | RemoteEvent | ≤ 4/s | C→S | Jump intent |
| `StartRunRequest` | RemoteFunction? **No** | ≤ 0.5/s | C→S | RemoteEvent + ack; functions block the client thread |
| `EndRun` | RemoteEvent | ≤ 1/s | C→S | Bank / abandon |
| `Heartbeat` | UnreliableRemoteEvent | 4/s | C→S | Ping + client tick |
| `ZoneInit` | RemoteEvent | once/run | S→C | Origin, seed, world, time anchor, first 3 chunks |
| `ChunkLoaded` | RemoteEvent | 1 per 12 rows | S→C | A validated `ChunkDef` |
| `RunState` | RemoteEvent | ≤ 10/s, on change | S→C | phase, rows, score, acorns, combo, mission deltas |
| `RunEvents` | UnreliableRemoteEvent | ≤ 8/s | S→C | Cosmetic-only: near-miss, train warning, gust, stumble |
| `ProfileSync` | RemoteEvent | on change, throttled 4/s | S→C | Currency, xp, level, ownership mirrors |
| `UIRequest` | RemoteEvent | ≤ 6/s | C→S | Open collection/shop/quests data fetch |
| `UIResponse` | RemoteEvent | reply | S→C | Payloads for the above |
| `Toast` | RemoteEvent | ≤ 2/s | S→C | Server-authored notifications ("Mission complete") |

**No `RemoteFunction` is used.** A client can stall a `RemoteFunction`'s server thread by never
responding, and a compromised client can call one in a loop. Request/response is modelled as two
events with a `requestId` and a 5 s server-side expiry.

### 5.2 Bandwidth budget

Per player per run, the steady state is `Heartbeat` (4 × ~24 B) + `RunState` (on change only, ~60 B) +
`RunEvents` (~200 B/s) + `TimeSync` folded into `Heartbeat`. Traffic positions cost nothing because
they are computed.

```
steady run traffic ≈ 0.4 KB/s down, 0.1 KB/s up     (excluding Roblox engine cost)
chunk burst        ≈ 1.8 KB per 12 rows, ~110 rows/min → 1.0 KB/s
```

Compare with state replication of 24 vehicles at 20 Hz (~9 KB/s down) — a 20× reduction, which is what
makes 16 concurrent zones affordable on one server.

### 5.3 Time synchronisation

Server sends its monotonic `simTime` in every `Heartbeat` reply and in `ZoneInit`. Client estimates
`offset = median(simTime - clientClock)` over the last 8 samples, then renders at
`tRender = clientClock + offset + HALF_PING`, clamped to advance at most 5% faster than real time
when catching up. A correction larger than 250 ms triggers a resync banner rather than a snap.

### 5.4 RemoteGuard

Every incoming remote passes through one gate before any service sees it:

```lua
RemoteGuard.handle(remoteName, player, handler)
	-- 1. player is a real Player and is in the session table
	-- 2. per-remote token bucket (per player, per remote)   [04 §11 rates]
	-- 3. payload type/shape validation against ApiTypes (deep, including range clamps)
	-- 4. xpcall around handler; errors logged with a stack trace and a per-player counter
```

A player who trips the rate limit 20 times in 60 s is logged and, in `Practice`/`Classified`, has
that remote disabled for the session with a `Toast`. This is a soft mitigation: nothing a client can
send is *sufficient* to gain value anyway (see §6).

---

## 6. Authority and validation matrix

| Concern | Client may | Server decides | Anti-cheat evidence |
|---|---|---|---|
| Movement | Send a direction + tick | Accept/reject (position derived from accepted steps) | Server never accepts a position |
| Distance / rows | Predict for display | Counts accepted steps | Steps require cooldown + adjacency |
| Survival | Predict death locally | Own collision evaluation + rewind window | Collision is computed from `(lane, k, t)` |
| Currency | Display mirror | All grants/spends, with source tags | `TrySpend` re-reads balance server-side |
| XP / level | Display | Derived from server events | Level rewards are server-granted |
| Mission progress | Display | Incremented by validated events | Client cannot report progress |
| Achievement | Display | Evaluated on server counters | Same counters as stats |
| Animal ownership | Display | `InventoryService` on save | Equip validates ownership |
| Purchases | Send `PurchaseItem` intent for soft currency | Price from config, balance check, atomic write | Receipt ledger for Robux |
| Sales / price | Nothing | Config only | Client cannot propose a price |
| Leaderboards | Nothing | `OrderedDataStore` writes, 60 s cadence | Writes only from `SocialService` |
| Settings (volume etc.) | Send values | Sanitised, clamped, persisted | Values clamped to 0–10 / enum |

The client's `ProfileSync` payload is explicitly described as a **mirror**: it exists so the UI can
render instantly, and any mismatch is resolved in favour of the server with no user-visible
correction beyond a number quietly changing.

---

## 7. Data layer

### 7.1 Schema (v3, canonical)

```lua
type Profile = {
	_v: number,                     -- schema version
	_savedAt: number,               -- os.time() of last write
	userId: number,
	createdAt: number,

	currencies: { acorns: number, golden: number },
	level: { xp: number, level: number },

	records: {
		bestRows: number, bestScore: number, bestCombo: number,
		totalRows: number, totalRuns: number, totalDeaths: number,
		totalNearMisses: number, playSeconds: number,
	},

	animals:  { owned: { [string]: boolean }, equipped: string, unlockedAt: { [string]: number } },
	cosmetics:{ owned: { [string]: boolean }, equipped: { [string]: string? },
	            loadouts: { Loadout }, equippedLoadout: number },

	missions: {
		daily:  { resetAt: number, entries: { MissionEntry } },
		weekly: { resetAt: number, entries: { MissionEntry } },
		rerollsUsed: number,
	},

	achievements: { [string]: { progress: number, complete: boolean, claimed: boolean } },
	login: { dayIndex: number, lastClaimAt: number, cycle: number },

	settings: {
		music: number, sfx: number, ui: number, muted: boolean,
		graphicsTier: "auto" | "low" | "medium" | "high",
		reducedMotion: boolean, cameraShake: boolean,
		inputMap: { [string]: string },     -- action -> key/gamepad code
	},

	stats: { perWorld: { [string]: { bestRows: number, bestScore: number, runs: number } } },
	purchases: { owned: { [string]: boolean }, productCounts: { [string]: number } },
	flags: { tutorialDone: boolean, badgesAwarded: { [string]: boolean }, firstRunDone: boolean },
	badges: { [string]: boolean },       -- platform badge ids already awarded
}
```

Defaults are produced by `SchemaMigration.defaults()`. Runtime code never indexes the profile without
a nil-safe read; `ProfileUtil.get(profile, "currencies.acorns", 0)` exists for that.

### 7.2 Session-locked store

`ServerScriptService/Server/Services/Data/ProfileStore.luau` — our own implementation, ~250 lines,
because the semantics we need are specific and the failure modes are catastrophic if wrong.

**Load** (per player, in `PlayerDataService`):

```lua
-- UpdateAsync is atomic; we claim a lock inside the same transform
local ok, profile = store:Update(playerKey, function(old)
	old = old or SchemaMigration.defaults(userId)
	if old.__lock and old.__lock.sessionId ~= sessionId then
		if os.time() - old.__lock.at < SESSION_TIMEOUT then
			return nil                      -- someone else holds it; abort the write
		end
		-- stale lock: take over, note it
		old.__staleRecovered = true
	end
	old.__lock = { sessionId = sessionId, at = os.time() }
	return old
end)
```

- `SESSION_TIMEOUT = 60 s` with a 30 s heartbeat rewrite of `__lock.at`.
- On a held lock, the loader retries 5 times over 12 s, then **refuses the session**: the player sees
  "Your save is open in another server. Rejoin in a minute." No defaults are created, nothing is
  written.
- On a DataStore error after all retries (backoff 1, 2, 4, 8 s; 4 attempts), same refusal path.
- **The rule that must never be broken:** a failed load never produces a default profile that is then
  saved. `PlayerDataService:Get` returns `nil` and every caller must handle that.

**Save:**

```lua
store:Update(playerKey, function(old)
	if old and old.__lock and old.__lock.sessionId ~= sessionId then
		return nil                         -- we lost the lock; do not clobber
	end
	profile._savedAt = os.time()
	profile.__lock = { sessionId = sessionId, at = os.time() }
	return profile
end)
```

- Autosave every 120 s staggered by `userId % 120` so a server does not fire 16 writes at once.
- Immediate save after: purchase, unlock, level-up, world unlock, daily claim, mission claim.
- `PlayerRemoving`: final save, then release the lock (`__lock = nil`) so another server can take over.
- `game:BindToClose`: save all loaded profiles in parallel, wait up to 25 s, release locks.

### 7.3 Migrations

`SchemaMigration.migrate(profile)` runs on load, in order, version by version. Each step is a pure
function `v(n) -> v(n+1)` and each is unit-tested with a fixture of the old shape. Unknown future
versions (`profile._v > CURRENT`) are refused with a session error rather than downgraded — a
downgrade would silently delete a newer player's data.

### 7.4 Receipt ledger

`ReceiptLedger` is a separate DataStore keyed by `PurchaseId` (string), value `{ userId, key, at }`,
`TTL_DAYS = 90` enforced by pruning during the weekly maintenance pass. `ProcessReceipt` writes the
ledger entry **in the same `UpdateAsync` transform** that grants the item, so a duplicate receipt
either grants exactly once or is detected and answered `PurchaseGranted` immediately.

---

## 8. World construction and pooling

`ZoneService` owns zones; `WorldBuilder/*` owns the look of a world. A builder is a module returning:

```lua
type WorldBuilder = {
	BuildZone(zone: Zone, profile: WorldProfile, rng: Rng): ()   -- static scenery
	BuildChunk(zone: Zone, chunk: ChunkDef): ()                  -- per-chunk rows
	ClearChunk(zone: Zone, chunk: ChunkDef): ()                  -- recycle
	VehicleModel(zone: Zone, type: VehicleTypeId): Instance      -- pooled
}
```

- **Static scenery** (trees, rocks, buildings) is placed once per zone and moved between chunk
  boundaries as the run advances, so a 5,000-row run does not build 5,000 forests.
- **Vehicles** come from a per-zone pool of 40; a chunk borrows the vehicles it needs and returns them
  on recycle. Pool exhaustion is logged and the chunk renders fewer vehicles (never fails).
- **Chunk rows** are built from a small set of `Part`/`MeshPart` templates cloned and `CFrame`d — no
  per-row mesh generation at runtime.
- `StreamingEnabled = true` with `StreamingMinRadius = 128`, `StreamingTargetRadius = 320`. Zones are
  400 studs apart, so a client only ever streams its own zone plus the lobby.

---

## 9. Client: controllers

`ControllerRegistry` mirrors the server registry: `Init`, `Start`, `Stop`, priority order.
Controllers are required to be **idempotent on `Start`** so a respawn or rejoin does not double-bind.

| Controller | Responsibility | Key rule |
|---|---|---|
| `InputController` | Keyboard, gamepad, touch (swipe + D-pad), context stack | Emits intents; never moves anything |
| `MovementController` | Local prediction, step tween, buffering, reconciliation | Uses only accepted-step data from the server for anything that affects rewards prediction |
| `TrafficViewController` | Interpolates `TrafficSim` output to render CFrames, recycles pooled models | Never runs collision logic that grants rewards |
| `CameraController` | Frame-locked follow, death pull-back | `RenderStepped`; no TweenService on the camera |
| `UIController` | Router, screen stack, input capture | One screen owns input at a time |
| `EffectsController` | Pooled emitter, screen shake (offset only), vignette | Caps concurrent emitters by `GraphicsTier` |
| `AudioController` | Music director, SFX director, 3 buses, ducking | Bus volumes from settings; nothing bypasses |

**Input contexts.** `Lobby`, `Gameplay`, `Modal`, `Cutscene`. Each context declares which inputs it
consumes; the top of the stack wins. Gameplay consumes direction and jump; `Modal` consumes
everything and pauses local prediction (the server run continues but the player is standing still —
and standing still in traffic is dangerous, so opening the pause menu in a live lane is blocked with a
message: "Step to safety first"). That last rule prevents players from pausing to escape death.

---

## 10. Telemetry

`Telemetry.emit(event, fields)` batches into a 30 s flush. Two sinks:

1. **In-house counters** in a `DataStore` (`FawnRush_Metrics_v1`) for live ops dashboards we control.
2. **Roblox analytics** where the platform API applies — `AnalyticsService:LogCustomEvent` for
   progression markers and `LogEconomyEvent` for currency flows and `LogFunnelStepEvent` for the
   first-run funnel. `[VERIFY]` Signatures must be re-checked against current documentation before
   Phase 8; if any differ, the call is wrapped in a feature flag and disabled.

Event names (snake_case, stable, never renamed once shipped):

```
session_start, session_end, run_start, run_end, run_bank, run_death,
death_cause, rows_total, near_miss, combo_tier, animal_unlock, cosmetic_equip,
mission_complete, mission_claim, daily_claim, level_up, shop_open, shop_purchase,
robux_purchase_attempt, robux_purchase_complete, badge_award, world_unlock,
gen_fallback, ui_error, remote_reject, load_fail, save_fail
```

No personal data beyond the Roblox `UserId` and the platform's own attributes. No free-text fields.

---

## 11. Error handling and observability

- `Logger` with `debug/info/warn/error`, a per-server ring buffer of the last 300 entries, and a tag
  per service.
- **Developer overlay** (`F3` on desktop, 3-finger tap on mobile, gated to studio/authorized user ids
  in config): shows FPS, ping, zone id, run phase, entity counts, economy transaction log, and the
  last 20 errors. This is the QA team's primary tool and replaces print-debugging.
- **Error budget:** more than 5 unhandled remote errors for a player in 60 s logs a `remote_reject`
  telemetry event with the offending remote name. Over 50, the player's remotes are muted for the
  session (they can rejoin). This is anti-abuse hygiene, not punishment of legitimate players.
- **Load/save failures** raise a player-facing modal (never a silent reset) and a telemetry event.

---

## 12. Testing harness (no external dependencies)

Decided in `00` D9: no Wally packages.

- `src/server/Tests/TestKit.luau` — `describe/it/expect`, `beforeEach`, timing assertions, and a tiny
  deterministic fake clock.
- `src/server/Tests/RunTests.server.luau` — guarded by `RunService:IsStudio()` **and** a
  `TEST_MODE` attribute; runs the suite and prints a report when `_G.FAWN_RUSH_RUN_TESTS` is set or the
  `--test` flag file exists in Studio. Ships in the repo (tests are source) but is inert in live.
- Test files live beside the module they test: `TrafficSim.spec.luau`, `ChunkGenerator.spec.luau`,
  `SafePathValidator.spec.luau`, `EconomyService.spec.luau`, `SchemaMigration.spec.luau`, and so on.
- Simulation tests are pure — no Roblox instances, no players — so they run in milliseconds and can be
  run in a loop over 10,000 seeds.

---

## 13. Boot sequence (server)

```
1  Telemetry guard (do not crash if the service is unavailable)
2  Logger init
3  Data service Init  → validate DataStore reachability; if unavailable, mark degraded
4  Economy/Inventory/Mission/Achievement Init → read config, validate cross-references
   (config validation: every animal id referenced by a mission exists; every price > 0;
    every cosmetic slot is known; every gamepass id is either 0 or a positive integer)
5  Zone/Chunk/Traffic Init → build the lobby, warm pools for 4 zones
6  Run Init → bind remotes
7  Social Init → start leaderboard poll loop (60 s), presence
8  Monetization Init → MarketplaceService callbacks; log unconfigured ids as warnings
9  Start loops: autosave, metrics flush, leaderboard cache
10 Accept players
```

A failed config validation is a **hard stop** with a loud error, because a config that references a
non-existent animal id would corrupt a save later. Fail fast at boot, not at runtime.

---

## 14. Failure modes and what the player sees

| Failure | Server behaviour | Player sees |
|---|---|---|
| DataStore load fails | Session refused, nothing written | Modal: "Couldn't load your save. Please rejoin in a minute." (retry button) |
| DataStore save fails mid-session | Retry; keep the profile in memory; retry on the next autosave and on leave | Nothing, unless the final save also fails → "Your last save didn't go through. Progress in this session may not be kept." |
| Duplicate session | Second server refused | Rejoin prompt with the reason |
| Chunk validation fails 4× | Guaranteed template, `gen_fallback` telemetry | Nothing (seamless) |
| Traffic/gust schedule missing | Run continues with base speeds | Nothing |
| Gamepass id `0` in config | Feature disabled, warning at boot | Purchase button absent, not dead |
| Product id `0` | Same | Pack tile shows "Coming soon" and is not clickable |
| Badge id `0` | Award path no-ops | Nothing |
| Audio asset id `0` | Bus silent, one warning per id | Silence, never an error loop |
| Player leaves mid-run | Run finalised as abandoned, saved | — |
| Server shutdown | `BindToClose` saves all, releases locks | Rejoin elsewhere with data intact |

---

## 15. What this architecture deliberately does not do

- No client-authoritative physics for anything that scores.
- No `RemoteFunction` request/response.
- No `wait()` / deprecated APIs (`spawn`, `delay`, `wait`, `Instance:remove`, `BodyMovers`,
  `Humanoid:LoadAnimation`, `game:GetService("PointsService")`).
- No global `_G` state outside the explicit test hook and the developer overlay toggle.
- No `while true do wait() end` polling loops; `task.wait` inside `task.spawn` with a named loop and a
  stop handle, driven by the service's `Stop`.
- No implicit ordering dependence between services at `Start` beyond the declared priority.
