# FAWN RUSH

**Every crossing is a new adventure.**

A multiplayer Roblox game about small animals crossing very dangerous places.

| | |
|---|---|
| Genre | Multiplayer animal survival / endless crossing / collection / progression |
| Platform | Roblox (PC, mobile, tablet, console) |
| Primary device | Touch, landscape |
| Engine | Roblox Luau, Rojo 7 source layout |
| Status | **Phase 5 — UI foundations implemented; phase partial; Studio verification pending** |
| Code | Roblox Luau source + `default.project.json`. Written for Studio but never run there — see "Testing instructions" |
| Mandatory scope | 48 tracked requirements across Prompts B, C, D, E — see [Requirements Register](docs/10_REQUIREMENTS_REGISTER.md) |

---

## What is built

A Roblox source project with gameplay, five world profiles, and partial UI foundations. **Nothing has
been executed in Roblox Studio.** Phase labels distinguish source-built work from Studio-verified work;
these tables describe implementation intent, not observed runtime behaviour.

| Phase 2 requirement | State |
|---|---|
| Functional starting lobby | Forest clearing, sign, trees, start line, living deer |
| Playable baby deer | Procedurally built rigged deer, hop arc, idle bob, turning |
| Lane-based movement | Grid steps, 0.10 s cadence, single-slot input buffer, held-input running |
| Smooth follow camera | Damped, lead offset, raycast pull-in, death pull-back |
| Four functional traffic lanes | 1–3 lane corridors, four vehicle archetypes, both directions |
| Cars at different speeds | 9–18 studs/s base × per-type multiplier × per-lane jitter |
| Collision detection | Server-authoritative swept overlap against closed-form traffic |
| Run acorns | Generated per chunk and credited to the current run by the server; not account currency and not saved |
| Distance counter | HUD, metres, server-derived |
| Score system | `rows × 10 + acorn value`, computed only on the server |
| Death and restart flow | Impact freeze → results card → Retry or Lobby, under 2.5 s |
| Gameplay HUD | Distance, score, acorns, touch D-pad, mobile-first layout |
| Procedural lane generation | Deterministic seeded chunks, difficulty ramp, medians |
| Safe-path validation | Time-indexed search proves every shipped chunk is survivable |
| Lobby → gameplay transition | One tap, isolates the player into their own zone |
| Keyboard + touch controls | WASD/arrows, swipe anywhere, on-screen D-pad, gamepad D-pad and stick |

**Phase 3 added**

| Feature | State |
|---|---|
| Thirteen species | Config-driven rigs with genuinely different proportions, palettes and extras |
| Thirteen animation states | idle, alert, walk, run, jump, fall, land, turn, fright, stumble, happy, death, victory |
| Animation architecture | Pure pose library + priority state machine with blending; one system drives all species |
| Hazard roster | Cars, sports cars, trucks, vans, buses, motorcycles, trains, closures, wildlife |
| Near misses and combos | Server-detected, de-duplicated, combo ladder to ×5.0 with 6 s decay |
| Jump | Committed one-tile leap, immune to wildlife at the apex, server-validated |
| Lobby presence | Server-owned model + nameplate per player, hidden while they run |
| Feedback | Near-miss flash, capped camera shake, pickup sparkle, death flash |

**Phase 4 added — five worlds**

| World | Identity | Difficulty | Collectible |
|---|---|---|---|
| Greenwood Crossing | Sunlit forest highway, wide medians | 9–18 studs/s, 500-row ramp | Acorn |
| City Chaos | Crosswalks, kerbs, buildings, buses and taxis | 12–21, 560 rows, densest corridors | Token |
| Desert Dash | Sand, mesas, cacti, heat haze | 13–23, 600 rows | Cactus Nut |
| Snowy Summit | Ice road, pines, snowfall, slower traffic | 8–16, 640 rows | Ice Gem |
| Neon Night | Wet neon boulevard, holo signage, fastest traffic | 15–25, 700 rows | Light Shard |

