extends Control
# Hot Wheels Beat That — Open World City
# Car selection screen: pick any of the 30 real Beat That cars.
# Left side shows a live 3D preview of the highlighted car (the real
# .glb model, slowly turning); right side is the grid of all cars.
# Keyboard: arrows to move, Enter to pick. Gamepad: D-pad / stick
# to move, A to pick. Mouse/touch: click a car (hover highlights it
# in the preview).

const MavsCarScript := preload("res://scripts/mavs_car.gd")

var _first_button: Button = null
var _preview_key := ""
var _turntable: Node3D
var _preview_model: Node = null
var _preview_name: Label
var _preview_stats: Label

func _ready() -> void:
	# --- Root styling: glossy dark-blue gradient background ---
	add_child(UiTheme.background())

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# --- Top bar: back button left, title centred ---
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 12)
	vbox.add_child(top_bar)
	var back_btn := UiTheme.make_button("← MAPS", UiTheme.GREY_BTN, Vector2(140, 44), 18)
	back_btn.pressed.connect(_on_back)
	top_bar.add_child(back_btn)
	var title := UiTheme.title_label("HOT WHEELS BEAT THAT", 44)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(title)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(140, 0)
	top_bar.add_child(spacer)

	vbox.add_child(UiTheme.body_label("PICK YOUR CAR  —  %d CARS  —  OPEN CITY" % CarData.CARS.size(), 20, UiTheme.ORANGE))
	vbox.add_child(UiTheme.body_label("Click / tap a car to drive it, or use arrows + Enter (gamepad: D-pad + A)", 15, UiTheme.TEXT_DIM))

	# --- Preview (left) + car grid (right) ---
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(hbox)

	# Preview panel.
	var preview_vbox := VBoxContainer.new()
	preview_vbox.add_theme_constant_override("separation", 8)
	preview_vbox.custom_minimum_size = Vector2(400, 0)
	hbox.add_child(preview_vbox)

	var preview_frame := PanelContainer.new()
	preview_frame.add_theme_stylebox_override("panel", UiTheme.panel_style())
	preview_vbox.add_child(preview_frame)

	var vp_container := SubViewportContainer.new()
	vp_container.custom_minimum_size = Vector2(400, 400)
	vp_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_frame.add_child(vp_container)
	_build_preview_viewport(vp_container)

	_preview_name = Label.new()
	_preview_name.text = ""
	_preview_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_name.add_theme_font_size_override("font_size", 28)
	_preview_name.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))
	preview_vbox.add_child(_preview_name)

	_preview_stats = Label.new()
	_preview_stats.text = ""
	_preview_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_stats.add_theme_font_size_override("font_size", 17)
	_preview_stats.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	preview_vbox.add_child(_preview_stats)

	# --- Scrollable grid of cars ---
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hbox.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)

	for car in CarData.CARS:
		var btn := _make_car_button(car)
		grid.add_child(btn)
		if _first_button == null:
			_first_button = btn

	# Focus the first car so keyboard/gamepad works immediately.
	if _first_button != null:
		_first_button.grab_focus.call_deferred()

	# Show the currently selected car in the preview (or the first).
	_show_preview(CarData.selected_key)

func _process(delta: float) -> void:
	# Slow turntable spin so the player sees the car from all sides.
	if _turntable != null:
		_turntable.rotation.y += 0.35 * delta

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
		get_viewport().set_input_as_handled()

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/map_select.tscn")

# ------------------------------------------------------------------ preview

func _build_preview_viewport(container: SubViewportContainer) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(400, 400)
	vp.transparent_bg = false
	container.add_child(vp)

	# Lighting for the preview: dark blue backdrop, bright ambient,
	# and a key light so the paint and chrome read properly.
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.12, 0.35)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.9, 1.0)
	env.ambient_light_energy = 1.0
	world_env.environment = env
	vp.add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.4
	sun.shadow_enabled = false
	vp.add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 150, 0)
	fill.light_energy = 0.5
	fill.shadow_enabled = false
	vp.add_child(fill)

	var cam := Camera3D.new()
	cam.position = Vector3(0, 2.1, 10.5)
	cam.fov = 50.0
	cam.current = true
	vp.add_child(cam)
	# Look slightly down at the car's middle.
	cam.look_at(Vector3(0, 0.6, 0), Vector3.UP)

	_turntable = Node3D.new()
	_turntable.name = "Turntable"
	vp.add_child(_turntable)

