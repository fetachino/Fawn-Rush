# 00 — Index, Conventions, Glossary, Decision Log

## Reading order

1. [01 — Game Design Document](01_GAME_DESIGN_DOCUMENT.md) — the game and its rules
2. [04 — Gameplay Mechanics Spec](04_GAMEPLAY_MECHANICS_SPEC.md) — the numbers those rules resolve to
3. [02 — Technical Architecture](02_TECHNICAL_ARCHITECTURE.md) — the runtime those numbers demand
4. [03 — Project File Tree](03_PROJECT_FILE_TREE.md) — where each of those modules lives
5. [05 — UI/UX Specification](05_UI_UX_SPECIFICATION.md) — the surface all of it is presented through
6. [06 — Asset Production Plan](06_ASSET_PRODUCTION_PLAN.md) — geometry, animation, VFX, audio
7. [07 — Monetization Plan](07_MONETIZATION_PLAN.md) — what is sold, what never is
8. [08 — Milestones](08_MILESTONES.md) — the order of work and its exit criteria
9. [09 — Risk & Testing Plan](09_RISK_AND_TESTING_PLAN.md) — how it is proven, and what could go wrong
10. [10 — Requirements Register](10_REQUIREMENTS_REGISTER.md) — all 48 line items of Prompts B–E with status
11. [11 — Studio Integration Gate](11_PHASE2_VERIFICATION.md) — the run sheet for the first session on the PC
12. [12 — Studio Handoff](12_STUDIO_HANDOFF.md) — Windows setup, launch, open Studio-only issues

The repository overview and the outstanding-integrations checklist are in the root
[README](../README.md).

Design first because it constrains code. Mechanics before architecture because the networking model
is derived from the fairness rules in the mechanics spec, not the other way around. Testing is last to
read but first in gating: `09` defines the conditions under which any phase may close.

---

## Conventions used across these documents

**Units.** One grid tile (`TILE`) is 4 studs. One stud is 0.28 m. All positions in gameplay code are
expressed in *tile space* — integers `(col, row)` — and converted to world studs only at the render
boundary. Tile space keeps the deterministic simulation exact and immune to floating-point drift.

