## Phase 5 follow-up — responsive source completion

A focused source pass completed the responsive layouts and portrait HUD guidance that were still addressable
without Studio. It also connected reduced-motion settings to direct camera/UI effects and run-start failures
to the existing button failure state. No Studio, Luau, Blender or Python runtime was available. No tests,
builds, exports, device runs, visual inspections or performance measurements are claimed. Phase 5 remains
**Partial** and no phase has been Studio-verified; Phase 4 still lacks required binary exports.

### Implemented and wired

- Every currently implemented screen exposes a viewport-driven layout API, and `UIController` refreshes
  those layouts as the camera viewport or text scale changes. Insets remain owned by the safe frame.
- Portrait HUD guidance is positioned beside the score row in the top band. The existing Phase 5 geometry
  test now asserts its bounds and non-overlap with score, combo and acorns; it adds assertions inside an
  existing case, so the suite remains 12 cases and the project remains at 99 written cases.
- Reduced motion suppresses camera shake, direct near-miss/death flashes and pickup sparkles. Ambient
  weather and character motion are not comprehensively gated.
- Run-start local/server refusals and timeouts now use the button failure state as well as visible inline
  status. The existing loading and cancellable slide/scale navigation remain unchanged.
- Touch FOV remains 70: narrowing it without Studio calibration risks reducing lateral hazard visibility.

### Still incomplete

- Phase 5 remains open: pause, planned screens/components, fade/modal systems, broad component coverage,
  Studio/device layout and accessibility review are outstanding.
- B2 still lacks profile/currency/level/notification services and additional live destinations. B9 still
  lacks inventory/shop services, offers, odds and purchases; B10 has no real reward/unlock triggers. No
  balance, progression, ownership or reward data was fabricated.
- B12 appearance and particle budgets have not been measured. Phase 4 `.blend`/`.fbx` deliverables remain
  absent; manifest asset IDs remain unconfigured.
- All four Studio suites still contain 99 written `TestKit.it` cases, none executed.

### Documentation and tracking

Updated the requirements register, UI specification, milestones, Studio gate/handoff, README and this log.
B3 moved from Partial to Built for source layouts of currently implemented screens only; it is not Verified.
Rollup: B 6 Built / 5 Partial / 1 Pending; C 0 / 2 / 10; D 0 / 0 / 13; E 0 / 3 / 8; overall 6 Built / 10
Partial / 32 Pending / 0 Verified. Phase 6 and Phase 8 work has not started.

---


# Changelog

## Phase 4 closure audit

Twelve requested checks. Six defects found and fixed, one of which would have made the Blender export
crash on its first run. No world-system redesign; no Phase 5 work started.

### Fixed — Blender pipeline

- **The LOD build called a non-existent asset (blocking).** `build_object(name + LOD_SUFFIX)` passed the
  suffixed name straight into `meshlib.build_asset()`, which looks up `ASSETS[...]` — so every LOD
  build raised `KeyError` and `build_environment.py` could never have completed. `build_object` now
  takes the asset name and the object name separately.
- **`modifier_apply` ran with a stale selection.** Decimate is applied through `bpy.ops`, which acts on
  the active object; the object was made active but never selected and nothing was deselected first.
  It now deselects all, selects the target, then applies.
- **OBJ objects were unnamed.** The exporter emitted vertices and faces but no `o` line, so importers
  that key off object names produced an anonymous mesh. Added, with a note that the format carries no
  normals or UVs by design.

### Fixed — Roblox

- **The lobby lost its shadows.** Phase 4 routed lobby scenery through `WorldKit`, whose parts are
  deliberately shadowless for run cost. That was an unintended visual regression in the Phase 2 lobby.
  `WorldKit.setShadows()` now lets a single fixed scene opt back in, and `LobbyBuilder` does.
- **Graphics tier was memoised for the whole session.** A player changing their quality setting between
  runs kept the first run's effect budget. `WorldEffectsController` now calls `GraphicsTier.refresh()`
  per run.
