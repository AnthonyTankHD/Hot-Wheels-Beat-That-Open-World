# Game Plan — Hot Wheels Beat That: Open World City

## Vision

Hot Wheels: Beat That! (2007, Eutechnyx) rebuilt as an open-world Hot
Wheels city. A little Hot Wheels car driving through a full city built
for it — streets, skyscrapers, ramps off rooftops, loops, jumps, boost
pads, neighborhoods to explore. Free roam, no track walls.

Tied into the Hot Wheels Hunt Book Android app: cars unlocked in the
city sync to the Hunt Book collection, points and badges flow both ways.
The app is the hub, the game is the playground.

Open source (MIT) and customizable. A built-in mod manager to browse,
download, and enable community-made mods.

## Engine and platforms

- **Engine: Godot 4.3** (open source, MIT). Chosen 2026-11-15.
- **Platforms:** native on Steam Deck / SteamOS, other Linux distros,
  Windows, and Mac — all up to date, same game, same build.
- **Controllers:** full support for XInput (Xbox) and PlayStation
  controllers, with haptic feedback (rumble) — e.g. on boost pads,
  landings, and hard steering at speed.
- **Controls:** W/S or RT/LT = gas/brake, A/D or left stick / D-pad =
  steer, right thumbstick = camera (orbit + zoom), Space / A = handbrake,
  R / right-stick press = reset, V / Y = switch camera, Esc / Back =
  pause menu. No C-button camera.
- The project lives in `src/godot/` (`project.godot`, `scenes/`,
  `scripts/`). First playable prototype: a driving scene in an open
  Hot Wheels city with all 30 Beat That cars to pick from.

## Driving mechanics — M.A.V.S.

