# 05 — UI/UX Specification

Owner: Mobile UI/UX Designer. Implementation owner: `UIController`, `UI/*`.

The target is a UI that a 12-year-old can operate with a thumb, in landscape, on a 6-inch screen, in a
room with glare on the glass, while a bus is coming. Every rule below is in service of that.

**Implementation status (Phase 5 audit).** This document remains the design target, not a claim that all
screens or components exist. Current source has the lobby, world selection, HUD, results, catalogue/detail,
customization shell, shop shell and session-local settings. Pause, quests, rewards, leaderboard, events,
unlock reveal, account services and purchase/ownership flows are not connected. Code-level layout tests
are written but have not been executed; no screen has been Studio-verified.

---

## 1. Principles

1. **One primary action per screen.** It is always visually dominant (larger, brighter, higher
   contrast, positioned in the thumb arc). Everything else is secondary and visually quieter.
2. **No dead ends.** Every screen has a visible way back. Every locked feature states its unlock
   condition and where to work on it.
3. **Touch first.** Hover is an enhancement on pointers, never required. Minimum interactive target
   88 × 88 reference px. Press feedback begins on touch-down, not on release.
4. **Thumb-reachable.** Primary controls live in the bottom 40% of the screen or the right-hand arc.
5. **Readable at a glance.** Body text never below 14 reference px; contrast ≥ 4.5 : 1 for text,
   ≥ 3 : 1 for interactive borders.
6. **Motion explains, never decorates obscurely.** Every animation communicates a relationship
   (where a panel came from, what changed). Nothing loops in the player's field of view during a run.
7. **The road is sacred.** No HUD element may overlap the central play band (`§7.2`) or the row the
   player is about to enter.

---

## 2. Design tokens

`Shared/Config/UIConfig.luau` — the single source. Screens must never hard-code a colour, size, or
duration.

### 2.1 Colour

| Token | Hex | Use |
|---|---|---|
| `bg.deep` | `#0E1A14` | App background, scrim base |
| `bg.base` | `#16261D` | Screen background |
| `surface.1` | `#1F3327` | Cards, panels |
| `surface.2` | `#29412F` | Raised surface, default button |
| `surface.3` | `#34513B` | Hover / active surface |
| `line.soft` | `#3E5A46` | Dividers, 1 px borders |
| `ink.high` | `#FFF6E4` | Primary text |
| `ink.mid` | `#C9D6C4` | Secondary text |
| `ink.low` | `#8FA292` | Tertiary, disabled text |
| `brand.gold` | `#F2B33D` | Primary CTA, logo, acorn |
| `brand.moss` | `#4E7A3A` | Success surfaces, growth |
| `accent.sky` | `#7FC8F8` | Informational, links |
| `state.success` | `#57B85A` | Confirmations |
| `state.warn` | `#F2A33C` | Cautions |
| `state.danger` | `#BC3E2F` | Failure, destructive; darkened in `UIConfig` to meet the contrast lock |
| `gold.golden` | `#FFC93C` | Golden Acorn only |

Rarity palette and its shape rules are in `01` §9.2 and must be consumed through `RarityBadge`, never
inlined.

**Contrast locks** (asserted by a unit test over the token table):
`ink.high` on `bg.base` ≥ 7 : 1 · `ink.mid` on `surface.1` ≥ 4.5 : 1 · `brand.bark` on `brand.gold`
≥ 4.5 : 1 (that is the only legal text colour on gold) · `white` on `state.danger` ≥ 4.5 : 1.

### 2.2 Type

Font family: `Gotham` (`GothamBlack`, `GothamBold`, `GothamMedium`, `Gotham`), which is present on every
Roblox client — no upload, no licence issue. Sizes are reference px at a 720 px reference viewport
height; the root `UIScale` multiplies them.