**Axes.** The run advances along **−Z** (Roblox's conventional forward). `row` increases toward −Z.
`col` increases toward +X. Lane centres sit at `Z = −row * TILE`, column centres at `X = col * TILE`.

**Time.** The authoritative simulation runs on a fixed 20 Hz server tick (`TICK_HZ = 20`). Client
rendering runs at frame rate and interpolates between ticks. All durations in these docs are seconds
unless marked `ms`.

**Severity tags.** Where a requirement is at risk of being faked, it is tagged:

- `[CODE]` — fully implementable in this repository.
- `[STUDIO]` — requires manual action in Roblox Studio or the Creator Dashboard.
- `[ASSET]` — requires an uploaded asset ID.
- `[LIVE]` — can only be verified on a published server.

**Numbers.** Every tunable number quoted in these docs is a *default* value and lives in
`src/shared/Config/*.luau`. Documents must never be the source of truth for balance — the config
modules are. If a doc and the config disagree, the config wins and the doc gets fixed.

---

## Glossary

| Term | Meaning |
|---|---|
| **Run** | One attempt, from spawn to death or abandonment. |
| **Lane** | One row of the crossing grid. A vehicle lane carries traffic; a safe row does not. |
| **Corridor** | A group of 1–3 adjacent vehicle lanes travelling the same direction, with no gap between them. |
| **Median** | A safe row between corridors where a player can stand indefinitely. |
| **Chunk** | A generated block of 12 rows (one corridor plus surrounding medians and scenery). |
| **Clearance** | Distance in tiles between the player and the nearest hazard edge during a tick. |
| **Near-miss** | A hazard passing within `NEAR_MISS_TILES` of the player while the run is live. Awards combo. |
| **Combo** | Multiplier ×1.0–×5.0 built by consecutive near-misses, decaying after `COMBO_DECAY`. |
| **Row depth** | Total rows advanced in a run. The public "distance" metric. |
| **World profile** | A config block describing a world's theme, traffic parameters, scenery, and audio. |
| **Ghost solver** | The path-validation agent run by chunk generation to prove a chunk is survivable. |
| **Rewind window** | Server-side lag compensation: vehicle positions are rewound by clamped ping when judging a step. |
| **Safe row** | A row with no hazards: grass, sidewalk, sand, snow bank, or neon pad. |
| **Zone** | An isolated slice of the world reserved for one player's run so runs cannot interfere. |

---

## Decision log

Each entry: the decision, the alternative that was rejected, and why. These are the decisions a
reviewer is most likely to want to relitigate.

**D1 — Grid stepping, not free movement.**
*Chosen:* discrete tile-to-tile steps with interpolation. *Rejected:* analog steering.
*Why:* the genre's tension comes from committed moves — you cross a lane and you are exposed until
the step resolves. Analog movement makes hazard prediction mushy, makes the simulation
non-deterministic, and makes server validation of a client position nearly impossible on mobile
latency. Grid movement yields exact, testable fairness.

**D2 — Server-authoritative traffic, client-side prediction of the same deterministic simulation.**
*Chosen:* both sides run `TrafficSim` from the same seed and tick schedule; the server is the judge.
*Rejected:* server-streaming full vehicle snapshots only. *Why:* snapshots alone produce visible
rubber-banding on 150 ms mobile connections and make near-misses feel random. A shared deterministic
sim plus a small rewind window gives instant local feedback with server truth as the arbiter.

**D3 — Anchored vehicles moved by CFrame from a snapshot buffer, not physics.**
*Chosen:* vehicles are anchored; the server advances a pure-data simulation; clients interpolate.
*Rejected:* unanchored parts with velocity. *Why:* physics replication on 40 vehicles × 8 zones is
expensive on low-end mobile, nondeterministic, and can produce tunnelling at high speed. Pure data
simulation is cheap, exact, and testable in isolation.

**D4 — One zone per player, laid out on a shared world grid.**
*Chosen:* each player gets an isolated 26 × N strip, zones spaced 400 studs apart.
*Rejected:* one shared endless world for everyone. *Why:* interference between players breaks the
fairness guarantee, and a shared world makes per-player difficulty scaling impossible. Isolation
keeps the social lobby (you see every player's animal and cosmetics) without letting anyone ruin
someone else's run.

**D5 — Animals are cosmetic-only in competitive play.**
*Chosen:* no animal changes speed, hitbox, or reward rate in a ranked context. *Rejected:* per-animal
stats/perks. *Why:* leaderboards compare players across animals. A stat advantage converts collection
into a competitive necessity and pushes the game toward pay-to-win. Personality lives in animation,
sound, and a non-scored "Aura" VFX.

**D6 — Golden Acorns are earn-only. Never purchasable with Robux.**
*Chosen:* hard currency is a skill/commitment signal. *Rejected:* selling both currencies.
*Why:* the moment the premium currency is buyable, every item priced in it becomes a Robux item with
extra steps. Keeping it earn-only preserves a visible, honest skill ladder.

**D7 — No paid random rewards of any kind.**
*Chosen:* acorn-priced cosmetic "Caches" exist with published odds and a duplicate-protection
counter; nothing purchasable with Robux is randomised. *Rejected:* paid loot boxes. *Why:* minor
audience, platform policy direction, and reputational cost. Published-odds soft-currency caches keep
the collection thrill legal and legible.

**D8 — UI built declaratively in Luau, not as Studio-authored instances.**
*Chosen:* a component library constructs every screen at runtime from config + code.
*Rejected:* hand-placed GuiObjects saved in the place file. *Why:* hand-built UI is invisible to
version control, impossible to review, and duplicates logic per screen. Code-built UI gives one
source of truth for tokens and states, and makes the entire game reproducible from this repo.

**D9 — No external runtime packages (unless approved).**
*Chosen:* a small in-repo toolkit (`Signal`, `Logger`, `RateLimiter`, test kit) replaces common
community modules. *Rejected:* pulling ProfileService, Promise, Fusion, TestEZ at Phase 1.
*Why:* every runtime dependency is a supply-chain and maintenance liability inside Roblox where
package management is still fragile. The specific functionality we need from each is small and is
implemented deliberately, with tests. This is revisited in Phase 6 if the custom data layer proves
too costly to harden.

**D10 — Difficulty is time-based on lane index with a hard cap per world.**
*Chosen:* difficulty rises with rows crossed and clamps at that world's `RAMP_ROWS`.
*Rejected:* unbounded scaling. *Why:* an uncapped curve eventually generates impossible walls; the
cap guarantees that a world's late game is "hard forever", not "unfair at minute nine".

**D11 — Chunk generation is validated by simulation before it is allowed to ship to clients.**
*Chosen:* a ghost solver proves a survivable path exists for every chunk. *Rejected:* heuristic
spacing rules alone. *Why:* spacing rules are necessary but not sufficient — phase alignment across a
3-lane corridor can create a wall that satisfies per-lane gaps. Only a solver catches that.

**D12 — Landscape-first UI with portrait fallback for menus.**
*Chosen:* gameplay is landscape-only; lobby and menus reflow for portrait. *Rejected:* forcing
landscape everywhere. *Why:* Roblox mobile users do not rotate predictably, and a locked lobby is a
churn point. Gameplay genuinely needs the horizontal field of view.

---

## Open questions carried into Phase 2

Logged here so they are not lost. None block Phase 2.

1. **Monetization tuning** — pass prices are placeholders until the soft-launch cohort data exists.
2. **Expedition mode** (chaining worlds within one run) — designed in `01` §11 but deliberately
   deferred beyond Phase 10. It is additive and requires no core changes.
3. **Console badge set / achievements parity** — Roblox platform achievements are out of scope for
   v1; the in-game achievement system covers the intent.
4. **Voice/emote social layer** — emotes are in `01` §14; voice is explicitly out of scope.
5. **Custom server regions** — no action.
