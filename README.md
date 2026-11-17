# Hot Wheels Beat That — Open World City

An open-source, fully moddable open-world Hot Wheels city game, built on Hot Wheels: Beat That! (2007, Eutechnyx) as reference and inspiration.

Drive a little Hot Wheels car through a full city built for it — streets, skyscrapers, ramps off rooftops, loops, jumps, boost pads, neighborhoods to explore. Free roam. No track walls.

This is a separate project from the Hot Wheels Hunt Book Android app — but the two tie together: cars you unlock in the city sync to your Hunt Book collection, and points and badges flow both ways. The app is the hub, the game is the playground.

## Vision

- **Open world city** — a Hot Wheels city environment: downtown, docks, suburbs, all connected by track.
- **Open source** — MIT licensed. Anyone can read it, fork it, build on it.
- **Customizable** — custom cars, paint, tracks, city parts, neighborhoods.
- **Mod manager** — browse, download, and enable community-made mods (cars, tracks, skins, city parts) from inside the game.
- **Hunt Book tie-in** — unlocks and progress sync with the Hot Wheels Hunt Book Android app.

## Status

Playable prototype: 64 cars (30 original Beat That cars, 33 Highway 35 cars, Iridium), a drivable city plus the 4 original zones (Attic, Bedroom, Bowling Alley, Mini Golf). See docs/GAME_PLAN.md for the full plan.

## Setup

Open `src/godot/project.godot` in Godot 4.3. First open imports the project (64 cars, 4 zones) — give it a few minutes.

## Large files (download from the Release)

Three files are too big for normal repo uploads, so they live on the [v0.1-assets release](https://github.com/AnthonyTankHD/Hot-Wheels-Beat-That-Open-World/releases/tag/v0.1-assets) — download them and drop them in:

- `src/godot/models/zones/zone1000.bin` — Attic landblock
- `src/godot/models/zones/zone2000.bin` — Bedroom landblock
- `src/godot/models/iridium.glb` — Iridium (Hot Wheels Unleashed 2)

Godot picks them up on first open. Without them, the Attic and Bedroom zones load empty and Iridium is missing from the car list.

## Project layout

- `src/` — game source code
- `assets/` — game assets (models, textures, audio)
- `mods/` — mod manager data and community mods
- `docs/` — design docs and the game plan
- `technyx/` — (not in this repo) the Technyx toolset used to extract Beat That's ArcBank archives lives in the workspace during research.

## License

MIT — see LICENSE. Copyright (c) 2026 Anthony Tankersley.
