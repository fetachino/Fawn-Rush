# 09 — Risk and Testing Plan

Owner: QA & Performance Engineer. This document is a gate, not a formality: Phases 2–10 each close
against criteria defined here.

**Development posture (supersedes the per-phase Studio rule).** The owner develops from a phone, so
source work proceeds without per-phase Studio runs; this does not mean later phases are already built.
Studio verification is a rolling integration gate (`docs/11`) plus the release gate (§9). Under this
posture a phase may close on **L1 unit tests written + code-level review**, and L2/L3/L4 verification
accumulates at the gate. The risk this creates — defects that a five-minute Play session would have caught — is carried in the risk
register as R16 and mitigated by `docs/12_STUDIO_HANDOFF.md`, which records every Studio-only issue as
it is discovered rather than at the end.

**Related registers.** The 48 mandatory line items of Prompts B–E and their per-item status live in
[docs/10 — Requirements Register](10_REQUIREMENTS_REGISTER.md). The rolling Studio integration gate
lives in [docs/11 — Integration Gate](11_PHASE2_VERIFICATION.md). This document supplies the
test levels, exploit suite and budgets those two consume.

---

## 1. Test strategy

Four levels, four different kinds of truth.

| Level | Runs where | Proves | Frequency |
|---|---|---|---|
| **L1 Unit** | Studio or Luau CLI, pure functions | Formulas, generation, validation logic | Every change (sub-second suites) |
| **L2 Integration** | Studio, multi-player local server | Service boundaries, remotes, persistence against real DataStore | Every phase exit |
| **L3 Exploit** | Studio with a script executor analogue (a server-side fuzz client) | A hostile client cannot gain value | Every phase exit from Phase 2 |
| **L4 Live** | Published testing place, ≥ 8 real clients | Real latency, real DataStore, real Marketplace, real devices | Phase 8 and Phase 10, and before every release |

**What "tested" means here.** A test being written is not a test result. Under the current phone-first
posture, `Built` records source implementation and review; `Verified` requires an executed test at the
appropriate level with its evidence recorded. L4 items that cannot be run in the current environment are
tagged `[LIVE PENDING]` and are listed in `KNOWN_LIMITATIONS.md` until closed. No claim of verified
saving, purchases, or leaderboards is made on the basis of Studio alone.

---

## 2. Test environments

| Env | Purpose | Data | Players |
|---|---|---|---|
| `local` | Development | Mock DataStore (in-memory) behind the same interface | 1–4 |
| `studio-test` | L1/L2/L3 | Real DataStore API, dedicated test keys `test_<userId>` | up to 8 |
| `live-test` | L4 | Real DataStore, private testing place | up to 16 |
| `production` | Shipped | Real | 16/server |

DataStore keys are namespaced by environment: `FawnRush_prod_v3_<userId>` vs
`FawnRush_test_v3_<userId>`. A build refuses to start if a production key prefix is used while
`RunService:IsStudio()` — a guard against wiping live data from a test run.

---

## 3. Exploit suite (L3)

Every row is a test with a scripted hostile client. "Expected" is what the server must do.

