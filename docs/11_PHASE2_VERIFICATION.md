# 11 — Studio Integration Gate

**Purpose changed at Phase 3.** This is no longer a blocker in front of Phase 3. It is the **first
session on the Windows PC**, and it is where `Built` becomes `Verified`. Development continued past
this gate on purpose (see `docs/08` "Development posture"); the cost of that decision is paid here.

Run this in order the first time the project is opened in Studio. Then run it again before release
with the current build, not the Phase 2 build — the checklist below covers Phase 2 functionality and
must be extended with each later phase's additions (`docs/12` records what to add).

Owner: QA & Performance Engineer · Signed by: project owner

---

## 0. Preconditions

| # | Check | Done |
|---|---|---|
| P1 | Rojo 7.4+ on PATH (`rojo --version`) | [ ] |
| P2 | Rojo Studio plugin installed and Studio restarted | [ ] |
| P3 | `rojo serve` running in the project folder | [ ] |
| P4 | Studio connected; `ReplicatedStorage.Shared`, `ServerScriptService.Server`, `StarterPlayerScripts.Client` all present | [ ] |
| P5 | Output window cleared before pressing Play | [ ] |

If P1–P4 fail, stop: this is a setup problem, not a code problem.

---

## 1. Gate A — automated suite

Press Play. With `RUN_TESTS_ON_BOOT` enabled, the server runs Phase 2, 3, 4 and 5 suites in order.

**Expected from source counts:** 16, 41, 30 and 12 `TestKit.it` cases respectively (99 total by the end
of Phase 5). These are written cases, not executed tests. `TestKit.report()` runs after each suite and
shares one counter, so an all-passing boot should report cumulative totals of 16/16, 57/57, 87/87 and
99/99. Record the actual Output verbatim; these expected totals are not a recorded result.

| # | Assertion group | Expected | Pass |
|---|---|---|---|
| A1 | Rng determinism — same seed | identical stream | [ ] |
| A2 | Rng determinism — different seeds | streams diverge | [ ] |
| A3 | Tile → world conversion | exact stud values | [ ] |
| A4 | Adjacency matches the direction table | forward/left/back targets correct | [ ] |
| A5 | Column and row bounds | col 8 valid, col 9 and row −1 rejected | [ ] |
| A6 | Score arithmetic | 100 / 105 / 0 | [ ] |
| A7 | Vehicle position is pure | two calls equal; starts off-screen, exits | [ ] |
| A8 | Overlap hits the right tile | hits col 0, misses col 5 and the next row | [ ] |
| A9 | Tile safety covers the margin | about-to-hit false, long-before true | [ ] |
| A10 | **Solid wall is rejected** | `false` | [ ] |
| A11 | Wide gap in the same lane is accepted | `true` | [ ] |
| A12 | 50 chunks all validated | 0 unvalidated | [ ] |
| A13 | Headway never below the floor | 0 violations | [ ] |
| A14 | No corridor over 3 lanes | 0 violations | [ ] |
| A15 | Chunks start and end on a median | 0 violations | [ ] |
| A16 | Same seed → same chunk | identical rows/lanes | [ ] |

Also record: `generated 50 chunks in ___ ms (___ needed a retry)`.

**Gate A fails if** any assertion fails, or generation takes longer than ~2 s for 50 chunks
(that would mean the solver is too slow to run during play).

---

## 2. Gate B — manual gameplay checklist

Do these in one Play session unless stated. Mark F (fail) with a one-line note.

| # | Step | Expected | P/F | Note |
|---|---|---|---|---|
| B1 | Boot | Lobby: deer on a path, FAWN RUSH sign, trees, start line. Output shows `Fawn Rush server ready` | [ ] | |
| B2 | Camera framing | Deer centred, low, road ahead visible; no clipping through ground or trees | [ ] | |
| B3 | Press `W` | Deer turns away, moves forward, camera follows without snapping | [ ] | |
| B4 | Press `PLAY` | Cuts to the road strip; distance `0 m`; HUD visible; lobby hidden | [ ] | |
| B5 | Hold `W` | Continuous run, ~9–10 steps/s, no stutter between steps | [ ] | |
| B6 | Tap `D` twice quickly | Both steps register (buffer works) | [ ] | |
| B7 | Hold `A` into the edge | Stops at column −8 without error or drift | [ ] | |
| B8 | Observe traffic | Four distinct vehicle shapes; sports cars visibly faster than trucks; both directions | [ ] | |
| B9 | Walk into a car | Freeze, then results card; cause reads "Hit by a car" | [ ] | |
| B10 | Press `RETRY` | New run immediately at `0 m` with fresh traffic; no leftover vehicles from the last run | [ ] | |
| B11 | Step onto an acorn | Model disappears; current-run tally +1 (grass) or +3 (road); no account balance changes | [ ] | |
| B12 | Run 100+ m | Road extends ahead with no gaps; old rows recycle; FPS stays stable | [ ] | |
| B13 | Die 10 times intentionally | Every death looks avoidable in hindsight; no wall of traffic with zero gap | [ ] | |
| B14 | Press `LOBBY` from results | Camera returns to the forest; PLAY available again; run world cleared | [ ] | |
| B15 | Whole session (10 min) | No red errors in Output beyond the expected camera warnings (§5) | [ ] | |

