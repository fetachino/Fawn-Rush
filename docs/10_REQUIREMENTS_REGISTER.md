# 10 — Requirements Register: Prompts B, C, D, E

**Status: binding.** Every line item in Prompts B, C, D and E is a mandatory deliverable. This
document is the single source of truth for whether each one is done. A feature is never marked
complete because its source file exists.

Owner: Game Director · Maintained by: whoever closes a requirement, in the same commit.

---

## 1. Status vocabulary

Four states. The difference between `Built` and `Verified` is the whole point of this document.

| Status | Means exactly this | Requires |
|---|---|---|
| **Pending** | Nothing implemented, or only a design exists. | — |
| **Partial** | Some of the requirement works. The `Notes` column says which part and which part is missing. | A built subset |
| **Built** | Source exists, is wired into the running game, and follows the architecture. **Not executed.** | Code + review |
| **Verified** | A human ran it and it behaved as specified. | Studio execution, recorded in `docs/11_PHASE2_VERIFICATION.md` (Phase 2) or the phase's test record |

**Rule zero.** `Verified` is only available at the Studio integration gate (`docs/11`). Development
continues past that gate by design (`docs/08` "Development posture"), so `Built` accumulates during
phases and `Verified` accumulates only when someone runs the game. Verified count today: **0**.

**Rule one.** A status may only change in the same commit that adds the evidence, and the change is
logged in §7 of this document.

**Rule two.** Duplicated functionality is a defect. §5 lists what each prompt must build *on* rather
than rebuild.

---

## 2. Where each prompt lives

| Prompt | Primary phase(s) | Secondary | Blocking gate |
|---|---|---|---|
| **B — Premium visuals & UX** | 5 (UI/UX), 3 (character presentation) | 4 (environment art), 7 (previews, unlock reveals), 9 (VFX polish) | Phase 2 gate |
| **C — Progression & retention** | 6 (XP, missions, daily, achievements, persistence) | 4 (world unlocks), 7 (collection, rarity, cosmetics), 8 (seasonal events) | Phase 2 gate, then Phase 5 |
| **D — Monetization** | 8 (all of it) | 5 (shop shell), 10 (purchase testing) | **Platform IDs** `[STUDIO]` + Phase 6 data |
| **E — QA & polish** | 10 (release) | Continuous: every phase exit | All of the above |

Prompt E is not "the last phase". It is a gate at every phase boundary (see `docs/08_MILESTONES.md`)
and a full release pass in Phase 10.

---

## 3. Prompt B — Premium visuals and UX (12 requirements)