- **The prop-cap assertion was vacuous.** It compared against `MAX_PROPS_PER_CHUNK * 2`, which no world
  could ever exceed. Tightened to the real cap, which every world still passes at 24 of 40.

### Corrected — documentation

- **Asset-definition count.** The Phase 4 report said "seven asset definitions" and then listed eight.
  `meshlib.ASSETS` holds **8**; `assets/blender/README.md` now names them.
- **Export fidelity is documented, not assumed.** A table in the Blender README states exactly what
  each path preserves: scale, orientation, origin, naming, materials, normals/UVs, LOD. Recorded that
  the OBJ path's material handling in Studio is unverified, and that FBX is authoritative for
  multi-material assets (`docs/12` S14).
- **Missing textures are now listed.** The manifest gained a `textures` section (character atlas,
  vehicle palette, neon emissive), all `todo` with empty ids. Character and vehicle meshes are
  specified to use a palette atlas; the manifest previously did not mention it.
- **The exit criteria record the shortfall.** `docs/08` now also states that the "throw-away sixth
  world" proof was not performed, alongside the already-recorded unmet mesh criterion.

### Source-reviewed (static only; not executed)

- **Two exporter commands, documented separately** — one Python-only, one Blender; different outputs.
- **Five worlds are structurally distinct**, not tinted: different prop kinds, prop bands, densities,
  road surface, marking style, median material, lighting rig and ambient emitter.
- **Collectible values are world-independent.** `ChunkGenerator` reads values from `GameConfig`; a world
  only changes the pickup's *chance* and its skin.
- **Client-side run lighting cannot conflict between players.** `Lighting` is replicated state, client
  edits stay local, and the server sets it once at boot; the unlock seam is `EnvironmentRig`.
- **Phase 1–3 callers are intact.** `requestStart` has exactly one caller (updated), `EnvironmentService`
  still exposes `init`, `WorldRenderer` still exports `removeCollectible`, and all three suites' inputs
  (`WorldConfig.get`, `rampRows`, `cornerWeights`) still exist.

### Not verified

Everything. No Studio session, no Blender run, no Python run. The two exporters remain unexecuted —
fixing a crash on paper is not the same as seeing it produce a mesh.

# Changelog

## Phase 4 — Worlds and the Blender pipeline

Five playable worlds from one schema, a reusable scenery kit, per-world lighting and ambience, the
unlock rule, and both halves of the asset pipeline. Nothing was executed; nothing is claimed as
verified.

### Worlds

Five profiles in `shared/Config/WorldConfig.luau`, each with its own difficulty curve, palette,
lighting rig, ambient effect, scenery density and collectible skin:

| World | Identity | Difficulty | Collectible |
|---|---|---|---|
| Greenwood Crossing | Sunlit forest highway, wide medians, the gentlest ramp | 9–18 studs/s, 500-row ramp | Acorn |
| City Chaos | Downtown: crosswalks, kerbs, buildings, buses and taxis | 12–21, 560 rows, densest corridors | Token |
| Desert Dash | Sand, mesas, cacti, heat haze, fast and sparse | 13–23, 600 rows, widest prop band | Cactus Nut |
| Snowy Summit | Frozen pass, ice road, pines, snowfall — slower and slippery | 8–16, 640 rows, longest headways | Ice Gem |
| Neon Night | Wet neon boulevard, holographic signage, fastest traffic | 15–25, 700 rows, tightest headway | Light Shard |

Collectible *values* are identical across worlds on purpose: `docs/01` §8 forbids a world that pays
better per row, which would make the first world pointless.

### Reusable world architecture

- **`shared/Config/WorldConfig.luau`** — the schema. Gameplay keys feed `ChunkGenerator` unchanged;
  presentation keys feed the renderer. `validate()` checks palette completeness, difficulty sanity,
  corridor weights, prop profiles, effect caps and unlock ordering, and runs at boot.
