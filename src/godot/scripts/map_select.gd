extends Control
# Map select — Hot Wheels City plus the four real maps from the
# original Hot Wheels Beat That! (2007), decoded from the game's own
# ArcBank data. No fake maps: every playable card is real geometry.
#
# Navigation: the WHOLE CARD is the selectable element. D-pad /
# arrow keys move card to card across the grid (explicit neighbours,
# so the uneven last row behaves), the focused card gets a thick
# gold ring, Enter / A (or a mouse click on the card) drives.
# Esc / B goes back.

var _cards: Array[Button] = []
var _back_btn: Button

# name, scene, minimap texture, descriptor lines (two short lines
# per card — the cards are compact so two rows fit on one screen)
const MAPS := [
	{
		"name": "HOT WHEELS CITY", "scene": "res://scenes/main.tscn",
		"minimap": "", "tag": "OPEN CITY",
		"lines": ["380 × 380 open city", "Streets • Ramps • Boost pads"],
	},
	{
		"name": "ATTIC", "scene": "res://scenes/zone_attic.tscn",
		"minimap": "res://data/maps/minimap-attic.png", "tag": "BEAT THAT! • ZONE 3",
		"lines": ["The original Attic room", "Train table • Big hills • Toys"],
	},
	{
		"name": "BEDROOM", "scene": "res://scenes/zone_bedroom.tscn",
		"minimap": "res://data/maps/minimap-bedroom.png", "tag": "BEAT THAT! • ZONE 1",
		"lines": ["The original Bedroom", "Dinosaur • Toys • Big furniture"],
	},
	{
		"name": "MINI GOLF", "scene": "res://scenes/zone_minigolf.tscn",
		"minimap": "res://data/maps/minimap-minigolf.png", "tag": "BEAT THAT! • ZONE 2",
		"lines": ["The original haunted Mini Golf", "Portcullis • Coffins • Axes"],
	},
	{
		"name": "BOWLING ALLEY", "scene": "res://scenes/zone_bowling.tscn",
		"minimap": "res://data/maps/minimap-bowling.png", "tag": "BEAT THAT! • ZONE 4",
		"lines": ["The original Bowling Alley", "Lanes • Ball return • Pins"],
	},
]

func _ready() -> void:
	add_child(UiTheme.background())

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	vbox.add_child(UiTheme.title_label("SELECT YOUR MAP", 40))
	vbox.add_child(UiTheme.body_label("Five maps — the open city plus the four original Beat That! rooms", 16, UiTheme.TEXT_DIM))

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 24)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(grid)
	for i in range(MAPS.size()):
		var m: Dictionary = MAPS[i]
		grid.add_child(_card_button(m))
	_wire_neighbors()

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 16)
	vbox.add_child(bottom)
	_back_btn = UiTheme.make_button("← BACK", UiTheme.GREY_BTN, Vector2(160, 48), 18)
	_back_btn.pressed.connect(_on_back)
	bottom.add_child(_back_btn)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(spacer)
	var hint := UiTheme.body_label("Arrows / D-pad — Move      Enter / A — Select      Esc / B — Back", 15, UiTheme.TEXT_DIM)
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bottom.add_child(hint)
	# Back sits under the grid: down from the bottom row lands on it.
	if _cards.size() >= 5:
		_cards[3].focus_neighbor_bottom = _cards[3].get_path_to(_back_btn)
		_cards[4].focus_neighbor_bottom = _cards[4].get_path_to(_back_btn)
		_back_btn.focus_neighbor_top = _back_btn.get_path_to(_cards[3])

	if not _cards.is_empty():
		_cards[0].grab_focus.call_deferred()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
		get_viewport().set_input_as_handled()

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/start_menu.tscn")

func _on_map_chosen(scene_path: String) -> void:
	CarData.selected_map = scene_path
	get_tree().change_scene_to_file("res://scenes/car_select.tscn")

# ------------------------------------------------------------------ cards

# Grid layout (3 columns, uneven last row):
#   [0 City] [1 Attic] [2 Bedroom]
#   [3 Mini Golf] [4 Bowling]
# Explicit neighbours so D-pad / arrows always land where the player
# expects, including down from Bedroom (no card below col 3) which
# lands on Bowling, the nearest card below.
func _wire_neighbors() -> void:
	if _cards.size() < 5:
		return
	var c: Array[Button] = _cards
	c[0].focus_neighbor_right = c[0].get_path_to(c[1])
	c[0].focus_neighbor_bottom = c[0].get_path_to(c[3])
	c[1].focus_neighbor_left = c[1].get_path_to(c[0])
	c[1].focus_neighbor_right = c[1].get_path_to(c[2])
	c[1].focus_neighbor_bottom = c[1].get_path_to(c[4])
	c[2].focus_neighbor_left = c[2].get_path_to(c[1])
	c[2].focus_neighbor_bottom = c[2].get_path_to(c[4])
	c[3].focus_neighbor_right = c[3].get_path_to(c[4])
	c[3].focus_neighbor_top = c[3].get_path_to(c[0])
	c[4].focus_neighbor_left = c[4].get_path_to(c[3])
	c[4].focus_neighbor_top = c[4].get_path_to(c[1])

# Gold ring drawn around the focused card (border only, so the card
# art shows through). The Button draws this over its normal/hover
# stylebox whenever it has focus.
func _focus_ring() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0)
	s.draw_center = false
	s.border_color = UiTheme.GOLD
	s.set_border_width_all(5)
	s.set_corner_radius_all(14)
	s.content_margin_left = 0
	s.content_margin_right = 0
	s.content_margin_top = 0
	s.content_margin_bottom = 0
	return s