The car now runs on the **MAdvanced Vehicle System (M.A.V.S.)** by
Millu30 (MIT, https://godotengine.org/asset-library/asset/3697),
integrated 2026-11-15. It replaces the custom arcade controller from
the Toy Box rebuild with real vehicle physics: `VehicleBody3D` +
4 `VehicleWheel3D`, automatic 5-speed gearbox, grip / drift /
burnout, headlights + brake lights, engine + tyre sounds, tyre-smoke
particles, a chase camera with right-stick orbit, and a minimap.

- The car is `scripts/mavs_car.gd` (extends the addon's `MVehicle3D`).
  `apply_car()` maps each car's top speed / accel / color onto the
  M.A.V.S. drivetrain; `boost()` is what the boost pads call.
- M.A.V.S. force numbers are tuned for a ~1 kg car, so the drivetrain
  is scaled up (mass 1000 kg, differential x20) and the addon has no
  top-speed cap of its own — `mavs_car.gd` caps speed per car and
  scales reverse, and sets stronger braking (the addon's brake value
  barely slows a 1000 kg car). Measured headless: 0 to top speed
  (~29 u/s for Bone Shaker) in ~8 s, gears shifting 1-4, stop from
  top speed in ~1.5 s, reverse engages and backs up cleanly.
- Godot 4.3 compatibility: the addon targets 4.5/4.6 but loads and
  runs on 4.3. Fixes needed: the addon ships format=4 example scenes
  (removed — only the two format=3 scenes the controller needs are
  kept), stale UIDs in its scene files (removed), and it must run on
  the Jolt physics engine (set in `project.godot`).
- The per-car top speed / accel still come from `data/cars.gd`
  (24-32 u/s, derived from the car names — the real SCR stats are
  shared across all cars).
- **Real models are in** (2026-11-15): all 30 cars converted from the
  game's ArcBank v5 files to glTF (`src/godot/models/`, 94 MB) and
  wired into the car — the box-built placeholders are gone. Each model
  is auto-fitted at load: physics wheel radius/position, collision
  box, headlights, brake lights, hood camera and tyre smoke all follow
  the model's own geometry, and the real wheel meshes are reparented
  onto the physics wheels so they steer and spin. The models carry
  their own textures, so the M.A.V.S. colour tint stays off.
  Converter quirk: the `.glb` files carry a -90° X rotation on the
  Body node (the converter's node matrix carries R while the vertices
  are already Y-up), so `mavs_car.gd` counter-rotates the model root
  +90° on X at load — without it the car renders standing on its nose.
  Ride-height fix: the car settled ~0.2 too high (suspension resting
  at max droop, model wheels floating), so the physics suspension
  rest length is 0.05 (`SUSP_REST_LENGTH` in `mavs_car.gd`) while the
  visual wheel offset stays 0.2 (`WHEEL_REST`) — the car now settles
  at y≈1.0 with the model tyres on the ground. Verified headless
  2026-11-16: all 30 cars load with correct orientation and 4 real
  wheels each (0 fails), Bone Shaker drives 0→23 u/s, gears shift,
  pause/resume works. Windows build with real models: 149 MB ZIP.
- **Pause menu** (2026-11-15): Esc / Back opens a pause menu
  (`scripts/pause_menu.gd`) with Resume, Settings, Change Car and
  Quit to Menu. Settings: camera sensitivity slider, invert-camera-Y
  toggle, master + engine volume sliders, and keyboard rebinding for
  every driving action (click a key, press the new one; gamepad
  bindings shown read-only). Settings persist in `user://settings.cfg`
  (`scripts/settings.gd`); the game actually pauses while the menu is
  open (`get_tree().paused`). Verified headless: pause freezes the
  car (position moved 0.0), settings apply immediately and save.
- **Wheels, camera, car select fixes** (2026-11-16, from Anthony's
  playtest video): the wheels looked like flat grey discs and did not
  appear to spin, and the camera was so close the car filled the
  screen. Root causes: the chrome rim material (metallic 0.9) has
  nothing to reflect in the Compatibility renderer, so it rendered
  flat grey; the chase camera sat only ~4.6 units behind the car.
  Fixes: wheel chrome is tamed at load (`tame_chrome` in
  `mavs_car.gd` — metallic 0.45, roughness 0.35, per-mesh duplicate
  so the body's chrome is untouched), so the rims read as bright
  silver with a dark tyre ring; the chase camera now sits ~8-10
  units back (spring length 8.0 + per-car length, in both
  `apply_settings()` and the Cam_Holder camera-switch defaults), so
  the whole car is visible. The wheel spin itself was verified
  working headless (spinner rotation 0→115 rad over 5 s of driving,
  RPM positive forward, correct direction) — it only *looked* static
  because the flat grey disc had no readable features. Also new:
  **car select inside the pause menu** — CHANGE CAR opens a list of
  all 30 cars right in the pause menu and swaps the car in where
  you are (no reload, HUD name updates); and the **car select
  screen now shows a live 3D preview** of the highlighted car (the
  real .glb, slowly turning on a turntable, chrome tamed the same
  way). Verified headless: all 30 cars pass wheel-radius / chrome /
  camera checks (0 fails), pause-menu car swap works, preview loads
  all 30 models (0 fails). Windows build: 150 MB ZIP.
- **Full conflict check + real wheel fix** (2026-11-16, after Anthony
  said "yup same thing" on the 150 MB build): the chrome tame was
  real but was NOT the cause — three deeper bugs were hiding under
  it, all in `mavs_car.gd` / the physics setup:
  1. **Wheels at the wrong place.** The physics engine (Jolt)
     captures each `VehicleWheel3D` rest transform when the wheel is
     added to the tree (in `_build_wheels`, at the defaults
     x=±0.95, z=±1.3) and writes it back every frame, so
     `_fit_model`'s fitted positions (e.g. 16 Angels x=±1.19,
     z=±2.50) were silently ignored. The visual wheels sat bunched
     toward the middle of the car, tucked under the body, instead of
     at the model's own wheel wells. Fix: after fitting, each wheel
     is removed and re-added to the tree so the physics re-registers
     it with the fitted transform (verified: frame-60 positions now
     stay fitted, only tiny suspension travel on Y).
  2. **Wheels did not spin.** The manual spinner rotation
     (`spinner.rotation.x += rpm * ...`) accumulated (0→63 rad over
     3 s) but the mesh never moved: the physics engine already spins
     each `VehicleWheel3D` node around its axle, and the wheel node's
     basis carries a mirror (determinant -1), so the two equal
     rotations cancelled instead of adding (proven by a basis probe:
     wheel basis and spinner basis both rotated ~32°, mesh global
     basis did not move). Fix: the manual spin code is removed — the
     physics spin now shows (mesh global basis rotates ~32° over
     3 s). The spinners stay as the reparenting targets; they just
     don't rotate.
  3. **Ride height: tyres sunk ~0.28 into the ground.** The car
     settled at y≈0.72 with the old suspension rest length (0.05).
     Fix: `SUSP_REST_LENGTH` 0.05 → 0.30 (swept headless; rest length
     and settle height move ~1:1), car now settles at y≈0.98 with
     tyre bottoms ~0.48, just touching the ground top (0.5).
     `CONTACT_Y` also moved -0.52 → -0.45. The old comment claiming
     "rest 0.05 settles the car at y≈1.00" was wrong and is corrected.
  Other conflicts found and fixed in the same pass: **Shift Down and
  steer_left were both bound to KEY_A** (project.godot +
  `settings.gd` DEFAULT_KEYS) — Shift Down now uses KEY_E (E was
  unused; the gearbox is automatic so Shift Down is dormant, but the
  shared binding was a real latent conflict the rebind logic could
  never resolve). Checked and clean: no leftover references to the
  deleted `car.gd`; pause menu vs city input (city opens on Esc/Back
  via `_unhandled_input`, pause closes via `_input`, no double
  handling); settings applied once (load guard) and idempotent;
  car-swap frees the old model root AND the old wheel meshes in the
  spinners (no accumulation, verified: 1 mesh per spinner after two
  swaps); car-select preview has its own SubViewport camera and
  lighting, separate from the chase Cam_Holder; numpad Camera
  Up/Down/Left/Right are the addon's intentional keyboard camera
  tilt, not dead actions. Verified headless: import clean, all
  scripts `--check-only` pass, main + car_select run 180 frames with
  zero script errors, test_models (all 30 cars load, 0 fails; pause
  freeze + settings + resume; pause car swap), test_carselect (30/30
  previews, 0 fails), test_drive / test_brake / test_coast /
  test_vehicle all clean. Windows build: re-exported (see below).
- **Wheel placement: off the axle** (2026-11-16, after Anthony
  playtested the 149 MB build and said the wheels were "out of place
  of the axel" — real wheels and spinning were fixed, but the front
  wheel hung ahead of the nose and the far-side front wheel looked
  like it floated above the hood). Two root causes, both in
  `mavs_car.gd`:
  1. **The physics overwrites the wheel node position every step.**
     An isolated headless test proved it: a bare VehicleBody3D +
     one VehicleWheel3D set to (0.95, 0.391, 1.3) read back
     (0.95, 0.171, 1.3) by frame 300 — Godot/Jolt writes the
     simulated wheel centre into the node every step, so the set
     position is only the initial attach point. The old code hung
     the visual wheel 0.2 below that node on the spinner
     (`WHEEL_REST`), so the visual wheel ended up 0.256 below the
     model's axle and the tyre bottom sat ~0.23 under the ground.
     Fix: the spinner now sits exactly on the physics wheel node
     (position `Vector3.ZERO`), and the attach point is computed as
     `model_center_y + SUSP_REST_LENGTH - STATIC_SAG`, where
     `STATIC_SAG` is 0.041 (measured static suspension compression:
     Bone Shaker front 0.0406, rear 0.0415). `WHEEL_REST` is gone.
     Bone Shaker settle probe after the fix: visual wheel centre
     vs model axle error <= 0.001 on all four corners; car settles
     y≈0.925; tyre bottoms 0.47 (0.028 sink, as designed).
  2. **Repeated in-game car swaps progressively broke the
     suspension.** A 30-car probe showed cars sinking (car_y 0.93
     → 0.25) with the error growing by swap index; a diagnostic
     (reset-only x3 fine at 0.93, swaps degrading 0.93 → 0.85 over
     8 steps) proved swaps were the trigger, and a counterfactual
     with the wheel remove/add disabled stayed stable (1.16–1.41,
     no degradation). So Jolt never reliably unregisters /
     re-registers a re-added wheel — stale registrations pile up
     and the car sinks. A deferred re-add (2 physics frames) did
     NOT help. Fix: on every swap the four old wheel nodes are
     freed and **fresh wheel nodes are created** (`_build_wheels`),
     positioned by `_fit_model`, and added to the tree once (Jolt
     captures the fitted positions on first entry); the new real
     wheel meshes are reparented into the spinners only after the
     wheels are in the tree, so the car's yaw cancels instead of
     doubling. The old remove/add block and `_readd_wheels_deferred`
     are deleted. First load never re-adds at all (wheels are
     created in `_ready` and fitted before the first physics sync).
  Verification: 30-car settle-gated probe (axle = mesh origin vs
  model wheel centre) — 28/30 cars at <= 0.008, worst 0.016
  (NITRODOORSLAMMER, Y-only sag residual ~1% of tyre diameter).
  The AABB-centre error is up to 0.06 on FORMUL8R / POWERBOMB /
  SPECTYTE, but that is mesh asymmetry along the axle (more
  material inboard), not placement — the axle itself is exact.
  Car height 0.89–0.93 for all 30, tyre bottoms 0.46–0.47, no
  sinking across swaps. test_models: phase 4 all 30 swaps 0 fails,
  pause freeze + settings + resume, pause car swap works. **Rendered
  visual check (new):** the game now runs under Xvfb + Mesa
  llvmpipe (Godot Compatibility renderer, OpenGL 4.5) and real
  screenshots were captured — `wheel-check-rear.png`,
  `wheel-check-side.png`, `wheel-check-front34.png` (Bone Shaker):
  both wheels visibly on the axle, spoked rims, tyres on the
  ground, body sitting right, front wheel under the fender (not
  ahead of the nose). Windows build: re-exported, 149 MB ZIP
  (md5 3547581e31aca472b39508158ec791be).

- **Brake lights removed (2026-11-16, Anthony's request — driving
  feels "very nice", brake lights just had to go).** The brake
  lights were the M.A.V.S. addon's `rare_lights` system: a
  `Rare_Lights` node with two red emissive boxes built by
  `_build_lights()` in `mavs_car.gd`, shown by
  `advanced_vehicle_controller.gd` whenever braking/reversing or
  the handbrake was held. Removed: the whole `Rare_Lights`
  build block, the `rare_lights` export var and all three
  show/hide call sites in the addon, and the positioning line in
  `_fit_model`. Braking itself is untouched (test_brake: 29.1 ->
  0.6 u/s in ~1.5 s of brake, then reverse engages). Headlights
  stay (Front_Lights + Lights action, F key). Verified: probe of
  the loaded car tree finds no brake-light nodes; all 30 cars
  load/swap 0 fails; car select previews 30/30; rendered rear
  screenshot while braking (`brake-check-rear.png`) shows the
  rear with no red boxes — only the real model's own tail-light
  lenses, which are part of the .glb body and were left alone.
  Windows build: re-exported, 149 MB ZIP
  (md5 453df2ca7afec2e1b5dd39ff47f07a86).

- **Clean rich UI phase (2026-11-16, Anthony tested the build that
  morning and said "Holy shit that shit is perfect" — wheels,
  brake lights, and feel all approved — then chose the UI over
  feel tuning first, stressing it must be clean and organized).**
  One shared metallic glossy theme (`scripts/ui_theme.gd`,
  class `UiTheme`) across every screen: runtime-generated
  rounded-corner metal gradient textures (bright gloss band at
  the top, dark base at the bottom) for buttons — orange Play,
  blue Settings/Change Car, red Quit, grey Back, per-car colors
  on the car grid — dark navy panels with gold borders, gold
  title text with shadow, dark-blue vertical gradient background.
  Flow is now Start menu -> Map select -> Car select -> City,
  and Quit to Menu returns to the START MENU (was: car select).
  - **Start menu** (`scenes/start_menu.tscn`, now the project
    main scene): HOT WHEELS / BEAT THAT! / OPEN WORLD CITY,
    gold divider, PLAY / SETTINGS / QUIT, quiet city-skyline
    silhouette along the bottom edge. Enter / A plays.
  - **Map select** (`scenes/map_select.tscn`): Hot Wheels City
    as the only playable map (top-down street sketch, 380x380,
    ramps/boost pads, DRIVE THE CITY button) plus two honest
    LOCKED / COMING SOON slots — no fake playable maps.
  - **Car selector** (tidied `scripts/car_select.gd`): same live
    3D turntable preview, glossy per-car-color buttons in a
    clean 3-column grid, BACK button to map select (Esc / B).
  - **Settings** (new `scripts/settings_panel.gd`, class
    `SettingsPanel`, used in BOTH the standalone settings screen
    `scenes/settings_menu.tscn` and inside the pause menu, so
    there is exactly one settings UI): camera sensitivity,
    invert camera Y, master/engine volume, and the 11 key
    rebinds with gamepad labels, in a ScrollContainer with a
    styled gold scrollbar that actually scrolls (content ~1465
    px vs a 440 px viewport on the settings screen, 378 px in
    pause). Settings still persist to `user://settings.cfg` and
    apply immediately. The Godot 4 toggle switch draws on the
    RIGHT of its label, so the Invert check button is
    shrink-wrapped to keep the switch next to the text instead
    of parked under the scrollbar.
  - **Pause menu** (rewritten `scripts/pause_menu.gd`): three
    clean swapping panels — main (RESUME / SETTINGS / CHANGE
    CAR / QUIT TO MENU), settings (the shared panel + BACK),
    in-pause car list. Esc steps back a panel before resuming;
    an Esc that cancels a rebind no longer also resumes the
    game (panel flags it via `consume_esc_cancel()`).
  - Also fixed while in there: the driving HUD hint at the
    bottom of the screen was anchored centre-bottom with a
    left offset, so it ran off the right edge; it is now
    full-width with centred text.
  - Bugs caught by the rendered screenshots and fixed in the
    same pass: (1) the background gradient faded to WHITE at
    the bottom — `Gradient.set_color(1, ...)` after `add_point`
    recolors the mid point by index, leaving the bottom point
    at the default white; the two default points are now set
    before the mid point is added. (2) A stale
    `user://settings.cfg` in the VM still had Shift Down = A
    from before the KEY_E fix; deleted, fresh installs get E.
  Verification: all scripts pass `--check-only`; each menu
  scene runs 180 frames headless with zero script errors; a
  33-check headless flow probe (start -> map -> car select ->
  drive -> pause -> settings -> quit to start menu, plus
  slider change, scroll-to-bottom, rebind start/Esc-cancel,
  in-pause car swap) passes 33/33; test_carselect 30/30 and
  test_models phase 4 0/30 fails, phase 5 pause swap works
  (no regressions). **Rendered visual check:** 7 screenshots
  under Xvfb + llvmpipe (`ui-start-menu.png`,
  `ui-map-select.png`, `ui-car-select.png`,
  `ui-settings-top.png`, `ui-settings-scrolled.png`,
  `ui-pause-menu.png`, `ui-pause-settings.png`) — read and
  fixed from: glossy buttons, gold scrollbar, dark background
  throughout, no overlap or clipping anywhere. Zero
  `rare_lights` references remain.
  - **Phantom Racer green window tint (same build, Anthony's
    add-on).** The Phantom Racer's only glass surface, `Screen
    FR`, rendered white/opaque and vanished against the car's
    white body. `mavs_car.gd` gained `tint_glass_green()` /
    `tint_glass_green_tree()` — same per-mesh duplicate pattern
    as `tame_chrome()`: surfaces whose material name contains
    "screen" or "glass" get a duplicated material with albedo
    (0.12, 0.8, 0.3), alpha/roughness/metallic untouched.
    Applied only when the loaded key is PHANTOMRACER (in
    `_load_model` and in the car-select preview), so the other
    29 cars are untouched — verified headless (16 Angels'
    Screen FR/RR still white). Rendered check
    (`ui-phantom-before-a/b.png` vs `ui-phantom-after-a/b.png`):
    the windshield/canopy reads clearly green from both
    angles, matching the car's green rims; body paint untouched.
    Windows build with the UI + green glass: re-exported,
    149 MB ZIP (md5 0145dd678fb678381095dbcd03fd3966).

## Why Beat That

- 2007 PC game, abandonware (Eutechnyx defunct, Activision no longer
  sells or supports it) — fully moddable.
- Eutechnyx in-house engine. Assets live in ArcBank (`.arc`) files
  packed inside `cdfiles.dat` / `cdfiles.ar` pairs. Scripts are plain
  text (`.ls`).
- The Technyx toolset (https://github.com/PredatorCZ/Technyx) can
  extract the CDFILES pairs for Beat That on PC.
- 30 cars, 16 levels, 4 zones (Bedroom, Mini Golf, Attic, Bowling
  Alley) to use as reference and assets.

## Phases

### Phase 1 — Get the game and crack it open
- Transfer the Beat That PC setup ZIP (929 MB) and install the game.
- Use Technyx to extract the game archives — cars, tracks, textures.
- Read the plain-text scripts to see how the game works.

### Phase 2 — Learn the pieces
- How the cars are built (models, stats, handling).
- How the tracks/maps are built.
- What can change and how the engine loads it.
- Decides whether we mod the real game or rebuild the open world on
  top of its assets (open-source rebuild is the current direction).
- **Track geometry — CRACKED and shipped (2026-11-16).** All 4
  original zones are decoded from the real game data and drivable in
  the build — see "Real Beat That maps" below. Phase 2 is done.

### Phase 3 — Build the city
- Design the Hot Wheels city: downtown, docks, suburbs, all connected
  by track.
- Open world map with streets, ramps, loops, jumps, boost pads.
- A car driving around in it, free roam, no track walls.

### Phase 4 — Make it a game
- Collectibles, stunts, jumps, challenges.
- Cars to unlock by exploring and doing stunts.
- The 30 Beat That cars as the starting roster, plus room for more.

### Phase 5 — Tie it to the Hunt Book app
- Cars unlocked in the city sync to the Hunt Book collection.
- Stunts and finds earn Hunt Book points and badges.
- Game progress shows up in the app.

### Phase 6 — Mod manager
- Built-in browser for community-made mods (cars, tracks, skins,
  city parts).
- Download, enable/disable, and share mods from inside the game.

## Real Beat That maps — all 4 original zones, decoded and drivable (2026-11-16)

The track geometry was the one piece of the reverse-engineering
that was still uncracked. It is cracked now: all 4 zones from the
original Hot Wheels Beat That! (PC, 2007) are in the build as real
decoded geometry — not lookalikes, not placeholders. The map select
has 5 cards: Hot Wheels City first, then Attic, Bedroom, Mini Golf,
Bowling Alley. No locked slots remain for the zones.

### How the zones were decoded
- Each zone's landblock is a `ZONE<NNNN>A.ARC` file (ArcBank v5,
  same container as the cars). The existing car converter
  (`tools/arcbank-v5/arc_to_gltf.py`) converts them unchanged — the
  v5 layout is the same for zones and cars.
- Zone → landblock (from the readable `.LS.ARC` zone scripts):
  Zone 1 Bedroom = zone2000, Zone 2 Mini Golf = zone4000,
  Zone 3 Attic = zone1000, Zone 4 Bowling Alley = zone3000.
  Lighting comes from the same scripts (ambient 102/106/109,
  light 254/234/203, sun angle −150/60).
- Textures are matched by material NAME, not by binary binding
  (a naive u32 scan gives false positives). `zone_to_gltf.py`
  strips the parenthetical/suffix and matches the texture name;
  231/257 zone1000 materials matched (90%). Unmatched materials
  stay white (small props / generic names).
- The real decoded `IMG_MAPOVERLAY` minimap PNGs are the card art
  on the map select (one per zone).
- Zone sizes (true indexed-triangle bboxes, 1:1 scale — the
  authentic tiny-toy-car feel): Attic ~1386×730, Bedroom
  ~2424×886 (room shell 725×1035), Bowling ~962×536,
  Mini Golf ~3106×600. The car is 5.8 long.

### Collision — three root causes, all fixed
1. **Godot's glTF importer drops the vertex array of any
   primitive with no NORMAL attribute.** Some zone vertex buffers
   have no normals, so those meshes got no collision. Fix: the
   converter synthesizes smooth per-vertex normals (average of
   face normals) for any vertex buffer lacking them.
2. **The editor import of the zone files is pathologically slow**
   (10+ min per zone in this VM). Fix: the zones are NOT
   editor-imported. They ship as raw `.bin` files (byte-identical
   `.glb` data) and load at runtime via `GLTFDocument`
   (`FileAccess` + `append_from_buffer`), ~2.5 s per zone.
   The Windows export preset includes them via
   `include_filter="models/zones/*.bin"` — without that, the
   exporter's `all_resources` filter skips `.bin` files and the
   zones fail to load in the exported game. Verified: the .pck
   contains all 4 zone files (4× `glTF` magic) and the exported
   .pck loads a zone and builds collision.
3. **A CollisionShape3D nested under a MeshInstance3D never
   registers with the physics server.** The shapes existed (238
   for the Attic) but the car fell straight through. Fix: each
   CollisionShape3D is a DIRECT child of the StaticBody3D, with
   the mesh's global transform copied onto it.
- Bonus fix in the same pass: zone4000 (Mini Golf) had a
  self-parent cycle (node 460 `wingL2` listed itself in its own
  children) that hung GLTFDocument in infinite recursion. The
  converter now skips self-parent links.

### Zone fix — spawns, lighting, camera, map-select navigation (2026-11-16)
Anthony playtested the maps build and said ALL four zones feel off
— look and driving feel both. The zone-fix pass reworked every zone
and the map select. Verified by rendered screenshots read with my
own eyes + headless 60 Hz drive tests (render probes under llvmpipe
give very little game-time, so distance moved in a render probe is
NOT a reliable drivability measure — headless drive tests are).

**Spawns — old ones were all traps.** Raycast spawn-finding is
unreliable on zone geometry (it steps over hollow pipes and misses
invisible wedges); drive tests are the arbiter. Final spawns, all
verified by headless 10 s gas tests at full 60 Hz:
- Attic: (577, 111.6, 51), yaw 270 — 163 units west at 29 u/s,
  160-unit clear run before the table edge (fall respawn catches
  it). The old spawn (352, 26) wedged on a hollow ribbed pipe
  after 31 units.
- Bedroom: (535, 805.6, -13), yaw 180 — 166 units south at 29 u/s,
  still going. The old spawn hit the north wall after ~10 units.
- Bowling: (-400, 186.5, -150), yaw 90 — KEPT, drives the full
  lane east at 29 u/s (166 units in 10 s); the pin pit is the
  natural end after ~750 units.
- Mini Golf: (74, 206.6, -100), yaw 270 — 148 units west at
  19.2 u/s from the high flat area. The old spawn sat on a steep
  bumpy ramp (car pitched 17° nose-up, launched off the course).
- New in `scripts/zone.gd`: `spawn_yaw` (degrees; +Z at 0, +X at
  90) and `cam_distance` exports; `_place_at_spawn()` (position +
  rotation + camera anchor yaw + zero velocities, called after
  `apply_car` so the model load cannot clobber the facing); fall
  respawn now resets rotation too; **stuck reset** — gas held +
  speed < 0.5 u/s for > 3.0 s respawns (parked cars never reset).
  `floor_y` = play level − 60 per zone.

**Lighting — the washout root cause.** All 4 zones share the
original .LS lighting (ambient 102/106/109, light 254/234/203,
SHADOW-INTENSITY 0.0), but the scenes had `shadow_enabled = true`,
so the car sat in deep shadow under tables/beams and rendered
black. Fix: shadows OFF on every zone DirectionalLight3D;
ambient raised to (0.7, 0.75, 0.85); background dark brown →
sky blue (Mini Golf dusky); **Bedroom toned down** (ambient
0.5/0.55/0.65, light energy 1.0 → 0.8) so the white bed reads
as a bed, not a white void. **A real ProceduralSkyMaterial sky
was added to all 4 zones** so the metallic car paint has a
reflection source (a solid background color does not feed
metallic reflections in the Compatibility renderer).

**Camera fill light** (`mavs_car.gd` `_build_cam_fill_light()`):
a SpotLight3D on the chase camera, shining forward at the car
(range 20, angle 55, energy 0.7, warm white, no shadow). Honest
result: it barely changes a BLACK Bone Shaker's rear — black
metallic paint reflects almost no direct light; the sky gives
only a subtle roof sheen. Non-black cars read clearly. The
dead-rear black-blob look is worst-case for the Bone Shaker
specifically; most of the 64-car roster is not black.

**Map select navigation rework** (`scripts/map_select.gd`):
the whole card is now one `Button` (clickable + focusable),
all children ignore the mouse so clicks land on the button,
Enter / A and mouse click both drive, Esc / B goes back.
Explicit focus neighbours for the 3-column grid (City↔Attic↔
Bedroom row 1; Mini Golf↔Bowling row 2; down from Bedroom lands
on Bowling; down from row 2 lands on BACK; BACK up returns to
Mini Golf); the focused card gets a border-only gold ring
(`draw_center=false`, width 5). **Two layout bugs found by
rendered screenshots and fixed in the same pass:** (1) a Button
does NOT size to its children, so the buttons stayed ~56px tall
while the content spilled out and overlapped — fixed with a
fixed 254px `custom_minimum_size` matched to the measured
content (labels resolve their minimum size only once in the
tree, so build-time measurement returns ~0; headless also
reports label heights 3x too tall — measure under the real
renderer); (2) the minimap PanelContainer's `panel_style`
content margins (16px top/bottom) made an 80px minimap into a
112px frame, pushing DRIVE off the card — fixed with a
`_frame_style()` with 4px margins (frame now 80px for a 72px
minimap). Cards are compact (title 22 + tag 13 + minimap 72 +
2 lines + drive) so two rows fit a 720px screen. Verified:
rendered screenshots show the gold ring on City and on Bowling
Alley when focused; headless focus probe (right,right,down,
left,left,up,down,down) lands exactly per the wiring.

### Spawn-on-wall fix — spawns moved to open floor (2026-11-16)
Anthony playtested the maps build and said he spawns ON THE
WALL, not the ground floor, on the maps — and suggested
rotating the plane so it could be on the ground floor.
Investigation first, before any rotation:
- **Raycast down at every spawn: the car IS on a horizontal
  floor** (normal up, up_dot = 1.0) — Attic 109.6, Bedroom
  803.6, Bowling 184.3, Mini Golf 204.6, City 0.5. The
  floors are horizontal; the rooms are correctly oriented.
- **Aerial establishing shots (high 3/4 + top-down, all 5
  maps): no landblock is tipped.** The Attic table, the
  Bedroom bed, the Bowling lane and the Mini Golf course all
  read as flat horizontal surfaces from above.
- **The zone .glb ENVIRONMENT nodes carry a −90° X rotation,
  but that is part of the correct game→glTF conversion** (the
  stored bed normal is (0,0,1); the rotation maps it to world
  up). Zeroing it would turn floors into walls — the exact
  bug reported. **DECISION: no zone is rotated.**
- **Root cause: the spawn points sat immediately next to the
  rooms' real walls**, so the chase camera (behind the car)
  was jammed against a wall and the wall filled the spawn
  view. The walls are real room geometry (TRACK nodes:
  `attic_wall02a`, `groundwood2`, Bedroom `TRACK_Shadowobj2`
  tiles), correctly placed — just too close to the spawns.
  Fix = move the spawns to open floor, facing the longest
  clear run. (Anthony's "rotate the plain" was his hypothesis,
  not the cause.)
- A 50–60 unit raycast grid (flat = normal.y > 0.95, ±6
  neighbours within 1.0, then 8-direction horizontal
  clearance at car height) picked the candidates, but
  **raycast clearance alone is NOT enough** — it misses
  overhead track beams and it cannot tell a slope from a
  floor. Every candidate was judged by a rendered spawn
  screenshot read with my own eyes (a teleport probe
  renders any (x, y, z, yaw) in a zone scene). Two
  grid-best picks were REJECTED by the screenshot:
  Mini Golf (−828, −227) sits on an ~18° slope (car tilts,
  rolls at spawn, faces a dirt hillside); Attic (540, 14)
  sits ON the yellow track (beams overhead fill the frame).
  Attic facing south (yaw 0) faces the wooden south wall
  head-on; Attic facing east (yaw 90) faces a dark-blue
  wall/structure.
- Final spawns (spawn + spawn_yaw exports AND the Car node
  transform updated in each .tscn; `zone.gd`
  `_place_at_spawn()` reads them, and fall respawn + stuck
  reset reuse them, so the new spawn is also the respawn
  point). Yaw: 0 = +Z/south, 90 = +X/east, 180 = −Z/north,
  270 = −X/west. Spawn Y = floor + 2.0.
  - Attic: **(440, 111.6, 14), yaw 180 (north)** — on the
    white table (NOT the yellow track), facing the track.
  - Bedroom: **(448, 805.6, −150), yaw 45 (SE)** — open bed,
    200 clear SE; only a sliver of wall in the top-left.
  - Bowling: **(−257, 186.3, −132), yaw 90 (east)** — centre
    of the lane (the old spawn was 18 units south, at the
    lane's south edge/gutter); lane clear east 200.
  - Mini Golf: **(74, 206.6, −100), yaw 180 (north)** — the
    zone-fix flat patch, re-faced north (was yaw 270/west);
    car level on flat sand, open view north. The course has
    no strictly flat spot anywhere (grid found 0), so a
    perfectly level Mini Golf spawn does not exist; this is
    the flattest verified patch.
  - City: **unchanged (−20, 1, −20), yaw 0** — already on
    open street.
- Verified: all 15 scripts `--check-only` clean; all 9 scenes
  180 frames, 0 script errors (the `Parameter "m" is null`
  lines in headless runs are dummy-rendering-server noise,
  not script errors); rendered spawn + drive screenshots
  read with my own eyes for all 5 maps; earlier playtest
  fixes re-verified in the same pass (city stuck reset fires,
  Attic camera stays level on the bank, Mini Golf pipe still
  raised — `zone4000.bin` plate Y 216.3–218.6, md5
  `f216ddabe0ff837deb0a3a6e6de371fe`).
- Still open: minimaps weak except Bowling; black cars still
  dark from dead behind (fill light 1.5 helps, does not fix);
  Mini Golf bumpy off the flat area; the raised Mini Golf
  pipe floats ~3 units above the ridge.
- Deliverable: `hot-wheels-beat-that-spawn-fix-build.zip`
  (identical to the main prototype ZIP).

### Bowling lane hole — car falls through the lane and flips (2026-11-16)
Anthony tested the spawn-fix build on his Deck and reported
"Still not on ground floor tho" / "Same thing it didn't fix
here" / "you see textures glitches", with two photos and a
19 s video of the Bowling Alley (16 Angels). Video frame 15:
the car FLIPPED ON ITS SIDE, underside/chassis visible, Hot
Wheels logo on the base, wedged against the blue/cosmic wall.
**The .pck was NOT stale** — the delivered spawn-fix ZIP's
.pck carries the NEW spawn (−257, 186.3, −132, 2 hits, yaw 90
east confirmed from the Car-node basis) and 0 old-spawn hits,
in both the distinct ZIP and the main-path copy. So Anthony
was on the new build; the new build was genuinely still wrong
in Bowling.
- **Root cause: the lane has a collision HOLE east of
  x≈−221.** Raycast-down grid (Godot's own collision): lane
  flat y=184, normal up 1.0, x=−270..−220; **GAP x=−218
  eastward** (no surface y=200→100); east grid x=−90..350:
  no lane at y=184 anywhere (only a 233 slab, deep pits at
  y≈−115, and the real lane resuming at x=330–350, y=185–
  192). Mesh data agrees: lane-band verts (y 180–190,
  z −152..−112) stop at x=−220 in every position pool; the
  converted zone3000.bin is simply MISSING the lane east of
  −221 (~60% of the lane). The car drives east off the end
  of the real lane, falls through (playtest mid-drive:
  (−175.5, 154.2, −132), min_y 60.3), tumbles, and ends up
  on its side against the north blue/cosmic wall — the flip
  reproduces in the VM (v2 playtest, Bone Shaker on its side
  at SPEED 62) and on the Deck at 60 fps, so it is NOT a
  low-fps artifact. The earlier "drives the full lane" claim
  was wrong: that headless test only drove 166 units
  (−400→−234) and stopped 13 units short of the hole.
- The lane is a sunken channel, not the room's ground floor:
  the south checkered floor sits 31–42 units ABOVE the lane
  (y≈215–226 vs lane 184), which is why the room reads as a
  wall from the low chase cam. The blue surface in Anthony's
  photo 2 is the north-side blue/cosmic wall base the car
  lands on after falling through the hole.
- **Fix: a red lane strip patch in `scripts/zone.gd`**
  (`_build_lane_patch()`, Bowling Alley only, called from
  `_ready()` after `_build_zone()`): a StaticBody3D with a
  BoxMesh (red-orange, matching the lane) + a BoxShape3D,
  x −225..330, z −152..−112, top y=184.35 (0.05 above the
  real lane so it renders cleanly over the 4-unit overlap),
  running the full lane to the pins (real lane resumes
  x=330 at y≈185). Visual + collision together, so the car
  drives on visible red, not on air over the pit. No other
  map is touched (early return for any other zone_name); no
  zone is rotated.
- **Verified rendered with own eyes:** 16 Angels, straight
  east, no steering — spawn (−257.35, 184.71, −132) SPEED 0;
  mid-drive **(182.42, 184.77, −132), speed 31.1, yaw 90,
  min_y=184.3** — the car drove 439 units east past the old
  hole, upright on red, never dropping below lane level
  (before: mid-drive (−175.5, 154.2), min_y 60.3, flipped).
  Spawn + mid-drive screenshots read; the patch blends with
  the real lane (no visible seam/step). The exported .pck
  was also run directly and prints
  `[Zone] Bowling Alley: lane patch added (x -225..330, top
  y=184.35)`; its .pck carries the new spawn (2 hits) and 0
  old-spawn hits.
- **Texture glitches — diagnosed, not a mapping bug:** the
  checkered carpet (`zone3_carpet.png`, 2×2 woven checkers)
  and the orange sofacloth (`sofacloth.png`, red/orange
  squares) are the CORRECT original textures, and their UVs
  DO tile (carpet −4.5..5, sofacloth −5..7 repeats). The
  "stretched/noisy" look is the original low-res textures at
  a large world scale (~100 units per tile, ~50-unit
  checkers) viewed from the close chase cam. Follow-up
  option (not done): scale those materials' TEXCOORD_0 by
  ~2× in zone3000.bin for denser tiling.
- Still open: minimaps weak except Bowling; black cars still
  dark from dead behind; Mini Golf bumpy off the flat area.
- Deliverable: `hot-wheels-beat-that-bowling-fix-build.zip`
  (md5 `d29bbc37bc9170c325ebb2f452d72efa`, 287,831,273 bytes;
  identical to the main prototype ZIP).

### Make all the maps read right side up — per-zone camera + Mini Golf spawn (2026-11-16)

- **Ask:** from the Deck, all four zones read tilted/sideways —
  the floor looks like a wall, the room looks rotated. Fix how
  the maps READ from the driving view. City is the control (reads
  fine, untouched).
- **Verdict — camera, not geometry (re-verified with fresh eyes):**
  no landblock is tipped. All TRACK tiles are identity Y-up; the
  ENVIRONMENT shells are upright in world space (their +90° X node
  rotation compensates a Z-up-authored mesh). The TRACK geometry is
  level; the "tilted" reading is what the low chase cam shows.
  - **Bowling (worst):** the lane is a sunken channel — the
    checkered floor beside it sits 31–42 units ABOVE the lane —
    so from the low chase cam (2 up, 8 back, level) the elevated
    floor reads as a vertical wall and the furniture on it (snack
    tables, scoring consoles, bottles) reads as hanging from the
    ceiling. Score TVs face down-and-toward the lane (blue screen
    visible from the lane), pinsetter is a tall machine above the
    pins — those are correct, not tipped.
  - **Mini Golf:** the spawn faced north (yaw 180) up a bumpy
    slope the car can barely climb (speed 1.4–2.7, ~10 units in
    120 frames) and the car sat tilted on it. The spawn ground
    itself is flat (floor y≈205, slope ~0) — the facing was the
    problem, not the spot.
  - **Attic / Bedroom:** already read level with the default cam
    (level horizon, floor = floor, walls vertical, car level).
    A uniform camera raise was tested and REJECTED for them — it
    makes the Attic a white void + jumbled beams and the Bedroom
    an even bigger blank bed. No change.
- **Fix (per-zone, not uniform):**
  - **Bowling chase cam raised + pitched down:** new per-zone
    exports on `zone.gd` — `cam_height` (holder Y above car
    origin, default 2.0), `cam_pitch` (degrees, negative = look
    down, default 0.0) — applied by `_apply_zone_cam()` after
    `apply_settings()` and after pause-menu car swaps, and stored
    on the cam holder (`base_pitch_deg`, `base_spring_length`) so
    `Cam_Holder.switch_camera()` keeps the zone's setup instead
    of resetting to 8.0 / level. Bowling scene: `cam_height =
    10.0`, `cam_pitch = -17.0`, `cam_distance = 14.0`. The
    scoring consoles and bowling balls now read as sitting on
    surfaces, the lane reads as floor, the car stays visible in
    the lower-middle of the frame.
  - **Mini Golf spawn re-faced:** `spawn_yaw` 180 → −90 (face
    west along the flat strip at y≈205, z=−100). The car now
    drives 69+ units west on flat ground (y 205.04 throughout,
    speed 24.2) instead of crawling north up the slope. Same
    spawn point, same camera.
  - **Attic / Bedroom / City:** unchanged (camera + spawn as
    before). Bowling lane patch, all spawns, stuck resets, and
    the level-camera (roll) fix are intact and re-verified.
- **Verification (this build):** all 16 scripts `--check-only`
  clean; all 4 zones + city run 180+ frames, 0 script errors;
  headless drive tests per zone (Bowling 439 units east on the
  lane patch, speed 29, never drops; Mini Golf 69 units west on
  flat ground, speed 24.2; Bedroom 48 units on the bed, speed
  21; Attic unchanged). Rendered screenshots read with own eyes
  for every zone — spawn + mid-drive, level horizon, floor reads
  as floor, walls as walls (Bowling furniture sitting, Mini Golf
  car level on the course, Attic yellow track level, Bedroom bed
  level). Probe scripts and evidence in
  `workspace/hot-wheels-beat-that/upright/` (`probe_cam.gd`,
  `verify_upright.gd`, `probe_flat2.gd`, `analyze2.py`,
  `local_aabb2.py`, `dump_hier.py`, `cam-*.png`, `vrf-*.png`).
- **Still open:** the Bedroom's spiky black silhouette on the
  right horizon (geometry artifact, not a tilt — unidentified);
  Mini Golf is very bumpy off the flat strip (fall respawn
  catches it); Bowling's checkered floor still reads steep from
  the low side (it IS 31–42 units above the lane — original
  geometry); minimaps weak except Bowling; black cars still dark
  from dead behind.
- Deliverable: `hot-wheels-beat-that-upright-build.zip`
  (md5 `86bc5af91c1c146fbb19d52a3ea23389`, 287,832,976 bytes;
  identical to the main prototype ZIP).

### Bowling upright round 2 — the north floor is missing (2026-11-16)
Anthony annotated the upright build's Bowling spawn shot and sent
it back: the red lane reads as floor now (good), but the purple
pinsetter / furniture cluster at the top still reads as hanging
from the ceiling, and the checkered room floor reads as a wall on
the left/top. The floor/ceiling relationship is wrong from the
spawn view. Bowling only; Attic/Bedroom/Mini Golf were fine and
were not touched.
- **Geometry verified, not assumed.** The pinsetter
  (FI_PinReseting, x=-342) and score TVs (Z3-scoreTV06–09, y
  198–232, z -96..-155, x 265/128/-10/-148) are UPRIGHT in the
  converted geometry (local Z is up; screens face the lane) — the
  previous "correct as-is" verdict on orientation was right, but
  the read is a camera + missing-geometry problem, not an
  orientation problem. The purple machine at the far end is the Hot
  Wheels logo sign (hotwheelogo01, (350.8, 318.1, -98.5), ~147
  tall) — a wall sign, upright; it reads as hanging only because
  the low camera looks up at it.
- **The north floor is MISSING from the converted geometry**
  (same loss class as the lane hole). Godot raycast finds void
  from z=-110 to the north wall (z=+64) for almost every x east of
  -200, and z=+15..+60 is void too. A triangle-area count over
  zone3000.bin finds only ~1,068 sq units of horizontal surface in
  the whole north band (scattered furniture tops) vs ~16,753 in the
  south band (a real floor) and ~11,267 in the lane band. The GLB
  holds all 145 meshes the original .ARC has, so the floor was
  never in the source data — the ball-return consoles, score-TV
  poles, snack table and seating were authored standing on legs
  over an open pit, and the original game's high camera never
  showed it.
- **Why it reads as hanging (occlusion).** From the low chase cam
  (y~194, below the floor at 215) the sightline to a console base
  (y~230) passes through the sunken channel's wall (top y=215), so
  the base is occluded and the furniture floats against the sky.
  The south floor reads as a wall for the same reason (camera below
  it). A floor patch alone is not enough (at the low camera it
  reads as a dark slab overhead) and a camera raise alone is not
  enough (the consoles still float on stilts over a void) — the fix
  needs both.
- **Fix 1 — north floor patch** (`scripts/zone.gd`
  `_build_north_floor_patch()`, Bowling only): a floor slab at the
  south floor's level (top y=215) spanning the void band,
  x -225..350, z -110..+64, dark slate carpet colour
  (0.15, 0.17, 0.26), visual + collision. The furniture legs sink
  into it exactly the way legs meet a floor. The car can never
  reach it (29 units above the lane, no ramp).
- **Fix 2 — Bowling chase camera raised above the room floor**
  (`scenes/zone_bowling.tscn`: cam_height 10 → 38, cam_distance
  14 → 28, cam_pitch -17° → -26°; applied via the per-zone cam
  exports in `zone.gd` + `Cam_Holder.gd` base values so a camera
  switch keeps it). Camera matrix tested rendered (control, H=32,
  H=38, H=45, H=52, short-arm H=38/D=12/P=-45 and H=40/D=15/P=-40):
  H=38/D=28/P=-26 reads best at spawn — south floor as floor, lane
  as floor, consoles sitting on the dark patch, car visible.
- **Known trade-off — hanging score TVs.** The TVs (y ~195–232)
  hang over the lane in the chase camera's line of sight, so the
  car ducks behind one briefly (~1 s) when passing each TV
  (raycast-proven: the sightline from the H=38 camera to the car
  passes y=197.6 at x=128, and the TV is solid there for y
  195–232). Any high chase camera has this; only a top-down camera
  or raising the TVs avoids it. Raising the TVs edits original
  geometry and is a separate call — not done here. At spawn there
  is no TV between camera and car, so the spawn view is clear.
  (Side note for future debugging: two early diagnostic probes
  reported the camera "flipped" in front of the car — that was a
  probe arg-indexing bug giving a NEGATIVE spring length, not a
  game bug. The correct probes show the camera correctly behind the
  car at all times.)
- **Verification (this build):** all scripts `--check-only` clean;
  all 9 scenes run (5 drivable 220 frames, 4 UI 60 frames), 0 script
  errors; rendered Bowling spawn + mid-drive shots from the shipped
  build read with own eyes (spawn reads unambiguously right side
  up; car drives the full lane upright, speed 29, never drops).
  Lane patch, spawn (-257, 186.3, -132, yaw 90), stuck reset and
  level-camera roll fix all intact and re-verified. Evidence and
  probes in `workspace/hot-wheels-beat-that/upright2/` (NOTES.md,
  cam matrix shots, `probe_arm.gd`, `probe_los.gd`, `probe_fov.gd`).
- Deliverable: `hot-wheels-beat-that-bowling-upright2-build.zip`
  (287,834,340 bytes, md5 `d6316e854bf7d261462d097ed7e0b119`;
  identical to the main prototype ZIP). Exported .pck verified
  directly: it prints both patch lines and the C2 camera
  (holder (0, 38, 0), pitch -26, spring 28).

### Spawns and driving (original map pull)
- Spawn points are measured from floor-height raycast grids
  (flattest spots): Attic (−150, 199, −200), Bedroom
  (400, 809, −150), Bowling (−400, 189, −150),
  Mini Golf (−900, 154, 0) — the Mini Golf car faces +X
  (downhill) because the spawn is on a ramp.
  **Superseded by the zone fix above — those spawns are all
  replaced; see the final spawn list.**
- Drop tests: all 4 zones PASS (car settles on the floor).
  Drive tests: Attic, Bedroom, Bowling PASS (car moves 13–17
  units under gas, no fall-through); Mini Golf moves 4.2 units
  under gas on its bumpy ramp and does not fall through.
- Rendered screenshots (read, in the repo root):
  Attic shows the wooden train-table floor, beams and the yellow
  Hot Wheels track; Bedroom shows the white bed surface (bright /
  washed out — the bed sheets are white); Bowling Alley shows the
  red lane, orange gutters, snack-bar menu and cosmic wallpaper;
  Mini Golf shows the dirt ramp with grass edges and obstacles.
- Zone files: `src/godot/models/zones/zone{1000,2000,3000,4000}.bin`
  (~110 MB total). The .pck is ~232 MB (was ~130 MB).
  The `phybin` collision blob (`ZONE<NNNN>P.ARC`) was NOT decoded
  — collision comes from the visual mesh trimesh instead, which
  works. The battle-arena landblocks (`ZONE<NNNN>BA*`) and
  MAP-JUNGLE are not included.

## Metallic glossy car finish (2026-11-16)

All 30 cars have a metallic glossy die-cast finish instead of the
matte finish. The real `.glb` textures stay — same paint colours
and decals — only the material finish changes.
- `gloss_body_paint()` in `scripts/mavs_car.gd` (same per-mesh
  duplicate-material pattern as `tame_chrome()`, so the shared
  imported materials are never mutated): body paint surfaces get
  metallic 0.3 / roughness 0.15.
- Body paint ONLY. Skipped by material name: glass/screen,
  tyre/tire, chrome, light/glow, plastic. Tyres stay matte rubber;
  glass is untouched (so the Phantom Racer green window tint
  still works — gloss runs first, then the tint).
- Applied in BOTH paths: the in-game `_load_model` and the
  car-select preview (`car_select.gd`).
- Verified: all 30 cars load and gloss 3–6 paint surfaces each;
  Phantom Racer glosses 4 and tints 1 glass surface green.
  Rendered screenshots read: Bone Shaker (black, skull decal,
  chrome engine/grille) and Phantom Racer (white, glossy, green
  windows + green rims) both read as real die-cast cars.
  Note: the Compatibility renderer has no environment map, so the
  gloss reads as a sheen/highlight rather than a full mirror
  reflection — Anthony's eyes on his real build are the final
  check.

## Roster expansion — Highway 35 cars + Iridium (2026-11-16)

The roster grew from 30 to **64 cars**: 33 Planet Hot Wheels
Highway 35 cars plus the Iridium from Hot Wheels Unleashed 2.
- **Source:** "Planet Hot Wheels Highway 35 Cars" by Natr
  (Sketchfab, Free Standard license, ripped from the defunct
  Planet Hot Wheels MMO). Anthony downloaded it himself and sent
  the ZIP — the Sketchfab download API needs a login, so Muse
  could not fetch it directly. The Iridium came in a second ZIP
  from Anthony (Sketchfab, Zorg_Sinister, CC-BY-4.0).
- **Split:** one combined 15.2 MB `.glb` (212 nodes, 35 cars on a
  grid, each = body + windshield + 4 wheel meshes) was split by a
  pure-Python glTF reader/writer (`/tmp/split_cars.py`) into one
  `.glb` per car, normalised to the Beat That convention (Y-up,
  nose +Z, ~2.5 wide x ~5.8 long, Body node with R_x(-90deg),
  wheels as children with T*R_x(+90deg) matrices, textures
  embedded). Body materials set to OPAQUE (the source had them
  BLEND); glass materials renamed to contain "glass" so the gloss
  pass skips them. The car-select "30 CARS" label is now dynamic
  (`%d CARS` from `CarData.CARS.size()` — reads "64 CARS").
- **Skipped (duplicates of the Beat That roster):** 24/Seven
  (already 24SEVEN) and Muscle Tone (already MUSCLETONE). Power
  Rocket and Twin Mill are NOT duplicates — neither is in the
  30-car roster (POWERBOMB is a different car), so both were
  added. Wild Thing is a 3-wheeler in the source (two flat
  half-discs form one thin central rear wheel) — included as-is.
- **Iridium:** the source is skinned, but the skin is in bind
  pose — every joint world matrix exactly cancels its
  inverseBindMatrix, so baked == raw. The raw positions ARE the
  final car (Y-up: X = length nose +X, Y = up, Z = width), so no
  skinning is done; the car is rotated R_y(-90deg) to nose +Z and
  scaled to 5.8 long. Its two merged wheel meshes (each holds
  both left+right wheels) are split by raw-Z sign. Body = merged
  Chassis + Livery + Exterior + Interior (4 primitives); glass =
  3 merged glass meshes; body materials get metallicFactor 0.0 so
  the gloss pass applies.
- **Per-car stats:** top_speed 24–32 / accel 16–22 by deterministic
  hash of the key (same range as the original 30). Button colours
  from each car's body-texture average, mapped into the roster's
  vivid palette style.
- **Verified:** all 23 scripts `--check-only` clean; headless
  `test_models` phase 4 — **0 fails across all 64 cars** (loaded,
  basis ok, 4 real wheels, ride height y 0.86–0.94, radii ok,
  chrome ok, camera 8–9); phase 5 pause swap works;
  `test_carselect` — 0 fails, all 64 previews load. Rendered
  screenshots read with own eyes: car select shows "64 CARS"
  with the Highway 35 section in the grid; Twin Mill, Iridium
  and Deora II all drive mid-speed in open ground (SPEED 62–67)
  with wheels on the axle and bodies reading correctly. Gloss:
  HW35 cars gloss 1 paint surface each, Iridium glosses 4.
- **Final combined build (2026-11-16 evening):** the zone fix and
  the Highway 35 cars are now in ONE build —
  `hot-wheels-beat-that-zones-fixed-build.zip` (287,833,632 bytes,
  md5 `9aba8428c33053f34dbb6fe6077b14af`), also at the standard
  `hot-wheels-beat-that-prototype-windows.zip` path. Windows EXE
  (84 MB) + pck (290 MB, includes all 4 zone .bin files and all
  64 cars). The earlier staging ZIP
  (`hot-wheels-beat-that-highway35-staging.zip`, md5
  `7843568a83cf1e3fce521c2fa2315827`) was built mid-zone-fix and
  is superseded.

## All-5-maps playtest + fixes (2026-11-16)

Anthony asked for a full playtest of all 5 maps ("do spot the
errors") and chose to fix what it found. The playtest drove every
map rendered (Xvfb + llvmpipe, ~3 fps) and read the screenshots;
evidence in `workspace/hot-wheels-beat-that/playtest/` (screenshots
+ 6 drive clips). **Verdicts:** Bowling Alley cleanest; Bedroom
worst (spawn wedges the car); City spawn faces a building with no
stuck reset; Attic + Mini Golf camera rolls ~40° on banks/slopes;
Mini Golf has a green pipe across the frame at roof height; black
cars read as dark blobs from the rear chase cam; minimaps weak
except Bowling (left alone — bigger job). **Caveat:** the playtest
ran at ~3 fps, where Godot caps physics steps per frame, so
game-time runs slower than real time — Anthony's Deck is the final
check. **Lesson (re-learned the hard way): headless 60 Hz drive
tests do NOT prove a spawn — the zone-fix team's headless tests
measured Bedroom driving 166 units at 29 u/s while the rendered
playtest wedged on a ridge the coarse grid missed. Every spawn
fix here was verified with a RENDERED drive test.**

**Fix 1 — Bedroom spawn wedges the car.** Root cause, proven by
a fine raycast grid (step 2): a 3-unit-high ridge at y=806.6
(vs bed 803.6) at (534–536, -14..-12), directly under the front
axle — the 0.42-radius wheels cannot climb a 3-unit vertical
step. The zone-fix team's coarse grid missed the 2–4-unit-wide
ridge. New spawn **(560, 805.6, -60), yaw 180** — fine grid shows
flat 803.6 across the whole car footprint, with a 180-unit clear
run north to the wall at z=-248.7. (`scenes/zone_bedroom.tscn`:
spawn export + Car transform.) Verified rendered (Bone Shaker):
car drives freely from the new spawn — SPEED 35 mid-drive, 66
units north at 23.8 u/s by the final frame. The floating rainbow
disc is NOT a misplaced prop: a camera-ray probe hit the north
wall (z=-248.7) 294 units out — it is a CD/poster ON the wall,
~150 units above the bed, original-game wall art. Left alone.

**Fix 2 — City spawn faces a building + no stuck reset.** Old
spawn (0, 0) faced a building dead ahead (clear run only ~76
units). New spawn **(-20, 1, -20), yaw 0** — the x=-20 line is the
middle of the gap between the x=0 and x=-40 building columns,
with a 200+ unit clear run down the street to the border wall
(raycast-verified). (`scripts/city.gd`: `SPAWN` const +
`_place_at_spawn()` mirroring `zone.gd`; `scenes/main.tscn` Car
transform.) Stuck reset added to `city.gd` — same rule as the
zones (gas held + speed < 0.5 u/s for > 3 s → respawn at spawn;
parked cars never reset). Verified rendered (Bone Shaker): car
drives the full 200+ units to the border wall, wedges at SPEED 0,
and the reset fires — the car is back at spawn driving within
15 frames. City layout and buildings untouched.

**Fix 3 — Camera rolls ~40° on banks/slopes (Attic + Mini
Golf).** Root cause: `Camera_Anchor` is `top_level`, so it does
not inherit the car's transform — instead a `RemoteTransform3D`
(created in `mavs_car.gd` `_build_markers()`) copies the car's
FULL global transform, including roll and pitch, to the anchor
every frame. `Cam_Holder.gd` only ever touched the anchor's Y
rotation, so it could not level the frame. Fix in
`addons/M.A.V.S/Scripts/Cam_Holder.gd` (end of `_physics_process`,
chase cams only — hood cam untouched): zero the anchor's world
roll/pitch (`cam_parent.rotation.x/z = 0`, yaw keeps following
the car), plus belt-and-braces force the holder's own WORLD roll
to 0 (`global_rotation = Vector3(x, y, 0)`) after the local
rotation is set — this preserves the forward direction exactly
and is immune to RemoteTransform3D ordering. Verified rendered:
Attic banked section — the vertical posts and wood planks are
level in the frame while the car itself leans ~40° on the bank
(correct: the car banks, the camera doesn't); Mini Golf slope —
frame level, horizon flat.

**Fix 4 — Mini Golf green pipe across the frame.** The bar is a
thin vertical plate (0.5 thick, 2.7 tall, 203 long) at x≈19.5,
y 210.3–213.0, spanning z -124..79 — a portcullis gate rail the
car drives under, original course architecture. Identified as
node 118 (`x012-z012:TRACK_shadowland`) prim 3, mat 84, tris
54–59 + 80–81, 12 vertices — an isolated strip, exclusive to the
plate (verified: no other primitive uses those vertices). Rerouting
was ruled out first: east of the spawn is a void (no floor at
x=100–150), north/south lanes are not flat (drops to 157/169 with
holes), the beam spans the whole westward corridor, and moving
the spawn west of the beam fails — the flat patch there is only
~26 units and ends in a 31-unit cliff that high-centers a
slow-moving car (proven: spawn (0,-100) wedged at speed 3.7),
while the x=24 bump needs the run-up from the (74,-100) spawn
to power over it. **Fix chosen: raise the plate.** The 12 plate
vertices were moved +6 in Y directly in `models/zones/zone4000.bin`
(backup at `playtestfix/zone4000.bin.bak`; script
`playtestfix/raise_beam.py`), plate now y 215.9–219.0. Verified
rendered: the solid green bar is now in the upper frame (~100px
above the roof, not at roof height), the roofline is clear, the
car drives under it and on to x=-40 at 22.3 u/s. The raycast
confirms it too (west rays at y=210/212 now clear, y=218 hits).
The plate stays visually near its supports (the x=24 ridge tops
out at y≈213).

**Stretch — black cars as dark blobs.** Chase-cam fill light
(`mavs_car.gd` `_build_cam_fill_light()`) raised 0.7 → 1.5.
Verified rendered: Bone Shaker rear shows more definition
(chassis bar, rear panel edges, roof sheen) in the Bedroom, and
16 Angels (red) reads clearly with NO washout — rich red, flame
decal visible, twin exhausts crisp. Black paint is still dark
from dead behind (it is black paint), but the light helps without
harming other cars.

**Verification (this build):** all scripts `--check-only` clean;
all 9 scenes 180 frames headless, 0 script errors; headless drive
tests per fixed item; rendered screenshots read with own eyes for
every fix (Bedroom driving from spawn, city stuck-reset firing,
Attic frame level on the bank, Mini Golf pipe raised off the
roofline, 16 Angels no-washout). Probe scripts and evidence in
`workspace/hot-wheels-beat-that/playtestfix/` (bedroom2, city2,
attic2, minigolf2/5, bedroom16 + `probe_*.gd`, `find_*.py`,
`raise_beam.py`).
- **Playtest-fixes build (2026-11-16 evening):**
  `hot-wheels-beat-that-playtest-fixes-build.zip` (287,833,495
  bytes, md5 `9c7cb4d4a96014d9c9b3e21ff2b63cbe`), also at the
  standard `hot-wheels-beat-that-prototype-windows.zip` path
  (identical file, same md5). Windows EXE (84 MB) + pck (290 MB).
  **Still open:** minimaps (weak except Bowling — bigger job,
  untouched); black cars still read dark from dead behind (the
  fill light helps, it does not solve black paint); Mini Golf
  course is very bumpy elsewhere (the car can fall off the flat
  area into holes — the fall respawn catches it).

## Repo layout

- `src/` — game source code
- `assets/` — game assets
- `mods/` — mod manager data and community mods
- `docs/` — design docs
