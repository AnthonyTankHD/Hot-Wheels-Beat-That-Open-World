extends Node3D
# Hot Wheels Beat That — Open World City
# Builds the city at runtime: blocks of buildings, ramps, boost pads,
# border walls, and the driving HUD. Esc / Back (gamepad) opens the
# pause menu (Resume / Settings / Change Car / Quit to Menu).

const WORLD_HALF := 190.0
# Spawn: (-20, -20) facing +Z down the x=-20 street. The old spawn at
# (0, 0) faced a building dead ahead (clear run only ~76 units — the
# playtest drove straight into it at ~73). The x=-20 line is the
# middle of the gap between the x=0 and x=-40 building columns, with
# a 200+ unit clear run to the border wall (raycast-verified).
const SPAWN := Vector3(-20, 1, -20)
const SPAWN_YAW := 0.0 # degrees; car faces +Z at 0

var _car: MVehicle3D
var _name_label: Label
var _speed_label: Label
var _boost_label: Label
var _pause_menu: PauseMenu
var _stuck_time := 0.0

func _ready() -> void:
	GameSettings.load_settings()
	_car = $Car
	var car_data: Dictionary = CarData.selected()
	_car.apply_car(car_data)
	_place_at_spawn()
	_build_city()
	_build_hud(car_data)
	_build_pause_menu()
	_car.apply_settings()

# Put the car on the spawn point, facing the spawn direction, with
# the chase camera already behind it (mirrors zone.gd).
func _place_at_spawn() -> void:
	_car.position = SPAWN
	_car.rotation = Vector3(0, deg_to_rad(SPAWN_YAW), 0)
	_car.linear_velocity = Vector3.ZERO
	_car.angular_velocity = Vector3.ZERO
	var anchor: Node3D = _car.get_node_or_null("Camera_Anchor")
	if anchor != null:
		anchor.rotation.y = deg_to_rad(SPAWN_YAW)

func _build_pause_menu() -> void:
	_pause_menu = PauseMenu.new()
	add_child(_pause_menu)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("change_car"):
		if _pause_menu != null and not _pause_menu.is_open():
			_pause_menu.open(_car, _apply_selected_car)
			get_viewport().set_input_as_handled()

# Swap in the car picked from the pause menu (or anywhere else):
# reload the model + drivetrain in place, refresh the camera distance
# for the new car's length, and update the HUD name.
func _apply_selected_car() -> void:
	var car_data: Dictionary = CarData.selected()
	_car.apply_car(car_data)
	_car.apply_settings()
	if _name_label != null:
		_name_label.text = car_data["name"]

func _process(_delta: float) -> void:
	if _speed_label != null and _car != null:
		_speed_label.text = "SPEED %d" % int(absf(_car.speed) * 4.0)
		if _car.boost_timer > 0.0:
			_boost_label.text = "BOOST!"
			_boost_label.visible = true
		else:
			_boost_label.visible = false
		# Wedged against a building with the gas floored and going
		# nowhere: respawn instead of sitting stuck. Same rule as the
		# zones (zone.gd): only when the player is actually holding
		# gas, so a parked car never resets out from under them.
		# The city had no reset at all — the playtest sat at speed 0
		# for 60+ game-seconds against a wall. Now it matches the zones.
		if Input.is_action_pressed("gas") and absf(_car.speed) < 0.5:
			_stuck_time += _delta
			if _stuck_time > 3.0:
				_place_at_spawn()
				_stuck_time = 0.0
		else:
			_stuck_time = 0.0

# ---------------------------------------------------------------- city

func _build_city() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	# Border walls so the car can't drive off the edge of the world.
	_add_wall(Vector3(0, 2, -WORLD_HALF), Vector3(380, 4, 2))
	_add_wall(Vector3(0, 2, WORLD_HALF), Vector3(380, 4, 2))
	_add_wall(Vector3(-WORLD_HALF, 2, 0), Vector3(2, 4, 380))
	_add_wall(Vector3(WORLD_HALF, 2, 0), Vector3(2, 4, 380))
	# City blocks: grid of buildings with streets between them.
	# Keep the middle plaza (around the spawn) clear.
	for gx in range(-4, 5):
		for gz in range(-4, 5):
			if abs(gx) <= 1 and abs(gz) <= 1:
				continue # spawn plaza stays open
			if rng.randf() < 0.25:
				continue # leave some blocks empty (parking lots)
			var x := gx * 40.0 + rng.randf_range(-6.0, 6.0)
			var z := gz * 40.0 + rng.randf_range(-6.0, 6.0)
			var h := rng.randf_range(6.0, 30.0)
			var w := rng.randf_range(14.0, 24.0)
			var d := rng.randf_range(14.0, 24.0)
			_add_building(Vector3(x, h * 0.5, z), Vector3(w, h, d), rng)
	# Ramps: angled boxes you can drive up (gentle 18-degree slope).
	_add_ramp(Vector3(60, 0, -60), 0.0)
	_add_ramp(Vector3(-70, 0, 40), PI * 0.5)
	_add_ramp(Vector3(20, 0, 100), PI)
	# Boost pads: glowing orange strips on the main streets.
	_add_boost_pad(Vector3(0, 0.1, -40), Vector3(0, 0, 0))
	_add_boost_pad(Vector3(-40, 0.1, 0), Vector3(0, PI * 0.5, 0))
	_add_boost_pad(Vector3(80, 0.1, 20), Vector3(0, PI * 0.25, 0))

