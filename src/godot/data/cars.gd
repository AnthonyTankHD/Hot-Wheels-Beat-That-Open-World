class_name CarData
extends RefCounted
# All 72 cars: the 30 Hot Wheels: Beat That! cars (parsed from the real
# SCR files), 33 Planet Hot Wheels Highway 35 cars, the Iridium
# from Hot Wheels Unleashed 2, and 8 Hot Wheels Turbo Driver: Race
# The World cars from the .blend Anthony sent. Base stats in the SCR
# files are shared (DEFAULT-GEARBOX), so each car gets a distinct top
# speed / accel derived deterministically from its key. Colors are
# per-car so every pick looks different on the road.

static var selected_key: String = "BONESHAKER"
# Which map scene to load when a car is picked. Set by the map
# select screen; defaults to the Hot Wheels City.
static var selected_map: String = "res://scenes/main.tscn"

const CARS: Array = [
	{"key": "16ANGELS", "name": "16 Angels", "color": Color(0.156, 0.143, 0.950), "top_speed": 31.0, "accel": 21.0},
	{"key": "24SEVEN", "name": "24/Seven", "color": Color(0.950, 0.640, 0.143), "top_speed": 25.0, "accel": 21.0},
	{"key": "BONESHAKER", "name": "Bone Shaker", "color": Color(0.143, 0.950, 0.533), "top_speed": 29.0, "accel": 17.0},
	{"key": "BRUTALISTIC", "name": "Brutalistic", "color": Color(0.950, 0.842, 0.143), "top_speed": 31.0, "accel": 16.0},
	{"key": "BULLYGOAT", "name": "Bully Goat", "color": Color(0.950, 0.143, 0.250), "top_speed": 25.0, "accel": 17.0},
	{"key": "CHICANE", "name": "Chicane", "color": Color(0.950, 0.331, 0.143), "top_speed": 29.0, "accel": 17.0},
	{"key": "COOLONE", "name": "Cool One", "color": Color(0.950, 0.143, 0.143), "top_speed": 24.0, "accel": 21.0},
	{"key": "COVELITE", "name": "Covelite", "color": Color(0.950, 0.143, 0.667), "top_speed": 30.0, "accel": 20.0},
	{"key": "DACAR", "name": "DaCar", "color": Color(0.143, 0.210, 0.950), "top_speed": 25.0, "accel": 18.0},
	{"key": "DEMON", "name": "Demon", "color": Color(0.950, 0.143, 0.371), "top_speed": 25.0, "accel": 17.0},
	{"key": "DIESELBOY", "name": "Diesel Boy", "color": Color(0.143, 0.950, 0.587), "top_speed": 24.0, "accel": 21.0},
	{"key": "FORMUL8R", "name": "Formul8r", "color": Color(0.519, 0.143, 0.950), "top_speed": 31.0, "accel": 16.0},
	{"key": "HELLFIRE", "name": "Hellfire", "color": Color(0.950, 0.143, 0.654), "top_speed": 31.0, "accel": 20.0},
	{"key": "HOLLOWBACK", "name": "Hollowback", "color": Color(0.950, 0.143, 0.640), "top_speed": 32.0, "accel": 20.0},
	{"key": "JACKHAMMER", "name": "Jackhammer", "color": Color(0.735, 0.143, 0.950), "top_speed": 29.0, "accel": 20.0},
	{"key": "MIDDRIFT", "name": "Mid Drift", "color": Color(0.950, 0.425, 0.143), "top_speed": 27.0, "accel": 17.0},
	{"key": "MSTSUZUKA", "name": "MS-T Suzuka", "color": Color(0.143, 0.829, 0.950), "top_speed": 24.0, "accel": 20.0},
	{"key": "MUSCLETONE", "name": "Muscle Tone", "color": Color(0.950, 0.143, 0.748), "top_speed": 24.0, "accel": 21.0},
	{"key": "NITRODOORSLAMMER", "name": "Nitro Doorslammer", "color": Color(0.143, 0.950, 0.479), "top_speed": 25.0, "accel": 21.0},
	{"key": "OFFTRACK", "name": "Off Track", "color": Color(0.479, 0.950, 0.143), "top_speed": 29.0, "accel": 17.0},
	{"key": "PHANTOMRACER", "name": "Phantom Racer", "color": Color(0.950, 0.143, 0.183), "top_speed": 30.0, "accel": 18.0},
	{"key": "POWERBOMB", "name": "Power Bomb", "color": Color(0.425, 0.143, 0.950), "top_speed": 24.0, "accel": 17.0},
	{"key": "ROCKSTER", "name": "Rockster", "color": Color(0.371, 0.143, 0.950), "top_speed": 29.0, "accel": 19.0},
	{"key": "SHADOWMK2", "name": "Shadow Mk II", "color": Color(0.143, 0.950, 0.775), "top_speed": 29.0, "accel": 16.0},
	{"key": "SK2BATTLESPEC", "name": "SK2 Battlespec", "color": Color(0.950, 0.869, 0.143), "top_speed": 24.0, "accel": 18.0},
	{"key": "SOOOFAST", "name": "Sooo Fast", "color": Color(0.950, 0.210, 0.143), "top_speed": 29.0, "accel": 21.0},
	{"key": "SPECTYTE", "name": "Spectyte", "color": Color(0.950, 0.143, 0.883), "top_speed": 32.0, "accel": 18.0},
	{"key": "SPEEDBUMP", "name": "Speed Bump", "color": Color(0.143, 0.950, 0.479), "top_speed": 25.0, "accel": 18.0},
	{"key": "SPINEBUSTER", "name": "Spinebuster", "color": Color(0.143, 0.143, 0.950), "top_speed": 30.0, "accel": 22.0},
	{"key": "SUPERTSUNAMI", "name": "Super Tsunami", "color": Color(0.143, 0.950, 0.721), "top_speed": 25.0, "accel": 22.0},
	# Planet Hot Wheels Highway 35 cars (33) — split from the combined
	# "HW35 cars.glb" Anthony downloaded from Sketchfab. Skipped two
	# duplicates already in the roster: 24/Seven (24SEVEN) and
	# Muscle Tone (MUSCLETONE).
	{"key": "BACKDRAFT", "name": "BackDraft", "color": Color(0.143, 0.505, 0.95), "top_speed": 25.0, "accel": 16.0},
	{"key": "BALLISTIK", "name": "Ballistik", "color": Color(0.637, 0.95, 0.143), "top_speed": 25.0, "accel": 20.0},
	{"key": "CHARGER", "name": "Charger", "color": Color(0.95, 0.274, 0.143), "top_speed": 25.0, "accel": 22.0},
	{"key": "CORVETTE", "name": "Corvette", "color": Color(0.45, 0.45, 0.467), "top_speed": 31.0, "accel": 18.0},
	{"key": "COUPE", "name": "Coupe", "color": Color(0.95, 0.359, 0.143), "top_speed": 30.0, "accel": 16.0},
	{"key": "DEORA2", "name": "Deora II", "color": Color(0.143, 0.412, 0.95), "top_speed": 25.0, "accel": 22.0},
	{"key": "ELCAMINO", "name": "El Camino", "color": Color(0.45, 0.45, 0.45), "top_speed": 28.0, "accel": 22.0},
	{"key": "F150", "name": "F-150", "color": Color(0.95, 0.566, 0.143), "top_speed": 24.0, "accel": 21.0},
	{"key": "HWNOMAD", "name": "HW Nomad", "color": Color(0.143, 0.87, 0.95), "top_speed": 30.0, "accel": 21.0},
	{"key": "IROCFIREBIRD", "name": "Firebird IROC", "color": Color(0.183, 0.95, 0.143), "top_speed": 31.0, "accel": 22.0},
	{"key": "KRAZY8S", "name": "Krazy 8s", "color": Color(0.95, 0.572, 0.143), "top_speed": 30.0, "accel": 19.0},
	{"key": "MEGADUTY", "name": "Mega Duty", "color": Color(0.95, 0.448, 0.143), "top_speed": 27.0, "accel": 22.0},
	{"key": "MOTOCROSSED", "name": "Moto-Crossed", "color": Color(0.536, 0.505, 0.488), "top_speed": 32.0, "accel": 16.0},
	{"key": "POWEROCKET", "name": "Power Rocket", "color": Color(0.783, 0.143, 0.95), "top_speed": 24.0, "accel": 18.0},
	{"key": "POWERPIPES", "name": "Power Pipes", "color": Color(0.45, 0.45, 0.45), "top_speed": 32.0, "accel": 22.0},
	{"key": "POWERPISTONS", "name": "Power Pistons", "color": Color(0.95, 0.621, 0.143), "top_speed": 25.0, "accel": 18.0},
	{"key": "RAGEOUS", "name": "Rageous", "color": Color(0.143, 0.534, 0.95), "top_speed": 27.0, "accel": 22.0},
	{"key": "REDBARON", "name": "Red Baron", "color": Color(0.95, 0.435, 0.143), "top_speed": 30.0, "accel": 16.0},
	{"key": "ROADROCKET", "name": "Road Rocket", "color": Color(0.143, 0.95, 0.213), "top_speed": 29.0, "accel": 21.0},
	{"key": "ROADRUNNER", "name": "Road Runner", "color": Color(0.95, 0.593, 0.143), "top_speed": 29.0, "accel": 20.0},
	{"key": "SIDEDRAFT", "name": "Side Draft", "color": Color(0.95, 0.143, 0.711), "top_speed": 28.0, "accel": 21.0},
	{"key": "SILVERBULLET", "name": "Silver Bullet", "color": Color(0.95, 0.2, 0.143), "top_speed": 25.0, "accel": 17.0},
	{"key": "SLINGSHOT", "name": "Slingshot", "color": Color(0.48, 0.143, 0.95), "top_speed": 30.0, "accel": 18.0},
	{"key": "SPLITWINDOWVETTE", "name": "Split Window Corvette", "color": Color(0.95, 0.706, 0.143), "top_speed": 31.0, "accel": 17.0},
	{"key": "SWEET16", "name": "Sweet 16", "color": Color(0.95, 0.634, 0.143), "top_speed": 28.0, "accel": 22.0},
	{"key": "SWITCHBACK", "name": "Switchback", "color": Color(0.143, 0.496, 0.95), "top_speed": 27.0, "accel": 20.0},
	{"key": "TBIRD", "name": "'57 T-Bird", "color": Color(0.95, 0.352, 0.143), "top_speed": 28.0, "accel": 16.0},
	{"key": "THUNDERBOLT", "name": "Thunderbolt", "color": Color(0.423, 0.143, 0.95), "top_speed": 32.0, "accel": 18.0},
	{"key": "TOYOTARSC", "name": "Toyota RSC", "color": Color(0.95, 0.779, 0.143), "top_speed": 28.0, "accel": 20.0},
	{"key": "TWINMILL", "name": "Twin Mill", "color": Color(0.95, 0.213, 0.143), "top_speed": 32.0, "accel": 17.0},
	{"key": "VULTURE", "name": "Vulture", "color": Color(0.95, 0.466, 0.143), "top_speed": 27.0, "accel": 20.0},
	{"key": "WILDTHING", "name": "Wild Thing", "color": Color(0.604, 0.95, 0.143), "top_speed": 25.0, "accel": 21.0},
	{"key": "ZOTIC", "name": "Zotic", "color": Color(0.95, 0.613, 0.143), "top_speed": 25.0, "accel": 19.0},
	# Iridium from Hot Wheels Unleashed 2 (Sketchfab, Zorg_Sinister,
	# CC-BY-4.0) — skinned source, baked to the roster convention.
	{"key": "IRIDIUM", "name": "Iridium", "color": Color(0.143, 0.781, 0.95), "top_speed": 27.0, "accel": 17.0},
	# Hot Wheels Turbo Driver: Race The World cars (8) — from the
	# "Turbo Driver Cars.blend" Anthony sent, exported per car to
	# .glb (body Y-length scaled to 5.6, nose +Z, wheels as Body
	# children, textures embedded). Sharkruiser is #7 on Anthony's
	# Top 10. "Turbo Dakar" (not "Dakar") so it can never be read as
	# "DaCar" (DACAR) in the grid or the garage. Invader is a
	# 6-wheeler in the source: the middle front pair are static
	# rollers, the outer 4 spin.
	{"key": "ARACHNOROD", "name": "Arachnorod", "color": Color(0.143, 0.700, 0.143), "top_speed": 28.0, "accel": 19.0},
	{"key": "DAKAR", "name": "Turbo Dakar", "color": Color(0.950, 0.750, 0.400), "top_speed": 26.0, "accel": 18.0},
	{"key": "DRIFTKING", "name": "Drift King", "color": Color(0.143, 0.500, 0.950), "top_speed": 30.0, "accel": 20.0},
	{"key": "INVADER", "name": "Invader", "color": Color(0.600, 0.950, 0.143), "top_speed": 27.0, "accel": 19.0},
	{"key": "JETTHREAT", "name": "Jet Threat 4.0", "color": Color(0.950, 0.143, 0.500), "top_speed": 31.0, "accel": 17.0},
	{"key": "RD04", "name": "RD-04", "color": Color(0.550, 0.650, 0.750), "top_speed": 29.0, "accel": 18.0},
	{"key": "SHARKRUISER", "name": "Sharkruiser", "color": Color(0.143, 0.650, 0.800), "top_speed": 28.0, "accel": 20.0},
	{"key": "STOCKAR", "name": "Stockar", "color": Color(0.950, 0.850, 0.200), "top_speed": 25.0, "accel": 21.0},
]

static func get_car(key: String) -> Dictionary:
	for c in CARS:
		if c["key"] == key:
			return c
	return CARS[2] # Bone Shaker fallback

static func selected() -> Dictionary:
	return get_car(selected_key)
