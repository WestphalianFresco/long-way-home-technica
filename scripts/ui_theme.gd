extends RefCounted
## Shared palette, fonts and the project Theme for Long Way Home.

const BG := Color(0.018, 0.037, 0.057)
const PANEL := Color(0.018, 0.042, 0.062, 0.96)
const TEXT := Color(0.92, 0.97, 1.0)
const MUTED := Color(0.70, 0.79, 0.85)
const LINE := Color(0.62, 0.85, 0.96, 0.30)
const CYAN := Color(0.62, 0.89, 1.0)
const AMBER := Color(0.94, 0.75, 0.39)
const DANGER := Color(0.95, 0.45, 0.38)

static func font(file: String) -> Font:
	var path := "res://assets/%s" % file
	if ResourceLoader.exists(path):
		return load(path)
	return null

static func heading_font() -> Font:
	var f := font("Heading.ttf")
	if f:
		return f
	var sys := SystemFont.new()
	sys.font_names = PackedStringArray(["Helvetica Neue", "Arial", "sans-serif"])
	sys.font_weight = 300
	return sys

static func mono_font() -> Font:
	var f := font("Mono.ttf")
	if f:
		return f
	var sys := SystemFont.new()
	sys.font_names = PackedStringArray(["Menlo", "Consolas", "monospace"])
	return sys

static func box(fill: Color, border: Color, width := 1, pad := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(width)
	s.set_content_margin_all(pad)
	s.anti_aliasing = false
	return s

static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 16
	t.set_color("font_color", "Label", TEXT)

	var clear := Color(0, 0, 0, 0)
	t.set_stylebox("normal", "Button", box(Color(CYAN, 0.03), LINE, 1, 12))
	t.set_stylebox("hover", "Button", box(Color(CYAN, 0.09), Color(CYAN, 0.7), 1, 12))
	t.set_stylebox("pressed", "Button", box(Color(AMBER, 0.16), AMBER, 1, 12))
	t.set_stylebox("hover_pressed", "Button", box(Color(AMBER, 0.2), AMBER, 1, 12))
	t.set_stylebox("disabled", "Button", box(clear, Color(LINE, 0.12), 1, 12))
	# Focus must be obvious without relying on hairlines alone.
	t.set_stylebox("focus", "Button", box(clear, AMBER, 2, 12))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", AMBER)
	t.set_color("font_hover_pressed_color", "Button", AMBER)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(MUTED, 0.45))

	t.set_stylebox("panel", "PanelContainer", box(PANEL, LINE, 1, 18))
	t.set_stylebox("background", "ProgressBar", box(Color(CYAN, 0.06), clear, 0, 0))
	t.set_stylebox("fill", "ProgressBar", box(CYAN, clear, 0, 0))
	t.set_color("font_color", "CheckButton", MUTED)
	t.set_color("font_hover_color", "CheckButton", TEXT)
	t.set_color("font_focus_color", "CheckButton", TEXT)
	t.set_stylebox("focus", "CheckButton", box(clear, AMBER, 2, 4))
	t.set_color("font_color", "LinkButton", CYAN)
	t.set_stylebox("focus", "LinkButton", box(clear, AMBER, 2, 2))
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	return t
