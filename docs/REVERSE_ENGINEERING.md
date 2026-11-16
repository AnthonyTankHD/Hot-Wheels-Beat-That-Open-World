# Reverse Engineering Notes — Hot Wheels: Beat That! (PC, 2007)

How the game's files were cracked open, and the tools to do it yourself.

## The game

Hot Wheels: Beat That! (Eutechnyx, 2007, Activision). PC version. Abandonware — Eutechnyx is defunct and Activision no longer sells or supports it.

- Engine: Eutechnyx in-house engine
- Main exe: `HOT.exe` (5.6 MB)
- Assets packed into `CDFILES.DAT` + `archive0.ar` pairs (`Data/` and `lData/`)
- Scripts are plain text (`.ls`)
- 30 cars, 16 levels, 4 zones (Bedroom, Mini Golf, Attic, Bowling Alley)

## Tools

### Technyx (upstream)

[Technyx](https://github.com/PredatorCZ/Technyx) extracts `cdfiles.dat` / `cdfiles.ar` pairs for Eutechnyx games, including Beat That PC. Build it from source (CMake, Release). Note: it expects the archive file named uppercase `ARCHIVE0.AR` — symlink it if yours is lowercase.

```bash
technyx_toolset cdfiles_extract "Data/CDFILES.DAT"
```

This produces a ZIP with all the extracted files (2,141 files, 1.47 GB for the main `Data` archive).

### ArcBank v5 converter (this repo)

Technyx's `arc_extract` only supports ArcBank **version 3**. Every `.ARC` file in Beat That is **version 5**, and patching the version check crashes with `std::bad_alloc`. So a standalone Python converter was built instead:

```
tools/arcbank-v5/
├── arcbank.py      — ArcBank v5 parser (header, entry table, buffers, meshes, models, textures)
├── arc_to_gltf.py  — converts a car *_LOD0_GRA.ARC to glTF 2.0 (.glb)
├── dxt.py          — DXT1/DXT3/RGBA4 texture decoder
└── README.md       — full format documentation
```

Usage:

```bash
python3 tools/arcbank-v5/arc_to_gltf.py BONESHAKER_LOD0_GRA.ARC boneshaker.glb
```

All 30 cars convert cleanly and import into Godot 4.3 with zero errors.

## What was cracked

**The v5 container is structurally identical to v3.** The header, the 16-byte entry table, the index/vertex buffers, meshes, and models all parse with the v3 layout. The Technyx crash has one specific cause: the **Material** entries. v5 materials use a different parameter layout — after the 24-byte header comes a float `1.0` (`0x3F800000`) where v3 expects a param count, so the v3 parser tries to allocate ~1 billion params and dies. That's the whole crash.

### ArcBank v5 format (summary)

- Header: 60 bytes (same struct as v3) + zero padding to `0x80`
- Entry table at `0x80`, 16-byte entries: `u32 index, u32 offset, i32 nameOffset, u8 type, u8 size[3]` (big-endian 24-bit size)
- **Entry offsets are relative to the end of the entry table** (`0x80 + 16×count`)
- Entry types: `0x01` Texture, `0x02` Material, `0x09` Mesh, `0x0f` IndexBuffer, `0x10` VertexBuffer, `0x1d` Model, `0xfd` EntryNames, `0xff` Group. One v5-only type `0x42` (24 bytes) remains unidentified.
- IndexBuffer: `u32 count` + `u16` indices (winding flipped per triangle for glTF)
- VertexBuffer: `u32 numVerts, u32 stride, u32 flags` + data. Attribute order in the file is **Position, Normal, Color, Uv0** (verified by unit-length normals).
- Mesh: 52-byte header + primitives with index/vertex clusters
- Model: 276-byte nodes (column-major matrices; game is Z-up, Y = length)
- Textures: `u32 width/height/numMips/hash/type` + mip data; type 26 = RGBA4, `"DXT1"` = BC1, `"DXT3"` = BC3

Full details in `tools/arcbank-v5/README.md`.

### Car models

Each car has `_LOD0_GRA.ARC` (high detail), `_LODX_GRA.ARC` (low detail), `_PHY.ARC` (physics, binary), `_SCR.ARC` (script, readable text), `_SND.HDR` + `_SND.RAW` (sounds).

Bone Shaker example: 3 meshes, 5 nodes (Body + 4 wheels), 8 body surfaces, ~79,250 triangles, bbox 2.7 wide × 2.0 tall × 5.8 long. Body texture includes the skull and crossbones, chrome underside, taillight, wheel rims.

All 30 cars: 2–3 meshes, 5 nodes, 8–16 materials, 6–9 embedded texture images, 80k–169k vertices each.

## Parsed data (this repo)

- `data/cars/cars.json` — all 30 cars' parsed script stats (mass, braking, gearbox ratios). Note: **all 30 cars share the same base stats** (mass 299, braking 0.7, final ratio 4.44, DEFAULT-GEARBOX), so per-car feel in the prototype comes from assigned speed/accel variation, not real per-car stats.
- `data/scripts/` — the 30 car `*_SCR.ARC` files (readable text) plus `GUN_SCR.ARC` (weapon script). Example (Bone Shaker):

```
ARCC / VEHICLE / VEHICLE-MOVER-TYPE / GSRACECAR / MOVER / APOINT 1053 /
NAME BONESHAKER / ARCHIVE DEFAULT / SCENE BODY / DYNAMICS MASS /
INERTIA 1500 1800 1200 / VELOCITY-DAMPING / ANGULAR-DAMPING /
PHYSICS-MODEL DEFAULT / CENTER-OF-MASS 0.051 0.10 / MATERIAL FRICTION /
DAMTAKEN / DAMGIVEN / LODS BRIDGE_PHYSICS_AUTO / DAMAGE COMPONENTs
(Front, Rear, SideL, SideR — each MAXHEALTH, MORPH targets, effects) /
VEHICLE-MOVER CHASSIS BRAKING 0.70 / RELATIVESPEED 0.50 /
GEARBOX DEFAULT-GEARBOX FINAL-RATIO 4.44 / REVERSE-RATIO / NUM-GEARS /
GEARS 1.27... / CONTROLLER AUTO
```

## Tracks / zones (not yet decoded)

- 353 zone/track-related files. `MAP-*` files are minimap overlay images, not geometry.
- Zone structure: ZONE1–4 (the 4 zones), ZONE12/13/14, ZONE21/22/23, ZONE31/32/33, ZONE41/42/43 (levels), each with `.LS.ARC` (readable script) and `.EPD.ARC`.
- `GLOBALPHY` files ZONE1000–1003, 2000–2003, 3000–3003, 4000–4003 hold the actual track physics/geometry — binary, **not yet decoded**.
- ZONE1.LS.ARC (readable): LANDBLOCK = zone2000, SKY = bedroomsky, SUNANGLE -150, AMBIENT-COLOUR, LIGHT-COLOUR, TIME, SHADOW-INTENSITY, LENSFLARE.

## Caveats

- Material→texture mapping in the converter is name-heuristic, not decoded from the file. Body materials get the `*BodyDA.png` texture, tyres get a `pwheel*.png`, chrome gets metallic PBR, lights get no texture. The v5 material params and texture bindings are partially decoded but the exact diffuse-slot mapping isn't proven — if a car looks wrong, the mapping is the first suspect.
- UVs are passed through unflipped — if textures appear upside down, flip V in the converter.
- Vertex `COLOR_0` is passed through as-is (RGBA8); the 4th byte may not be alpha on some cars.
- The `0x42` entry type is ignored.
- No visual render test was possible in the VM used for conversion (no GPU); validation is headless import + geometry/texture inspection only.

## The 30 cars

16ANGELS, 24SEVEN, BONESHAKER, BRUTALISTIC, BULLYGOAT, CHICANE, COOLONE, COVELITE, DACAR, DEMON, DIESELBOY, FORMUL8R, HELLFIRE, HOLLOWBACK, JACKHAMMER, MIDDRIFT, MSTSUZUKA, MUSCLETONE, NITRODOORSLAMMER, OFFTRACK, PHANTOMRACER, POWERBOMB, ROCKSTER, SHADOWMK2, SK2BATTLESPEC, SOOOFAST, SPECTYTE, SPEEDBUMP, SPINEBUSTER, SUPERTSUNAMI