| # | Attack | Method | Expected |
|---|---|---|---|
| E1 | Teleport forward | Send `StepRequest` 40× in one second | Steps 12+ rejected by the rate limiter; distance gained ≤ accepted steps |
| E2 | Out-of-cooldown step | Send two steps 10 ms apart | Second rejected; position unchanged |
| E3 | Bounds violation | Step to `col = 40` | Rejected; no penalty; no state change |
| E4 | Move while dead | Steps after death confirmed | Rejected; no revive, no score |
| E5 | Fake reward | Craft a `RunState` payload from the client | Server never reads run state from the client; nothing happens |
| E6 | Fake currency | Send `PurchaseItem` with a manipulated price field | Price is read from config; payload field ignored; balance unchanged or spent at the real price |
| E7 | Negative spend | `TrySpend` with a negative amount via any remote | Rejected by validation (amount must be > 0) |
| E8 | Claim twice | Send `ClaimMission` for the same mission | First succeeds, second returns "already claimed" |
| E9 | Claim unearned | Claim a mission with 0 progress | Rejected with a reason |
| E10 | Equip unowned | `EquipAnimal` for an animal not owned | Rejected; equipped state unchanged |
| E11 | Duplicate receipt | Replay the same `PurchaseId` 20× | Granted exactly once |
| E12 | Forged receipt | Call `ProcessReceipt` locally for a fake product | Requires the platform callback; a local call produces no grant |
| E13 | Remote spam (all remotes) | 200 msg/s per remote for 30 s | ≤ 20 rate-limit trips, then the remote is muted for the session; server CPU stable |
| E14 | Malformed payloads | `nil`, strings, huge tables, NaN, cyclic tables into every remote | Guard rejects each; zero unhandled errors in the log |
| E15 | Session hijack | Second client attempts to load the same profile | Lock refuses the second session; no writes from it |
| E16 | Leaderboard write | Attempt to call `LeaderboardStore` from a client | Not exposed as a remote at all |
| E17 | Burst purchase race | Two purchase requests in the same tick for the last affordable item | One succeeds, one is rejected for insufficient funds; no negative balance |
| E18 | Settings abuse | Set music volume to 1e9 or a string | Clamped/sanitised before persistence |
| E19 | Zone intrusion | Attempt to read/move another player's zone via instance path | Zones are server-only; clients hold references to their own zone only |
| E20 | Clock manipulation | Client reports a wild `clientTick` | Ping estimate clamps; rewind window cannot exceed `REWIND_MAX_MS` |

E1, E5, E11, E13 and E14 are **release blockers**. The others are faults that must be fixed in the
phase they appear.

---

## 4. Unit test inventory (L1)

Suites live beside their modules. Pure functions only — no Roblox instances — so the whole L1 suite runs
in well under a second and can be fuzzed.

| Suite | Cases | Key assertions |
|---|---|---|
| `Rng.spec` | 8 | LCG matches a reference vector; stream derivation is stable; adjacent seeds do not correlate |
| `GridMath.spec` | 10 | Tile ↔ world round-trips exactly; bounds clamp; adjacency is symmetric |
| `TrafficSim.spec` | 24 | `vehicleAt` is a pure function of `t`; lane index range covers the view window; `isHit` symmetric in direction; headway/gap identity holds; gust multiplier applied identically |
| `ChunkGenerator.spec` | 32 | Same seed → identical `ChunkDef` across 10,000 seeds; every corridor ≤ 3 lanes; every corridor followed by ≥ 1 median; every lane `headway ≥ minHeadway`; no two collectibles share a tile; obstacles never occupy the only free column |
| `SafePathValidator.spec` | 18 | Accepts 10,000 generated chunks; **rejects a hand-built impossible corridor** (the phase-alignment wall); rejects the node-cap case; returns a path whose moves are each legal; wait-only corridors accepted |
| `Scoring.spec` | 12 | Score formula monotonic in rows; combo steps exact; no world multiplier > 1.0 |
| `SchemaMigration.spec` | 14 | v1 → v2 → v3 fixtures migrate without data loss; unknown future version refused; defaults contain every key the code reads (reflection over `DataTypes`) |
| `ProfileUtil.spec` | 8 | Dotted get returns the default for a missing path; never mutates |
| `RateLimiter.spec` | 6 | Token bucket refills correctly; burst respected; zero tokens → rejected |
| `CurrencyService.spec` | 20 | Grant/Spend arithmetic; caps; negative rejected; Double Acorns whitelist covers every source key in the game (reflection over `EconomyConfig`) |
| `InventoryService.spec` | 14 | Ownership checks; equip requires ownership; loadout slot limits respected (1 free, 4 with the pass) |
| `MissionService.spec` | 18 | Daily reset at the UTC boundary; progress only from events; claim once; reroll count |
| `ProgressService.spec` | 10 | XP curve matches the table in `01` §13; multi-level jumps handled; rewards granted once per level |
| `UIConfig.spec` | 6 | Contrast locks from `05` §2.1; every token referenced by a component exists |
| `MonetizationConfig.spec` | 6 | No duplicate ids; every id is `0` or a positive integer; resolve maps round-trip |
| `ReceiptLedger.spec` | 10 | Replay is idempotent; reservation → grant → complete ordering; abandoned reservation retries |
| `AssetConfig.spec` | 12 | Every configured id is `""` or a positive integer; every animal, cosmetic and vehicle referenced by config has an entry; every manifest `status` is a known state; no id collides across kinds |
| `AudioConfig.spec` | 6 | Every cue id is `0` or a positive integer; no duplicate ids; bus defaults are within 0–10 |