# One whole-card button: the card art + text live inside it, and
# every child ignores the mouse so clicks land on the button itself.
# Enter / A on a focused card and a mouse click both fire pressed.
# NOTE: a Button does NOT size to its children, so the button's
# minimum height is a FIXED value matched to the compact content
# below. Measured under the real renderer (Xvfb, not headless —
# headless reports label heights 3x too tall): title 31 + tag 18 +
# minimap frame 80 + 2 lines 40 + drive 26 + 5 separations 25 = 220,
# plus the 24px of vbox offsets = 244, so a 254px button holds it
# with ~10px to spare. Measuring the content at build time does not
# work — Label minimum sizes resolve only once in the tree, so the
# measured value comes back ~0 and the grid makes the buttons ~56px
# tall with the content spilling out (seen in the first render
# check). Two rows of 254px cards + chrome fits a 720px screen.
func _card_button(m: Dictionary) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(340, 254)
	btn.add_theme_stylebox_override("normal", UiTheme.panel_style())
	btn.add_theme_stylebox_override("hover", UiTheme.panel_style(UiTheme.PANEL_BG.lightened(0.12), UiTheme.GOLD, 3, 14))
	btn.add_theme_stylebox_override("pressed", UiTheme.panel_style(UiTheme.PANEL_BG.darkened(0.15), UiTheme.GOLD, 3, 14))
	btn.add_theme_stylebox_override("focus", _focus_ring())
	btn.add_theme_stylebox_override("disabled", UiTheme.panel_style())
	btn.pressed.connect(_on_map_chosen.bind(String(m["scene"])))
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 16
	vbox.offset_top = 12
	vbox.offset_right = -16
	vbox.offset_bottom = -12
	vbox.add_theme_constant_override("separation", 5)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vbox)
	vbox.add_child(UiTheme.title_label(String(m["name"]), 22))
	var tag_color: Color = UiTheme.ORANGE if String(m["minimap"]) == "" else UiTheme.TEXT_DIM
	vbox.add_child(UiTheme.body_label(String(m["tag"]), 13, tag_color))
	if String(m["minimap"]) == "":
		vbox.add_child(_mini_map())
	else:
		vbox.add_child(_zone_minimap(String(m["minimap"])))
	for line in m["lines"]:
		vbox.add_child(UiTheme.body_label(line, 14))
	var drive := UiTheme.body_label("DRIVE  >", 18, UiTheme.ORANGE)
	drive.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(drive)
	_ignore_mouse_tree(vbox)
	_cards.append(btn)
	return btn

func _ignore_mouse_tree(root: Control) -> void:
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in root.get_children():
		if child is Control:
			_ignore_mouse_tree(child)

# The minimap frame: same dark panel + gold border as panel_style,
# but with only 4px content margins. panel_style's 16px top/bottom
# margins would make an 80px minimap into a 112px frame, which is
# what pushed the DRIVE label off the bottom of the card.
func _frame_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.02, 0.05, 0.16)
	s.border_color = UiTheme.GOLD_DARK
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	s.content_margin_left = 4
	s.content_margin_right = 4
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s

# The real track layout from the original game: the decoded
# IMG_MAPOVERLAY minimap (white ribbon on black), shown as-is.
func _zone_minimap(path: String) -> PanelContainer:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _frame_style())
	frame.custom_minimum_size = Vector2(300, 80)
	var tex: Texture2D = load(path)
	var rect := TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(300, 72)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(rect)
	return frame

# A small top-down sketch of the city: streets, building blocks,
# orange boost pads, red spawn dot. Decorative, not to scale.
func _mini_map() -> PanelContainer:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _frame_style())
	frame.custom_minimum_size = Vector2(300, 80)
	var map := Control.new()
	map.custom_minimum_size = Vector2(300, 72)
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(map)
	# Streets.
	for y in [16, 36, 56]:
		var h := ColorRect.new()
		h.color = Color(0.28, 0.33, 0.52)
		h.position = Vector2(0, y)
		h.size = Vector2(300, 5)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		map.add_child(h)
	for x in [66, 146, 226]:
		var v := ColorRect.new()
		v.color = Color(0.28, 0.33, 0.52)
		v.position = Vector2(x, 0)
		v.size = Vector2(5, 72)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		map.add_child(v)
	# Building blocks.
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in range(9):
		var bx := rng.randf_range(8.0, 260.0)
		var by := rng.randf_range(8.0, 56.0)
		var b := ColorRect.new()
		b.color = Color(0.10, 0.14, 0.34)
		b.position = Vector2(bx, by)
		b.size = Vector2(rng.randf_range(18.0, 34.0), rng.randf_range(10.0, 16.0))
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		map.add_child(b)
	# Boost pads (orange) on the streets.
	for pos in [Vector2(60, 16), Vector2(146, 36), Vector2(226, 56)]:
		var p := ColorRect.new()
		p.color = UiTheme.ORANGE
		p.position = pos + Vector2(-5, -3)
		p.size = Vector2(14, 7)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		map.add_child(p)
	# Spawn dot (red) at the centre plaza.
	var spawn := ColorRect.new()
	spawn.color = Color(1.0, 0.2, 0.2)
	spawn.position = Vector2(146, 32)
	spawn.size = Vector2(10, 10)
	spawn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map.add_child(spawn)
	return frame