| ID | Requirement | Phase | Status | Evidence / acceptance to reach Verified |
|---|---|---|---|---|
| B1 | Original, polished character presentation | 3, 4 | **Built** | 13 species from config with real proportions, explicit joint pivots and a 13-state animation system (`AnimationLib`, `Animator`). The Phase 3 closure audit confirmed a single CFrame writer and added state-coverage, finite-angle and idle-fallback assertions. Phase 4 built the Blender pipeline that will replace the primitive rigs, but no mesh exists yet. Verified when the states of `docs/01` §6.2 are seen playing and `01` §6.3 passes on a phone |
| B2 | Professional home screen | 5 | **Partial** | Lobby has logo, tagline, PLAY, world label, animal name/rarity, and a procedural preview. Missing: currency/profile header, level ring, notification dots, and much of the specified navigation. |
| B3 | Complete responsive UI | 5 | **Built** | Every implemented screen now exposes viewport-driven reflow, including catalogue grid columns, safe-frame-aware sizing and portrait/compact layouts; HUD portrait guidance is in the top strip. Source geometry checks are written, not executed. Device-cutout and rendered-layout review remain Studio-only; unbuilt screens are not implied complete. |
| B4 | Desktop hover effects | 5 | **Built** | `UI/Components.luau` MouseEnter/Leave → 1.03 scale + colour tween. Verified when observed on desktop in Studio |
| B5 | Mobile touch feedback | 5 | **Built** | Press states fire on `InputBegan` (touch and mouse); D-pad has its own press animation. Verified on device emulation |
| B6 | Button animations and transitions | 5 | **Partial** | Button state feedback, cancellable slide/scale transitions, loading feedback and a visible run-start failure state with inline reason exist. Missing fade, modal system, complete state demonstration and device verification. |
| B7 | Animated currency counters | 5 | **Built** | `Components.currencyPill` animates changed values, flashes gain/spend direction and uses shared number formatting. It is wired to run-only acorns; account balance and purchase spending are not connected. |
| B8 | Character previews | 7 | **Built** | Lobby and collection detail use draggable procedural `ViewportFrame` previews with a shared four-lease cap and release on hide. No cache/inertia; Studio performance remains unverified. |
| B9 | Collection and shop interfaces | 7, 8 | **Partial** | A catalogue grid/detail and three honest empty shop tabs exist. No ownership/equip, live offers, odds disclosure, or purchase flow. |
| B10 | Reward and unlock animations | 7 | **Pending** | Rarity-tiered unlock reveal (7 presentations), level-up, mission complete |
| B11 | Consistent design system | 5 | **Partial** | Central colours, type, spacing, elevation/motion/breakpoint tokens, contrast checks, reduced-motion gating for direct camera/UI feedback and text-scale foundations exist. Full component coverage, planned primitives and Studio accessibility review remain incomplete; ambient/character motion is not comprehensively gated. |
| B12 | Professional visual effects | 9 | **Partial** | Server-side atmosphere/bloom/colour grade; acorn spin + bob; near-miss flash, capped camera offset shake, pickup sparkle and death flash. Reduced motion now suppresses the latter feedback. Missing: pooled emitter system, speed lines, unlock radial and measured tier-based particle budgets; visual quality/performance remain Studio work. |

**Built 6 · Partial 5 · Pending 1 · Verified 0**

**Non-negotiable for B:** no default-looking Roblox buttons anywhere, and no screen ships with
placeholder text. Both are checked at the Phase 5 exit.

### 3.1 Remaining Prompt B work — implementation and dependency classification

`Built` and `Partial` describe source state only. The Studio and external blockers below remain separate; none is evidence of an executed test or device review.

| ID | Source-implementable work still outstanding | Dependency / verification class | Boundary |
|---|---|---|---|
| B2 | Add further home navigation only when its destination screens have real behavior; do not invent profile values or notification dots. | Service-dependent; planned-screen/source work; Studio-verifiable | Currency, level, profile and notification data require Phase 6 services; additional routes must not be dead ends. |
| B3 | No source reflow remains for currently implemented screens; viewport and text-scale changes both refresh layout. | Studio-verifiable | Verify safe-area/cutout behavior and rendered layouts across device sizes before calling this Verified. |
| B6 | Fade/modal behavior and complete feedback-state flow can be added in source without external services. | Source-implementable; Studio-verifiable | Device demonstration and actual transition/accessibility behavior remain unverified. |
| B9 | Catalogue ownership/equip state, live offers, odds and purchase flow require their real backends. | Service-dependent; externally blocked for platform purchases; Studio-verifiable | Inventory/profile and shop services are later-phase work; platform IDs are external inputs. Do not fabricate balances, offers or odds. |
| B10 | Reveal/level-up/mission-complete presentation can be authored in source, but must be triggered by real rewards. | Source-implementable presentation; service-dependent triggers; asset-dependent only if authored assets are chosen | No reward/unlock source exists yet; a standalone visual is not a completed reward system. |
| B11 | Remaining reusable component coverage is source work. | Source-implementable; Studio-verifiable | Accessibility review and control usability require rendered Studio/device review. |
| B12 | Additional effects and safe static budgets are source work; existing appearance and cost need measurement. | Source-implementable; asset-dependent only for chosen uploaded content; Studio-verifiable | Do not claim visual quality, particle performance or tier budgets without Studio measurement. |

