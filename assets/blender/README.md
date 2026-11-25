# Fawn Rush — Blender asset pipeline

Everything the five worlds draw is **procedurally generated in Luau from primitives**
(`src/shared/World/WorldKit.luau`). That is deliberate for Phase 4: it is deterministic, costs no
upload, and keeps the repository portable. It is also **temporary** — doc `06` §9 says so, and the
manifest marks every prop `procedural`.

This folder is how those primitives become real meshes.

---

## What is here, and what is not

| Path | What it is | Runs where |
|---|---|---|
| `lib/meshlib.py` | Primitive geometry, material table, and the asset definitions both exporters share | Any Python 3 |
| `export_obj.py` | Writes `.obj` + `.mtl` per asset | **Any Python 3** — no Blender needed |
| `build_environment.py` | Builds the same assets as real Blender objects, materials, LODs, and exports `.fbx` | **Blender** (headless or GUI) |
| `../../export/_reference/REF_Box_4stud.obj` | The scale gate from `06` §5.2.1, committed as a real file | — |

**No `.blend` or `.fbx` binary is committed.** The development environment has no Blender and no
Python runtime, so those files cannot be produced here. Saying otherwise would be a fabrication.
The two commands below produce them.

---

## Using it

### 1. The free path (no Blender)

```bash
python3 assets/blender/export_obj.py --out assets/export
```

Produces `ENV_Tree_Broadleaf_A.obj`, `ENV_Rock_A.obj`, `ENV_Cactus_A.obj`, `ENV_Building_A.obj`,
`ENV_NeonTower_A.obj` and a shared `ENV_Palette.mtl`. Importable into Roblox Studio's 3D Importer
or into Blender.

`meshlib.ASSETS` currently defines **8** assets: `ENV_Tree_Broadleaf_A`, `ENV_Rock_A`,
`ENV_Mushroom_A`, `ENV_Building_A`, `ENV_Cactus_A`, `ENV_Mesa_A`, `ENV_Tree_Pine_A`,
`ENV_NeonTower_A`.

### What each export preserves

| Property | `.obj` path | `.fbx` path |
|---|---|---|
| Scale | Yes — 1 unit = 1 stud, verified by the reference cube | Yes |
| Orientation | Yes — Y up, matching the importer's default | Yes — exported `-Z` forward / `Y` up |
| Origin | Yes — ground contact, centred | Yes |
| Object name | Yes (`o <name>`) | Yes |
| Materials | As `MTL` references; **whether Studio honours them is unverified** | Yes, as material slots with per-face indices |
| Normals / UVs | Not written; both Blender and Studio compute normals. No UVs, because this pipeline is flat palette colour, not textured | Yes |
| LOD | No | Yes — `<name>_LOD1` built by a decimate modifier |

The FBX path is the authoritative one for anything multi-material. The OBJ path is the fast,
dependency-free preview.

### 2. The full path (Blender)

```bash
blender --background --python assets/blender/build_environment.py -- --out assets/export
```

Opens a clean scene, builds every asset as named objects with palette materials, applies the
`Decimate` LOD pass, and writes `assets/export/<AssetName>.fbx` plus one `.blend` per family.

---

## Conventions every asset follows

Straight from `06` §5.2, and enforced by `meshlib.validate()`:

| Rule | Value | Why |
|---|---|---|
| Scale | 1 Blender unit = 1 stud, unit scale 1.0 | A 4-stud tile must import as exactly 4 studs |
| Ground | Origin at ground contact, centred laterally | A misplaced origin shifts every placement |
| Forward | Scenery faces −Y in Blender so it faces −Z in Roblox | Matches the 3D Importer defaults |
| Materials | One palette material per asset, flat colours | Cheaper than textures at this stylisation |
| Topology | Quads and triangles only, no interior faces | Import safety |
| Collision | None authored | Gameplay collision is AABB maths on the server (`04` §7) |
| Naming | `<AssetName>` matching `assets/manifest.json` | The manifest is the registry |

---

## Importing back into the game

1. Studio → **3D Importer** → select `assets/export/<AssetName>.fbx`.
2. Set import scale so the reference cube measures 4.00 studs. If it does not, stop — every asset
   will be wrong.
3. Confirm the resulting `MeshPart` size against `06` §2.3.
4. Upload, copy the id.
5. Paste the id into `assets/manifest.json`, change `status` to `uploaded`, and fill `robloxId`.
6. Add a `AssetConfig` entry when Phase 5 introduces one; until then `WorldKit` is the only consumer.

A prop whose manifest entry is missing is a test failure, not a silent fallback: the Phase 4 suite
asserts every `WorldConfig` prop kind has a `environment.byKind` entry.

---

## Replacing a procedural builder

`WorldKit` exists so this is a one-file change:

1. Add a `MeshId` path in a future `AssetConfig` keyed by the same prop kind name.
2. In `WorldKit.prop`, prefer the mesh when an id is configured and fall back to the builder when it
   is not. No world config, renderer, or test changes.

That fallback is why `status: procedural` is not a problem to be hidden — it is the designed
degradation path until real art exists.
