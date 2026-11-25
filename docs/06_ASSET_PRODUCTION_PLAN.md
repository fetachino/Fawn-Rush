# 06 — Asset Production Plan

Owner: Art Director / Animation & VFX / Sound. Covers geometry, rigs, animation, VFX, audio, and the
placeholder policy that governs Phases 2–4.

---

## 1. The honest position on assets

Two facts constrain this project and both are stated up front rather than discovered late.

**Fact 1 — Code can build geometry, but code cannot sculpt.** Phases 2–3 ship animals and vehicles
built from primitives in Luau (`AnimalBuilder`, `VehicleBuilder`), assembled into a proper rigged model
with correct proportions, joints, pivot points, and animation-ready structure. These are **temporary
assets** and are marked as such in the UI-free but visible-in-repo sense: every one of them carries a
`TEMPORARY` attribute and `AssetConfig` records `status = "procedural"`. They will look like a
well-built stylised toy, not like a Blender sculpt, and this document does not pretend otherwise.

**Fact 2 — Asset IDs cannot be invented.** Every asset that must be uploaded (meshes, textures, images,
audio) is referenced through a config module with an empty default. Nothing in the codebase contains a
fabricated `rbxassetid://` string. When an ID is missing, the consuming system degrades visibly and
logs once (`02` §14), and the outstanding-integrations checklist in the README keeps it visible.

What this means for delivery: the game is fully playable and testable with temporary geometry, and the
Blender pipeline below is the path that replaces it. Each replacement is a config change, not a code
change, because the rig interface is fixed (`§3.3`).

---

## 2. Asset inventory

Statuses: `PROC` = procedural temporary (Phase 3), `BLEND` = Blender-authored (Phase 4),
`UPLOAD` = needs a Roblox asset id.

### 2.1 Characters — 12 shipping animals + 1 secret

| Asset name | Species | Rarity | Tris (target) | Materials | Rig | Animations | Collision | Status |
|---|---|---|---|---|---|---|---|---|
| `CH_Deer` | Baby deer | Common | 2,400 | Palette atlas 1024² | 18-joint | Full set (10) | Box 2×3×2 | PROC → BLEND |
| `CH_Rabbit` | Rabbit | Common | 1,900 | 1024² | 18 | Full + long-ear chain | Box 1.6×2.6×1.6 | PROC → BLEND |
| `CH_Cat` | Cat | Common | 1,800 | 1024² | 18 | Full + tail curl | Box 1.8×2.6×1.8 | PROC → BLEND |
| `CH_Dog` | Dog | Common | 2,000 | 1024² | 18 | Full + wag | Box 2.0×2.9×2.0 | PROC → BLEND |
| `CH_Duck` | Duck | Uncommon | 1,600 | 1024² | 16 | Full + waddle | Box 1.6×2.4×1.6 | PROC → BLEND |
| `CH_Raccoon` | Raccoon | Uncommon | 2,100 | 1024² | 18 | Full + mask blink | Box 1.9×2.7×1.9 | PROC → BLEND |
| `CH_Fox` | Fox | Rare | 2,300 | 1024² | 18 | Full + tail flare | Box 1.9×2.8×1.9 | PROC → BLEND |
| `CH_Hedgehog` | Hedgehog | Rare | 2,200 | 1024² | 16 | Full + curl | Box 1.7×2.3×1.7 | PROC → BLEND |
| `CH_RedPanda` | Red panda | Epic | 2,500 | 1024² | 18 | Full + tail drape | Box 2.0×2.8×2.0 | PROC → BLEND |
| `CH_Otter` | Otter | Epic | 2,300 | 1024² | 18 | Full + slide | Box 2.1×2.6×2.1 | PROC → BLEND |
| `CH_WolfPup` | Wolf pup | Legendary | 2,600 | 1024² | 18 | Full + howl idle | Box 2.0×3.0×2.0 | PROC → BLEND |
| `CH_BearCub` | Bear cub | Mythic | 2,800 | 1024² | 18 | Full + heavy landing | Box 2.4×3.2×2.4 | PROC → BLEND |
| `CH_MoonlitFawn` | Moonlit fawn | Secret | 2,600 | 1024² + emissive | 18 | Full + glow pulse | Box 1.8×3.0×1.8 | PROC → BLEND |