- **`shared/World/WorldKit.luau`** — 17 procedural builders (tree, pine, bush, rock, mushroom, cactus,
  mesa, building, street light, billboard, snow bank, ice sheet, neon tower, neon sign, holo pylon,
  pond, bridge) behind one `prop()` dispatch. A new prop is one function plus one table entry.
- **`shared/World/EnvironmentRig.luau`** — the lighting rig, shared by the server's lobby baseline and
  the client's per-run application, so the two cannot drift apart.
- **`shared/Util/GraphicsTier.luau`** — low/medium/high from the player's own quality setting, with a
  `game` attribute override for testing. Effect rates and accent emitters scale against it.
- **`shared/Simulation/WorldUnlock.luau`** — the unlock rule as a pure function of `{level,
  lifetimeRows}`, plus `snapshot()` for UI and `describe()` for a one-line requirement.

Adding a sixth world is a config block. No simulation, generator, service or renderer control flow
changes — proven by the fact that Phase 4 changed none of them.

### Rendering

`client/Controllers/WorldRenderer.luau` was rewritten to be world-driven rather than Greenwood-hard
-coded: road surface and markings per profile (`edge`, `crosswalk`, `dashed`, `glow`), median material
per style, scenery band and density per world, collectible skin per world. Placement is a pure hash of
(row, attempt) rather than the server RNG, so every client builds the same scenery with no network
cost and the generator's determinism is untouched.

Two new controllers:

- **`EnvironmentController`** applies the run's lighting **locally**. `Lighting` is shared replicated
  state; if the server set it per run, two players in different worlds would fight over one rig.
- **`WorldEffectsController`** runs one ambient emitter (leaves, dust, sand, snow, motes) plus an
  optional accent (fireflies), attached to a part that follows the camera, rate-capped by tier.

### Defects found and fixed during the phase

| # | Severity | Area | Detail |
|---|---|---|---|
| B1 | S2 | Scenery | Three worlds placed scenery at 30 studs from the centreline, inside the 32-stud playfield — buildings would have stood where the player walks. Every band minimum is now outside the field, and a test pins it. |
| B2 | S3 | WorldKit | `pine()` contained a truncated snow-cap block referencing a non-existent `Version.DEFAULT`. |
| B3 | S3 | WorldKit | `collectible()` material used `a or b and c or d`, which binds wrongly and could assign the boolean `true` as a material for a shard. |
| B4 | S4 | WorldKit | `bridge()` picked its ice/wood variant from `colors.ice`, which **every** palette defines, so every bridge would have been frozen. The variant is now explicit. |
| B5 | S4 | Config | `MAX_PROPS_PER_CHUNK` was a renderer-local magic number; it is now `GameConfig` data and a test bounds it. |

### Blender pipeline

- **`assets/blender/lib/meshlib.py`** — pure Python 3 geometry: box, sphere, cylinder, the palette, the
  asset definitions and `validate()`. Shared by both exporters so they cannot drift.
- **`assets/blender/export_obj.py`** — writes `.obj` + `.mtl` with **no Blender required**.
- **`assets/blender/build_environment.py`** — Blender entry point: real mesh objects, palette
  materials, a decimated LOD variant, `.fbx` per asset and `.blend` per family.
- **`assets/export/_reference/REF_Box_4stud.obj`** — the scale gate from `docs/06` §5.2.1, committed as
  a real file because it is a required validation asset and a cube is trivially correct.

**No `.blend` or `.fbx` binary is committed.** The development environment has no Blender and no Python
runtime, so those bytes cannot be produced here. The manifest records this explicitly
(`pipeline.binaryAssetsPresent: false`) rather than implying otherwise.

### Manifest