| Token | Font | Size | Line height | Use |
|---|---|---|---|---|
| `type.display` | GothamBlack | 44 | 1.05 | Logo, results number |
| `type.h1` | GothamBlack | 30 | 1.1 | Screen titles |
| `type.h2` | GothamBold | 23 | 1.15 | Section headers, card titles |
| `type.h3` | GothamBold | 19 | 1.2 | List row titles |
| `type.body` | GothamMedium | 16 | 1.35 | Paragraphs, descriptions |
| `type.bodyStrong` | GothamBold | 16 | 1.35 | Emphasis |
| `type.small` | GothamMedium | 14 | 1.3 | Labels, captions |
| `type.tiny` | GothamMedium | 12 | 1.25 | Meta, chips (never for actions) |
| `type.number` | GothamBlack | 22 | 1.0 | Currency pills, counters |

Text is `TextTruncate = AtEnd` for names and `TextWrapped` for descriptions with `AutomaticSize` on
the Y axis. Never both in one label.

**Text scale setting.** Accessibility slider multiplies all `type` sizes by 0.9–1.4 and re-runs screen
layout. Layouts must therefore be `UIAspectRatioConstraint` / `UIGridLayout` / `AutomaticSize`-driven,
never absolute-pixel stacking.

### 2.3 Spacing, radius, elevation

| Token | Value |
|---|---|
| `space.1 … space.8` | 4, 8, 12, 16, 24, 32, 48, 64 |
| `radius.sm / md / lg / pill` | 8, 14, 22, 999 |
| `stroke.width` | 1 px (2 px for focused/selected) |
| `elev.1` | shadow offset 0, 2; blur 8; alpha 0.20 |
| `elev.2` | shadow offset 0, 6; blur 18; alpha 0.28 |
| `elev.3` | shadow offset 0, 12; blur 32; alpha 0.36 |

Roblox has no native drop shadow: `elev.*` is implemented as a duplicated `ImageLabel` with a soft
blur texture from `AssetConfig` (`ui.shadow.soft`). If the asset is unset, elevation degrades to a
1 px border — never to a missing panel.

### 2.4 Motion

| Token | Duration | Easing |
|---|---|---|
| `motion.instant` | 80 ms | Linear |
| `motion.fast` | 120 ms | Quad Out |
| `motion.base` | 180 ms | Quad Out |
| `motion.slow` | 280 ms | Quart Out |
| `motion.cinematic` | 420 ms | Sine InOut |
| `motion.press` | 70 ms in, 110 ms out | Back Out (2.2) |

The current screen transition foundation slides and scales content; it does not yet implement the specified
fade or modal/scrim behavior. Reduced motion skips screen transitions and makes `Theme.tween()` apply goals
immediately. Camera shake, near-miss/death flashes and pickup sparkles are suppressed when the session-local
setting is enabled. Ambient weather, character animation and all other motion are not comprehensively tied to
this setting and still require an accessibility review.

---

## 3. Layout system

### 3.1 Root

```
ScreenGui (IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder 10)
└─ SafeFrame            UIScale from viewport; padding = safe-area insets
   ├─ Layer.Background  (world blur / themed backdrop, non-interactive)
   ├─ Layer.Screen      (current screen)
   ├─ Layer.Overlay     (HUD, toasts, tooltips)
   └─ Layer.Modal       (scrim + modal, focus trap)
```

Current source uses `GuiService:GetGuiInset()` plus 12 px padding and scales the safe frame from the
actual viewport. Each implemented screen exposes a viewport layout API that `UIController` refreshes on
resize and text-scale changes; this is source reflow, not proof of rendered geometry. Additional device-cutout allowance is not
implemented or Studio-verified. Never place text within 16 px of the screen edge on mobile.

### 3.2 Breakpoints

| Class | Viewport height | Behaviour |
|---|---|---|
| `compact` | < 420 px | Single column, 2-across grids, HUD text reduced one step |
| `regular` | 420–719 px | Standard mobile layout |
| `expanded` | ≥ 720 px | Desktop/tablet: side rails, 4-across grids, hover enabled |

