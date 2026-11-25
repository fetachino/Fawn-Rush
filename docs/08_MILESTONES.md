# 08 — Development Milestones

Ten phases. Each has an objective, dependencies, file set, exit criteria, and an effort estimate in
developer-days (one senior developer). A phase does not close while a critical defect is open.

Effort is for a single developer; the real schedule assumes two in parallel from Phase 3 onward
(engineering + art).

| Phase | Name | Effort | Cumulative |
|---|---|---|---|
| 1 | Design & architecture | 4 | 4 |
| 2 | Gameplay prototype | 10 | 14 |
| 3 | Animals & traffic | 12 | 26 |
| 4 | Worlds & assets | 20 | 46 |
| 5 | UI/UX | 16 | 62 |
| 6 | Progression & persistence | 14 | 76 |
| 7 | Collection & customisation | 12 | 88 |
| 8 | Monetization & social | 12 | 100 |
| 9 | Audio, VFX, polish | 14 | 114 |
| 10 | Testing, optimisation, release | 16 | 130 |

**Current position.** Phase 1 is complete; Phases 2, 3 and 4 are source-built but not Studio-verified
(Phase 4 still lacks its required binary mesh exports); Phase 5 is **Partial**. No phase has been
Studio-verified. Development continues without per-phase Studio runs; see "Development posture" below.

---

## Development posture (workflow change)

Decided after Phase 2. Supersedes the "phase cannot close without Studio" rule that was in force at
Phase 2.

**Constraint.** The owner develops by communicating on a phone and has no access to Roblox Studio
until the project is transferred to a Windows PC. Requiring a Studio run before each phase would stop
all development.

**Consequence, and the trade it makes.**

| Before | Now |
|---|---|
| A phase closes only when its features are `Verified` in Studio | A phase closes when its features are `Built` and reviewed; `Verified` happens at the integration gate |
| Phase 3 blocked by `docs/11` | Phase 3 proceeds; `docs/11` becomes the first thing run on PC |
| Status vocabulary used at phase exits | Same vocabulary, different pace: `Built` accumulates, `Verified` accumulates only at the gate |

**This is a real risk, accepted deliberately.** Code written without execution carries defects that
would have been caught in minutes. The mitigation is not optimism, it is process:

1. Every module is reviewed for syntax, requires, API validity and ownership boundaries before the
   phase is called done (§"Definition of done", below).
2. The in-repo test suite grows with each phase. It is the first thing that runs on PC.
3. Each phase's framework boundaries are checked for cycles and for duplicated systems.
4. Unresolved Studio-only issues are recorded in `docs/12_STUDIO_HANDOFF.md` as they are found, not
   remembered later.

**Definition of done for a phase, under this posture.** A phase is complete when: its modules exist,
are wired into boot, are documented, have tests written, have passed a code-level review (no syntax
or require errors, no deprecated APIs, no client trust), and its requirements in `docs/10` are marked
`Built` or `Partial` with the reason. `Verified` is never used before the gate.

**What still blocks.** Prompt D cannot close without platform IDs, and no DataStore verification is
possible before a published place. Those remain external blockers regardless of workflow.

**Gates that survive.**

| Gate | When | Blocks |
|---|---|---|
| **Integration gate** `docs/11` | First Windows + Studio session | Any `Verified` claim, and all release work |
| **Release gate** `docs/09` §9 | Phase 10 | Shipping |
| **Final audit** | Before "development complete" | The handoff |

---

## Requirement integration map — Prompts B, C, D, E

Prompts B–E are mandatory deliverables, not optional polish. Each is assigned to the phase that can
close it, and every line item is tracked in `docs/10_REQUIREMENTS_REGISTER.md` with one of four
statuses (Pending / Partial / Built / Verified).

