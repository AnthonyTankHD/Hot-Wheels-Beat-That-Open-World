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

## Repo layout

- `src/` — game source code
- `assets/` — game assets
- `mods/` — mod manager data and community mods
- `docs/` — design docs