Portrait menu layouts are supported in source and every currently implemented screen reflows at viewport
changes. During a portrait run, a rotate-to-landscape hint occupies the top HUD band to the right of the
score row; its rectangle is part of `UIConfig.hudLayout()` and the existing geometry test checks its bounds,
protected-band placement and separation from score, combo and acorns. The touch camera FOV remains 70: reducing
it could narrow lateral hazard visibility, and no source-only change can establish equivalent sightlines
without Studio calibration. Rendered cutout/layout behavior and camera sightlines remain Studio checks.

### 3.3 Reusable layout primitives

`Panel`, `Row`, `Column`, `Spacer`, `Grid`, `ScrollList` — thin wrappers over `UIListLayout`,
`UIGridLayout`, `UIPadding`, `UIAspectRatioConstraint`. Screens are composed from these; a raw
`Frame` inside a screen file is a review flag.

---

## 4. Component library

Every component is a factory returning `{ instance, api }` where `api` exposes state changes, not raw
children. Screens never reach into a component's instance.

### 4.1 `Button` — the state machine

| State | Visual | Sound | Timing |
|---|---|---|---|
| Default | `surface.2` fill, `line.soft` 1 px, `ink.high` label | — | — |
| Hover (pointer only) | `surface.3`, scale 1.03, stroke `brand.gold` at 25% | `ui.hover` (soft, 6% vol) | 120 ms |
| Pressed | scale 0.96, fill darkened 8%, label unchanged | `ui.click` | 70 ms down / 110 ms up |
| Disabled | `surface.1` at 45%, `ink.low` label, no stroke | none | — |
| Loading | label stays, spinner at right, hit-blocked, `min 400 ms` | none | — |
| Success | stroke `state.success` 2 px + check glyph, 700 ms, then revert | `ui.success` | 180 ms in |
| Failure | shake ±4 px × 3 over 200 ms, stroke `state.danger` 800 ms, helper text below appears | `ui.error` | 200 ms |

Rules:
- A failure is **never silent**: if the server rejects an action, the button shows `Failure` and the
  reason appears in a `Toast` in the same frame. The current run-start flow instead shows a visible
  inline lobby status; the general toast system is not built.
- `Loading` is used for any action that crosses the network with > 150 ms expected latency (purchase,
  claim, equip). The current button state uses a text ellipsis, not a spinner or minimum display time.
- Disabled buttons carry a `reason` string surfaced by long-press (mobile) or hover (desktop); this is
  not implemented for every button.
- Touch feedback fires on `InputBegan`, so the visual response is immediate even on a slow frame.
- Source includes default/hover/pressed/disabled/loading/success/failure states. Run-start refusals and
  local request failures now set the failure state and retain a visible inline reason. The specified failure
  shake, sound, toast and demonstrated timings are not complete or Studio-verified.

### 4.2 The rest

| Component | Notes |
|---|---|
| `IconButton` | Square, 88 × 88 minimum, icon centred, optional badge dot |
| `Panel` | `surface.1`, `radius.md`, `elev.1`, optional header row with title + close |
| `Modal` | Scrim `#04100A` at 72%, panel `radius.lg`, focus trap, tap-outside dismiss for non-destructive only, swipe-down dismiss on mobile |
| `Toast` | Bottom-centre above the thumb zone, max 2 stacked, 2.4 s, colour-coded, queued |
| `Toggle` | Track 52 × 30, knob 26, 140 ms slide, optimistic with rollback on server reject |
| `Slider` | Track 6 px, knob 28 px (44 px hit area), tap-to-jump, value label right-aligned, snapping for volume (1) |
| `TabBar` | Underline indicator sliding 180 ms, `ink.mid` → `ink.high` on active |
| `ScrollList` | Virtualised: creates at most `visible + 3` rows; recycled on scroll; momentum preserved |
| `CurrencyPill` | Icon + count-up animation (400 ms) + green flash on gain, red on spend; tappable → shop |
| `ProgressBar` | Height 10/14/18; optional segmented ticks; label overlay optional |
| `RarityBadge` | Colour + shape + abbreviation; shape is the primary non-colour channel |
| `ViewportPreview` | Rotating model, drag to spin, inertia, hard cap of 4 live instances |
| `Tooltip` | Hover 400 ms delay on pointer; long-press 500 ms on touch |
| `EmptyState` | Illustration, heading, one-line reason, single action button |