All five use the same schema and simulation. World profiles and selection UI are implemented in source;
visual distinction and gameplay remain unverified. Unlock requirements are previewed but not enforced
until a real profile and progression service exist.

**Phase 5 foundations added**

- Central UI tokens, responsive helpers, contrast checks, reduced-motion handling and text scaling.
- Shared HUD layout calculations, portrait rotate guidance in the top HUD band, and a four-lease viewport-preview budget.
- Lobby, world selection, collection catalogue, customization shell, shop shell, settings, HUD and results
  screens. Every implemented screen has viewport- and text-scale-driven reflow wired through `UIController`; menus assign
  initial gamepad focus, and run-start failures show a button state plus a non-overlapping inline reason.
- Studio-boot Phase 5 design and geometry tests are wired in, but have not run. HUD rectangles come from a
  shared helper and do not establish rendered Studio geometry or cutout behavior. The touch camera FOV remains
  70 pending Studio sightline calibration so lateral hazard visibility is not reduced speculatively.

These are foundations, not a completed Phase 5. B3 is source-built for all currently implemented screens,
but no layout or device behavior has been Studio-verified. **Still disconnected or incomplete:** persistent
currency, ownership, equipping, cosmetic inventory, offers, purchases, odds, missions, rewards, pause, profile
persistence, audio, and the rest of the planned UI screens. Lobby and collection previews use procedural
rigs; no uploaded mesh IDs are configured. Phase 6 and Phase 8 work has not started.

---

## Setup on Windows

### 1. Install Rojo

Rojo turns this repository into a Roblox place.

**Option A — Rokit (recommended)**

```powershell
winget install rokit
rokit init
rokit add rojo-rbx/rojo
rojo --version
```

**Option B — manual**

1. Download the latest `rojo-*-win64.zip` from https://github.com/rojo-rbx/rojo/releases.
2. Extract `rojo.exe` somewhere permanent, e.g. `C:\Tools\rojo\`.
3. Add that folder to `PATH` (Start → "environment variables" → Path → New).
4. Open a **new** terminal and run `rojo --version` (needs 7.4 or newer).

### 2. Install the Rojo Studio plugin

1. Open Roblox Studio.
2. **Plugins → Manage Plugins →** search "Rojo" (by rojo-rbx), or download `Rojo.rbxm` from the Rojo
   releases page and drop it into `%LOCALAPPDATA%\Roblox\Plugins`.
3. Restart Studio.

### 3. Serve the project

```powershell
cd "path\to\Fawn Rush"
rojo serve
```

Leave that terminal open. It prints `Rojo server listening on localhost:34872`.

### 4. Connect Studio

1. Open Studio → **New → Baseplate** (any baseplate is fine; the game deletes it).
2. Open the Rojo panel (Plugins tab → Rojo) → **Connect**.
3. You should see `ReplicatedStorage.Shared`, `ServerScriptService.Server`, and
   `StarterPlayer.StarterPlayerScripts.Client` appear in the Explorer.
4. Press **Play** (F5).

The server builds the lobby, the client builds your deer, and the lobby screen appears. Press **PLAY**
to start a run.

> Rojo syncs *source* only. Press **Stop** and **Play** again and everything rebuilds from the repo —
> you never need to save the place file.

---

## Testing instructions

### Automated tests (run automatically in Studio)

On server boot in Studio, `src/server/Tests/Phase2Tests.luau` prints to the **Output** window. The
block below is the **expected** shape of that output, not a recording — it has never been run:

```
[tests] -- Rng determinism
  ok    same seed produces the same sequence
  ...