| Prompt | Items | Closed in | Also touches | Cannot close without |
|---|---|---|---|---|
| **B — Premium visuals & UX** | 12 | **Phase 5** (8 of 12) | Phase 3 and 4 (B1 character), 7 (B8, B9, B10), 9 (B12) | Integration gate; the 4-instance preview cap met on the low tier |
| **C — Progression & retention** | 12 | **Phase 6** (7 of 12) | Phase 4 (C9 worlds), 7 (C1, C2, C3, C10), 8 (C11 events) | Integration gate, Phase 5 UI, DataStore access |
| **D — Monetization** | 13 | **Phase 8** (13 of 13) | Phase 5 (D9 shop shell), 10 (E6 purchase tests) | Five gamepass ids + five product ids `[STUDIO]`; Phase 6 data |
| **E — QA & polish** | 11 | **Phase 10** (release) | Every phase exit (gates) | All of the above |

Per-phase coverage. Under the phone-first posture a phase closes when its requirements are `Built`;
the integration gate is where they become `Verified`.

| Phase | Requirements that must be `Built` when this phase closes |
|---|---|
| 3 | B1 |
| 4 | enabling only — B1 mesh pass, C9 world definitions |
| 5 | B2, B3, B4, B5, B6, B7, B9 (shop shell), B11 |
| 6 | C4, C5, C6, C7, C8, C9, C12 |
| 7 | B8, B9 (collection), B10, C1, C2, C3, C10 |
| 8 | C11, D1–D13 |
| 9 | B12 |
| 10 | E1–E11 |

A phase may not close while any listed requirement is `Pending`. Phase 10 requires all 48 to be
`Verified`, or listed in `KNOWN_LIMITATIONS.md` as cosmetic-only.

---

## Phase 1 — Design & Architecture ✅ complete

**Objective.** A specification precise enough that two engineers could build the game independently
and end up with the same game.

**Delivered.** This documentation set: GDD, architecture, file tree, mechanics spec, UI/UX spec, asset
plan, monetization plan, milestones, risk and test plan.

**Exit criteria.** Every later phase can name the documents and config keys it consumes; no unresolved
"we'll figure it out" in the core loop, the fairness model, or the data schema.

**Open items carried forward.** Blender asset production (Phase 4), platform IDs (any time before
Phase 8), audio sourcing (Phase 9), Expedition mode (post-launch).

---

## Phase 2 — Working gameplay prototype ✅ built

**Status.** Built and code-reviewed. Not Studio-verified. First run happens at the integration gate
(`docs/11`).

**Objective.** A player can join, enter Greenwood, cross rows with responsive controls, be killed by a
car, see a results screen, and retry. No UI polish, no data persistence beyond a stub, no collection.

**Dependencies.** Phase 1. Rojo installed. Studio place created.

**Files.**
`default.project.json`, `rokit.toml`, `.luaurc`, `.gitignore`,
`shared/Config/GameConfig.luau`, `shared/Config/WorldConfig.luau` (Greenwood only),
`shared/Types/GameTypes.luau`, `shared/Types/ApiTypes.luau`,
`shared/Constants/{Net,Layers,Keys}.luau`,
`shared/Util/{Signal,Result,Logger,TableUtil,GridMath,Rng,TweenPresets,RateLimiter}.luau`,
`shared/Net/{Remotes,RemoteGuard}.luau`,
`shared/Simulation/{TrafficSim,ChunkGenerator,SafePathValidator,Scoring}.luau`,
`shared/Framework/{Registry,Class}.luau`,
`server/Bootstrap.server.luau`, `server/Services/ServiceRegistry.luau`,
`server/Services/{RunService,ZoneService,ChunkService,TrafficService}.luau`,
`server/Builders/{AnimalBuilder,VehicleBuilder}.luau`, `server/World/{Shared/Props,Shared/RoadBuilder,Greenwood}.luau`,
`client/Bootstrap.client.luau`, `client/Controllers/{ControllerRegistry,InputController,MovementController,TrafficViewController,CameraController}.luau`,
`client/UI/{UIRoot,Theme}.luau`, `client/UI/Screens/{HUD,Results}.luau`.