Total ≈ 278 unit cases.

---

## 5. Integration and performance (L2)

### 5.1 Scenario suite

| # | Scenario | Pass condition |
|---|---|---|
| I1 | Join → play → leave → rejoin | All profile fields survive; nothing resets |
| I2 | Two players, one server | Independent zones; no interference; both runs validate |
| I3 | Player leaves mid-run | Run finalised as abandoned; currency and XP granted; no error |
| I4 | Server shutdown with 8 players | All profiles saved and locks released within 25 s |
| I5 | DataStore unavailable | Session refused with the modal; no writes attempted |
| I6 | Duplicate session | Second server refused, first unaffected |
| I7 | Level-up during a run | Rewards granted once; UI shows the level-up after results, not during the run |
| I8 | Mission completes mid-run | Progress updates; claim available at results |
| I9 | Purchase while running | Blocked (shop is not reachable during a run) |
| I10 | Rejoin after a crash between death and save | Distance recorded at least up to the last accepted step; no duplicate rewards |

### 5.2 Performance budgets

Measured with the in-game overlay plus Studio's microprofiler. "Low tier" is the mandated floor: a
2019-era mid-range Android at graphics level 4.

| Metric | Low tier target | Mid tier | Desktop |
|---|---|---|---|
| Frame rate (run) | ≥ 30 FPS, P1 frame < 33 ms | ≥ 45 FPS | ≥ 60 FPS |
| Server Heartbeat CPU | < 35% of budget | < 35% | < 35% |
| Concurrent zones | 16 | 16 | 16 |
| Parts in the client workspace | < 6,000 | < 12,000 | < 25,000 |
| Live vehicles per zone | ≤ 40 | ≤ 40 | ≤ 40 |
| Particle emitters per zone | ≤ 24 | ≤ 40 | ≤ 60 |
| GUI instances on screen | < 900 | < 1,400 | < 2,000 |
| Network down | < 2.5 KB/s per player | — | — |
| Memory growth in a 10-hour soak | < 5% | < 5% | < 5% |

### 5.3 Generation cost

`SafePathValidator` must complete a chunk in ≤ 4 ms at the 95th percentile and 6 ms at the 99th, with
the node cap at 6,000. Phase 2 measures this on the low tier with a timing harness over 10,000 chunks
and fails the phase if p99 exceeds 6 ms — a slow solver would stall zones, which players feel as a
hitch at exactly the moment a corridor arrives.

### 5.4 Render cost specifics

`ViewportPreview` (limited to 4) is the single most expensive UI element on mobile. Budget: ≤ 2 ms/frame
for all live previews combined on the low tier. Beyond 4 requested previews, the list falls back to a
cached image rendered once at selection time.

### 5.5 Soak and load

- **10-hour soak**, 16 bots running continuously through death/retry: no zone leak (zone count constant),
  no profile leak (`PlayerDataService` table size returns to 0 after bots leave), memory growth < 5%.
- **Load test**, 16 real clients on the live-test place for 30 minutes: no remote backlog, server
  heartbeat < 35%, no disconnects.
- **Recovery test:** kill a server mid-save and verify that no profile is lost or duplicated (the
  session lock must expire and the next session must recover cleanly).

---

## 6. Device and input matrix

| Tier | Reference | Role |
|---|---|---|
| Low | 2019 mid-range Android, 2 GB RAM, graphics 4 | Mandated floor |
| Mid | iPhone SE 2 / recent mid-range Android | Primary audience |
| High | iPhone 13+ / iPad | |
| Desktop | Integrated GPU, Chrome | Competitive audience |
| Console | Xbox controller | Input parity only |

