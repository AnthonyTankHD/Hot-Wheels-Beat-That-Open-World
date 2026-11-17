class_name GameSettings
extends RefCounted
# Persistent game settings: camera, volume, keyboard bindings.
# Stored in user://settings.cfg (ConfigFile). Joypad bindings are the
# project defaults and are shown read-only in the pause menu.

const SAVE_PATH := "user://settings.cfg"

static var cam_sensitivity: float = 2.0
static var invert_cam_y: bool = false
static var master_volume: float = 0.8
static var engine_volume: float = 0.8
# action name -> keycode (keyboard only)
static var keys: Dictionary = {}
static var _loaded := false
static var _joypad_events: Dictionary = {}

const REBINDABLE_ACTIONS: Array = [
	"gas", "brake", "steer_left", "steer_right",
	"Hand Brake", "Shift Up", "Shift Down",
	"Lights", "Camera Change", "Reset", "Nitro",
]
const DEFAULT_KEYS: Dictionary = {
	"gas": KEY_W, "brake": KEY_S,
	"steer_left": KEY_A, "steer_right": KEY_D,
	"Hand Brake": KEY_SPACE, "Shift Up": KEY_Q, "Shift Down": KEY_E,
	"Lights": KEY_F, "Camera Change": KEY_V, "Reset": KEY_R, "Nitro": KEY_Z,
}
const ACTION_LABELS: Dictionary = {
	"gas": "Gas", "brake": "Brake",
	"steer_left": "Steer Left", "steer_right": "Steer Right",
	"Hand Brake": "Handbrake", "Shift Up": "Shift Up", "Shift Down": "Shift Down",
	"Lights": "Lights", "Camera Change": "Switch Camera",
	"Reset": "Reset Car", "Nitro": "Nitro",
}
const GAMEPAD_LABELS: Dictionary = {
	"gas": "RT", "brake": "LT",
	"steer_left": "Left Stick / D-Pad Left", "steer_right": "Left Stick / D-Pad Right",
	"Hand Brake": "A", "Shift Up": "RB", "Shift Down": "LB",
	"Lights": "Left Stick Click", "Camera Change": "Y",
	"Reset": "Right Stick Click", "Nitro": "X",
}

static func load_settings() -> void:
	if _loaded:
		return
	_loaded = true
	# Capture the project-default joypad events before any rebind,
	# so rebinding a key never wipes the gamepad bindings.
	for action in REBINDABLE_ACTIONS:
		var joy: Array = []
		if InputMap.has_action(action):
			for ev in InputMap.action_get_events(action):
				if ev is InputEventJoypadMotion or ev is InputEventJoypadButton:
					joy.append(ev)
		_joypad_events[action] = joy
	keys = DEFAULT_KEYS.duplicate()
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		cam_sensitivity = float(cfg.get_value("camera", "sensitivity", cam_sensitivity))
		invert_cam_y = bool(cfg.get_value("camera", "invert_y", invert_cam_y))
		master_volume = float(cfg.get_value("audio", "master", master_volume))
		engine_volume = float(cfg.get_value("audio", "engine", engine_volume))
		for action in REBINDABLE_ACTIONS:
			if cfg.has_section_key("keys", action):
				keys[action] = int(cfg.get_value("keys", action))
	cam_sensitivity = clampf(cam_sensitivity, 0.5, 4.0)
	master_volume = clampf(master_volume, 0.0, 1.0)
	engine_volume = clampf(engine_volume, 0.0, 1.0)
	apply_volumes()
	apply_key_bindings()

static func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("camera", "sensitivity", cam_sensitivity)
	cfg.set_value("camera", "invert_y", invert_cam_y)
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "engine", engine_volume)
	for action in REBINDABLE_ACTIONS:
		cfg.set_value("keys", action, int(keys.get(action, DEFAULT_KEYS[action])))
	cfg.save(SAVE_PATH)

static func apply_volumes() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.001)))

static func apply_key_bindings() -> void:
	for action in REBINDABLE_ACTIONS:
		if not InputMap.has_action(action):
			continue
		InputMap.action_erase_events(action)
		for ev in _joypad_events.get(action, []):
			InputMap.action_add_event(action, ev)
		var key_ev := InputEventKey.new()
		key_ev.keycode = int(keys.get(action, DEFAULT_KEYS[action]))
		InputMap.action_add_event(action, key_ev)

# Assign a new keyboard key to an action. If the key is already used by
# another rebindable action, that action falls back to its default key.
static func set_key(action: String, keycode: Key) -> void:
	for other in REBINDABLE_ACTIONS:
		if other != action and int(keys.get(other, DEFAULT_KEYS[other])) == int(keycode):
			keys[other] = DEFAULT_KEYS[other]
	keys[action] = int(keycode)
	apply_key_bindings()
	save_settings()

static func key_name(action: String) -> String:
	return OS.get_keycode_string(int(keys.get(action, DEFAULT_KEYS[action])))