**Exit criteria.**
1. Frame-locked step cadence is identical for tap, swipe, and held key on a phone.
2. `SafePathValidator` rejects a hand-built impossible corridor and accepts 10,000 generated chunks with
   zero failures and zero accepted-then-died-without-decision cases in a 200-run soak.
3. Death → results → retry in under 2.5 s of non-gameplay time.
4. Server rejects an out-of-cooldown step, a bounds-violating step, and a step while dead (verified by a
   scripted remote fuzzer).
5. Runs at 30 FPS on the low-tier test device with a full zone loaded.

**Explicitly not in Phase 2.** Saving, currency, animals beyond the deer, other worlds, menus, audio.

---

## Phase 3 — Animals & traffic · Prompt B ✅ built

**Closes prompt requirements:** B1. **Status:** Built and code-reviewed; not Studio-verified. Adds 13
species, a 13-state animation system, six new hazard families, near misses and combos, jumps, and lobby
presence. The Phase 3 suite is written but unexecuted.

**Objective.** The deer feels alive; the twelve other animals exist and are playable; the full hazard
roster is implemented and validated.

**Dependencies.** Phase 2.

**Files.** `shared/Config/AnimalConfig.luau`, `server/Builders/AnimalBuilder.luau` (full rig + validate),
`client/Controllers/AnimationController.luau`, `client/Effects/*`,
`shared/Simulation/HazardPatterns.luau`, spec files for the roster.

**Exit criteria.** All ten animation states per animal (`01` §6.2) pass the feel checklist in `01` §6.3.
Hazards 1–9 implemented with the fairness cues from `01` §7.2. Trains announced. Vans telegraphed.
Closures solvable. 60 FPS desktop / 30 mobile with 4 animals on screen.

---

## Phase 4 — Worlds & assets · built

**Enables:** B1 (Blender mesh pass), C9 (world definitions). **Closes no prompt requirement on its own.**

**Status:** Built and code-reviewed; not Studio-verified. Five world profiles, a reusable scenery kit,
per-world lighting and ambience, the unlock rule, and exporter source are in place. No `.blend` or `.fbx`
exports were generated; the binary-mesh exit criterion remains unmet.

**Met:** adding a sixth world is a config block — Phase 4 changed no simulation, generator, service or
renderer control flow. Every world has its own scenery, ambience, palette and difficulty profile. The
scale gate exists as a committed reference `.obj`.

**Not met, deliberately:** the exit criterion "at least the deer and two vehicles replaced by real
meshes" is **not satisfied**. This environment has no Blender and no Python runtime, so no binary mesh
can be produced or imported here. The pipeline that produces them is complete and documented, and
`assets/manifest.json` records `pipeline.binaryAssetsPresent: false` rather than implying otherwise.
Streaming remains off and unmeasured. The "throw-away sixth world" proof was likewise not performed —
extensibility is evidenced instead by five worlds sharing one schema and by a test asserting every
configured prop kind resolves to a builder.

**Objective.** Five visually distinct, config-driven worlds. Blender pipeline live; at least the deer
and two vehicles replaced by real meshes as proof of the pipeline.

**Dependencies.** Phase 3, Blender pipeline from `06` §5.

**Files.** `shared/Config/{WorldConfig(5 profiles),AssetConfig}.luau`,
`server/World/{WorldRegistry,CityChaos,DesertDash,SnowySummit,NeonNight,LobbyBuilder}.luau`,
`assets/manifest.json`, `assets/blender/*`, `assets/export/*`.

**Exit criteria.** Adding a sixth world requires only a config block + one builder module (proven by
building a throwaway test world and deleting it). Every world has its own scenery, ambience hook,
palette, and difficulty profile. Scale gate (`06` §5.2.1) passes. Streaming measured, not assumed.

---

## Phase 5 — UI/UX · Prompt B

**Status: Partial; not closed and not Studio-verified.** UI foundations exist, but the full component
library, all fourteen screens, device-quality verification and Phase 5 exit criteria are not complete.
B3 is source-built for every currently implemented screen; this does not close Phase 5 or imply the
unbuilt screens exist. The register records the remaining subsets and blockers.