Tested inputs on every tier: touch D-pad, touch swipe, keyboard, gamepad, mouse-click on desktop, and
mixed (touch device with a connected controller). Portrait and landscape for menus; landscape and
portrait for the run.

### 6.1 Feel acceptance tests (manual, per tier)

1. Ten taps in a row at 150 ms intervals produce ten steps and no dropped input.
2. A 60 ms-early press is buffered, not lost (count steps over 20 rapid presses).
3. A held direction produces a continuous run at exactly the cooldown rate.
4. Swipe thresholds: a 20 px flick does nothing; a 40 px flick steps once, not twice.
5. Death reads as impact, not as a freeze or a teleport.
6. Camera never clips through a building or the ground in any world.
7. The animal is visible at all times; nothing in the HUD overlaps it on any tested aspect ratio.

---

## 7. QA process

- **Bug severity.** S1 blocker (data loss, currency exploit, crash) — stop everything. S2 critical
  (progression blocked, purchase fails) — fix before the phase closes. S3 major (visual/audio defect,
  awkward text) — fix before release. S4 minor — backlog.
- **Every bug report** carries: device, tier, world, row, reproduction steps, and the overlay's session
  id so the server log can be found.
- **Regression suite** = the L1 suites plus a curated 12-scenario L2 playlist, run at every phase exit
  and before every release.
- **Playtest cadence.** Playtests at Phase 2, 5, and 9 with at least five players who have never seen
  the game. Notes recorded verbatim; "feels off" is a valid finding and must be investigated before
  dismissal.

---

## 8. Risk register

Likelihood × impact, with the mitigation that is actually in this plan.

| # | Risk | L | I | Mitigation | Owner |
|---|---|---|---|---|---|
| R1 | Client/server simulation divergence causes unfair deaths | M | **High** | Shared deterministic modules; closed-form traffic; rewind window; 10,000-seed parity test; `[L4]` latency testing | Networking |
| R2 | Authority hole lets a client mint currency | L | **High** | All mutations in `CurrencyService`; client sends intent only; E5/E6/E7; server-side reconciliation in Phase 6 | Engineering |
| R3 | Data loss on save/load failure | L | **High** | Session lock, refusal-on-failure, no defaults over good data, `BindToClose`, recovery test | Engineering |
| R4 | Generation produces an unsurvivable wall | M | **High** | Ghost solver + 4-step relaxation + guaranteed template + telemetry on fallbacks | Gameplay |
| R5 | Mobile performance below 30 FPS | M | **High** | Budgets from Phase 2, tiered graphics, virtualised lists, emitter caps, mandated low-tier device | QA |
| R6 | UI unreadable or unusable on a phone | M | High | Mobile-first tokens, protected band test, six aspect ratios, playtests at Phase 5 | UI/UX |
| R7 | Asset pipeline slips (no Blender assets at launch) | M | Med | Procedural assets are shippable-but-label-temporary; the pipeline is per-asset, not all-or-nothing | Art |
| R8 | Scope creep from Expedition/Gauntlet | M | Med | Both explicitly deferred with a documented design so they are not invented mid-build | Director |
| R9 | Economy inflation or deflation | M | Med | Central config, per-run earnings modelled in `01` §12, telemetry on earn/spend per session | Economy |
| R10 | Monetization perceived as pay-to-win | L | High | Never-sold list, Double Acorns whitelist, no paid randomness, disclosure copy verbatim from config | Monetization |
| R11 | Roblox API/behaviour change (AnalyticsService signatures, `UnreliableRemoteEvent`) | M | Med | `[VERIFY]` markers; feature flags; wrappers that no-op safely | Engineering |
| R12 | Platform IDs never supplied, blocking Phase 8 | M | Med | Every consumer hides unconfigured items; the game is fully playable with all ids `0` | Producer |
| R13 | Audio rights problem | L | Med | Licence file per cue; no cue ships without a recorded licence; silence is an acceptable fallback | Sound |
| R14 | Single-developer bus factor | M | Med | Everything is in the repo (code, docs, config, manifest); no Studio-only knowledge; setup verified by a new developer at Phase 10 | Director |
| R15 | Leaderboard manipulation | M | Med | Server-only writes; sanity caps (rows per session); weekly key rotation; anomaly log | Social |