Collision boxes are gameplay data, not art data: `04` §7.1 fixes them, and the art must fit *inside*
them. A model wider than its box is rejected at review.

### 2.2 Vehicles — 7 (plus modular livery variants)

| Asset name | Length | Half-width | Tris | Notes |
|---|---|---|---|---|
| `VH_Compact` | 2 tiles | 1.20 | 900 | Baseline silhouette |
| `VH_Sports` | 2 tiles | 1.15 | 1,100 | Lower stance, spoiler |
| `VH_Pickup` | 3 tiles | 1.35 | 1,000 | Open bed |
| `VH_Van` | 2.5 tiles | 1.25 | 1,050 | Box body, indicator lights |
| `VH_Bus` | 4 tiles | 1.40 | 1,300 | Window band, destination sign |
| `VH_Motorcycle` | 1 tile | 0.65 | 700 | Rider is a stub silhouette, not a character |
| `VH_Train` | 10 tiles | 1.60 | 1,800 | 3-car repeating segment, headlight bar |

Every vehicle: 4 wheel meshes reused from a shared wheel asset (`VH_Wheel_01`), headlight and taillight
`Attachment`s with fixed names, an indicator `Attachment` pair for vans, and a single body mesh with a
palette texture. Livery variants are texture swaps, not new meshes.

### 2.3 Environment

| Family | Assets | Tris each | Where |
|---|---|---|---|
| Trees | `ENV_Tree_Broadleaf_A/B`, `ENV_Tree_Pine_A/B`, `ENV_Tree_Dead_A` | 380–900 | W1, W4 |
| Bushes | `ENV_Bush_A/B/C`, `ENV_Hedge_01` | 120–260 | W1, W2 |
| Ground cover | `ENV_Grass_Clump_A/B`, `ENV_Flower_A/B/C` | 40–90 | W1 |
| Rocks | `ENV_Rock_A/B/C`, `ENV_Cliff_01` | 150–700 | All |
| Fungi | `ENV_Mushroom_A/B` | 60–120 | W1 |
| Water | `ENV_Pond_01`, `ENV_Stream_01` | 200 | W1, W4 |
| City | `ENV_Building_A–F`, `ENV_TrafficLight_01`, `ENV_StreetLight_01`, `ENV_Hydrant_01`, `ENV_Bench_01`, `ENV_Billboard_01` | 200–1,400 | W2 |
| Desert | `ENV_Cactus_A/B`, `ENV_Mesa_A/B`, `ENV_Tumbleweed_01`, `ENV_Bones_01` | 150–900 | W3 |
| Snow | `ENV_SnowPine_A/B`, `ENV_SnowBank_A/B`, `ENV_Icicle_01`, `ENV_IceSheet_01` | 120–600 | W4 |
| Neon | `ENV_NeonSign_A–D`, `ENV_HoloPylon_01`, `ENV_Cable_01` | 180–500 | W5 |
| Signs | `ENV_Sign_Wood_A/B`, `ENV_Sign_Road_A/B`, `ENV_Barrier_01`, `ENV_Cone_01` | 80–220 | All |
| Collectibles | `CL_Acorn`, `CL_Coin`, `CL_CactusNut`, `CL_IceGem`, `CL_Shard`, `CL_GoldenAcorn` | 120–260 | Per world |

### 2.4 Cosmetic attachments

10 slots × ~6 items = **~58 cosmetics** at launch. Each is a single mesh with an `Attachment` target
class (`Head`, `Neck`, `Spine`, `FootFL/FR/BL/BR`), a canonical scale, and a `fitsRig` tag list. Budget
150–700 tris each. Trail and aura cosmetics are VFX-only (no mesh).

### 2.5 UI assets

Icon set (SVG source → PNG export): play, pause, home, back, close, settings, shop, quests, trophy,
paw, lock, check, chevron, plus, minus, acorn, golden-acorn, car, train, warning, sound on/off, music,
sparkle, camera, rotate, filter, search, sort, gift, calendar, star, fire, snowflake, leaf, cactus,
neon, VIP crown, roblox-robux glyph (platform-owned, no redraw). ~38 icons, 128 × 128, exported at 1×
and 2×.