**Objective.** The full component library and all fourteen screens, at mobile quality, on real devices.

**Dependencies.** Phase 4 (needs real data shapes). Can start in parallel from Phase 3 for components.

**Implemented foundations.** Central UI tokens and pure HUD geometry helpers; responsive safe-frame
scaling and viewport/text-scale reflow APIs wired for every currently implemented screen; top-band portrait rotate
guidance with geometry assertions; button/touch feedback, reduced-motion gates for direct camera/UI effects
and session-local text scaling; lobby and collection previews with a four-lease cap; gamepad initial
selection; visible run-start outcomes; and a Studio-boot Phase 5 suite. Source is wired but unexecuted.

**Not met.** Many planned screens and component types are absent; collection ownership/equip, real shop
offers/odds/purchases, pause, missions, rewards and profile-backed settings are disconnected. Rendered
screen layouts, cutouts, camera sightlines and accessibility still need Studio/device review; touch FOV stays
at 70 to avoid risking lateral hazard visibility before calibration. Blender exports remain outstanding
from Phase 4. Phase 6 and Phase 8 work has not started.

**Exit criteria.** Every button in `05` §4.1 has all seven states implemented and demonstrated. The
protected-band layout test passes at six aspect ratios. Every screen reachable and back-navigable on a
6-inch phone in landscape with one thumb. No hard-coded colour or size outside `UIConfig`
(lint rule). Zero screens with placeholder text. None of these criteria has been demonstrated in Studio.

---

## Phase 6 — Progression & persistence · Prompt C

**Closes prompt requirements:** C4, C5, C6, C7, C8, C9, C12.

**Objective.** Real saving, real economy, real progression. Nothing in this phase may be faked.

**Dependencies.** Phase 5 (UI to display it), Phase 2 (server lifecycle).

**Files.** `server/Data/{ProfileStore,SchemaMigration}.luau`,
`server/Services/{PlayerDataService,CurrencyService,ProgressService,MissionService,AchievementService,LoginRewardService,SettingsService}.luau`,
`shared/Config/{EconomyConfig,MissionConfig,AchievementConfig}.luau`,
`shared/Util/{ProfileUtil,TimeUtil}.luau`.

**Exit criteria.**
1. Load → play → leave → rejoin retains currency, XP, level, records, missions, settings.
2. A failed load refuses the session and writes nothing (verified by injecting a DataStore error).
3. Two servers cannot hold the same profile; the second is refused with a clear message.
4. `BindToClose` saves all loaded profiles within 25 s under a 16-player load test.
5. Currency transactions reconcile: a 500-run soak shows `sum(grants) - sum(spends) == final balance`
   for every profile, with no negative balances and no client-induced grants.
6. Mission progress only increments from server events (a remote fuzzer that tries to report progress
   is ignored).

**Note on honesty.** DataStore reliability can only be *proven* on a published server. Phase 6 exit
criteria are met in Studio against the real DataStore APIs; the `[LIVE]` verification pass happens in
Phase 10 and is a release blocker.

---

## Phase 7 — Collection & customisation · Prompt C + B

**Closes prompt requirements:** C1, C2, C3, C10, B8, B9 (collection), B10.

**Objective.** The cast is collectable, ownable, equippable, and previewable without hurting framerate.

**Dependencies.** Phase 6 (ownership), Phase 3 (models), Phase 5 (UI).

**Files.** `shared/Config/CosmeticConfig.luau`, `server/Services/InventoryService.luau`,
`server/Builders/{CollectibleBuilder,NameplateBuilder}.luau`,
`client/UI/Screens/{Collection,Customize,UnlockReveal}.luau`,
`client/UI/Components/{RarityBadge,ViewportPreview}.luau`.

**Exit criteria.** 13 animals + ~58 cosmetics ownable and equippable, persisted, and previewed with the
4-instance cap respected. Unlock reveal implemented per rarity tier with all seven presentations
distinct in colour, shape, motion, and sound. Fitting warnings correct for long-eared and angled rigs.
Collection scroll holds 30 FPS on the low-tier device.