func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	return m

func _add_wall(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _mat(Color(0.1, 0.15, 0.4))
	body.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	add_child(body)

func _add_building(pos: Vector3, size: Vector3, rng: RandomNumberGenerator) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	# Dark blue / grey towers; every third one gets a warm tint.
	var shade := rng.randf_range(0.10, 0.22)
	var tint := Color(shade, shade * 1.2, shade * 2.0)
	if rng.randf() < 0.33:
		tint = Color(shade * 1.4, shade, shade * 0.9)
	mesh.material_override = _mat(tint)
	body.add_child(mesh)
	# Orange roof trim so the skyline reads Hot Wheels at a glance.
	var trim := MeshInstance3D.new()
	var trim_box := BoxMesh.new()
	trim_box.size = Vector3(size.x + 0.6, 0.5, size.z + 0.6)
	trim.mesh = trim_box
	trim.position = Vector3(0, size.y * 0.5 + 0.2, 0)
	trim.material_override = _mat(Color(1.0, 0.55, 0.0))
	body.add_child(trim)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	add_child(body)

func _add_ramp(pos: Vector3, rot_y: float) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.y = rot_y
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(10, 1, 22)
	mesh.mesh = box
	mesh.material_override = _mat(Color(1.0, 0.55, 0.0))
	# Tilt the ramp so the far end is ~7 units high.
	mesh.rotation.x = -0.32
	body.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(10, 1, 22)
	col.shape = shape
	col.rotation.x = -0.32
	body.add_child(col)
	add_child(body)

func _add_boost_pad(pos: Vector3, rot: Vector3) -> void:
	var area := Area3D.new()
	area.position = pos
	area.rotation = rot
	area.monitoring = true
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(8, 0.2, 4)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.6, 0.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.45, 0.0)
	mat.emission_energy_multiplier = 2.0
	mesh.material_override = mat
	area.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(8, 2.0, 4)
	col.shape = shape
	area.add_child(col)
	area.body_entered.connect(_on_boost_pad_body_entered)
	add_child(area)

func _on_boost_pad_body_entered(body: Node3D) -> void:
	if body == _car:
		_car.boost()

# ------------------------------------------------------------------ HUD

func _build_hud(car_data: Dictionary) -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var name_label := Label.new()
	name_label.text = car_data["name"]
	name_label.position = Vector2(16, 12)
	name_label.add_theme_font_size_override("font_size", 32)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))
	name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0))
	name_label.add_theme_constant_override("shadow_offset_x", 2)
	name_label.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(name_label)
	_name_label = name_label
	_speed_label = Label.new()
	_speed_label.text = "SPEED 0"
	_speed_label.position = Vector2(16, 52)
	_speed_label.add_theme_font_size_override("font_size", 24)
	_speed_label.add_theme_color_override("font_color", Color.WHITE)
	_speed_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0))
	_speed_label.add_theme_constant_override("shadow_offset_x", 2)
	_speed_label.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(_speed_label)
	_boost_label = Label.new()
	_boost_label.text = "BOOST!"
	_boost_label.position = Vector2(16, 88)
	_boost_label.add_theme_font_size_override("font_size", 28)
	_boost_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.0))
	_boost_label.visible = false
	layer.add_child(_boost_label)
	var hint := Label.new()
	hint.text = "W/S gas & brake  |  A/D or left stick steer  |  Right stick camera  |  Space handbrake  |  Esc / Back: pause"
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -40
	hint.offset_bottom = -8
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0))
	hint.add_theme_constant_override("shadow_offset_x", 1)
	hint.add_theme_constant_override("shadow_offset_y", 1)
	layer.add_child(hint)