---

## 9. Release checklist (Phase 10)

- [ ] L1 suite green, ≥ 260 cases
- [ ] E1/E5/E11/E13/E14 green, full exploit suite green
- [ ] 12-scenario regression playlist green
- [ ] 10-hour soak: no leaks, memory growth < 5%
- [ ] Perf budgets met on all four tiers
- [ ] `[LIVE]` DataStore load/save/refuse-session verified on the testing place
- [ ] `[LIVE]` receipt replay verified with a real purchase
- [ ] `[LIVE]` leaderboard write/read verified across two servers
- [ ] All five worlds reachable and unlockable; all thirteen animals obtainable by a free account (verified
      by a scripted free-account playthrough)
- [ ] Every config id either set and verified, or listed in `KNOWN_LIMITATIONS.md`
- [ ] No placeholder UI text; no `TODO` in a user-visible string
- [ ] Sound/music licence file complete
- [ ] Reduced motion, text scale, and colour-blind modes verified by a settings test
- [ ] Fresh-clone setup under 15 minutes, verified by someone who has not done it
- [ ] `KNOWN_LIMITATIONS.md`, `CHANGELOG.md`, and the final README written

---

## 10. Known limitations

Honest items that will exist in `KNOWN_LIMITATIONS.md` at release unless the relevant integration
closes first.

1. **Temporary geometry.** Any animal or vehicle whose manifest status is not `verified` ships as
   procedural primitives and is labelled as such (`06` §9).
2. **Unconfigured platform ids.** With pass/product/badge ids at `0`, those surfaces are hidden and no
   purchase or badge award can occur.
3. **Silent audio.** Cues without a licensed file are silent and logged.
4. **Studio-only verification.** Saving, purchases, and leaderboards are only *proven* at L4. Until the
   `[LIVE]` passes run, they are implemented-and-tested-in-principle, not verified.
5. **Deferred modes.** Expedition and Daily Gauntlet are designed but not built.
6. **No LOD on animals.** They are within budget at 2.4–2.8k tris, so LOD would not pay for itself yet.
7. **Spectate mode** is not implemented; the data hook exists.
8. **Console achievements** (Roblox platform achievements) are out of scope for v1.


---

## 11. Related documents

This plan gates every other document; each link below is the section it actually tests.

- [00 — Index](00_INDEX.md) — reading order and the decision log this plan defends
- [01 — Game Design Document](01_GAME_DESIGN_DOCUMENT.md) — §6.3 feel criteria, §7 fairness doctrine, §12 economy
- [02 — Technical Architecture](02_TECHNICAL_ARCHITECTURE.md) — §5 networking, §6 authority matrix, §7 data layer, §12 test harness
- [03 — Project File Tree](03_PROJECT_FILE_TREE.md) — `Tests/*.spec.luau` placement and the toolchain
- [04 — Gameplay Mechanics Spec](04_GAMEPLAY_MECHANICS_SPEC.md) — §4 traffic, §6 safe-path proof, §7 collision, §10 lifecycle
- [05 — UI/UX Specification](05_UI_UX_SPECIFICATION.md) — §2.1 contrast locks, §4.1 button states, §7.2 protected band
- [06 — Asset Production Plan](06_ASSET_PRODUCTION_PLAN.md) — §5.4 import gate, §7.2 audio placeholder policy, §9 temporary-asset disclosure
- [07 — Monetization Plan](07_MONETIZATION_PLAN.md) — §7 `ProcessReceipt` contract and §9 failure handling
- [08 — Milestones](08_MILESTONES.md) — the phase exit criteria that cite this document

Files this plan produces at Phase 10: `docs/KNOWN_LIMITATIONS.md`, `docs/RELEASE_CHECKLIST.md`,
`docs/CHANGELOG.md` (contents defined in §9 above).