---

## Phase 8 — Monetization & social · Prompt D + C11

**Closes prompt requirements:** D1–D13, C11. **Blocked on** platform ids `[STUDIO]`.

**Objective.** Purchases that work, cannot be duplicated, and are honest. Leaderboards that reflect the
server's truth.

**Dependencies.** Phase 6. **Blocked on** platform IDs `[STUDIO]`.

**Files.** `server/Services/{MonetizationService,ShopService,SocialService,LeaderboardStore,BadgeAwardService}.luau`,
`server/Data/ReceiptLedger.luau`, `shared/Config/{MonetizationConfig,BadgeConfig}.luau`,
`client/UI/Screens/{Shop,GamepassShop,Leaderboard,EventMenu}.luau`.

**Exit criteria.** Receipt replay grants exactly once (tested by replaying the same `PurchaseId` 20
times). Ownership restored on rejoin. Unconfigured ids hide their UI. Leaderboards update from
`OrderedDataStore` with a 60 s cadence and survive a store error by serving the last cache. Every pass
and product has disclosure copy rendered verbatim from config.

---

## Phase 9 — Audio, VFX & polish · Prompt B12

**Closes prompt requirements:** B12.

**Objective.** The game sounds and feels finished without breaking the performance budget.

**Dependencies.** Phase 7/8.

**Files.** `shared/Config/AudioConfig.luau`, `client/Controllers/{AudioController,EffectsController}.luau`,
`client/Audio/{MusicDirector,SfxDirector,AudioBuses}.luau`, `client/Effects/{ParticlePresets,Pools,ScreenEffects}.luau`,
`shared/Util/TweenPresets.luau` (tuned), `assets/audio/*` + `LICENSES.md`.

**Exit criteria.** 34 cues + 6 tracks configured or explicitly listed as missing. Emitter budget
enforced per tier. Music cross-fades on world change and on death (duck, not stop). Reduced-motion mode
verified. No sound plays after leaving a run. Vignette/shake within the intensity caps in `01` §7.4.

---

## Phase 10 — Testing, optimisation, release · Prompt E

**Closes prompt requirements:** E1–E11. This phase *is* Prompt E. It also re-verifies all 48 items in
`docs/10` and produces `docs/KNOWN_LIMITATIONS.md`, `docs/RELEASE_CHECKLIST.md` and `docs/CHANGELOG.md`.

**Objective.** Prove it, then ship it.

**Dependencies.** All phases. **Blocked on** a published testing place `[LIVE]`.

**Files.** All `*.spec.luau` suites, `server/Tests/RunTests.server.luau`, `client/Dev/*`,
`README.md` final, `docs/KNOWN_LIMITATIONS.md`, `docs/RELEASE_CHECKLIST.md`, `docs/CHANGELOG.md`.

**Exit criteria.**
1. Full test suite green (`09` §4).
2. Exploit suite green (`09` §3).
3. Performance budgets met on all four device tiers (`09` §5.2).
4. Ten-hour soak with 16 simulated players: no memory growth beyond 5%, no zone leaks, no profile
   leaks.
5. Every item on the outstanding-integrations list either done or documented in
   `KNOWN_LIMITATIONS.md`.
6. A new developer can clone, `rokit install`, `rojo serve`, and play in under 15 minutes, verified by
   someone who has not done it before.

---

## Post-launch roadmap (not committed)

| Item | Why | Risk |
|---|---|---|
| Expedition mode | Increases run variety without new content | Medium — chained difficulty needs its own fairness pass |
| Seasonal world skins | Cheap content cadence | Low — cosmetic over existing profiles |
| Daily Gauntlet | Competitive retention hook | Medium — needs seeded-run integrity |
| Additional animals | Collection depth | Low — the builder handles it |
| Spectator mode | Social | Medium — extra traffic |
| Trade-free cosmetic gifting | Social | High — support/fraud cost |