---

## 4. Prompt C — Progression and retention (12 requirements)

| ID | Requirement | Phase | Status | Evidence / acceptance to reach Verified |
|---|---|---|---|---|
| C1 | Animal collection | 7 | **Pending** | 13 animals ownable, equippable, persisted; collection screen |
| C2 | Character rarity | 7 | **Pending** | 7 tiers with distinct colour **and shape** and unlock presentation (`01` §9.2) |
| C3 | Cosmetic inventory | 7 | **Pending** | 10 slots, ~58 items, equip/unequip, fit warnings, loadouts |
| C4 | XP and levels | 6 | **Pending** | `Scoring.xpForRun` exists; curve, level rewards, world gates, level-up UI |
| C5 | Daily and weekly missions | 6 | **Pending** | 3 daily / 5 weekly, server-incremented from validated events, claim flow |
| C6 | Daily rewards | 6 | **Pending** | 7-day calendar that advances only on claim; no streak reset |
| C7 | Achievements | 6 | **Pending** | ~34 across 6 categories, progress, claims, platform badges (id 0 until configured) |
| C8 | Best-distance tracking | 6 | **Partial** | Per-session best computed in `RunService.finish` and shown on results. Missing: persistence, per-world best, leaderboards |
| C9 | Unlockable worlds | 4, 6 | **Partial** | Five worlds, their difficulty profiles and the unlock rule (`WorldUnlock`) are built; the lobby chip previews requirements. Missing: a real profile to check against, and enforcement (`GameConfig.WORLD_UNLOCK_ENFORCED`, Phase 6) |
| C10 | Collection completion rewards | 7 | **Pending** | Rewards at set thresholds (per rarity tier, per world) |
| C11 | Seasonal events | 8 | **Pending** | Event framework, limited cosmetics that return annually, world spotlight modifier |
| C12 | Persistent player progression | 6 | **Pending** | Session-locked DataStore, schema v1, migration, `BindToClose` save. `BindToClose` hook exists and is empty |

**Built 0 · Partial 2 · Pending 10 · Verified 0**

**Non-negotiable for C:** no mechanic may punish a returning player, and no limited-time item may be
required for normal progression (`docs/01` §18).

---

## 5. Prompt D — Monetization (13 requirements)

| ID | Requirement | Phase | Status | Evidence / acceptance to reach Verified |
|---|---|---|---|---|
| D1 | VIP gamepass | 8 | **Pending** | Nameplate, 3 cosmetics, lobby corner, emote; ownership cached then re-verified on join |
| D2 | Extra inventory / loadout slots | 8 | **Pending** | 3 additional loadouts; slot count enforced server-side |
| D3 | Exclusive animal bundles | 8 | **Pending** | Cosmetic colour variants only — never an animal that is otherwise unobtainable by play |
| D4 | Premium cosmetic trails | 8 | **Pending** | 5 trails; no gameplay effect |
| D5 | Double Acorns gamepass | 8 | **Pending** | Source whitelist from `docs/07` §2.1; a test asserts every source key exists in the table |
| D6 | Developer products | 8 | **Pending** | Three acorn packs, revive, seasonal bundle; ids `0` until created |
| D7 | Currency bundles | 8 | **Pending** | Acorn packs with honest per-Robux math, no fake "best value" |
| D8 | Optional revives | 8 | **Pending** | One per run, same tile, loses combo, disabled in ranked modes |
| D9 | Professional shop UI | 8 | **Pending** | Three tabs, ownership state, disclosure copy, odds modal for caches |
| D10 | Secure MarketplaceService integration | 8 | **Pending** | `ProcessReceipt`, `PromptGamePassPurchaseFinished` as a hint only |
| D11 | Server-side purchase validation | 8 | **Pending** | Price from config, never from the client; balance re-read server-side |
| D12 | Reliable receipt processing | 8 | **Pending** | Idempotent `ReceiptLedger`, replay test (same `PurchaseId` × 20 grants once) |
| D13 | Ownership verification | 8 | **Pending** | `UserOwnsGamePassAsync` on join, cached, re-verified; grants only from ownership |

