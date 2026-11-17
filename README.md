# Hot Wheels Beat That! — Open World City

Open-world Hot Wheels city mod of Hot Wheels: Beat That! (PC, 2007) built in Godot 4.3. Steam Deck native (SteamOS), also Linux, Windows, Mac. MIT licensed.

## Setup

Open `src/godot/project.godot` in Godot 4.3. First open imports the project (64 cars, 4 zones) — give it a few minutes.

## Large files (download from the Release)

Three files are too big for normal repo uploads, so they live on the [v0.1-assets release](https://github.com/AnthonyTankHD/Hot-Wheels-Beat-That-Open-World/releases/tag/v0.1-assets) — download them and drop them in:

- `src/godot/models/zones/zone1000.bin` — Attic landblock
- `src/godot/models/zones/zone2000.bin` — Bedroom landblock
- `src/godot/models/iridium.glb` — Iridium (Hot Wheels Unleashed 2)

Godot picks them up on first open. Without them, the Attic and Bedroom zones load empty and Iridium is missing from the car list.
