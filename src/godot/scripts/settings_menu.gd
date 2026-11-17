class_name SettingsMenu
extends Control
# Standalone settings screen, reached from the start menu (and
# anywhere else that sets return_scene first). Same SettingsPanel
# as the pause menu, so there is exactly one settings UI in the game.
# Esc / B goes back to wherever you came from.

static var return_scene: String = "res://scenes/start_menu.tscn"

func _ready() -> void:
	GameSettings.load_settings()
	add_child(UiTheme.background())

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style())
	panel.custom_minimum_size = Vector2(700, 620)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	vbox.add_child(UiTheme.title_label("SETTINGS", 40))

	var settings_panel := SettingsPanel.new()
	settings_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	settings_panel.custom_minimum_size = Vector2(640, 440)
	vbox.add_child(settings_panel)

	var back_row := HBoxContainer.new()
	back_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(back_row)
	var back_btn := UiTheme.make_button("← BACK", UiTheme.GREY_BTN, Vector2(200, 48), 18)
	back_btn.pressed.connect(_on_back)
	back_row.add_child(back_btn)
	back_btn.grab_focus.call_deferred()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
		get_viewport().set_input_as_handled()

func _on_back() -> void:
	get_tree().change_scene_to_file(return_scene)
