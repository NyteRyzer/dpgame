extends RefCounted
## Fenton-computer UI styling: dark glass panels with ectoplasmic green trim.

const GREEN := Color(0.3, 1.0, 0.5)
const GREEN_DIM := Color(0.15, 0.55, 0.3)
const PANEL := Color(0.03, 0.07, 0.06, 0.82)
const TEXT := Color(0.88, 1.0, 0.92)
const WARN := Color(1.0, 0.45, 0.4)


static func panel(border := GREEN_DIM, bg := PANEL, radius := 8, width := 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	s.shadow_color = Color(GREEN, 0.15)
	s.shadow_size = 6
	return s


static func bar_style(c: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(4)
	return s


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 18
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.9))
	t.set_constant("outline_size", "Label", 4)
	t.set_stylebox("panel", "PanelContainer", panel())
	t.set_stylebox("panel", "Panel", panel())
	var normal := panel(GREEN_DIM, Color(0.05, 0.12, 0.09, 0.9), 6)
	var hover := panel(GREEN, Color(0.08, 0.22, 0.14, 0.95), 6)
	var pressed := panel(GREEN, Color(0.15, 0.4, 0.22, 0.95), 6)
	var disabled := panel(Color(0.25, 0.3, 0.28), Color(0.05, 0.06, 0.06, 0.8), 6)
	for type in ["Button", "OptionButton"]:
		t.set_stylebox("normal", type, normal)
		t.set_stylebox("hover", type, hover)
		t.set_stylebox("pressed", type, pressed)
		t.set_stylebox("focus", type, hover)
		t.set_stylebox("disabled", type, disabled)
		t.set_color("font_color", type, TEXT)
		t.set_color("font_hover_color", type, Color(1, 1, 1))
		t.set_color("font_pressed_color", type, GREEN)
		t.set_color("font_disabled_color", type, Color(0.45, 0.5, 0.48))
	t.set_stylebox("normal", "LineEdit", normal)
	t.set_stylebox("focus", "LineEdit", hover)
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_stylebox("background", "ProgressBar", bar_style(Color(0.05, 0.1, 0.08, 0.9)))
	t.set_stylebox("fill", "ProgressBar", bar_style(GREEN))
	t.set_stylebox("slider", "HSlider", bar_style(Color(0.1, 0.25, 0.16)))
	t.set_stylebox("grabber_area", "HSlider", bar_style(GREEN_DIM))
	t.set_stylebox("grabber_area_highlight", "HSlider", bar_style(GREEN))
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_stylebox("panel", "TabContainer", panel())
	return t


static func label(text: String, size := 18, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func bar(c: Color, h := 16.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, h)
	b.add_theme_stylebox_override("fill", bar_style(c))
	b.max_value = 100.0
	return b
