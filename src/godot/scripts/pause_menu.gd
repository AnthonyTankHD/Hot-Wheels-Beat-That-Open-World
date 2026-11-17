class_name PauseMenu
extends CanvasLayer
# Pause menu for the driving scene. Three clean panels that swap:
# main (Resume / Settings / Change Car / Quit to Menu), settings
# (the shared SettingsPanel — same UI as the standalone settings
# screen, with a real scrollbar), and the in-pause car list.
# process_mode is ALWAYS so it keeps working while the tree is paused.
# Esc / Back toggles it; the driving scene opens it, this menu closes it.
# Quit to Menu now returns to the START MENU (was: car select).

var _car: MVehicle3D = null
var _open := false
var _resume_button: Button
# The three panels swap; only one is visible at a time.
var _main_vbox: VBoxContainer
var _settings_vbox: VBoxContainer
var _settings_panel: SettingsPanel
var _car_list_vbox: VBoxContainer
var _on_car_picked: Callable = Callable()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	visible = false
	_build_ui()

func is_open() -> bool:
	return _open

func open(car: MVehicle3D, on_car_picked: Callable = Callable()) -> void:
	_car = car
	_on_car_picked = on_car_picked
	_open = true
	_show_main_panel()
	visible = true
	get_tree().paused = true
	if _resume_button != null:
		_resume_button.grab_focus()

func resume() -> void:
	_open = false
	visible = false
	get_tree().paused = false

func _input(event: InputEvent) -> void:
	if not _open:
		return
	# An Esc that just cancelled a key rebind is not a "resume".
	if _settings_panel != null and _settings_panel.consume_esc_cancel():
		return
	if event.is_action_pressed("change_car"):
		if _settings_panel != null and _settings_panel.is_rebinding():
			return # the panel is capturing the next key
		if _settings_vbox.visible or _car_list_vbox.visible:
			_show_main_panel()
		else:
			resume()
		get_viewport().set_input_as_handled()

# ------------------------------------------------------------------ UI

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style())
	center.add_child(panel)

	# --- Main panel ---
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	_main_vbox = vbox

	vbox.add_child(UiTheme.title_label("PAUSED", 40))

	_resume_button = UiTheme.make_button("RESUME", UiTheme.ORANGE, Vector2(420, 46), 20)
	_resume_button.pressed.connect(resume)
	vbox.add_child(_resume_button)

	var settings_btn := UiTheme.make_button("SETTINGS", UiTheme.BLUE_BTN, Vector2(420, 46), 20)
	settings_btn.pressed.connect(_show_settings_panel)
	vbox.add_child(settings_btn)

	var change_btn := UiTheme.make_button("CHANGE CAR", UiTheme.BLUE_BTN, Vector2(420, 46), 20)
	change_btn.pressed.connect(_show_car_list)
	vbox.add_child(change_btn)

	var quit_btn := UiTheme.make_button("QUIT TO MENU", UiTheme.RED_BTN, Vector2(420, 46), 20)
	quit_btn.pressed.connect(_go_to_main_menu)
	vbox.add_child(quit_btn)

	# --- Settings panel (shared SettingsPanel, scrolls) ---
	var settings_vbox := VBoxContainer.new()
	settings_vbox.add_theme_constant_override("separation", 10)
	settings_vbox.visible = false
	settings_vbox.custom_minimum_size = Vector2(600, 560)
	panel.add_child(settings_vbox)
	_settings_vbox = settings_vbox

	settings_vbox.add_child(UiTheme.title_label("SETTINGS", 32))
	_settings_panel = SettingsPanel.new()
	_settings_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_settings_panel.apply_callback = Callable(self, "_apply_car_settings")
	settings_vbox.add_child(_settings_panel)
	var settings_back_row := HBoxContainer.new()
	settings_back_row.alignment = BoxContainer.ALIGNMENT_CENTER
	settings_vbox.add_child(settings_back_row)
	var settings_back := UiTheme.make_button("BACK", UiTheme.GREY_BTN, Vector2(200, 46), 18)
	settings_back.pressed.connect(_show_main_panel)
	settings_back_row.add_child(settings_back)

	# --- In-pause car list (hidden until CHANGE CAR is pressed) ---
	var car_vbox := VBoxContainer.new()
	car_vbox.add_theme_constant_override("separation", 10)
	car_vbox.visible = false
	panel.add_child(car_vbox)
	_car_list_vbox = car_vbox

	car_vbox.add_child(UiTheme.title_label("PICK A CAR", 32))
	car_vbox.add_child(UiTheme.body_label("Picking a car swaps it in right where you are — no reload.", 15, UiTheme.TEXT_DIM))

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(460, 380)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	car_vbox.add_child(scroll)

	var car_grid := GridContainer.new()
	car_grid.columns = 2
	car_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	car_grid.add_theme_constant_override("h_separation", 8)
	car_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(car_grid)
	for car in CarData.CARS:
		var b := Button.new()
		b.text = "%s\nTop %d  Accel %d" % [car["name"], int(car["top_speed"]), int(car["accel"])]
		b.custom_minimum_size = Vector2(210, 56)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 16)
		var car_color: Color = car["color"]
		b.add_theme_stylebox_override("normal", UiTheme.button_stylebox(car_color, "normal"))
		b.add_theme_stylebox_override("hover", UiTheme.button_stylebox(car_color, "hover"))
		b.add_theme_stylebox_override("pressed", UiTheme.button_stylebox(car_color, "pressed"))
		b.add_theme_stylebox_override("focus", UiTheme.button_stylebox(car_color, "hover"))
		b.add_theme_color_override("font_color", Color.WHITE)
		b.pressed.connect(_pick_car.bind(String(car["key"])))
		car_grid.add_child(b)

	var back_row := HBoxContainer.new()
	back_row.alignment = BoxContainer.ALIGNMENT_CENTER
	car_vbox.add_child(back_row)
	var back_btn := UiTheme.make_button("BACK", UiTheme.GREY_BTN, Vector2(200, 46), 18)
	back_btn.pressed.connect(_show_main_panel)
	back_row.add_child(back_btn)

func _show_main_panel() -> void:
	if _main_vbox != null:
		_main_vbox.visible = true
	if _settings_vbox != null:
		_settings_vbox.visible = false
	if _car_list_vbox != null:
		_car_list_vbox.visible = false

func _show_settings_panel() -> void:
	if _main_vbox != null:
		_main_vbox.visible = false
	if _settings_vbox != null:
		_settings_vbox.visible = true
	if _car_list_vbox != null:
		_car_list_vbox.visible = false

func _show_car_list() -> void:
	if _main_vbox != null:
		_main_vbox.visible = false
	if _settings_vbox != null:
		_settings_vbox.visible = false
	if _car_list_vbox != null:
		_car_list_vbox.visible = true

# Pick a car from inside the pause menu: swap it in where the car
# already is (same spot, same city), update the HUD, and get driving.
func _pick_car(key: String) -> void:
	CarData.selected_key = key
	if _on_car_picked.is_valid():
		_on_car_picked.call()
	resume()

func _apply_car_settings() -> void:
	if _car != null:
		_car.apply_settings()

func _go_to_main_menu() -> void:
	get_tree().paused = false
	_open = false
	get_tree().change_scene_to_file("res://scenes/start_menu.tscn")
