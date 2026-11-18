extends Control
# Hot Wheels Beat That — Open World City
# Car selection screen: pick any of the 72 cars.
# Each car sits on a flat Hot Wheels blister-pack card (the card
# art Anthony sent, res://data/car_card_bg.png — bright blue, flame
# logo, track silhouette, "3+" bottom-left) — the car's real model
# thumbnail, pre-rendered once into res://data/car_thumbs/<key>.png
# by hub/td_thumbs.gd, sits in the middle of the art; the name and
# Top/Accel stats sit on the card's light strip in dark navy, with
# the car's roster color as a stripe along the bottom edge. Left
# side keeps the live 3D turntable preview of the highlighted car.
# Big readable cards, one scrollable grid.
# Keyboard: arrows to move, Enter to pick. Gamepad: D-pad / stick
# to move, A to pick. Mouse/touch: click a card (hover highlights
# it in the preview). The gold ring marks the focused/hovered card.

const MavsCarScript := preload("res://scripts/mavs_car.gd")
const CARD_ART := preload("res://data/car_card_bg.png")

const CARD_W := 260.0
const CARD_H := 394.0

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
	vbox.add_child(UiTheme.body_label("Click / tap a card to drive it, or use arrows + Enter (gamepad: D-pad + A)", 15, UiTheme.TEXT_DIM))

	# --- Preview (left) + card grid (right) ---
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

	# --- Scrollable grid of blister-pack cards ---
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
		var btn := _make_car_card(car)
		grid.add_child(btn)
		if _first_button == null:
			_first_button = btn

	# Focus the first card so keyboard/gamepad works immediately.
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

# ------------------------------------------------------------------ cards

# The blister-pack card: the Hot Wheels card art itself is the
# button background (StyleBoxTexture, same stylebox for every
# state). The art is 1354x2048 (aspect 0.661) and the card is
# 260x394 (aspect 0.660), so it fills the card with no visible
# distortion. The gold ring child marks focus/hover instead.
func _card_stylebox() -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = CARD_ART
	return sb

func _gold_ring() -> Panel:
	var ring := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = UiTheme.GOLD
	sb.set_border_width_all(5)
	sb.set_corner_radius_all(12)
	ring.add_theme_stylebox_override("panel", sb)
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.visible = false
	return ring

func _make_car_card(car: Dictionary) -> Button:
	var key := String(car["key"])
	var btn := Button.new()
	btn.text = ""
	btn.custom_minimum_size = Vector2(CARD_W, CARD_H)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_sb := _card_stylebox()
	btn.add_theme_stylebox_override("normal", card_sb)
	btn.add_theme_stylebox_override("hover", card_sb)
	btn.add_theme_stylebox_override("pressed", card_sb)
	btn.add_theme_stylebox_override("focus", card_sb)
	btn.add_theme_stylebox_override("disabled", card_sb)
	btn.pressed.connect(_on_car_picked.bind(key))

	# The car's real model (pre-rendered thumbnail). The thumbnail
	# is transparent, so the card art shows around the car; the car
	# itself sits in the middle band of the art, exactly where the
	# blister bubble sits on a real card. The thumbnail is 256x384,
	# the same aspect as the card, so it fills the card face.
	var thumb := TextureRect.new()
	var thumb_tex: Texture2D = load("res://data/car_thumbs/%s.png" % key.to_lower())
	if thumb_tex != null:
		thumb.texture = thumb_tex
	# EXPAND_IGNORE_SIZE MUST come before setting size: a Control's
	# size is clamped to its combined minimum size, and a
	# TextureRect's minimum size is the texture's native 256x384
	# unless expand is IGNORE_SIZE. Set size first and it sticks
	# at 256x384 and runs over the name label below (verified
	# rendered — that was the overlap bug).
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.position = Vector2(0, 0)
	thumb.size = Vector2(CARD_W, CARD_H)
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(thumb)

	# Car name on the card's light strip, dark navy on white (the
	# strip is the pale bottom of the card art, so gold text would
	# wash out — the shipped flat build used dark navy here).
	var name_label := Label.new()
	name_label.text = String(car["name"])
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.position = Vector2(8, 312)
	name_label.size = Vector2(CARD_W - 16, 34)
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color(0.05, 0.12, 0.35))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(name_label)

	var stats_label := Label.new()
	stats_label.text = "Top %d   •   Accel %d" % [int(car["top_speed"]), int(car["accel"])]
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.position = Vector2(8, 344)
	stats_label.size = Vector2(CARD_W - 16, 24)
	stats_label.add_theme_font_size_override("font_size", 15)
	stats_label.add_theme_color_override("font_color", Color(0.05, 0.12, 0.35))
	stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(stats_label)

	# The car's roster color as a stripe along the bottom edge —
	# the old grid told cars apart by color, and the stripe keeps
	# that cue on the cards.
	var stripe := ColorRect.new()
	stripe.color = car["color"]
	stripe.position = Vector2(0, CARD_H - 10)
	stripe.size = Vector2(CARD_W, 10)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(stripe)

	# Gold ring: the focus/hover mark. Shown while the card has
	# keyboard/gamepad focus or the mouse is over it.
	var ring := _gold_ring()
	btn.add_child(ring)
	var state := {"focused": false, "hovered": false, "ring": ring}
	btn.focus_entered.connect(_on_card_highlight.bind(state, true, "focused"))
	btn.focus_exited.connect(_on_card_highlight.bind(state, false, "focused"))
	btn.mouse_entered.connect(_on_card_highlight.bind(state, true, "hovered"))
	btn.mouse_exited.connect(_on_card_highlight.bind(state, false, "hovered"))
	# Highlighting a card (keyboard focus or mouse hover) shows its
	# real model in the preview on the left.
	btn.focus_entered.connect(_show_preview.bind(key))
	btn.mouse_entered.connect(_show_preview.bind(key))
	return btn

func _on_card_highlight(state: Dictionary, on: bool, which: String) -> void:
	state[which] = on
	(state["ring"] as Control).visible = bool(state["focused"]) or bool(state["hovered"])

func _on_car_picked(key: String) -> void:
	CarData.selected_key = key
	get_tree().change_scene_to_file(CarData.selected_map)
