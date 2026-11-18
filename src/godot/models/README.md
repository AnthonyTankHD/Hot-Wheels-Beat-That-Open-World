# Car models & maps

## Cars — 72 of them

One `.glb` file per car in this folder: the 30 original Hot Wheels: Beat That! cars, 33 Planet Hot Wheels Highway 35 cars, the Iridium from Hot Wheels Unleashed 2, and 8 Hot Wheels Turbo Driver: Race The World cars (Arachnorod, Turbo Dakar, Drift King, Invader, Jet Threat 4.0, RD-04, Sharkruiser, Stockar).

- The roster (names, colors, speeds) lives in `../data/cars.gd`.
- The car picker screen is `../scripts/car_select.gd`.
- The car picker cards show a rendered thumbnail per car, stored in `../data/car_thumbs/`.
- Note: `iridium.glb` is NOT in this folder on GitHub — it's too big for a normal upload, so it lives on the [v0.1-assets release](https://github.com/AnthonyTankHD/Hot-Wheels-Beat-That-Open-World/releases/tag/v0.1-assets). Download it and drop it in here; without it, Iridium is missing from the car list.

## How the cars drive

That's the physics, not the models — see `../addons/M.A.V.S/` (the M.A.V.S. driving system) and `../scripts/mavs_car.gd` (our setup that wires these models into it).

## Maps — the 4 original zones

`zones/` holds the four real maps from the 2007 game, fresh-ported 2026-11-17:

- `zone1000.bin` — Attic
- `zone2000.bin` — Bedroom
- `zone3000.bin` — Bowling Alley (lane + north floor baked in)
- `zone4000.bin` — Mini Golf

Loaded at runtime by `../scripts/zone.gd`. The city is built by `../scripts/city.gd`, not a file here.

The `.png` files next to each car are its textures (already inside the `.glb` files). The `.import` files are Godot's — leave them alone.