`assets/manifest.json` v3 adds a `worlds` section (every world, its prop kinds and its asset names), an
`environment.byKind` map, a `pipeline` block stating what exists, and collectibles per world. The Phase 4
suite asserts every `WorldConfig` prop kind has a `byKind` entry — a missing asset is a test failure, not
a silent fallback.

### Tests

`server/Tests/Phase4Tests.luau` adds **30** assertions: registry validity and ordering, palette
completeness, distinct difficulty signatures, prop-kind resolvability, selection and wraparound, unlock
truth tables, per-world generation and determinism, safe-path preservation in every world, vehicle
whitelisting, scenery/playfield separation, prop caps, effect-rate caps, graphics-tier scaling, missing
asset handling, and manifest mapping/ids/statuses.

Total written: **87** (16 + 41 + 30). **Executed: 0.**

### Not verified

Everything. No Studio session, no Blender run, no Python run. Specifically open: whether the five worlds
look distinct on a phone, whether ambient VFX hold 30 FPS on the low tier, whether the world chip reads
clearly, and whether either exporter produces importable geometry.

---


# Changelog

## Phase 3 closure audit

Focused review before Phase 4. Ten requested items, nine code defects found and fixed, one gameplay
defect (`S3`) closed at its root rather than worked around. Nothing was executed; no test result is
claimed.

### Fixed — correctness

- **Duplicate lobby animal (S3, severity S2).** The server built a presence rig for every player and the
  owning client also built its own, so each player saw two deer. Presence models now carry
  `OwnerUserId` and `InRun` attributes; `shared/Simulation/PresenceRules.luau` decides visibility as a
  pure function; `client/Controllers/PresenceController.luau` applies it. `PresenceService` no longer
  re-parents models for visibility, so a client-side hide cannot be undone by a server re-parent.
- **Dead wildlife speed config.** `HazardConfig.wildlife.speedMin/speedMax` were never read —
  position came from a separately configured period, producing crossers at 6.7–12.3 studs/s against a
  stated 5–9. Speed is now the authored number and `ChunkGenerator.makeWildlife` derives the cycle
  (`2 * spanX / speed`), with `ObstacleSim.wildlifeSpeed` exposing it for tests.
- **Unread chunk version.** `chunk.v` was written from Phase 3 but never read, so a future format
  change would have been silently mis-rendered. `shared/Simulation/ChunkFormat.luau` owns the version,
  and `SessionController` refuses a chunk newer than it understands with one warning. v1 chunks stay
  readable: a missing `obstacles` table already meant "none".
- **Wildlife collision ignored body depth.** `wildlifeHalflength` was configured and unused; the row
  was rounded to an integer. `ObstacleSim.wildlifeHit` now tests X and Z overlap for both bodies and
  checks the three candidate row buckets.
- **Wildlife placement.** Crossers no longer spawn in a chunk's first three rows (the player has just
  arrived and has no reaction time), never on a rail row, and never on the chunk's final row.
- **Presence slot drift.** `PresenceService.setAnimal` rebuilt a rig into whatever ring slot happened to
  be free and then recorded the old slot, so a changed animal could move a player once Phase 7 starts
  equipping. The slot is now passed into the rebuild.
- **`AnimationController` could pose nothing forever** if it ran before `MovementController` had built
  the rig. `adoptRig()` now retries from `update`.
- **`AnimationLib` `turn`/`land` used `math.clamp` correctly but `wildlifeBlocks` did not honour
  `SOLVER_SAMPLES`** — it hard-coded three samples while the config said four. It now reads the config.

### Fixed — performance

- `RunService.findHit` scanned every retained lane (~90) at 20 Hz per player. It now looks up the
  player's row and its two neighbours in `lanesByRow`, which is equivalent for a body under one tile
  deep and is three comparisons instead of ninety.
- Lobby presence rigs no longer spawn a dynamic `PointLight` per player (`AnimalBuilder.buildRig` gains
  a `lights` option). Sixteen synths-worth of dynamic lights was the one part of lobby presence that
  scaled badly on mobile.