---

## 3. Gate C — devices, inputs, multiplayer

| # | Scenario | How | Expected | P/F |
|---|---|---|---|---|
| C1 | Touch controls | Test → Emulation → iPhone 14, play | D-pad bottom-left; swipe also steps; buttons depress visibly | [ ] |
| C2 | Touch layout | Same | No HUD element covers the deer or the road ahead | [ ] |
| C3 | Keyboard | Desktop | WASD and arrows both work; no key repeat stutter | [ ] |
| C4 | Gamepad | Plug in a controller, play | D-pad and left stick both step; no double steps at neutral | [ ] |
| C5 | Two players and lobby presence | Test → Clients and Servers → 2 Players | Both players and nameplates appear in the lobby; each hides while that player runs; separate strips, no shared traffic or interference | [ ] |
| C6 | Player 2 leaves mid-run | Close one client | Server does not error; the other player is unaffected | [ ] |
| C7 | Low-tier emulation | Studio → emulation → slower device | 30 FPS or better in a run | [ ] |
| C8 | Compact landscape HUD | Emulate 844×390 with touch enabled | HUD and touch controls remain within the viewport and outside the 22–78% protected road band | [ ] |
| C9 | Insets and portrait layout | Emulate a notched portrait device | Reported insets are respected; rotate hint stays in the top band, clear of score/combo/acorns; no clipped HUD or overlapping menu header. Touch FOV remains 70 pending sightline review | [ ] |
| C10 | Menu navigation and focus | Use touch and a connected gamepad through each implemented menu | Every implemented route works; initial gamepad focus is visible; Back returns home | [ ] |
| C11 | Collection preview lifecycle | Open/close several species details and navigate away | Preview rotates; live count stays ≤4 and leases release on close, hide or removal | [ ] |
| C12 | Honest empty states | Open Collection, Customise and Shop | No ownership, offer, purchase or persistence is implied; selected shop tab remains on revisit | [ ] |
| C13 | Run-start response | Start a run; test refusal and a non-responsive start | Server acceptance waits for course initialization; refusal/timeout is visible and retry is possible | [ ] |
| C14 | Session accessibility controls | Toggle reduced motion and text scale, then revisit Settings | UI transitions, camera shake, direct flashes and pickup sparkles are suppressed; text scaling applies for this session only. Ambient/character motion still needs accessibility review | [ ] |
| C15 | Responsive screen reflow | Resize between compact portrait, compact landscape and expanded; visit every implemented screen | Layout APIs refresh; catalogue columns and content remain inside the safe frame; rendered behavior is recorded, not inferred from source | [ ] |

---

## 4. Gate D — defect log

Every failure above becomes a row. Severity per `docs/09` §7.

| ID | Severity | Area | Reproduction | Status |
|---|---|---|---|---|
| — | — | — | — | — |

**Exit rule:** zero open S1 (crash, data loss, currency exploit) and zero open S2 (progression
blocked, purchase fails, movement unresponsive). Any S3/S4 left open needs a documented disposition and
owner; it must not be represented as fixed or verified. Release readiness is decided at the Phase 10 gate.

---

## 5. Expected noise (not defects)

These are known and must not be logged as bugs:

- Output warnings from Roblox's default `PlayerModule` about a missing character. The game runs with
  `CharacterAutoLoads = false` and a scriptable camera; the warnings are harmless.
- Acorns do not explode into particles on pickup. There is no VFX system until Phase 9 (`docs/10` B12).
- No sound at all. Audio is Phase 9.
- Score is `rows × 10 + acorn value` and is not yet tuned (README known issue 7).

---

## 6. Sign-off

| Field | Value |
|---|---|
| Date | |
| Studio version | |
| Device / emulation | |
| Gate A result | |
| Gate B failures | |
| Gate C failures | |
| Open S1 / S2 | |
| Verdict | **PASS / PASS WITH CONDITIONS / FAIL** |

**If FAIL:** record it, fix it, re-run. A failure here does not stop development — it is added to
`docs/12_STUDIO_HANDOFF.md` as an open defect and worked alongside whatever phase is current.

**If PASS:** the integration gate is signed. Update `docs/10` §7 with every item this run proved, then
continue the phase in progress. The first three actions after a passing gate are:

1. Move each `Built` item the run proved to `Verified` in `docs/10`, with the evidence recorded.
2. Commit the signed gate with the defect log.
3. Re-run the gate after the next phase adds visible functionality — it is a rolling checklist, not a
   one-time formality.



