class_name UiTheme
extends RefCounted
# One consistent metallic glossy theme for every menu in the game:
# start menu, map select, car select, pause menu, settings.
# Buttons are real metallic gradients (bright gloss band at the top,
# dark base at the bottom) with rounded corners, generated once per
# color and cached. Panels are dark navy with a gold border.
# Clean and organized is the rule: same sizes, same spacing, same
# colors everywhere — nothing ad-hoc per screen.

const GOLD := Color(1.0, 0.8, 0.0)
const GOLD_DARK := Color(0.72, 0.52, 0.0)
const ORANGE := Color(1.0, 0.55, 0.0)
const NAVY := Color(0.05, 0.12, 0.35)
const NAVY_DARK := Color(0.03, 0.07, 0.22)
const PANEL_BG := Color(0.04, 0.09, 0.28)
const TEXT_LIGHT := Color(0.85, 0.9, 1.0)
const TEXT_DIM := Color(0.72, 0.78, 0.92)
const BLUE_BTN := Color(0.1, 0.35, 0.9)
const RED_BTN := Color(0.5, 0.12, 0.2)
const GREY_BTN := Color(0.4, 0.4, 0.45)

static var _metal_cache: Dictionary = {}

# ------------------------------------------------------------------ metal

# Vertical gradient stops for the metallic look: bright gloss at the
# top, a white specular band just under it, the base color through
# the middle, dark at the bottom.
static func _gradient_color(t: float, stops: Array) -> Color:
	for i in range(stops.size() - 1):
		var t0: float = stops[i][0]
		var t1: float = stops[i + 1][0]
		if t >= t0 and t <= t1:
			var f := 0.0 if t1 <= t0 else (t - t0) / (t1 - t0)
			return (stops[i][1] as Color).lerp(stops[i + 1][1] as Color, f)
	return stops[stops.size() - 1][1]

# A rounded-corner glossy metal texture for one base color. Generated
# per row (fill_rect) so it is fast; only the corner pixels are set
# one by one for the rounded alpha.
static func metal_texture(base: Color, w: int = 256, h: int = 64, radius: int = 12) -> ImageTexture:
	var key := "%s|%d|%d|%d" % [base.to_html(), w, h, radius]
	if _metal_cache.has(key):
		return _metal_cache[key]
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var stops: Array = [
		[0.0, base.lightened(0.65)],
		[0.14, Color(1, 1, 1).lerp(base.lightened(0.45), 0.45)],
		[0.42, base],
		[0.75, base.darkened(0.18)],
		[1.0, base.darkened(0.42)],
	]
	for y in range(h):
		var t := float(y) / float(maxi(h - 1, 1))
		img.fill_rect(Rect2i(0, y, w, 1), _gradient_color(t, stops))
	# Rounded corners: punch transparent pixels outside the arc.
	var r := float(radius)
	for cy in range(radius):
		for cx in range(radius):
			var dx := float(cx) - r
			var dy := float(cy) - r
			if sqrt(dx * dx + dy * dy) > r:
				img.set_pixel(cx, cy, Color(0, 0, 0, 0))
				img.set_pixel(w - 1 - cx, cy, Color(0, 0, 0, 0))
				img.set_pixel(cx, h - 1 - cy, Color(0, 0, 0, 0))
				img.set_pixel(w - 1 - cx, h - 1 - cy, Color(0, 0, 0, 0))
	var tex := ImageTexture.create_from_image(img)
	_metal_cache[key] = tex
	return tex

static func button_stylebox(base: Color, variant: String) -> StyleBoxTexture:
	var c := base
	match variant:
		"hover":
			c = base.lightened(0.22)
		"pressed":
			c = base.darkened(0.25)
		"disabled":
			c = Color(0.32, 0.33, 0.38)
	var sb := StyleBoxTexture.new()
	sb.texture = metal_texture(c)
	sb.texture_margin_left = 14
	sb.texture_margin_right = 14
	sb.texture_margin_top = 14
	sb.texture_margin_bottom = 14
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb

static func make_button(text: String, base: Color, min_size: Vector2 = Vector2(320, 56), font_size: int = 20) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_stylebox_override("normal", button_stylebox(base, "normal"))
	b.add_theme_stylebox_override("hover", button_stylebox(base, "hover"))
	b.add_theme_stylebox_override("pressed", button_stylebox(base, "pressed"))
	b.add_theme_stylebox_override("focus", button_stylebox(base, "hover"))
	b.add_theme_stylebox_override("disabled", button_stylebox(base, "disabled"))
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color(1.0, 0.95, 0.7))
	b.add_theme_color_override("font_disabled_color", Color(0.68, 0.68, 0.72))
	return b

# ------------------------------------------------------------------ panels

static func panel_style(bg: Color = PANEL_BG, border: Color = GOLD, border_w: int = 3, radius: int = 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 20
	s.content_margin_right = 20
	s.content_margin_top = 16
	s.content_margin_bottom = 16
	return s

# Full-screen dark blue vertical gradient background.
static func background() -> TextureRect:
	var g := Gradient.new()
	# Set the two default points FIRST (offsets 0 and 1), then add
	# the mid point: set_color() addresses points by INDEX, so
	# calling it after add_point() would recolor the mid point and
	# leave the bottom point at the default white.
	g.set_color(0, Color(0.06, 0.16, 0.42))
	g.set_color(1, Color(0.02, 0.05, 0.18))
	g.add_point(0.55, Color(0.04, 0.10, 0.30))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	gt.width = 16
	gt.height = 720
	var tr := TextureRect.new()
	tr.texture = gt
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

# ------------------------------------------------------------------ labels

static func title_label(text: String, size: int = 48, color: Color = GOLD) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 3)
	l.add_theme_constant_override("shadow_offset_y", 3)
	return l

static func body_label(text: String, size: int = 17, color: Color = TEXT_LIGHT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

static func section_header(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", ORANGE)
	return l

# Thin gold divider bar, centred.
static func gold_bar(width: int = 420) -> CenterContainer:
	var c := CenterContainer.new()
	var bar := ColorRect.new()
	bar.color = GOLD
	bar.custom_minimum_size = Vector2(width, 3)
	c.add_child(bar)
	return c

# ------------------------------------------------------------------ sliders

# Gold knob on a dark track, orange fill — matches the buttons.
static func style_slider(s: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.02, 0.05, 0.16)
	track.set_corner_radius_all(4)
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	s.add_theme_stylebox_override("slider", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = ORANGE
	fill.set_corner_radius_all(4)
	fill.content_margin_top = 5
	fill.content_margin_bottom = 5
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	var knob := StyleBoxFlat.new()
	knob.bg_color = GOLD
	knob.set_corner_radius_all(9)
	knob.content_margin_left = 9
	knob.content_margin_right = 9
	knob.content_margin_top = 9
	knob.content_margin_bottom = 9
	s.add_theme_stylebox_override("grabber", knob)
	var knob_hot := knob.duplicate() as StyleBoxFlat
	knob_hot.bg_color = Color(1.0, 0.9, 0.4)
	s.add_theme_stylebox_override("grabber_highlight", knob_hot)
	s.add_theme_stylebox_override("grabber_pressed", knob_hot)