Also: 9-slice panel background (`ui.panel.9slice`), soft shadow (`ui.shadow.soft`), and 5 world card
backdrops.

### 2.6 VFX (no upload required)

All VFX are Roblox-native `ParticleEmitter`/`Beam`/`Trail`/`Highlight` configured in
`client/Effects/ParticlePresets.luau`. No textures beyond Roblox defaults unless `AssetConfig`
supplies a soft sprite, in which case it degrades to the default sparkle.

| Effect | Emitter count | Rate cap (low tier / high tier) |
|---|---|---|
| Acorn pickup burst | 1 local | 6 / 14 |
| Near-miss speed lines | 2 local | 8 / 20 |
| Dust trail (running) | 1 attached | 4 / 10 |
| Jump puff | 1 local | 8 / 16 |
| Death impact | 2 local | 10 / 24 |
| Level-up glow | 3 local | 12 / 30 |
| Unlock radial (per rarity) | 1 + 2 | 20 / 60 |
| Ambient — leaves / snow / dust / rain / neon motes | 1 zone-wide | 16 / 48 |
| Headlights (pooled, per vehicle) | 2 per vehicle | 0 / 2 |
| World transition sweep | 1 | 12 / 30 |

Hard rule: total concurrent emitters per zone ≤ 24 on `low`, ≤ 60 on `high`. `EffectsController`
enforces the budget and drops the lowest-priority effect rather than degrading framerate.

---

## 3. Rig specification

### 3.1 Approach

Rigid `MeshPart` segments joined with `Motor6D` — the same topology family as R15 — not a single
skinned mesh. Reasons: the Studio Animation Editor animates `Motor6D` rigs with no import risk, the
rig is inspectable and repairable in code, and per-limb procedural animation (which drives Phase 3–4
feel requirements) is trivial. A skinned upgrade is possible later behind the same interface; it is
not the launch plan.

### 3.2 Joint hierarchy (every animal)

```
HumanoidRootPart (Root)
└─ Torso
   ├─ Neck ── Head ── Ear_L ── Ear_L_Tip
   │                └─ Ear_R ── Ear_R_Tip
   │                └─ Eye_L, Eye_R, Jaw (attachments, not joints)
   ├─ Tail_01 ── Tail_02 ── Tail_03
   ├─ Hip_FL ── Knee_FL ── Foot_FL
   ├─ Hip_FR ── Knee_FR ── Foot_FR
   ├─ Hip_BL ── Knee_BL ── Foot_BL
   └─ Hip_BR ── Knee_BR ── Foot_BR
```

18 joints. Names are **fixed** — animation code addresses them by name, and a rig missing `Ear_L_Tip`
fails `AnimalBuilder:ValidateRig` loudly at build time rather than animating nothing.

### 3.3 The rig interface (the contract that makes assets swappable)

```lua
type AnimalRig = {
	Model: Model,
	Root: BasePart,
	Torso: BasePart,
	Joints: { [string]: Motor6D },
	Attachments: { [string]: Attachment },   -- "Head", "Neck", "Spine", "FootFL"...
	Palette: { Primary: Color3, Secondary: Color3, Accent: Color3 },
	Height: number,
	CollisionBox: Vector3,
	Source: "procedural" | "blender",
}
```

`AnimalBuilder` returns this shape whether it assembles primitives or a `MeshPart` set from
`AssetConfig`. Nothing downstream may branch on `Source` except the QA overlay and the "temporary art"
warning in Studio.

### 3.4 Proportions

Canonical animal height 3.0 studs (bear 3.2, hedgehog 2.3). Head is 1.4 studs tall and 1.3 wide for
the deer; ears extend to 3.9 total. All attachment points are authored against the canonical body and
scaled per species by a factor clamped to `[0.75, 1.30]` so cosmetics never float or sink.

---

## 4. Animation

### 4.1 The ten required states