---

## 5. Screen specifications

Notation: regions are listed top to bottom. "CTA" = the single primary action.

### 5.1 Home (lobby)

```
┌───────────────────────────────────────────────────────────────┐
│ [LV 12 ▰▰▰▰▱▱ 340/450]           [🅐 1,240] [🅖 7] [☰]        │  top bar
│                                                               │
│                    FAWN  RUSH                                 │  logo
│                 Every crossing is a new adventure.             │
│                                                               │
│            ┌───────────────────────────┐                      │
│            │   live animal in viewport │  ← tap: rotate/drag  │
│            │   name · rarity · title   │                      │
│            └───────────────────────────┘                      │
│                                                               │
│   [🐾 Animals] [🛍 Shop] [📋 Quests] [🏆 Ranks]               │  nav rail
│                                                               │
│        ┌──────────────────────────────────────┐               │
│        │            P L A Y                   │  ← CTA        │
│        └──────────────────────────────────────┘               │
│   [Daily ✓]        [Greenwood Crossing ▸]      [⚙]            │  thumb row
└───────────────────────────────────────────────────────────────┘
```

- Logo is a `TextLabel` in `type.display` with the gold token plus a subtle 4 s breathing glow
  (disabled under `reducedMotion`).
- The animal preview is a `ViewportPreview` of the equipped animal with its idle animation.
- PLAY opens `RunSelect` directly if more than one world is unlocked; otherwise it starts Greenwood
  immediately (one tap to play for a brand-new player — critical for the first-session funnel).
- The world chip under PLAY shows the last-played world with a chevron to change it.
- Notifications (unclaimed missions, level rewards, daily) appear as a dot on the relevant nav item and
  as a single combined `Toast` on entry, never as multiple modals.
- Top bar collapses to icons in `compact`.

### 5.2 Run Select

World cards in a horizontal carousel, one card visible per screen on phone. Each card: name, three
colour swatches of the world palette, difficulty dots (1–5), best row depth, unlock state. Locked cards
show the condition ("Reach level 12 · 3,000 lifetime rows") with a progress bar **and** the current
value. Selecting a card selects it; PLAY on the card starts the run. A "Practice" toggle sits above the
carousel once unlocked.

### 5.3 HUD (in run)

```
┌────────────────────────────────────────────────────────────────┐
│ ▲ 128 m      ▰▰▰▱ combo ×2.1        [⏸]                        │  top strip (48 px)
│                                     🅐 46                      │
│                                                                │
│                     · · · ROAD · · ·                          │  ← central band: EMPTY
│                                                                │
│                                                                │
│   ┌───┐   ┌───┐          MISSION: cross 30 rows   ┌───┐  ┌───┐ │
│   │ ◀ │   │ ▲ │                                   │ ▲ │  │ ▶ │ │  controls
│   └───┘   └───┘                                   └───┘  └───┘ │
│          ┌───┐                              ┌───┐            │
│          │ ◀ │   (D-pad, left-handed)       │ ▶ │            │
│          └───┘                              └───┘            │
└────────────────────────────────────────────────────────────────┘
```

- **Distance** top-left (`type.number`), world name beneath in `type.tiny`.
- **Combo** top-centre: a ring that drains over `COMBO_DECAY` with the multiplier inside. Empty ring =
  no combo; it never shows an empty ring when there is no combo, it fades out.
- **Acorns** top-right, animated on pickup.
- **Pause** top-right corner, 88 × 88, always in the same place. Opening pause is blocked while standing
  in a live lane (`02` §9) with the toast "Step to safety first".
- **Mission chip** top-centre-right, one active mission, thin progress bar, fades to 60% opacity after
  10 s of no progress.