### Fixed — test quality

Five assertions proved almost nothing and were replaced with behavioural ones:

| Was | Now |
|---|---|
| "every state produces a pose" (count > 0) | core joint + at least three joints per state, and finite angles at five sample times |
| "no row is ever sealed" (threshold 15, unreachable) | every barrier row keeps `minClearColumns` free |
| "a train leaves a crossing window" (compared a constant to itself) | measures the window of a lane the generator actually produced |
| determinism compared kinds and rows only | full chunk signature: lanes, speeds, headways, phases, obstacles, collectibles |
| `validated` asserted true (the fallback always sets it) | also asserts no chunk needed the emergency empty-strip fallback |

Added: unknown-state idle fallback, near-miss reward boundary, crosser two-axis collision, wildlife
speed/period derivation, rail-row and entry-grace placement rules, presence ownership truth table, and
the chunk version contract. Phase 3 suite: 27 → 41 assertions. Total 57.

### Documentation

- `docs/10` gains §10, a Phase 3 coverage map (13 states → brief wording, 13 species, hazard roster,
  near misses, presence, chunk format), and its status rollup moved E10 to `Partial`.
- `docs/12` records S3 as resolved, narrows S5, updates S6, adds S9, and gains a nine-row defect log.
- `docs/03` gains §6, listing the modules added during implementation.
- `assets/manifest.json` now has explicit `owner` fields and adds animation, collectible and VFX
  families; every audio cue is named with an empty `robloxId`.
- README no longer implies execution: "What is built", expected-not-recorded sample output, corrected
  counts, and presence/audio known issues rewritten.

### Not verified

Everything above is code review and static reasoning. No Studio session has run. The suites, the
presence fix on screen with two clients, and the feel of the wildlife changes are all unverified.

---


# Changelog

All notable changes to Fawn Rush. One section per phase. Deviations from the Phase 1 specification
are recorded here rather than silently absorbed.

---

## Phase 3 — Animals, hazards, near misses, presence

**Status: built and code-reviewed. Not Studio-verified.** Written under the phone-first posture:
Studio is now a single integration gate, not a per-phase blocker (`docs/08` "Development posture").

### Added

**Shared**
- `Config/AnimalConfig.luau` — 13 species with real proportions, palettes, rarity, unlock conditions,
  gait and animation coefficients. `validate()` runs at boot.
- `Config/HazardConfig.luau` — rail, closure and wildlife parameters, difficulty gates, colours.
- `Animation/AnimationLib.luau` — 13 pose states as pure functions (idle, alert, walk, run, jump, fall,
  land, turn, fright, stumble, happy, death, victory).
- `Animation/Animator.luau` — priority state machine with sticky durations and cross-fade blending.
- `Simulation/Combo.luau` — ladder, decay, acorn and score rewards.
- `Simulation/NearMiss.luau` — clearance measurement and the qualifying threshold.
- `Simulation/ObstacleSim.luau` — static closures and closed-form wildlife motion.

**Server**
- `Services/PresenceService.luau` — lobby presence: one server-owned model and nameplate per player,
  hidden while that player is running.
- `Builders/NameplateBuilder.luau` — name + animal + rarity colour.
- `Tests/Phase3Tests.luau` — 27 assertions (cast integrity, rig contract, animation priorities, combo,
  near miss, obstacles, hazard generation).

**Client**
- `Controllers/AnimationController.luau` — poses the rig from the Animator; the only thing that writes
  part CFrames.
- `Controllers/EffectsController.luau` — near-miss flash, camera shake, pickup sparkle, death feedback.

### Changed

- `AnimalBuilder` is now species-driven: `buildRig(animalId)` builds any of the 13 species from
  config with explicit joint pivots and a `follow` map for hooves, ear inners and extras. `buildDeer()`
  remains as a compatible wrapper.