Defined in `01` §6.2. Every animal must ship all ten. Shared locomotion is authored once on the deer
skeleton and retargeted with per-species amplitude overrides; the three "personality" states (happy,
death, victory) are authored per species.

### 4.2 Two-track delivery

- **Phase 3 (procedural):** animation is computed in `client/Controllers` from the state machine —
  sine-driven limb cycles, eased ear/tail chains, head look-at. This ships first because it is
  testable, versionable, and gives acceptable feel immediately.
- **Phase 4 (authored):** `KeyframeSequence`s authored in Studio's Animation Editor on the exported
  rigs, uploaded, ids recorded in `AssetConfig`. The animation controller prefers an authored track
  when an id exists and falls back to procedural otherwise — permanently, per state. That fallback is
  a feature: adding an animal never blocks on animation.

Blend rules: cross-fade 0.12 s between locomotion and idle; 0.06 s into `Frightened` (must feel
immediate) and 0.15 s out; death does not cross-fade (it hard-cuts from the frozen frame).

### 4.3 Animation budget

| Item | Count |
|---|---|
| Shared locomotion keys | 1 clip × 4 states |
| Per-species personality clips | 3 × 13 = 39 |
| Per-species locomotion overrides | 13 |
| Victory animation cosmetics | 6 |
| Lobby emotes | 4 |
| **Total uploaded keyframe sequences** | **~62** |

---

## 5. Blender pipeline

### 5.1 File layout

```
assets/blender/
  CH_Deer.blend          one file per character (or one file per family with a collection per species)
  VH_Vehicles.blend      one file, a collection per vehicle
  ENV_Props.blend        one file, a collection per prop family
  ENV_City.blend
  ENV_Desert.blend
  ENV_Snow.blend
  ENV_Neon.blend
  CO_Cosmetics.blend
  _reference.blend       the 4-stud cube, the person-sized reference, the palette swatch card
assets/export/           <AssetName>.fbx  +  <AssetName>.png (palette)
```

### 5.2 Rules

1. **Scale.** Author with 1 Blender unit = 1 stud, unit scale 1.0. The gating check: import
   `_reference.blend`'s 4-stud cube and confirm in Studio that it measures exactly 4.00 studs and
   matches one tile. If it does not, every asset is wrong — stop and fix scale before anything else.
2. **Orientation.** Character faces −Y in Blender so it faces −Z in Roblox after import with the
   Roblox importer's default axes. Vehicles face +X (they travel along X).
3. **Origin.** At the model's ground contact point, centred laterally. A misplaced origin shifts every
   joint offset.
4. **Naming.** `<prefix>_<Family>_<Variant>` where prefix ∈ `{CH, VH, ENV, CL, CO, UI}`. Object names
   must match the joint names in §3.2 exactly.
5. **Materials.** One material per asset using a palette texture (single 1024² atlas, 4–6 flat colour
   regions, no gradients, no baked lighting). Flat-shaded `SurfaceAppearance` only for mythic/legendary
   heroes. No normal maps in v1 — they cost memory and buy nothing at this stylisation.
6. **UVs.** Non-overlapping, 4 px padding between islands, packed by material region.
7. **Topology.** No interior faces, no n-gons above 4 sides, no loose vertices. Decimate to the tri
   budget; do not exceed it "because it looks better".
8. **No external IP.** Every shape is original. No franchise silhouettes, no real-world logos.
9. **LOD.** Animals and vehicles ship one LOD. Props get a decimated variant below 300 tris where the
   budget allows; `GraphicsTier` selects it.
10. **Collision.** Never authored per-face. `AnimalBuilder`/`VehicleBuilder` build the collision box
    from config data. Meshes are `CanCollide = false` everywhere; gameplay collision is AABB math
    (`04` §7).

### 5.3 Export

FBX 7.4 binary, `Y Up` off (Z up in Blender, importer converts), apply modifiers, include armature and
animations when present, `-Z forward / Y up` per the Roblox 3D Importer's defaults. Stationary assets
export as `.glb` where the importer handles it more predictably (props, collectibles).

### 5.4 Import and registration

