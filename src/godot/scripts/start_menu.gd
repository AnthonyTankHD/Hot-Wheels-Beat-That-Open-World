extends Control
# Start menu — the first thing you see. Title, three clean choices,
# nothing else fighting for attention. Enter / A plays, arrows or
# D-pad move, Esc does nothing here (QUIT is the way out).

var _play_button: Button

func _ready() -> void:
	add_child(UiTheme.background())
	_build_skyline()

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	center.add_child(vbox)

	vbox.add_child(UiTheme.title_label("HOT WHEELS", 76))
	vbox.add_child(UiTheme.title_label("BEAT THAT!", 46, UiTheme.ORANGE))
	vbox.add_child(UiTheme.title_label("OPEN WORLD CITY", 22, UiTheme.GOLD))
	vbox.add_child(UiTheme.gold_bar(420))

	_play_button = UiTheme.make_button("PLAY", UiTheme.ORANGE)
	_play_button.pressed.connect(_on_play)
	vbox.add_child(_play_button)

	var settings_btn := UiTheme.make_button("SETTINGS", UiTheme.BLUE_BTN)
	settings_btn.pressed.connect(_on_settings)
	vbox.add_child(settings_btn)

	var quit_btn := UiTheme.make_button("QUIT", UiTheme.RED_BTN)
	quit_btn.pressed.connect(_on_quit)
	vbox.add_child(quit_btn)

	vbox.add_child(UiTheme.body_label("Enter / A — Play      Arrows / D-pad — Choose", 15, UiTheme.TEXT_DIM))

	if _play_button != null:
		_play_button.grab_focus.call_deferred()

# A quiet city skyline along the bottom edge — dark silhouettes only,
# so the menu stays the star of the show.
func _build_skyline() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var strip := HBoxContainer.new()
	strip.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	strip.offset_top = -80
	strip.add_theme_constant_override("separation", 6)
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(strip)
	for i in range(16):
		var h := rng.randf_range(28.0, 78.0)
		var w := rng.randf_range(34.0, 74.0)
		var b := ColorRect.new()
		# Lighter than the dark background bottom so the silhouette reads.
		b.color = Color(0.06, 0.14, 0.36)
		b.custom_minimum_size = Vector2(w, h)
		b.size_flags_vertical = Control.SIZE_SHRINK_END
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strip.add_child(b)
		# A couple of towers get a warm lit window strip.
		if rng.randf() < 0.3:
			var win := ColorRect.new()
			win.color = Color(1.0, 0.55, 0.0, 0.5)
			win.custom_minimum_size = Vector2(4, h * 0.5)
			win.size_flags_vertical = Control.SIZE_SHRINK_END
			win.mouse_filter = Control.MOUSE_FILTER_IGNORE
			strip.add_child(win)

func _on_play() -> void:
	get_tree().change_scene_to_file("res://scenes/map_select.tscn")

func _on_settings() -> void:
	SettingsMenu.return_scene = "res://scenes/start_menu.tscn"
	get_tree().change_scene_to_file("res://scenes/settings_menu.tscn")

func _on_quit() -> void:
	get_tree().quit()