- Mobile controls: a floating 4-way pad anchored bottom-left by default, **draggable** to either side
  and persisted per player. Swipe-anywhere also works and is the recommended input; the pad is the
  fallback for players who prefer buttons. Both are always live; a swipe does not require the pad.
- Jump: a circular 96 px button bottom-right, present only in worlds where jumping does something.
- The central band (from 22% to 78% of screen height) is reserved: **no persistent HUD may enter it.**
  `UIConfig.hudLayout()` supplies the same pixel rectangles used by HUD layout and code-level checks;
  these checks cover nine scenarios across eight viewport sizes, including safe insets, but remain
  unexecuted and do not replace Studio rendering review. There is no pause button/service in the current HUD.

### 5.4 Pause

Modal panel, not a full screen change (the run is still visible behind at 30% dim, so the player
retains context). Contents: Resume (CTA), current mission with progress, run stats so far, Settings,
Abandon Run (destructive, requires a confirm with the acorn total that will be kept stated explicitly).
No purchase surfaces in pause.

### 5.5 Results

```
┌──────────────────────────────────────────────────────────┐
│                    RUN OVER                              │
│                     128 m                                │
│              ▸ NEW PERSONAL BEST                         │  (conditional)
│                                                          │
│  Acorns earned        +96        ▮▮▮▮▮▮▮▮                 │
│  Best combo           ×2.6                               │
│  Near misses          11                                 │
│  XP                   +148  →  LV 12 ▰▰▰▰▱▱             │
│  Missions             1 complete  [Claim]                │
│                                                          │
│        ┌──────────────┐   ┌──────────────────┐           │
│        │   RETRY      │   │   TO LOBBY       │           │
│        └──────────────┘   └──────────────────┘           │
└──────────────────────────────────────────────────────────┘
```

This is an aspirational layout, not the current screen. The implemented Results screen shows the run-only
acorn tally; XP, mission claims and persistent account currency are not implemented.

- RETRY is the CTA and is reachable in under 2.5 s of total non-gameplay time from death.
- Rewards are itemised, never a single mystery number.
- Mission claim buttons appear inline so the player does not have to navigate to claim.
- The death cause is shown in words when it is instructive ("Hit by a bus on row 121"). It is never
  shown as a system error.
- If a revive is available and configured, it appears **between** the death animation and this screen as
  a separate, non-blocking offer with a clear "your combo is lost either way" line.

### 5.6 Collection

Search field, filter chips (rarity multi-select, Owned / Not owned), sort dropdown. Grid of cards:
preview thumbnail, name, `RarityBadge`, owned tick or lock. Tap opens a detail sheet: large
`ViewportPreview` (drag to spin), description, personality line, unlock method with progress, Equip /
Equipped / Locked-with-condition. Locked cards show a blurred silhouette plus the condition — never a
blank card.

### 5.7 Customise

Left: live full-body preview with the equipped set. Right: slot tabs (Hat, Face, Neck, Back, Feet,
Trail, Aura, Victory, Emote, Colour) and a grid of owned items for the slot. Items incompatible with
the current animal appear greyed with the reason ("doesn't fit long-eared animals"). Equip applies
instantly with a soft chime; unequip is a long-press or a clear "×" on the tile. Loadout chips (1–4)
at the bottom, with locked slots showing the pass name.

### 5.8 Shop

Three tabs: **Acorns**, **Golden**, **Robux**. Tiles show item, rarity, price, and owned state. Caches
are acorn-priced and their odds are visible via an "Odds" button opening a modal listing every
possible outcome and its probability — a legal and trust requirement, not a nicety. Robux tab lists
gamepasses and developer products with plain-language disclosure lines (`07` §6).

### 5.9 Quests

Tabs: Daily (3, each with progress bar, reward, and Claim button), Weekly (5), Achievements (6 category
sub-tabs). Claimed entries collapse to a checkmark row. A reroll button appears on the daily tab with
the remaining count.

### 5.10 Daily Rewards