**Built 0 · Partial 0 · Pending 13 · Verified 0**

**Blocking dependency:** Phase 8 cannot close without the five gamepass IDs and five product IDs
created in the Creator Dashboard. Until then every consumer hides its UI (never a dead button).

**Non-negotiable for D:** nothing purchasable may affect survival, speed, hazard density, or
leaderboard placement. Golden Acorns are never sold. No paid randomness.

---

## 6. Prompt E — Professional QA and polish (11 requirements)

| ID | Requirement | Phase | Status | Evidence / acceptance to reach Verified |
|---|---|---|---|---|
| E1 | Full gameplay testing | 2 (start), 10 (close) | **Pending** | 99 `TestKit.it` cases across four suites (16 Phase 2, 41 Phase 3, 30 Phase 4, 12 Phase 5), plus the 15-step gate checklist, are written but unexecuted. Gate: `docs/11` |
| E2 | UI navigation testing | 10 | **Pending** | Every screen reachable and back-navigable on a 6-inch phone |
| E3 | Mobile and desktop testing | 10 | **Pending** | Four device tiers, touch + keyboard + gamepad, portrait and landscape menus |
| E4 | Multiplayer testing | 10 | **Pending** | 16 simulated players, no interference, no zone or profile leak |
| E5 | Data persistence testing | 10 (after 6) | **Pending** | Load/leave/rejoin; refusal on failure; no defaults over good data; lock contention |
| E6 | Purchase testing | 10 (after 8) | **Pending** | Receipt replay, cancel, unknown product, player leaves mid-purchase |
| E7 | Exploit testing | 10 (start 3) | **Pending** | The 20-case suite in `docs/09` §3. E1/E5/E11/E13/E14 are release blockers |
| E8 | Performance testing | 10 | **Pending** | Budgets in `docs/09` §5.2 on four tiers; solver p99 ≤ 6 ms |
| E9 | Bug prioritization | Continuous | **Partial** | Severity scheme defined (`docs/09` §7: S1–S4). The Phase 3 closure audit produced the first defect log (`docs/12` §5); Studio findings still open at the gate |
| E10 | Fixes for critical and high-severity issues | Continuous | **Partial** | The Phase 3 closure audit fixed 1 high-severity and 8 medium/low findings (duplicate lobby animal, dead wildlife speed config, unread chunk version, rounding-based wildlife collision, five weak assertions). All self-found and unverified; Studio findings still start at the gate |
| E11 | Release readiness checklist | 10 | **Partial** | Defined in `docs/09` §9, not yet executed as a gate |

**Built 0 · Partial 2 · Pending 9 · Verified 0**

---

## 7. Rollup and change log

| Prompt | Built | Partial | Pending | Verified | Total |
|---|---|---|---|---|---|
| B — Visuals & UX | 6 | 5 | 1 | 0 | 12 |
| C — Progression | 0 | 2 | 10 | 0 | 12 |
| D — Monetization | 0 | 0 | 13 | 0 | 13 |
| E — QA & polish | 0 | 3 | 8 | 0 | 11 |
| **Total** | **6** | **10** | **32** | **0** | **48** |

**Change log** — append one row per status change. Never edit history.