func _find_body_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D and node.name.to_lower() == "body":
		return node
	for child in node.get_children():
		var found := _find_body_mesh(child)
		if found != null:
			return found
	return null

# Load the real .glb for a car and put it on the turntable, centred
# with its tyres on y = 0. Chrome is tamed the same way as in the
# game so the rims read as silver, not flat grey.
func _show_preview(key: String) -> void:
	if key == _preview_key and _preview_model != null:
		return
	_preview_key = key
	if _preview_model != null:
		_preview_model.free()
		_preview_model = null
	var path := "res://models/%s.glb" % key.to_lower()
	var packed: PackedScene = load(path)
	if packed == null:
		push_error("[car_select] could not load preview model: " + path)
		return
	var inst: Node = packed.instantiate()
	inst.name = "PreviewModel"
	# Same counter-rotation as the game: the .glb Body node carries a
	# -90deg X rotation while the vertices are already Y-up.
	inst.rotation.x = PI * 0.5
	_turntable.add_child(inst)
	_preview_model = inst
	var body := _find_body_mesh(inst)
	if body != null:
		# The instance rotation cancels the Body node's own rotation,
		# so the Body's local AABB maps 1:1 to preview space.
		var aabb: AABB = body.get_aabb()
		inst.position = Vector3(-aabb.get_center().x, -aabb.position.y, -aabb.get_center().z)
	MavsCarScript.tame_chrome_tree(inst)
	# Metallic glossy die-cast finish on the body paint, same as in
	# the game (tyres, glass and chrome untouched).
	if body != null:
		var glossed := MavsCarScript.gloss_body_paint(body)
		print("[car_select] glossed ", glossed, " paint surfaces (", key, ")")
	# Phantom Racer only: green window tint, same as in the game.
	if key == "PHANTOMRACER":
		MavsCarScript.tint_glass_green_tree(inst)
	# Update the labels under the preview.
	for car in CarData.CARS:
		if String(car["key"]) == key:
			_preview_name.text = String(car["name"])
			_preview_stats.text = "Top Speed %d   •   Accel %d" % [int(car["top_speed"]), int(car["accel"])]
			break

# ------------------------------------------------------------------ grid

func _make_car_button(car: Dictionary) -> Button:
	var btn := Button.new()
	btn.text = "%s\nTop %d  Accel %d" % [car["name"], int(car["top_speed"]), int(car["accel"])]
	btn.custom_minimum_size = Vector2(250, 84)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 20)
	# Glossy metal in the car's own color, so the grid reads as a
	# row of paint swatches with a consistent gold look.
	var car_color: Color = car["color"]
	btn.add_theme_stylebox_override("normal", UiTheme.button_stylebox(car_color, "normal"))
	btn.add_theme_stylebox_override("hover", UiTheme.button_stylebox(car_color, "hover"))
	btn.add_theme_stylebox_override("pressed", UiTheme.button_stylebox(car_color, "pressed"))
	btn.add_theme_stylebox_override("focus", UiTheme.button_stylebox(car_color, "hover"))
	btn.add_theme_stylebox_override("disabled", UiTheme.button_stylebox(car_color, "disabled"))
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_focus_color", Color(1.0, 0.95, 0.7))
	btn.pressed.connect(_on_car_picked.bind(car["key"]))
	# Highlighting a car (keyboard focus or mouse hover) shows its
	# real model in the preview on the left.
	btn.focus_entered.connect(_show_preview.bind(car["key"]))
	btn.mouse_entered.connect(_show_preview.bind(car["key"]))
	return btn

func _on_car_picked(key: String) -> void:
	CarData.selected_key = key
	get_tree().change_scene_to_file(CarData.selected_map)