[tests] generated 50 chunks in <measured ms> ms (<retry count> needed a retry)
[tests] PASSED 16/16
[tests] PASSED 57/57
[tests] PASSED 87/87
[tests] PASSED 99/99
```

What the suite proves:

- The RNG is deterministic for a seed and diverges between seeds (server/client agreement).
- Tile ↔ world conversion and bounds are exact.
- Score arithmetic matches the spec.
- A vehicle's position is a pure function of time, and overlap maths hits the right tile.
- **The fairness guarantee:** a synthetic solid wall of traffic is *rejected*, and a wide gap in the
  same lane is *accepted*.
- 50 generated chunks: every one validates, every lane clears the headway floor, no corridor exceeds
  three lanes, every chunk starts and ends on a safe median.

`src/server/Tests/Phase3Tests.luau` then adds 41 cases; `Phase4Tests.luau` adds 30 world and asset-contract
cases; `Phase5Tests.luau` adds 12 UI-token, HUD-geometry, preview-budget and catalogue cases. The four suites
contain 99 `TestKit.it` cases in total (16 + 41 + 30 + 12). `TestKit.report()` runs after each suite and
uses one shared counter, so an all-passing boot reports cumulative totals of 16/16, 57/57, 87/87 and 99/99.
These are expected source-derived totals, not a recorded run. **Written, not executed.**

Turn them off with `RUN_TESTS_ON_BOOT = false` in `src/shared/Config/GameConfig.luau`.

### Manual checklist

Run through this in order. Each line is something you can see or feel.

1. **Boot** — lobby appears: deer on a path, wooden sign reading FAWN RUSH, trees around. Output shows
   `Fawn Rush server ready`.
2. **Camera** — deer centred and low in frame with the road ahead visible. Press `W`: it turns away and
   the camera follows without snapping.
3. **Play** — press `PLAY`. The screen cuts to a road strip; distance reads `0 m`.
4. **Movement** — hold `W`. The deer runs forward at a steady cadence (~9–10 steps/s), not in
   stuttering hops.
5. **Responsiveness** — tap `D` twice quickly. Both steps register; the second is not swallowed.
6. **Traffic** — vehicles of different sizes and speeds approach from both sides. Sports cars visibly
   overtake trucks.
7. **Collision** — walk into a moving car. The deer freezes for a beat, then the results card appears
   with distance, score, the run's acorn tally, and "Hit by a car".
8. **Restart** — press `RETRY`. A fresh run starts immediately at `0 m` with new traffic.
9. **Run acorns** — step onto a golden acorn. It disappears and the current-run tally increments by 1 (grass) or 3
   (road).
10. **Road extends** — run 100+ metres. New rows appear ahead, old ones are recycled behind. No gap
    ever appears in the road.
11. **Safety** — die 10+ times. Every death should look avoidable in hindsight. A wall of traffic with
    no gap means the validator is broken: report the row number.
12. **Touch** — `Test → Emulation → Device` (iPhone 14), press Play. The D-pad appears bottom-left and
    swiping on empty screen also steps.
13. **Lobby return** — on the results card press `LOBBY`. The camera returns to the forest and `PLAY`
    is available again.
14. **Two players** — `Test → Clients and Servers → 2 Players`, press Play. Both run simultaneously
    without interfering; each has their own strip.

---

## Controls

| Action | Keyboard | Gamepad | Touch |
|---|---|---|---|
| Step forward | `W` / `↑` | D-pad ↑ / left stick ↑ | Swipe up / D-pad ▲ |
| Step back | `S` / `↓` | D-pad ↓ / left stick ↓ | Swipe down / D-pad ▼ |
| Step left | `A` / `←` | D-pad ← / left stick ← | Swipe left / D-pad ◀ |
| Step right | `D` / `→` | D-pad → / left stick → | Swipe right / D-pad ▶ |
| Jump | `Space` | A / R2 | JUMP button |

Holding a direction runs continuously. A press during the step cooldown is buffered for 0.18 s.

---

## Repository layout

The current source and documentation inventory is in [docs/03 — Project File Tree](docs/03_PROJECT_FILE_TREE.md).
The runtime is mapped by `default.project.json`: shared modules to `ReplicatedStorage.Shared`, server code to
`ServerScriptService.Server`, the asset manifest to `ServerStorage.Manifest`, and client code to
`StarterPlayer.StarterPlayerScripts.Client`. The UI is built by `client/Controllers/UIController.luau` and
`client/UI`; there is no `UIRoot.luau`. Test suites live in `src/server/Tests`, and are booted from
`src/server/Bootstrap.server.luau` only when Studio is running with `RUN_TESTS_ON_BOOT` enabled.

The source tree does not include a root `tests/` directory, a `rokit.toml`, `index.html`, profile or purchase
services, or the planned screens that are not listed in the file-tree document.

---

## Known issues

Honest list. These are real limitations of this slice.

1. **Nothing has been executed yet.** No Roblox Studio, Luau, Blender or Python runtime was available
   for this review. Four suites contain 99 written test cases (16 + 41 + 30 + 12); none has run. Start
   with `docs/11` and then the Phase 5 UI checklist in `docs/12`.
2. **No persistence or account currency.** Score and best distance are session/run data; acorns are a
   current-run tally, not a saved balance. Phase 6 profile and currency services are planned, not present;
   the `BindToClose` hook does not save data.
3. **Presence is built but unseen.** The server builds one stationary animal per player and every
   client filters it through `PresenceRules` (own model hidden, in-run hidden). The rule is
   covered by written source tests that are still unexecuted; whether it reads correctly on screen is a
   Studio check (`docs/12` S3).
4. **The fairness proof is a sample, not a theorem.** The validator proves a survivable path exists for
   the traffic phase at the chunk's entry time. It does not prove survivability for *every* possible
   entry phase. The retry ladder and the guaranteed template cover the remainder; a full phase-space
   proof is Phase 10 work.
5. **Traffic is rendered by the client.** A modified client can hide vehicles from its own screen but
   cannot avoid them: the server judges collision from the same lane data.
6. **Roblox's default camera scripts may log warnings** because there is no `Humanoid` character
   (`CharacterAutoLoads = false`). Our camera is scriptable and unaffected; the warnings are noise.
7. **Score is untuned.** `rows × 10 + acorn value` is the Phase 1 formula; the weights need a playtest
   pass in Phase 3.
8. **All art is procedural.** Deer and vehicles are built from parts and labelled temporary in
   `docs/06_ASSET_PRODUCTION_PLAN.md` §9. Blender meshes are Phase 4.
9. **No streaming.** `StreamingEnabled` remains off: run zones are client-built, and the Phase 4 worlds
   have not been measured with streaming enabled. Reconsider only after a Studio integration check.
10. **No audio and no pause service.** Audio is Phase 9; pausing, mission UI and profile-backed settings
    remain disconnected. Jump, near misses and combos exist; they are silent.
11. **Five worlds, one look each — unseen.** Each has its own palette, lighting rig, scenery kit and
    ambient effect, but no one has watched them. Distinctness is a Studio question (`docs/12` S10).
12. **Blender assets are definitions plus exporters, not files.** No `.blend` or `.fbx` exports were
    generated; Blender and Python were unavailable. Asset IDs remain empty. Run the documented exporters
    on a suitable workstation before importing any authored mesh.
13. **Ambient VFX are unmeasured.** One emitter per world, rate-capped by graphics tier — but the low
    tier has never been profiled (`docs/12` S11).

---

## Requirement tracking

Prompts B (premium visuals and UX), C (progression and retention), D (monetization) and E (QA and
polish) are mandatory deliverables. Every line item is registered, assigned to a phase, and tracked
with one of four statuses — `Pending`, `Partial`, `Built`, `Verified`.

| Prompt | Items | Closed by | Now |
|---|---|---|---|
| B — Premium visuals & UX | 12 | Phase 5 (with 3, 4, 7, 9) | 6 built · 5 partial · 1 pending |
| C — Progression & retention | 12 | Phase 6 (with 4, 7, 8) | 0 built · 2 partial · 10 pending |
| D — Monetization | 13 | Phase 8 | 13 pending |
| E — QA & polish | 11 | Phase 10, gated every phase | 0 built · 3 partial · 8 pending |

**Current rollup: 6 Built · 10 Partial · 32 Pending · 0 Verified.** Nothing in the game has been executed in Roblox Studio. `Built` in
the register means reviewed source implementation only; it does not mean Studio-verified.

**Studio integration gate.** `docs/11_PHASE2_VERIFICATION.md` is the rolling Studio gate, not a per-phase
blocker (`docs/08` "Development posture"). It runs four suites (99 written test cases, 0 run), the
manual checklists, device/multiplayer matrix and defect log. Phase 5 UI checks are in `docs/12`. Release
still requires zero open S1/S2 defects.

---

## Documentation

The Phase 1 design set in [`docs/`](docs/) is still authoritative, extended by the register and gate.

| Doc | Contents |
|---|---|
| [00 — Index](docs/00_INDEX.md) | Reading order, glossary, decision log |
| [01 — Game Design Document](docs/01_GAME_DESIGN_DOCUMENT.md) | Identity, loops, hazards, worlds, economy |
| [02 — Technical Architecture](docs/02_TECHNICAL_ARCHITECTURE.md) | Services, authority boundaries, networking |
| [03 — Project File Tree](docs/03_PROJECT_FILE_TREE.md) | Current repository tree, architecture and Studio setup |
| [04 — Gameplay Mechanics Spec](docs/04_GAMEPLAY_MECHANICS_SPEC.md) | Movement, traffic, generation, collision, scoring |
| [05 — UI/UX Specification](docs/05_UI_UX_SPECIFICATION.md) | Tokens, components, screens, mobile rules |
| [06 — Asset Production Plan](docs/06_ASSET_PRODUCTION_PLAN.md) | Assets, Blender pipeline, audio, placeholders |
| [07 — Monetization Plan](docs/07_MONETIZATION_PLAN.md) | Passes, products, receipt handling |
| [08 — Milestones](docs/08_MILESTONES.md) | Phases 1–10 with exit criteria |
| [09 — Risk & Testing Plan](docs/09_RISK_AND_TESTING_PLAN.md) | Test levels, exploit suite, performance budgets |
| [10 — Requirements Register](docs/10_REQUIREMENTS_REGISTER.md) | All 48 Prompt B–E line items, phase assignment, status, acceptance |
| [11 — Studio Integration Gate](docs/11_PHASE2_VERIFICATION.md) | Rolling Studio checks, defect log and sign-off |
| [12 — Studio Handoff](docs/12_STUDIO_HANDOFF.md) | Windows setup, launch, and every open Studio-only issue |
| [Blender Pipeline](assets/blender/README.md) | Asset conventions, the two exporters, import procedure |
| [CHANGELOG](CHANGELOG.md) | What each phase changed, including deviations |

---

## Outstanding external integrations

The UI review does not require platform IDs, but Phase 4 is not fully closed until its required binary mesh exports exist. Later platform-dependent phases also remain blocked by the integrations below.

- [ ] Roblox **gamepass IDs** (5) — Creator Dashboard
- [ ] Roblox **developer product IDs** (5) — Creator Dashboard
- [ ] Roblox **badge IDs** (8) — Creator Dashboard
- [ ] Roblox **audio asset IDs** — licensed or original uploads
- [ ] Roblox **image/mesh asset IDs** — Phase 4
- [ ] **DataStore API access** — Phase 6
- [ ] **Published testing place** — Phase 8/10 live verification

---

## Hard rules (unchanged)

1. The server owns truth. Currency, XP, distance, unlocks, purchases, mission progress, and leaderboard
   entries are computed server-side. The client sends intent.
2. No fabricated asset IDs. Anything unconfigured is `0` and its feature disables visibly.
3. No fake persistence.
4. No single-script game.
5. No dead buttons.
6. Mobile first.
7. No pay-to-win.
8. No copied content.