| Date | ID | From → To | Evidence |
|---|---|---|---|
| Phase 2 | — | — | Register created. Baseline: 3 built, 9 partial, 36 pending, 0 verified |
| Phase 3 | B1 | Partial → Built | Species-driven rig builder + 13-state animation system; awaiting the integration gate |
| Phase 3 audit | E10 | Pending → Partial | Closure audit fixed 1 high and 8 medium/low defects, all self-found (`docs/12` §5) |
| Phase 3 audit | E9 | Partial (unchanged) | First defect log exists; note updated, status unchanged |
| Phase 4 | C9 | Pending → Partial | Five worlds + unlock rule + lobby preview; enforcement waits for Phase 6 |
| Phase 4 | E1 | Pending (unchanged) | At the Phase 4 checkpoint, 87 `TestKit.it` cases across three suites were written; none had been executed |
| Phase 5 audit | B6 | Built → Partial | Button feedback and cancellable screen transitions exist; fade, modal behavior, full state demonstration and device review remain incomplete |
| Phase 5 audit | B7 | Pending → Built | Shared counter animation and formatting are wired to run-only acorns; no account balance or purchase spending is connected |
| Phase 5 audit | B8 | Partial → Built | Lobby and catalogue previews use the shared, budgeted procedural preview; performance remains unmeasured |
| Phase 5 audit | B9 | Pending → Partial | Catalogue/detail and empty shop tabs exist; ownership, offers, odds and purchases are absent |
| Phase 5 follow-up | B3 | Partial → Built | Responsive layout APIs now cover every implemented screen and are wired to viewport changes; portrait HUD guidance has source geometry. Device/cutout and rendered-layout checks remain pending and B3 is not Verified |

---

## 8. Reuse map — what each prompt must build on, not rebuild

Rule 4 of the brief is "do not duplicate functionality that already exists". This is the list that
makes that checkable in review.

| Existing module | Owns | Prompts that must reuse it |
|---|---|---|
| `UI/Theme.luau` | every colour, type size, radius, duration | B2–B12 — no literal hex or pixel size in a screen |
| `UI/Components.luau` | button state machine, panel, label, pad button | B4, B5, B6, B9 — new screens compose these |
| `Controllers/InputController.luau` | keyboard, gamepad, swipe, on-screen pad | C/D — any new menu must extend the context stack, not add listeners |
| `Controllers/SessionController.luau` | the only reader of run remotes | C4, C8 — run results flow through its signals |
| `Services/RemoteGate.luau` | rate limiting + payload validation for every remote | D6, D11, D12 and every new remote |
| `Services/RunService.luau` | steps, collision, collectibles, score, death | C4, C8, D5, D8 — XP, best distance and Double Acorns read from here |
| `Simulation/Scoring.luau` | score and XP formulas | C4 — do not re-derive XP elsewhere |
| `Services/PlayerDataService.luau` (planned Phase 6; not present) | the future sole writer of a profile | C1–C12, D1–D13 — currency and ownership must go through it |
| `Services/CurrencyService.luau` (planned Phase 6; not present) | every future grant and spend | C4, C6, D5, D7 — no other module may touch a balance |
| `docs/09` exploit suite | the attack list | E7 — new remotes add a row, not a new suite |

---

## 9. What "done" means for this register

All 48 requirements reach `Verified`, each with a recorded execution. A release may ship with
`Partial` items only if they are listed in `KNOWN_LIMITATIONS.md` and are cosmetic. `Pending` on any
Prompt C or D line item means the phase does not close.


---

## 10. Phase 3 coverage map

Where each Phase 3 deliverable sits, and which B–E requirement it advances. Written so a reviewer can
go from a requirement to the code that serves it, and back.

### 10.1 The thirteen pose states

`AnimationLib.STATES` defines thirteen. The Phase 3 brief named ten animations; the other three come
from `docs/01` §6.2, which specified the full set.