Seven cards in a row (2 rows × 4 on `compact`), each with a day number, an icon, a value, and a state
(claimed / claimable / future). Claim is a single CTA. Copy explicitly says "Missed days don't reset
your progress." No countdown clock is displayed anywhere.

### 5.11 Leaderboard

Tabs: Global, Weekly, Friends, Personal. Rows: rank, name and nameplate colour chip, equipped animal
icon, rows, and (for the friends tab) online status. The player's own row is pinned and highlighted
even when it is far down the list. Weekly shows the reset time in plain words ("resets Monday").

### 5.12 Settings

Grouped: **Audio** (music, SFX, UI, mute), **Display** (graphics tier, reduced motion, camera shake),
**Accessibility** (text scale, high contrast, colour-blind rarity shapes always on), **Controls**
(layout side, D-pad scale, controller mapping, sensitivity for swipe), **Account** (privacy note, data
explanation link), **Credits**. Every control persists server-side and applies immediately.

### 5.13 Unlock Reveal

Full-screen modal. Sequence: dim to 35% → radial light → model scales 0.6→1.0 with `motion.cinematic`
→ particles at rarity tier → name typed in over 200 ms → rarity badge stamps in with a 1.15 scale bounce
→ description fades up → `Equip` (CTA) and `Continue`. Skippable by tapping after 0.8 s. Rarity drives
the whole sequence per `01` §9.2.

### 5.14 Error states

`ErrorModal` is used for load failure, save failure, and session refusal. It always contains: what
happened, what it means for their progress in plain words, and one action (Retry / Rejoin). It never
says "Error 503" alone.

---

## 6. Navigation map

```
Home ─┬─ RunSelect ──► HUD ──► (Pause is planned, not implemented) 
      │                 └────► Results ──► Retry (HUD) | Home
      ├─ Collection ──► DetailSheet ──► Equip
      ├─ Customise ──► SlotTab ──► ItemGrid ──► Equip
      ├─ Shop ──┬─ Acorns ──► ItemDetail ──► Confirm
      │         ├─ Golden
      │         └─ Robux ──► Confirm (platform dialog)
      ├─ Quests ──► Claim flow
      ├─ DailyRewards ──► Claim
      ├─ Leaderboard
      ├─ EventMenu
      └─ Settings
```