1. Studio → 3D Importer → select `assets/export/<AssetName>.fbx`.
2. Set import scale so a known reference dimension matches (`§5.2.1`).
3. Confirm the resulting `MeshPart`'s size in the Properties panel against the target in §2.
4. Upload, copy the id.
5. Add it to `Shared/Config/AssetConfig.luau` **and** `assets/manifest.json`.
6. Re-run the config/asset validation suites (`09` §4, `AssetConfig.spec` and `AudioConfig.spec`)
   which assert every configured id is a number and every model referenced by config resolves.

### 5.5 Manifest format

`assets/manifest.json` — one entry per asset. This is the single registry the code reads to know what
exists.

```json
{
  "version": 1,
  "assets": [
    {
      "name": "CH_Deer",
      "kind": "character",
      "species": "deer",
      "sourceFile": "assets/blender/CH_Deer.blend",
      "exportFile": "assets/export/CH_Deer.fbx",
      "robloxId": "",
      "tris": 2380,
      "scaleStuds": { "x": 1.8, "y": 3.0, "z": 1.6 },
      "joints": ["Root","Torso","Neck","Head","Ear_L","Ear_L_Tip","Ear_R","Ear_R_Tip","Tail_01","Tail_02","Tail_03","Hip_FL","Knee_FL","Foot_FL","Hip_FR","Knee_FR","Foot_FR","Hip_BL","Knee_BL","Foot_BL","Hip_BR","Knee_BR","Foot_BR"],
      "attachments": ["Head","Neck","Spine","FootFL","FootFR","FootBL","FootBR"],
      "status": "procedural",
      "owner": "art"
    }
  ]
}
```

`status` transitions `procedural → exported → uploaded → verified`. Anything not `verified` at Phase 10
is listed in the release notes as temporary.

---

## 6. Visual direction reference

| World | Sky / fog | Ground | Lighting | Accent |
|---|---|---|---|---|
| Greenwood | Warm sky `#BFE3F2`, light haze | Mossy grass `#5C8A3C` | Sun 35°, soft shadows, dappled beam | Fireflies, sun shafts |
| City | Cool overcast `#C9D6E0` | Asphalt `#3A3F44`, concrete kerbs | Flat, harder shadows, shop glow | Taxi yellow, signage red |
| Desert | Bleached `#F6E3C0`, heat haze via `Atmosphere.Density` | Sand `#D9BC8A` | High sun, high contrast | Ochre rock, dust motes |
| Snow | Pale blue `#DCE8F2`, falling snow | Snow `#F2F6FA`, ice `#BEDCE8` | Low sun, blue shadows | Pine green, icicle glints |
| Neon | Near-black `#0B0A18` | Wet asphalt with reflection probes | Point lights, bloom (capped) | Magenta `#FF3FA4`, cyan `#35E0FF` |

Lighting rigs are built by `EnvironmentService` at boot from `WorldConfig` (`Atmosphere`,
`ColorCorrection`, `Bloom`, `SunRays`), scaled by `GraphicsTier`: bloom and sun rays are off on `low`,
halved on `medium`. Nothing is authored by hand in Studio because hand-tuned lighting is invisible to
version control.

---

## 7. Audio

### 7.1 Inventory (28 cues + 6 tracks)