| State | Brief wording | Notes |
|---|---|---|
| `idle` | "idle breathing animation" | breathing belly, head micro-motion |
| `alert` | — | ears forward, held still (`docs/01` §6.2) |
| `walk` | — | single-step gait, used for one-off steps |
| `run` | "natural running animation" | diagonal leg pairs, body bob, ear lag |
| `jump` | "a small jump animation" | tuck over the committed one-tile leap |
| `fall` | — | legs trailing, used past the apex |
| `land` | "landing" | absorption ease-out |
| `turn` | "turning" | lean into a direction change |
| `fright` | "frightened animation" | crouch, ears flat, triggered by a near miss |
| `stumble` | "stumble animation" | wobble, sticky duration |
| `happy` | "happy animation" | bounce, triggered by a pickup |
| `death` | "death/failure animation" | collapse, locks the state machine |
| `victory` | "victory animation" | rear-up + settle |

Expressive eyes, animated ears and a moving tail are rig and channel work rather than states: the eyes
are built in `AnimalBuilder` (and follow the head joint), while the ears and tail have their own
animated joints, scaled per species by `anim.earAmp` and `anim.tailAmp`.

**Requirements:** B1 (character presentation), B10 (unlock and reward animation, Phase 7).

### 10.2 The thirteen species

| Detail | Where |
|---|---|
| Proportions, palettes, gait multipliers, rarity, personality | `shared/Config/AnimalConfig.luau` |
| Rig assembly and species extras (bill, mask, spikes, tail rings, whiskers, glow) | `shared/Builders/AnimalBuilder.luau` |
| Animation for every species from one pose library | `shared/Animation/AnimationLib.luau` |
| Lobby presentation and nameplate | `server/Services/PresenceService.luau`, `server/Builders/NameplateBuilder.luau` |
| Ownership, unlocking, equipping, persistence | Phase 7 — not built |

The twelve collectable animals are the brief's roster; `Moonlit Fawn` (Secret) is the thirteenth and is
listed in `docs/01` §9.1. A test pins that split (12 + 1) so config and documentation cannot drift.

**Requirements:** B1 (presentation), C1 (animal collection), C2 (character rarity).

### 10.3 The hazard roster

| Hazard | Where | Requirement |
|---|---|---|
| Cars, sports cars, trucks, vans, buses, motorcycles | `GameConfig.VEHICLES`, `ChunkGenerator.makeLane`, `TrafficSim` | E1 (gameplay testing) |
| Trains on rail corridors | `ChunkGenerator.makeRailLane`, `HazardConfig.rail` | E1 |
| Temporary road closures | `ChunkGenerator` (closure pass), `HazardConfig.closure` | E1 |
| Wildlife crossers | `ChunkGenerator.makeWildlife`, `ObstacleSim` | E1 |
| Special event hazards | **Not built** — Phase 8 | C11 (seasonal events) |

The hazard roster is core gameplay and has no dedicated B–E line item; it is tracked by E1 and by the
Phase 3 exit criteria in `docs/08`.

### 10.4 Near misses and combos

| Piece | Where |
|---|---|
| Measurement (pure) | `shared/Simulation/NearMiss.luau` |
| Combo ladder and decay | `shared/Simulation/Combo.luau` |
| Award decision, de-duplication, rewards | `server/Services/RunService.luau` (`checkNearMiss`) |
| Flash, capped shake, combo pill | `client/Controllers/EffectsController.luau`, `client/UI/Screens/HUD.luau` |

**Requirements:** B12 (visual feedback for rewards and danger), C8 (best-distance tracking reads the
same run result), C4 (XP and score sources, Phase 6).

### 10.5 Lobby presence

`PresenceService` builds one stationary animal and nameplate per player; `PresenceRules` (shared, pure)
decides which of them a given client may draw; `PresenceController` applies it.

**Requirements:** not a B–E line item. Multiplayer lobby presence is a Phase 3 core objective tracked in
`docs/08`; its nearest register entries are E4 (multiplayer testing, Phase 10) and C-nothing.

### 10.6 Chunk format versioning

`shared/Simulation/ChunkFormat.luau` plus a refusal path in `SessionController`. Engineering contract,
not a requirement; it protects every future Phase 4 world from a silent client/server divergence.