Back behaviour: hardware/gesture back pops the router stack; a second back from Home asks "Leave?"
(because Roblox's default leave is destructive to a session). Never traps the player.

---

## 7. Gameplay-specific UX

### 7.1 Input

| Device | Forward | Lateral | Jump | Pause |
|---|---|---|---|---|
| Keyboard | W / ↑ | A / ← , D / → | Space | Esc / P |
| Gamepad | Left stick ↑ / D-pad ↑ | ← → | A (Xbox) / ✕ (PS) | Start |
| Touch | Swipe up, or D-pad ↑ | Swipe left/right, or D-pad | Jump button (if relevant) | Pause chip |

Gamepad mapping is user-editable in Settings. Dead zone 0.35 with re-arm at 0.20 (prevents double
steps from a stick at neutral). Swipe threshold 28 px within 220 ms; a swipe shorter than the threshold
is discarded rather than fired as a half-step.

### 7.2 The protected band

Screen regions in the run:

- 0–22% — HUD strip (distance, combo, pause, acorns).
- 22–78% — **protected**: the road, the animal, and the oncoming lane. No persistent element.
- 78–100% — controls and one-shot toasts.

The Phase 5 code-level layout test consumes `UIConfig.hudLayout()` rectangles and checks the protected
band, screen bounds, touch-target sizes and portrait guidance clearance across the six original ratios plus
compact landscape (844×390), a portrait safe-inset case and a 320×400 compact portrait case. It is written,
not executed; actual device geometry remains unverified.

### 7.3 Tutorial

Not a separate scene. A first-run overlay that appears *inside* a normal Greenwood run, in three beats:
1. Row 0: "Swipe up to cross" with a bouncing arrow on the D-pad / a swipe ghost trail.
2. First corridor: the game pauses the traffic for 1.0 s and shows "Wait for a gap."
3. First acorn: a pickup plus "Acorns buy animals."

Each beat dismisses on the matching action, never on a timer. The tutorial traffic is the same
generator, only with `D = 0` for the first 3 chunks. After the first death the overlay never returns.

### 7.4 Feedback hierarchy in the run

Information must arrive without requiring a look away from the road:

| Event | Channels |
|---|---|
| Acorn pickup | sound (positioned), small burst at the tile, pill count-up |
| Near miss | whoosh, rim vignette, combo ring pulse, brief offset shake |
| Train warning | horn + rail shake + top-strip banner text "TRAIN" |
| Gust | wind whoosh + directional particle streak + banner |
| Stumble | thud, screen dip 0.4°, brief slow-motion 0.15 s |
| Death | impact freeze, desaturate, camera pull-back |
| Personal best live | subtle gold rim on the distance readout when passing the previous record |

---

## 8. Mobile specifics

- Landscape gameplay is recommended; portrait remains playable and shows a rotate-to-landscape hint in the top HUD band. The touch FOV remains 70 pending sightline calibration.
- `GuiService:GetGuiInset()` respected; content never under the Roblox topbar in source geometry. Cutout behavior still needs Studio review.
- Control pad draggable left/right, remembered per player, size adjustable (0.85–1.4).
- No double-tap-to-purchase anywhere; destructive or monetary actions always need a confirm.
- Scroll lists use `ScrollingDirection.Y` with `ElasticBehaviour` off; momentum is native.
- Avoid `TextScaled` on multi-line labels (it produces inconsistent sizes on Android); use explicit
  sizes with the text-scale setting.
- Keyboard opens for search only, never automatically.
- All modals dismissible with a 120 px downward swipe.

---

## 9. Accessibility

| Requirement | Implementation |
|---|---|
| Contrast | Token-level locks asserted by test (`§2.1`) |
| Colour independence | Rarity always carries a shape + abbreviation, not only hue |
| Motion | Session-local `reducedMotion` skips UI transitions, camera shake, near-miss/death flashes and pickup sparkles. Ambient weather and character animation remain in motion; full accessibility review is pending. |
| Text size | 0.9–1.4 multiplier, layouts reflow |
| Sound independence | Every critical audio cue has a visual twin (banner, icon, text) |
| Input | Every action available on keyboard, gamepad, and touch; one-hand play possible with the pad on either side |
| Timing | No reaction test requires more than one simultaneous input; step cooldown is forgiving |
| Photosensitivity | No full-screen flashes above 3 Hz; the gait of the withe/red palette is capped (`01` §17) |

---

## 10. Performance rules for UI

1. `ScrollList` virtualises; a screen may never instantiate more than ~40 GUI instances per visible
   row set.
2. `ViewportPreview` cap = 4 live model previews. Current source enforces a four-lease cap and releases
   models on hide; it does not cache/reuse models by animal id.
3. No per-frame Roblox property writes from UI. Counters update at most 10 Hz and only when the value
   changes.
4. No `TweenService` on the run's camera or on anything inside the protected band.
5. `ScreenGui.Enabled = false` for inactive screens rather than destroying and rebuilding them; but
   any screen holding a `ViewportFrame` releases it on hide.
6. Hit-testing: use a single full-screen input-capturing frame per modal, not overlapping invisible
   buttons.

---

## 11. Copy standards

- Sentence case for buttons and labels ("Equip", "Claim reward"), except the primary CTA which is
  uppercase and spaced ("P L A Y").
- Second person, present tense, no exclamation marks outside unlock celebrations.
- Numbers: distance in metres (`128 m`), currency with thousands separators and `K`/`M` abbreviation
  above 10,000.
- Error copy states the cause and the next action. Never blame the player, never say "something went
  wrong".
- No dark-pattern copy: no "hurry", no "only left", no fake urgency.