- `MovementController` no longer moves parts. It publishes a visual state (`rootCFrame`, stepping,
  chaining, turning, airborne, dead) and `AnimationController` poses the rig. Movement and animation
  can no longer fight over a CFrame.
- `RunService` adds server-authoritative near misses, combos, jumps, closures and wildlife, and emits
  `runStarted` / `runEnded` signals for presence. Score now includes near-miss points.
- `ChunkGenerator` emits rail corridors, static closures and wildlife, all difficulty-gated, and
  guarantees closures can never seal a row.
- `SafePathValidator` treats barriers and wildlife as blocked tiles.
- `InputController` adds jump (Space, gamepad A/R2, touch button).
- `HUD` adds the combo pill with a drain bar and a touch jump button.
- `VehiclePool` adds distinct bus, motorcycle and train silhouettes plus a truck bed.
- `WorldRenderer` renders rail beds, closures and moving wildlife.

### Scope notes

1. **Jump carries one tile forward** whenever the tile ahead is legal, rather than requiring the
   client to report that forward was held. Deterministic on the server, one fewer trust boundary.
2. **Near misses are vehicle-only** in Phase 3. Wildlife contact kills; it does not award.
3. **Train warnings are not networked.** The client has the lane data and can detect an arriving
   train itself, so no per-train remote was added.
4. **Presence shows the default deer for everyone** until Phase 7 wires equipping through
   `PresenceService.setAnimal`. The hook exists and is documented rather than faked.
5. **All 13 animal models are procedural parts.** They are labelled temporary; Blender meshes remain
   Phase 4 and the joint contract they must satisfy is documented in `AnimalBuilder`.

### Source-reviewed (static inspection only)

- [x] Every new module's requires resolve to files that exist; no circular requires were identified.
- [x] All animation, combo, near-miss and obstacle maths are pure functions of time and parameters.
- [x] Server authority preserved: near-miss awards, combo state, jump acceptance, barrier rejection
      and wildlife collision are all server-side.
- [x] Phase 2 suites are untouched and still run first on boot.

### Not verified

- [ ] Anything visual. Pose quality, silhouette, blend smoothness and VFX intensity need eyes.
- [ ] The 27 new assertions actually passing in Studio.
- [ ] Presence with two real clients.
- [ ] Frame cost of 13 rigs, wildlife motion and the new vehicle types.

---

## Roadmap expansion — Prompts B, C, D, E made mandatory

**Scope:** planning and traceability only. **No gameplay code changed in this entry.**

The four additional requirement sets (B — premium visuals and UX, C — progression and retention,
D — monetization, E — professional QA and polish) are now binding deliverables rather than
intentions. Nothing was duplicated: each prompt maps onto a milestone that already existed.

### Added

- `docs/10_REQUIREMENTS_REGISTER.md` — all 48 line items (B12, C12, D13, E11) with ID, owning phase,
  status, and the exact acceptance condition that would move each one from `Built` to `Verified`.
  Includes a status rollup, a change log for status transitions, and a "reuse map" listing the existing
  modules each prompt must build on instead of re-implementing.
- `docs/11_PHASE2_VERIFICATION.md` — the blocking Studio gate: preconditions, 16 automated assertions,
  15 manual steps, a device/multiplayer matrix, a defect log with S1/S2 exit rules, the list of
  expected noise, and a sign-off block.

### Changed

- `docs/08_MILESTONES.md` — added the requirement integration map (prompt → phase), the per-phase
  coverage table, a status line for Phase 2, and a "Closes prompt requirements" line on Phases 3–10.
  Phase 3 is now explicitly blocked by the Phase 2 gate.
- `docs/09_RISK_AND_TESTING_PLAN.md` — cross-linked to the register and the gate.
- `docs/00_INDEX.md` — reading order extended to 10 and 11.
- `README.md` — status now reads "Studio verification pending"; added a Requirement tracking section
  with the live rollup; documentation table extended.

