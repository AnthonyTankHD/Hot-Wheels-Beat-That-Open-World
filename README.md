# Hot Wheels Beat That — Open World City

An open-source, fully moddable open-world Hot Wheels city game, built on
Hot Wheels: Beat That! (2007, Eutechnyx) as reference and inspiration.

Drive a little Hot Wheels car through a full city built for it — streets,
skyscrapers, ramps off rooftops, loops, jumps, boost pads, neighborhoods
to explore. Free roam. No track walls.

This is a separate project from the
[Hot Wheels Hunt Book](https://github.com/AnthonyTankHD/Hot-Wheels-Hunt-Book-android)
Android app — but the two tie together: cars you unlock in the city sync
to your Hunt Book collection, and points and badges flow both ways. The
app is the hub, the game is the playground.

## Vision

- **Open world city** — a Hot Wheels city environment: downtown, docks,
  suburbs, all connected by track.
- **Open source** — MIT licensed. Anyone can read it, fork it, build on it.
- **Customizable** — custom cars, paint, tracks, city parts, neighborhoods.
- **Mod manager** — browse, download, and enable community-made mods
  (cars, tracks, skins, city parts) from inside the game.
- **Hunt Book tie-in** — unlocks and progress sync with the Hot Wheels
  Hunt Book Android app.

## Status

Early setup. The Beat That PC game files are being transferred so the
original cars, tracks, and assets can be studied and used as reference.
See [docs/GAME_PLAN.md](docs/GAME_PLAN.md) for the full plan.

## Project layout

- `src/` — game source code
- `assets/` — game assets (models, textures, audio)
- `mods/` — mod manager data and community mods
- `docs/` — design docs and the game plan
- `technyx/` — (not in this repo) the Technyx toolset used to extract
  Beat That's ArcBank archives lives in the workspace during research.

## License

MIT — see [LICENSE](LICENSE). Copyright (c) 2026 Anthony Tankersley.
