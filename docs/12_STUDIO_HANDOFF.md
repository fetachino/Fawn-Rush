# 12 — Windows Handoff: setup, launch, and every open Studio-only issue

Living document. Updated at the end of every phase. It exists because the project is developed on a
phone and executed only at the integration gate (`docs/11`), so anything that can only be settled in
Studio is recorded here as it is found rather than remembered later.

**Current state:** Phase 1 complete; Phases 2–3 Built, Phase 4 Built with required binary exports outstanding, and Phase 5 Partial. No Studio verification has occurred. Four suites contain 99 written `TestKit.it` cases; 0 executed.

---

## 1. What you need on the PC

| Requirement | Notes |
|---|---|
| Windows 10/11 | |
| Roblox Studio | Current version. Update before the first run — API drift is the main unknown |
| Rojo 7.4+ | `rokit add rojo-rbx/rojo`, or the `rojo-*-win64.zip` from the releases page |
| Rojo Studio plugin | `Rojo.rbxm` into `%LOCALAPPDATA%\Roblox\Plugins`, then restart Studio |
| A terminal | PowerShell is fine |

Optional, for editing with autocomplete: VS Code + the Luau extension.

---

## 2. Launch in five steps

```powershell
cd "path\to\Fawn Rush"
rojo serve
```

1. Studio → **New → Baseplate**. Any baseplate works; the server deletes it at boot.
2. Rojo panel (Plugins tab) → **Connect** (defaults to `localhost:34872`).
3. Confirm `ReplicatedStorage.Shared`, `ServerScriptService.Server`,
   `StarterPlayer.StarterPlayerScripts.Client` appear in the Explorer.
4. Press **Play** (F5) and open the **Output** window immediately.

When all tests pass, the four suites should print cumulative `TestKit.report()` lines like these (other
boot messages may interleave; this is an expected shape, not a recorded run):

```
[tests] PASSED 16/16
[tests] PASSED 57/57
[tests] PASSED 87/87
[tests] PASSED 99/99
```

Phase 2 prints a 50-chunk generation timing and retry count before its report. Record the actual values
from Output; no timing or passing result is known yet. If any suite reports failures or a require/runtime
error interrupts the sequence, record the actual failure and which later suites did not run.

If the test blocks do not appear, the suites did not load — check for a red require error first.

---

## 3. The first hour: run in this order

1. **[docs/11](11_PHASE2_VERIFICATION.md) Gate A** — the automated suites. Record the real totals.
2. **docs/11 Gate B** — the manual gameplay checklist.
3. **Phase 3 additions** (below), which the docs/11 checklist predates.
4. **Phase 5 UI additions** (below), including the 844×390 compact-landscape case.
5. Log every failure in `docs/11` §4 and here in §5.

### Phase 3 checks to add to the manual pass

| # | Check | Expected |
|---|---|---|
| P3-1 | Watch the deer stand still | Breathing, ear sway, tail sway, head micro-motion. Not a frozen statue |
| P3-2 | Hold forward | Legs alternate in diagonal pairs, body bobs, ears lag behind the run |
| P3-3 | Press Space / gamepad A | Tuck, arc, land absorption. Carries one tile forward if the tile ahead is open |
| P3-4 | Jump into an animal crossing | The wildlife passes underneath; you are not killed at the apex |
| P3-5 | Walk into a road closure | Movement is refused, the deer does not die, no cooldown is burned |
| P3-6 | Let a car pass within a whisker | White flash, small shake, combo pill appears, current-run acorn tally increments, whoosh (silent until Phase 9); no account balance is credited |
| P3-7 | Chain three near misses | Combo climbs ×1.0 → ×1.25 → ×1.6 and the drain bar empties over ~6 s |
| P3-8 | Stand still for 6 s after a combo | Combo pill disappears and the multiplier is back to ×1.0 |
| P3-9 | Reach a rail row | Gravel bed, rails, sleepers, and a long train sweeping through |
| P3-10 | Watch a wildlife crosser | It moves left-to-right (or right-to-left on odd rows) at a steady speed and loops |
| P3-11 | Two-client test | Each player's animal and nameplate appears in the lobby; each hides while that player is running |
| P3-12 | Die | Death pose plays, results card shows near-miss count, combo is gone |
| P3-13 | Frame rate | Still 30 FPS on the low tier with a train, wildlife and 20 vehicles on screen |

