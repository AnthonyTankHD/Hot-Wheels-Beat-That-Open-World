class_name SettingsPanel
extends Control
# The one settings UI, used in two places:
#  - the standalone Settings screen (from the start menu)
#  - inside the pause menu (swapped in for the main panel)
# Camera, audio, and keyboard rebinds. Content lives in a
# ScrollContainer with a styled, always-visible-when-needed gold
# scrollbar, so the long controls list actually scrolls.
# Settings persist to user://settings.cfg via GameSettings and apply
# immediately; the host can pass apply_callback to refresh a live car
# (pause menu) after camera/volume changes.

var apply_callback: Callable = Callable()

var _rebinding: String = ""
var _rebind_buttons: Dictionary = {}
var _esc_cancelled: bool = false
var _scroll: ScrollContainer
var _cam_slider: HSlider
var _invert_check: CheckButton
var _master_slider: HSlider
var _engine_slider: HSlider

func _ready() -> void:
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	add_child(_scroll)
	_style_scrollbar(_scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(vbox)

	# --- Camera ---
	vbox.add_child(UiTheme.section_header("CAMERA"))
	vbox.add_child(_make_slider_row("Camera Sensitivity", GameSettings.cam_sensitivity, 0.5, 4.0, 0.1, _on_cam_sensitivity_changed, "_cam_slider", "%.1f"))
	_invert_check = CheckButton.new()
	_invert_check.text = "Invert Camera Y (right stick up / down)"
	_invert_check.button_pressed = GameSettings.invert_cam_y
	# Shrink to fit: the Godot 4 toggle switch draws on the RIGHT of
	# the text, so a full-width button would park it under the
	# scrollbar. Compact keeps it right next to the label.
	_invert_check.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_invert_check.add_theme_font_size_override("font_size", 17)
	_invert_check.add_theme_color_override("font_color", Color.WHITE)
	_invert_check.toggled.connect(_on_invert_toggled)
	vbox.add_child(_invert_check)

	# --- Audio ---
	vbox.add_child(UiTheme.section_header("AUDIO"))
	vbox.add_child(_make_slider_row("Master Volume", GameSettings.master_volume, 0.0, 1.0, 0.05, _on_master_volume_changed, "_master_slider", "%d%%"))
	vbox.add_child(_make_slider_row("Engine Volume", GameSettings.engine_volume, 0.0, 1.0, 0.05, _on_engine_volume_changed, "_engine_slider", "%d%%"))

	# --- Controls ---
	vbox.add_child(UiTheme.section_header("CONTROLS — CLICK A KEY TO REBIND IT"))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(grid)
	for action in GameSettings.REBINDABLE_ACTIONS:
		var name_label := _make_label(GameSettings.ACTION_LABELS[action])
		name_label.custom_minimum_size = Vector2(150, 0)
		grid.add_child(name_label)
		var key_btn := Button.new()
		key_btn.custom_minimum_size = Vector2(130, 34)
		key_btn.add_theme_font_size_override("font_size", 16)
		key_btn.pressed.connect(_on_rebind_pressed.bind(action))
		_rebind_buttons[action] = key_btn
		grid.add_child(key_btn)
		var pad_label := _make_label("Gamepad: " + GameSettings.GAMEPAD_LABELS[action])
		pad_label.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
		grid.add_child(pad_label)
	# Pause itself is fixed (Esc / Back) so it can't be rebound away.
	var pause_label := _make_label("Pause")
	pause_label.custom_minimum_size = Vector2(150, 0)
	grid.add_child(pause_label)
	grid.add_child(_make_label("Esc"))
	var pause_pad := _make_label("Gamepad: Back / View")
	pause_pad.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	grid.add_child(pause_pad)

	_refresh_controls()

# Gold scrollbar: dark track, gold thumb, chunky enough to see.
func _style_scrollbar(scroll: ScrollContainer) -> void:
	var vbar := scroll.get_v_scroll_bar()
	vbar.custom_minimum_size = Vector2(14, 0)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.02, 0.05, 0.16)
	track.set_corner_radius_all(5)
	vbar.add_theme_stylebox_override("background", track)
	vbar.add_theme_stylebox_override("scroll", track)
	var thumb := StyleBoxFlat.new()
	thumb.bg_color = UiTheme.GOLD
	thumb.set_corner_radius_all(5)
	thumb.content_margin_left = 2
	thumb.content_margin_right = 2
	thumb.content_margin_top = 2
	thumb.content_margin_bottom = 2
	vbar.add_theme_stylebox_override("grabber", thumb)
	var thumb_hot := thumb.duplicate() as StyleBoxFlat
	thumb_hot.bg_color = Color(1.0, 0.9, 0.4)
	vbar.add_theme_stylebox_override("grabber_highlight", thumb_hot)
	vbar.add_theme_stylebox_override("grabber_pressed", thumb_hot)

