# 03 — Current Project File Tree and Setup

This document describes the files that exist in this repository now. It is not a target tree for future phases. Planned systems that are not present are intentionally omitted; see `docs/08_MILESTONES.md` for future phase scope.

---

## 1. Repository tree

```text
fawn-rush/
├── .gitignore
├── .luaurc
├── CHANGELOG.md
├── README.md
├── default.project.json
├── selene.toml
├── stylua.toml
├── assets/
│   ├── manifest.json
│   ├── blender/
│   │   ├── README.md
│   │   ├── build_environment.py
│   │   ├── export_obj.py
│   │   └── lib/meshlib.py
│   └── export/_reference/
│       ├── REF_Box_4stud.obj
│       └── REF_Palette.mtl
├── docs/
│   ├── 00_INDEX.md
│   ├── 01_GAME_DESIGN_DOCUMENT.md
│   ├── 02_TECHNICAL_ARCHITECTURE.md
│   ├── 03_PROJECT_FILE_TREE.md
│   ├── 04_GAMEPLAY_MECHANICS_SPEC.md
│   ├── 05_UI_UX_SPECIFICATION.md
│   ├── 06_ASSET_PRODUCTION_PLAN.md
│   ├── 07_MONETIZATION_PLAN.md
│   ├── 08_MILESTONES.md
│   ├── 09_RISK_AND_TESTING_PLAN.md
│   ├── 10_REQUIREMENTS_REGISTER.md
│   ├── 11_PHASE2_VERIFICATION.md
│   └── 12_STUDIO_HANDOFF.md
└── src/
    ├── shared/
    │   ├── Animation/{AnimationLib,Animator}.luau
    │   ├── Builders/AnimalBuilder.luau
    │   ├── Config/{AnimalConfig,GameConfig,HazardConfig,UIConfig,WorldConfig}.luau
    │   ├── Constants/Net.luau
    │   ├── Net/Remotes.luau
    │   ├── Simulation/{ChunkFormat,ChunkGenerator,Combo,NearMiss,ObstacleSim,PresenceRules,SafePathValidator,Scoring,TrafficSim,WorldUnlock}.luau
    │   ├── Types/GameTypes.luau
    │   ├── Util/{GraphicsTier,GridMath,Logger,PreviewBudget,Rng,Signal}.luau
    │   └── World/{EnvironmentRig,WorldKit}.luau
    ├── server/
    │   ├── Bootstrap.server.luau
    │   ├── Builders/{LobbyBuilder,NameplateBuilder}.luau
    │   ├── Services/{ChunkService,EnvironmentService,PresenceService,RemoteGate,RunService,ServiceRegistry,ZoneService}.luau
    │   └── Tests/{Phase2Tests,Phase3Tests,Phase4Tests,Phase5Tests,TestHelpers,TestKit}.luau
    └── client/
        ├── Bootstrap.client.luau
        ├── Builders/VehiclePool.luau
        ├── Controllers/{AnimationController,CameraController,ControllerRegistry,EffectsController,EnvironmentController,InputController,MovementController,PresenceController,SessionController,TrafficRenderer,UIController,WorldEffectsController,WorldRenderer}.luau
        └── UI/
            ├── Components.luau
            ├── Theme.luau
            ├── ViewportPreview.luau
            └── Screens/{Collection,Customize,HUD,Lobby,Results,RunSelect,Settings,Shop}.luau
```

The compact brace notation above expands to the individual named `.luau` files shown in the repository. There is no root `tests/` directory, no `rokit.toml`, no `index.html`, and no `UIRoot.luau`.

---

## 2. Rojo mapping and runtime boundaries

`default.project.json` maps:

- `src/shared` to `ReplicatedStorage.Shared`.
- `src/server` to `ServerScriptService.Server`.
- `assets/manifest.json` to `ServerStorage.Manifest`.
- `src/client` to `StarterPlayer.StarterPlayerScripts.Client`.

It also disables automatic character loading and sets `Workspace.StreamingEnabled` to `false` and gravity to 140. The server creates RemoteEvents from `shared/Constants/Net.luau` through `shared/Net/Remotes.luau`; no remote instances are stored as binary assets.

The client boots controllers through `client/Bootstrap.client.luau` and `ControllerRegistry`. `SessionController` is the client boundary for run remotes; `UIController` constructs native Roblox UI from `client/UI` modules. The server boots services and binds client-originated remotes through `server/Bootstrap.server.luau` and `RemoteGate`. Run state and scoring remain server-authoritative.

Shared simulation and configuration modules supply deterministic traffic, chunks, safe-path checks, world profiles, animal data and the pure HUD layout helpers. `WorldKit` and `AnimalBuilder` create procedural geometry. There are no profile, inventory, currency, purchase, pause, reward or persistence services in the current source tree.

---

## 3. Phase 5 UI source map

- `shared/Config/UIConfig.luau` owns UI tokens, responsive scale, HUD rectangles, contrast checks and the protected-road-band helper.
- `shared/Util/PreviewBudget.luau` is the pure lease counter used by `client/UI/ViewportPreview.luau`.
- `client/UI/Theme.luau` exposes tokens, reduced-motion-aware tweens and session text scaling.
- `client/UI/Components.luau` provides native labels, panels, buttons, toggles, counters and touch-pad buttons.
- `client/UI/Screens/` contains the implemented lobby, world selection, catalogue, customization shell, shop shell, settings, HUD and results screens.
- `client/Controllers/UIController.luau` constructs and routes screens; `SessionController` owns run request/result correlation.
- `server/Tests/Phase5Tests.luau` is required by the Studio-only boot test sequence in `server/Bootstrap.server.luau`.

These are UI foundations, not account-backed features. The catalogue does not establish ownership or equipping; shop tabs do not offer or transact; settings are session-local. The Phase 5 tests exercise source helpers and configuration. Their HUD rectangles do not establish rendered Studio geometry.

---

## 4. Assets: actual status

The asset manifest and Blender scripts exist, but the repository contains only the OBJ/MTL reference files under `assets/export/_reference/`. It contains no generated `.blend` or `.fbx` deliverables, and no uploaded Roblox asset IDs are configured. Procedural Roblox parts remain the runtime art. The scripts have not been executed in this environment; no export or import result is claimed.

---

## 5. Windows and Studio setup

The full Windows setup and launch sequence is maintained in `README.md` and `docs/12_STUDIO_HANDOFF.md`. In brief:

1. Install Roblox Studio, Rojo 7.4 or newer, and the Rojo Studio plugin.
2. From the repository root, run `rojo serve` in PowerShell.
3. In Studio, create/open a Baseplate, connect the Rojo plugin, and confirm the mapped `ReplicatedStorage`, `ServerScriptService`, `ServerStorage` and `StarterPlayer` trees.
4. Press Play. The Studio-only test suites run when `RUN_TESTS_ON_BOOT` is enabled. Record the actual Output; the expected report shape is documented in `docs/11` and is not a prior test result.
5. Complete the gameplay, device, accessibility, navigation, multiplayer and visual checks in `docs/11` and `docs/12` before marking any requirement Studio-verified.

Rojo syncs source into Studio; the repository does not contain a saved place file. The test suites are written and wired but have not been executed. Phase 4 binary exports and subsequent platform integrations remain outstanding; no Studio visual verification, Blender export or runtime performance measurement has occurred.