### Phase 5 UI checks to add to the manual pass

| # | Check | Expected |
|---|---|---|
| P5-1 | Open each implemented screen by touch and gamepad | No title/Back overlap; visible actions are reachable; initial gamepad selection is usable |
| P5-2 | Navigate rapidly and resize/replace the camera | Superseded transitions do not hide the active screen; replaced-camera listeners disconnect |
| P5-3 | Emulate compact landscape, compact portrait and notched portrait | HUD targets meet 44 physical px; helper rectangles and the portrait rotate hint stay within the viewport/protected band and clear of score, combo and acorns; pad releases when HUD hides |
| P5-4 | Open/close lobby and catalogue previews repeatedly | Preview count returns to zero on hide/removal; capacity and general failure copy are distinct |
| P5-5 | Start a run, test refusal, duplicate input and missing response | Server validates world/request; duplicate input cannot start a second session; accepted/refused/timeout paths are visible |
| P5-6 | Change Shop tabs and revisit; change reduced motion/text scale | Tab selection persists; UI transitions, shake, flashes and pickup sparkles are suppressed under reduced motion; text scale remains session-local |
| P5-7 | Resize and visit every implemented screen in compact portrait/landscape and expanded layouts | Reflow occurs without clipping or header/action overlap; record any cutout-specific defects. Touch FOV 70 retains lateral hazard visibility pending visual calibration |

These are manual Studio checks. The Phase 5 source suite checks shared helper output and does not prove rendered geometry.

---

## 4. Known open items that only Studio can settle

Ordered by how likely they are to matter.

| # | Item | Why it is open | Where it lives |
|---|---|---|---|
| S1 | **Pose quality is unverified.** The 13 states are mathematically defined and have written, unexecuted source checks for joint coverage and finite angles, but whether they *read* as a deer running is an art question | Needs eyes | `AnimationLib` |
| S2 | **Camera behaviour without a Humanoid.** Roblox's default player module may log warnings | No character by design | README known issue 6 |
| S3 | **Resolved in the closure audit.** Presence models carry `OwnerUserId` and `InRun`; `PresenceRules` hides own and in-run models; `PresenceController` applies it | — | Closed — confirm on screen with two clients (P3-11) |
| S4 | **Train spawn position.** Trains use a widened overhang; verify they enter from off-screen rather than popping in | Geometry needs looking at | `ChunkGenerator.makeRailLane` |
| S5 | **Wildlife fairness, narrowed.** Entry grace (3 rows), no rail-row placement, speed derived from the configured range, and a two-axis collision test. The validator still samples instants rather than solving continuously | Known approximation | `ObstacleSim`, `ChunkGenerator` |
| S6 | **Performance of 13 rigs.** Only one animates at a time on the client; lobby rigs no longer spawn dynamic lights | Needs measurement | `PresenceService`, `AnimalBuilder` |
| S7 | **`UIShadow`.** Docs assert Roblox has no native drop shadow; elevation currently degrades to a border | If `UIShadow` exists, use it | `docs/05` §2.3 |
| S8 | **AnalyticsService signatures** are `[VERIFY]` before Phase 8 | Platform API | `docs/02` §10 |
| S9 | **Chunk version refusal.** `SessionController` rejects a chunk whose `v` is newer than it understands and logs one warning. Confirm the warning reads clearly if it ever fires | New code path | `ChunkFormat`, `SessionController` |
| S10 | **World identity.** Five worlds have distinct palettes, lighting, scenery kits and ambient effects; whether they *read* as five places rather than five tints is an art question. Check them side by side on a phone | Needs eyes | `WorldConfig`, `WorldRenderer`, `WorldEffectsController` |
| S11 | **Ambient VFX cost.** One emitter plus one accent per world, rate-capped by `GraphicsTier`. The low tier has never been profiled; confirm 30 FPS with traffic, scenery and weather together | Needs measurement | `WorldEffectsController` |
| S12 | **Blender exports untested.** `meshlib.validate()` is written and both exporters are complete, but neither has been run. The reference cube is hand-authored and correct; the generated meshes are not proven importable | No Blender/Python here | `assets/blender` |
| S13 | **World scenery inside the playfield.** Three worlds originally placed props at 30 studs, inside the 32-stud field. Now fixed at 38+, with a test — but confirm visually that nothing stands on the road | Fixed, unverified | `WorldConfig.props.bandMin` |
| S14 | **OBJ materials in Studio.** The OBJ exporter writes MTL references; whether the 3D Importer honours multi-material OBJs is unverified. The FBX path carries material slots explicitly and is the authoritative one for anything multi-material | Unverified | `assets/blender` |