func scroll_to_bottom() -> void:
	if _scroll != null:
		_scroll.scroll_vertical = 100000

func is_rebinding() -> bool:
	return _rebinding != ""

# True once if the last rebind was cancelled with Esc. The host
# (pause menu) checks this before treating that same Esc as "resume".
func consume_esc_cancel() -> bool:
	if _esc_cancelled:
		_esc_cancelled = false
		return true
	return false

func _input(event: InputEvent) -> void:
	if _rebinding == "":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_rebinding = ""
			_esc_cancelled = true
			_refresh_controls()
		else:
			GameSettings.set_key(_rebinding, event.keycode)
			_rebinding = ""
			_refresh_controls()
		# Drop focus so a bound Space/Enter doesn't re-trigger the button.
		get_viewport().gui_release_focus()
		get_viewport().set_input_as_handled()

# ------------------------------------------------------------------ build

func _make_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l

func _make_slider_row(label_text: String, value: float, min_v: float, max_v: float, step: float, on_changed: Callable, slider_var: String, fmt: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := _make_label(label_text)
	label.custom_minimum_size = Vector2(190, 0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.value = value
	slider.custom_minimum_size = Vector2(220, 0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_slider(slider)
	slider.value_changed.connect(on_changed)
	row.add_child(slider)
	var value_label := _make_label(_fmt_value(value, fmt))
	value_label.custom_minimum_size = Vector2(48, 0)
	row.add_child(value_label)
	set(slider_var, slider)
	slider.set_meta("value_label", value_label)
	slider.set_meta("fmt", fmt)
	return row

func _fmt_value(value: float, fmt: String) -> String:
	if fmt == "%d%%":
		return "%d%%" % int(value * 100.0)
	return fmt % value

# ------------------------------------------------------------------ settings

func _notify_applied() -> void:
	if apply_callback.is_valid():
		apply_callback.call()

func _on_cam_sensitivity_changed(value: float) -> void:
	GameSettings.cam_sensitivity = value
	GameSettings.save_settings()
	_sync_slider_label(_cam_slider)
	_notify_applied()

func _on_invert_toggled(pressed: bool) -> void:
	GameSettings.invert_cam_y = pressed
	GameSettings.save_settings()
	_notify_applied()

func _on_master_volume_changed(value: float) -> void:
	GameSettings.master_volume = value
	GameSettings.apply_volumes()
	GameSettings.save_settings()
	_sync_slider_label(_master_slider)
	_notify_applied()

func _on_engine_volume_changed(value: float) -> void:
	GameSettings.engine_volume = value
	GameSettings.save_settings()
	_sync_slider_label(_engine_slider)
	_notify_applied()

func _sync_slider_label(slider: HSlider) -> void:
	if slider != null and slider.has_meta("value_label"):
		var label: Label = slider.get_meta("value_label")
		label.text = _fmt_value(slider.value, String(slider.get_meta("fmt")))

func _on_rebind_pressed(action: String) -> void:
	_rebinding = action
	_refresh_controls()
	var btn: Button = _rebind_buttons[action]
	btn.text = "Press a key... (Esc cancels)"

func _refresh_controls() -> void:
	for action in GameSettings.REBINDABLE_ACTIONS:
		var btn: Button = _rebind_buttons.get(action)
		if btn == null:
			continue
		if action == _rebinding:
			btn.text = "Press a key... (Esc cancels)"
		else:
			btn.text = GameSettings.key_name(action)