### Status baseline (recorded so it cannot drift)

| Prompt | Built | Partial | Pending | Verified |
|---|---|---|---|---|
| B | 3 | 6 | 3 | 0 |
| C | 0 | 1 | 11 | 0 |
| D | 0 | 0 | 13 | 0 |
| E | 0 | 2 | 9 | 0 |
| **Total** | **3** | **9** | **36** | **0** |

### Process rules added

1. A requirement may only move to `Verified` in a commit that contains the recorded execution.
2. A phase may not close while any of its assigned requirements is `Pending` or `Partial`.
3. Phase 10 requires all 48 `Verified`, or listed in `KNOWN_LIMITATIONS.md` as cosmetic-only.
4. No gameplay expansion begins until `docs/11` is signed.

---

## Phase 2 — Playable vertical slice

**Scope:** lobby, deer, grid movement, camera, traffic, collision, collectibles, score, death/restart,
HUD, touch controls, procedural generation with safe-path validation, lobby → run transition.

### Added

**Repository**
- `default.project.json` — Rojo mapping for `Shared`, `Server`, `Client`; `CharacterAutoLoads = false`.
- `.luaurc`, `selene.toml`, `stylua.toml`, `.gitignore`.

**Shared (`src/shared`)**
- `Config/GameConfig.luau` — every tunable: grid, movement, collision, solver, camera, vehicle archetypes.
- `Config/WorldConfig.luau` — Greenwood profile (traffic, palette, collectible rates, lobby spawn).
- `Constants/Net.luau` — remote names and per-remote rates.
- `Types/GameTypes.luau` — `LaneDef`, `ChunkDef`, payload shapes (documentation + editor hints only).
- `Util/Signal.luau`, `Util/Logger.luau`, `Util/GridMath.luau`, `Util/Rng.luau`.
- `Net/Remotes.luau` — remotes are created at boot, never committed as binary instances.
- `Simulation/TrafficSim.luau` — closed-form vehicle positions, overlap tests, tile-safety sampling.
- `Simulation/ChunkGenerator.luau` — deterministic 12-row chunks, median/corridor structure, headway floor.
- `Simulation/SafePathValidator.luau` — time-indexed BFS proving a survivable path per chunk.
- `Simulation/Scoring.luau` — score and XP formulas.
- `Builders/AnimalBuilder.luau` — the procedural baby deer.

**Server (`src/server`)**
- `Bootstrap.server.luau` — remotes → lighting → lobby → services → remote binding.
- `Services/ServiceRegistry.luau` — explicit ordered boot, failed service disables itself.
- `Services/RemoteGate.luau` — token buckets, direction validation, error containment.
- `Services/ZoneService.luau` — one isolated strip per player, spaced 520 studs apart.
- `Services/ChunkService.luau` — generate ahead, stream to owner, prune behind.
- `Services/RunService.luau` — step validation, authoritative collision, collectible crediting, score, death.
- `Services/EnvironmentService.luau` — lighting, atmosphere, bloom, colour grade.
- `Builders/LobbyBuilder.luau` — forest clearing, sign, start line, trees, rocks.
- `Tests/TestKit.luau`, `Tests/Phase2Tests.luau` — 16 assertions covering determinism, geometry,
  scoring, traffic maths, and the fairness guarantee.

**Client (`src/client`)**
- `Bootstrap.client.luau`, `Controllers/ControllerRegistry.luau`.
- `Controllers/SessionController.luau` — the only place that reads run remotes; exposes signals.
- `Controllers/InputController.luau` — keyboard, gamepad (D-pad + stick), swipe, on-screen pad.
- `Controllers/MovementController.luau` — prediction, interpolation, buffering, reconciliation.
- `Controllers/CameraController.luau` — damped follow, lead offset, raycast pull-in, death framing.
- `Controllers/TrafficRenderer.luau`, `Builders/VehiclePool.luau` — pooled vehicles, zero per-frame allocation.
- `Controllers/WorldRenderer.luau` — roads, grass, trees, acorns, chunk recycling.
- `Controllers/UIController.luau`, `UI/Theme.luau`, `UI/Components.luau`, `UI/Screens/{Lobby,HUD,Results}`.

