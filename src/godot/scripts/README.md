# Scripts — what each one does

- `car_select.gd` — the car picker screen (3D preview + car grid).
- `mavs_car.gd` — **driving physics glue**: takes the real car models from `../models/` and plugs them into the M.A.V.S. physics system. Also gives the Phantom Racer its green window tint.
- `city.gd` — builds the open-world city and runs driving there (spawns, stuck reset, HUD).
- `zone.gd` — loads the four original maps from `../models/zones/`, places the car, sets up the cameras and the stuck reset.
- `map_select.gd` — the map picker screen (City + 4 original zones).
- `start_menu.gd` — the start menu (Play / Settings / Quit).
- `pause_menu.gd` — the pause menu while driving.
- `settings.gd` — saved settings (camera, volume, controls).
- `settings_menu.gd` — the standalone Settings screen.
- `settings_panel.gd` — the one settings UI, used by both the Settings screen and the pause menu.
- `ui_theme.gd` — the shared glossy look for all the menus.

Where the driving physics itself lives: `../addons/M.A.V.S/` — the M.A.V.S. vehicle system (see its own README.md in that folder). The car list lives in `../data/cars.gd`.