Fix order: confirm S3 on screen (two clients), then S10 (do the worlds feel different?), then S1
(pose quality), then the rest.

---

## 5. Defect log

Defects found by code inspection. Studio will add its own once the gate runs.

| Date | # | Severity | Area | Repro | Status |
|---|---|---|---|---|---|
| Phase 3 audit | A1 | **S2** | Lobby presence | Owning player saw a second animal: the server's `LobbyPresence` rig plus their own client rig | **Fixed** — `OwnerUserId`/`InRun` attributes, `PresenceRules`, `PresenceController` |
| Phase 3 audit | A2 | S3 | Hazards | `HazardConfig.wildlife.speedMin/speedMax` were never read; actual crosser speed was 6.7–12.3 studs/s against a stated 5–9 | **Fixed** — speed is authored, period derived |
| Phase 3 audit | A3 | S3 | Netcode | `chunk.v` was written and never read, so a newer chunk format would be silently mis-rendered | **Fixed** — `ChunkFormat` + refusal in `SessionController` |
| Phase 3 audit | A4 | S3 | Fairness | Wildlife could spawn on a chunk's first row, leaving ~0.3 s of reaction; also on rail rows | **Fixed** — entry grace of 3 rows, rail rows excluded, final row excluded |
| Phase 3 audit | A5 | S4 | Collision | `wildlifeHalfLength` was dead config; the row was rounded to an integer, so body depth never counted | **Fixed** — two-axis box test, both in collision and in tile blocking |
| Phase 3 audit | A6 | S4 | Tests | Five assertions were tautological or near-vacuous (empty pose, sealed-row threshold of 15, train headway vs. itself, unreadable determinism, `validated` always true) | **Fixed** — replaced with behavioural assertions |
| Phase 3 audit | A7 | S4 | Performance | `findHit` scanned every retained lane (~90) at 20 Hz per player | **Fixed** — `lanesByRow` lookup, three candidates |
| Phase 3 audit | A8 | S4 | Performance | Lobby rigs could each spawn a dynamic `PointLight` | **Fixed** — presence rigs build without lights |
| Phase 3 audit | A9 | S4 | Robustness | `AnimationController` posed nothing forever if it ran before `MovementController` had built the rig | **Fixed** — `adoptRig()` retries in `update` |
| Phase 3 audit | A10 | S4 | Lobby presence | `setAnimal` rebuilt a rig into whatever slot was free and then recorded the old slot, so a changed animal could move a player after Phase 7 starts equipping | **Fixed** — the slot is passed into the rebuild |
| Phase 4 | B1 | **S2** | Scenery | Greenwood, City and Neon placed scenery at 30 studs from the centreline, inside the 32-stud playfield, so buildings and trees stood where the player walks | **Fixed** — every band minimum is outside the field; a test pins it |
| Phase 4 | B2 | S3 | WorldKit | `pine()` contained a truncated snow-cap block referencing a non-existent `Version.DEFAULT` | **Fixed** |
| Phase 4 | B3 | S3 | WorldKit | The collectible material used `a or b and c or d`, which can assign the boolean `true` as a material for a shard | **Fixed** — resolved explicitly |
| Phase 4 | B4 | S4 | WorldKit | `bridge()` chose its ice variant from `colors.ice`, which every palette defines, so every bridge would have been frozen | **Fixed** — variant passed explicitly |
| Phase 4 | B5 | S4 | Config | `MAX_PROPS_PER_CHUNK` was a renderer magic number | **Fixed** — `GameConfig` data, bounded by a test |
| Phase 5 audit | S15 | S2 | UI root | HUD rectangles were not sourced from the same helper as screen layout; safe-frame/inset scaling assumptions were inconsistent | **Source-corrected** — safe-frame dimensions use viewport scale and GuiService insets; tests consume `UIConfig.hudLayout()`. Not executed or Studio-verified |
| Phase 5 audit | S16 | S3 | Navigation | Rapid transitions could leave competing tweens; replaced cameras retained viewport listeners | **Source-corrected** — transitions cancel by token and replaced camera listeners disconnect. Not executed or Studio-verified |
| Phase 5 audit | S17 | S3 | UI navigation | Menu headings could overlap Back controls; focus did not handle a gamepad connected after boot; Shop used hover as persistent selection | **Source-corrected** — headers adjusted, connection assigns focus, tabs use selected state. Not executed or Studio-verified |
| Phase 5 audit | S18 | S3 | Preview lifecycle | Lobby preview failure had no fallback; Collection described every failure as budget exhaustion; setup failures could leak preview resources | **Source-corrected** — differentiated fallback copy, lease release and protected setup cleanup. Not executed or Studio-verified |
| Phase 5 audit | S19 | S3 | Run start | Repeated starts could restart an active server run; malformed/unknown worlds fell back to default; timeout could leave a local request pending | **Source-corrected** — client/server duplicate guards, request validation/results and timeout cleanup. Not executed or Studio-verified |
| Phase 5 audit | S20 | S3 | HUD geometry | Portrait rotate guidance was removed to avoid covering the protected road band | **Source-corrected** — guidance occupies a tested top-band slot right of score; touch FOV remains 70 to preserve lateral hazard view pending Studio calibration |
| Phase 5 audit | S21 | S3 | Responsive/accessibility | Source layouts, focus, touch feedback and settings were not rendered on a device | **Partially source-corrected** — viewport layout APIs now cover and are wired for every implemented screen; device/cutout, accessibility review and all 99 test executions remain open |
| Phase 5 final review | S22 | S3 | Touch HUD | Several layout scales produced D-pad targets below the 44 px minimum | **Source-corrected** — compact touch controls use a bottom row and cross controls meet the target floor; test scenarios expanded. Not executed or Studio-verified |
| Phase 5 follow-up | S23 | S3 | Reduced motion | Camera shake, flashes and pickup particles were not tied to the session-local setting | **Source-corrected** — these direct effects are suppressed when reduced motion is enabled; ambient weather/character motion and rendered accessibility remain Studio review items |

---

## 6. Things that are *expected* to be incomplete

Not defects. Each is scheduled.

- No sound at all (Phase 9).
- No saving, account currency, levels or missions (Phase 6). Run-only acorn totals are not a persistent balance.
- Collection is a catalogue-only screen; ownership, equipping, inventory and loadouts are not active (Phases 6–7).
- Shop is an empty shell; no offers, odds, currency transactions, purchase or receipt service exists (Phase 8).
- Five world profiles and selection exist in source; visual/gameplay verification is pending.
- Art remains procedural primitives; no Blender `.blend`/`.fbx` exports or uploaded asset IDs exist.
- No pause service, missions, rewards, or persisted settings exist.
- Score weights are untuned defaults.

---

## 7. Transferring the project

The repository is portable by construction: no place file, no binary instances, no machine-specific
paths.

1. Copy the whole `Fawn Rush` folder (or `git clone` it) to the PC.
2. Confirm `default.project.json` sits at the folder root next to `src/`.
3. Follow §1 and §2.
4. Commit the signed `docs/11` gate and the defect log before starting new work.