### Deviations from the Phase 1 specification

Each of these is a deliberate, reasoned change. None removes a promised capability.

1. **`AnimalBuilder` lives in `shared/`, not `server/Builders/`.** The client builds its own animal in
   Phase 2, so the builder must be reachable from both sides. Phase 3 (server-side lobby presence) uses
   the same module without moving it again.
2. **Run-zone scenery is client-built; the server creates no parts for a run.** The server sends
   `ChunkDef` data and judges collision from it. A client cannot gain by lying about scenery, and
   server cost stays flat with 16 concurrent runs. `docs/02` §8 described server-side pooling for
   Phase 4's authored worlds; Phase 2 takes the cheaper path that the closed-form model makes possible.
3. **No `RemoteFunction` anywhere.** Matches `docs/02` §5.1; request/response is modelled as events.
4. **`StreamingEnabled = false` in Phase 2.** Run content is client-built and not streamed, so
   streaming would only risk unloading the lobby. It remained off through Phase 4 and has not been
   measured with the authored worlds.
5. **`StarterGui.Theme` was dropped from the project file.** The Phase 1 draft mapped a ModuleScript
   into `StarterGui`, which would clone it into every `PlayerGui` for no benefit. UI is built by
   `UIRoot`/`UIController` at runtime.
6. **No `workspace:GetServerTimeNow()` custom clock sync.** The built-in server clock is used directly
   by both sides, which is simpler and accurate enough for the closed-form model.
7. **Validator searches from a single entry phase.** A true phase-space proof is Phase 10 work; the
   retry ladder and the guaranteed template cover the remainder. Documented in README "Known issues" §4.
8. **Client step cooldown is 12 ms longer than the server's floor** (`CLIENT_COOLDOWN_PAD`), so a step
   is never rejected for landing a few milliseconds early on a skewed clock.

### Source-reviewed (static inspection only)

- [x] Every module's syntax and requires were inspected; no Studio or Luau execution is claimed.
- [x] Every documented number used in code exists in `GameConfig` / `WorldConfig` (no magic numbers in
      services or controllers).
- [x] Server rejects: out-of-cooldown steps, out-of-bounds steps, steps while dead or not running,
      unknown directions, unknown worlds, and rate-limit abuse.

### Not verified (cannot run Studio in this environment)

- [ ] First Play session: boot, lobby render, model build, camera framing.
- [ ] The 16 automated tests actually passing in Studio.
- [ ] Collision feel and the forgiveness window on 100+ ms latency.
- [ ] Touch D-pad and swipe on a real device.
- [ ] Frame rate on a low-tier Android.

These are the first four items of the manual checklist in the README.

### Fixed during review (before first run)

- `LobbyBuilder` referenced `board.BillboardGui.SignText`, which is not a valid path; the subtitle is
  now parented directly to the billboard GUI.
- Lobby `PLAY` button was left at `BackgroundTransparency = 1` by an over-eager entrance animation.
- Lobby tree trunks used `Enum.PartType.Cylinder` unrotated, which lays the cylinder on its side.
  Trunks are blocks.
- `Results` assigned to an undeclared global (`acorns = acornValue`).
- `ChunkGenerator.generate` was an accidental global.
- Solver node cap raised 6,000 → 12,000 so a legitimately solvable 12-row chunk cannot be misjudged.
- Client reconciliation now also corrects a drift of two or more tiles mid-run, not only when idle.

---

## Phase 1 — Design and architecture

Ten documents in `docs/` covering design, architecture, file tree, mechanics, UI/UX, assets,
monetization, milestones, and risk/testing. No code. See `docs/00_INDEX.md`.