| # | Cue | Duration | Notes |
|---|---|---|---|
| M1 | Lobby theme | 2:00 loop | Warm acoustic ensemble, 90 BPM |
| M2 | Greenwood | 2:10 loop | Guitar + pads, bird accents |
| M3 | City Chaos | 2:00 loop | Percussion, bass pulse |
| M4 | Desert Dash | 2:05 loop | Strings, frame drum |
| M5 | Snowy Summit | 2:20 loop | Piano, wind, soft bells |
| M6 | Neon Night | 2:00 loop | Synthwave, side-chain |
| S1 | Footstep (per species weight) | 0.12 | 3 random variants |
| S2 | Jump | 0.25 | |
| S3 | Land | 0.20 | |
| S4 | Acorn pickup | 0.20 | Pitch ladder per combo |
| S5 | Golden acorn pickup | 0.60 | Distinct, rare |
| S6 | Vehicle pass-by | 0.80 | 3 variants per vehicle class |
| S7 | Horn (distant car) | 0.60 | Lobby/ambient only |
| S8 | Train horn | 1.60 | Warning cue |
| S9 | Near miss | 0.30 | 3-semitone rise per combo tier |
| S10 | Impact / death | 0.90 | Ui impact + animal yelp |
| S11 | Stumble | 0.35 | |
| S12 | Level up | 1.40 | |
| S13 | Animal unlock — Common/Uncommon | 1.20 | |
| S14 | Animal unlock — Rare | 1.60 | |
| S15 | Animal unlock — Epic | 2.00 | |
| S16 | Animal unlock — Legendary | 2.60 | |
| S17 | Animal unlock — Mythic | 3.20 | |
| S18 | Animal unlock — Secret | 3.60 | |
| S19 | UI click | 0.08 | |
| S20 | UI hover | 0.06 | Pointer devices only |
| S21 | UI error | 0.25 | |
| S22 | Menu open | 0.14 | |
| S23 | Menu close | 0.12 | |
| S24 | Purchase success | 0.70 | |
| S25 | Achievement | 1.10 | |
| S26 | Mission complete | 1.00 | |
| S27 | Daily claim | 0.90 | |
| S28 | Ambient — wind / leaves / city hum / sand / neon buzz (5 files) | loop | Per world |

### 7.2 Placeholder policy

`AudioConfig` ships with **every id as `0`** and a `name` string per cue. `AudioController`:

```lua
function SfxDirector:Play(cueId)
	local assetId = AudioConfig.sfx[cueId].id
	if assetId == 0 then
		warnOnce("audio_missing:" .. cueId, ("[Audio] '%s' has no id configured; skipping."):format(cueId))
		return
	end
	...
end
```

The game is silent-but-functional until audio is configured, and the boot log prints
`[Audio] 0/34 ids configured`. There is no fabricated id and no substitute beep. Sourcing: original
recordings, commissioned stems, or Roblox Audio Library tracks with their licence terms recorded in
`assets/audio/LICENSES.md` (title, creator, source, licence, date). A cue without a recorded licence is
not shipped.

### 7.3 Mixing

Three buses (`Music`, `SFX`, `UI`) each 0–10 from settings, master mute. `MusicDirector` cross-fades
over 2.0 s and ducks music by 6 dB for 1.5 s on level-up and unlock reveals. `SfxDirector` applies a
per-cue cooldown (footsteps 0.08 s, pickups 0.03 s) so a burst of acorns does not produce 12
simultaneous samples — it produces a pitch-laddered sequence, which is better audio design anyway.

---

## 8. Cost and schedule sketch

| Workstream | Person-days | Phase |
|---|---|---|
| Procedural animal rig builder + 13 animals | 6 | 3 |
| Procedural vehicle builder + 7 vehicles | 3 | 3 |
| Procedural props (12 families) + 5 world builders | 10 | 4 |
| Blender: 13 animals (model, rig, UV, export) | 16 | 4 |
| Blender: 7 vehicles | 7 | 4 |
| Blender: environment props (~45 assets) | 14 | 4 |
| Animation authoring (10 states × 13 animals, retargeted) | 12 | 4–9 |
| ~58 cosmetics | 10 | 7 |
| UI icon set + 9-slice + shadows | 3 | 5 |
| VFX presets and tuning | 4 | 9 |
| Audio sourcing, editing, mixing | 8 | 9 |
| **Total art/audio** | **~93** | |

The procedural track (19 pd) is what makes Phases 2–4 deliverable before any Blender work lands, and
it is not wasted: the procedural rigs remain the fallback path for any future animal.

---

## 9. Temporary-asset disclosure

Every temporary asset is:

1. Attributable to `AnimalBuilder` / `VehicleBuilder` in the object's `Attributes` (`TEMPORARY = true`),
2. Listed in `assets/manifest.json` with `status: "procedural"`,
3. Shown with a small `PROVISIONAL` chip in the Collection detail sheet **in Studio only** (gated by
   `Studio` detection), so a reviewer never mistakes a primitive animal for finished art,
4. Named in the release notes at Phase 10 until replaced.

A procedural asset is never described as a finished model in any document, comment, or UI.
