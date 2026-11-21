class_name UITheme
extends RefCounted
## Builds the game's UI Theme in code and exposes the shared fonts/colours.
##
## Fonts are SystemFonts (Georgia / Segoe UI / Consolas on Windows) with fallbacks,
## so no font files are needed yet. Drop .ttf/.otf files into assets/fonts/ and
## point _font() at them to switch to bundled typography.
##
## Type variations available to Labels/Buttons via theme_type_variation:
##   TitleLabel, HeaderLabel, SerifLabel, DimLabel, MonoLabel, MenuTextButton, FlatButton, PaperLabel

const INK := Color(0.86, 0.83, 0.77)
const DIM := Color(0.55, 0.56, 0.58)
const FAINT := Color(0.36, 0.38, 0.41)
const ACCENT := Color(0.71, 0.16, 0.14) # corporate blood red
const ACCENT_SOFT := Color(0.85, 0.35, 0.28)
const WARM := Color(0.95, 0.74, 0.46) # desk-lamp amber
const COLD := Color(0.55, 0.7, 0.86) # monitor blue
const PANEL_BG := Color(0.043, 0.051, 0.06, 0.97)
const PANEL_BORDER := Color(0.2, 0.23, 0.26)
const PAPER := Color(0.85, 0.82, 0.75)
const PAPER_INK := Color(0.13, 0.12, 0.11)

static var _theme: Theme
static var _fonts: Dictionary[StringName, Font] = {}


static func serif() -> Font:
	return _font(&"serif", ["Georgia", "Cambria", "Times New Roman", "serif"], 0)


static func serif_spaced() -> Font:
	return _font(&"serif_spaced", ["Georgia", "Cambria", "Times New Roman", "serif"], 6)


static func sans() -> Font:
	return _font(&"sans", ["Segoe UI", "Helvetica Neue", "Arial", "sans-serif"], 0)


static func sans_spaced() -> Font:
	return _font(&"sans_spaced", ["Segoe UI Semibold", "Segoe UI", "Arial", "sans-serif"], 3)


static func mono() -> Font:
	return _font(&"mono", ["Consolas", "Cascadia Mono", "Courier New", "monospace"], 0)


static func _font(key: StringName, names: Array, spacing: int) -> Font:
	if _fonts.has(key):
		return _fonts[key]
	var sys := SystemFont.new()
	sys.font_names = PackedStringArray(names)
	sys.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	sys.hinting = TextServer.HINTING_LIGHT
	var font: Font = sys
	if spacing != 0:
		var v := FontVariation.new()
		v.base_font = sys
		v.spacing_glyph = spacing
		font = v
	_fonts[key] = font
	return font


static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


static func panel_style(bg: Color = PANEL_BG, border: Color = PANEL_BORDER, top_accent: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	if top_accent.a > 0.0:
		sb.border_width_top = 3
		sb.border_color = border
	sb.set_corner_radius_all(2)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 24
	sb.set_content_margin_all(0)
	return sb


static func flat_box(bg: Color, border: Color = Color.TRANSPARENT, border_w: int = 0, margin: float = 12.0, radius: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	return sb


static func _build() -> Theme:
	var t := Theme.new()
	t.default_font = sans()
	t.default_font_size = 24

	# Labels
	t.set_color(&"font_color", &"Label", INK)
	t.set_color(&"font_shadow_color", &"Label", Color(0, 0, 0, 0))

	_variation(t, &"TitleLabel", &"Label", serif_spaced(), 96, INK)
	_variation(t, &"HeaderLabel", &"Label", serif_spaced(), 34, INK)
	_variation(t, &"SerifLabel", &"Label", serif(), 28, INK)
	_variation(t, &"DimLabel", &"Label", sans_spaced(), 18, DIM)
	_variation(t, &"MonoLabel", &"Label", mono(), 20, COLD)
	_variation(t, &"PaperLabel", &"Label", serif(), 22, PAPER_INK)

	# Buttons: dark flat with a red underline accent on hover.
	var normal := flat_box(Color(0.09, 0.1, 0.115, 0.95), Color(0.22, 0.24, 0.27), 1, 10)
	normal.content_margin_left = 22
	normal.content_margin_right = 22
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.13, 0.12, 0.125, 0.98)
	hover.border_color = ACCENT
	hover.border_width_bottom = 2
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.2, 0.07, 0.07, 1.0)
	pressed.border_color = ACCENT_SOFT
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.06, 0.065, 0.07, 0.8)
	disabled.border_color = Color(0.13, 0.14, 0.15)
	t.set_stylebox(&"normal", &"Button", normal)
	t.set_stylebox(&"hover", &"Button", hover)
	t.set_stylebox(&"pressed", &"Button", pressed)
	t.set_stylebox(&"hover_pressed", &"Button", pressed)
	t.set_stylebox(&"disabled", &"Button", disabled)
	t.set_stylebox(&"focus", &"Button", StyleBoxEmpty.new())
	t.set_font(&"font", &"Button", sans_spaced())
	t.set_font_size(&"font_size", &"Button", 20)
	t.set_color(&"font_color", &"Button", INK)
	t.set_color(&"font_hover_color", &"Button", Color(1, 0.95, 0.9))
	t.set_color(&"font_pressed_color", &"Button", Color(1, 0.85, 0.8))
	t.set_color(&"font_hover_pressed_color", &"Button", Color(1, 0.85, 0.8))
	t.set_color(&"font_focus_color", &"Button", INK)
	t.set_color(&"font_disabled_color", &"Button", Color(0.32, 0.33, 0.35))

	# Big text-only menu buttons (main menu / pause menu).
	t.set_type_variation(&"MenuTextButton", &"Button")
	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = 0
	empty.content_margin_top = 4
	empty.content_margin_bottom = 4
	for state in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled", &"focus"]:
		t.set_stylebox(state, &"MenuTextButton", empty)
	t.set_font(&"font", &"MenuTextButton", serif_spaced())
	t.set_font_size(&"font_size", &"MenuTextButton", 38)
	t.set_color(&"font_color", &"MenuTextButton", Color(0.72, 0.7, 0.67))
	t.set_color(&"font_hover_color", &"MenuTextButton", Color(1, 0.96, 0.92))
	t.set_color(&"font_focus_color", &"MenuTextButton", Color(1, 0.96, 0.92))
	t.set_color(&"font_pressed_color", &"MenuTextButton", ACCENT_SOFT)
	t.set_color(&"font_hover_pressed_color", &"MenuTextButton", ACCENT_SOFT)
	t.set_color(&"font_disabled_color", &"MenuTextButton", Color(0.27, 0.27, 0.29))

	# Small flat buttons (tabs, list rows).
	t.set_type_variation(&"FlatButton", &"Button")
	var flat_n := flat_box(Color(0, 0, 0, 0), Color.TRANSPARENT, 0, 10)
	flat_n.content_margin_left = 16
	var flat_h := flat_box(Color(1, 1, 1, 0.05), Color.TRANSPARENT, 0, 10)
	flat_h.content_margin_left = 16
	var flat_p := flat_box(Color(0.6, 0.14, 0.12, 0.35), ACCENT, 0, 10)
	flat_p.content_margin_left = 16
	flat_p.border_width_left = 3
	t.set_stylebox(&"normal", &"FlatButton", flat_n)
	t.set_stylebox(&"hover", &"FlatButton", flat_h)
	t.set_stylebox(&"pressed", &"FlatButton", flat_p)
	t.set_stylebox(&"hover_pressed", &"FlatButton", flat_p)
	t.set_stylebox(&"focus", &"FlatButton", StyleBoxEmpty.new())
	t.set_font(&"font", &"FlatButton", sans())
	t.set_font_size(&"font_size", &"FlatButton", 20)

	# Panels
	t.set_stylebox(&"panel", &"PanelContainer", flat_box(PANEL_BG, PANEL_BORDER, 1, 0))
	t.set_stylebox(&"panel", &"Panel", flat_box(PANEL_BG, PANEL_BORDER, 1, 0))

	# Inputs
	var le := flat_box(Color(0.03, 0.035, 0.04), Color(0.24, 0.27, 0.3), 1, 10)
	var le_focus := le.duplicate() as StyleBoxFlat
	le_focus.border_color = ACCENT_SOFT
	t.set_stylebox(&"normal", &"LineEdit", le)
	t.set_stylebox(&"focus", &"LineEdit", le_focus)
	t.set_stylebox(&"read_only", &"LineEdit", le)
	t.set_color(&"font_color", &"LineEdit", INK)
	t.set_color(&"caret_color", &"LineEdit", WARM)
	t.set_color(&"font_placeholder_color", &"LineEdit", FAINT)
	t.set_font_size(&"font_size", &"LineEdit", 22)

	for state in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled", &"focus"]:
		t.set_stylebox(state, &"OptionButton", (normal if state != &"hover" else hover).duplicate())
	t.set_stylebox(&"panel", &"PopupMenu", flat_box(Color(0.06, 0.065, 0.075), PANEL_BORDER, 1, 6))
	t.set_color(&"font_color", &"PopupMenu", INK)
	t.set_color(&"font_hover_color", &"PopupMenu", Color.WHITE)
	t.set_stylebox(&"hover", &"PopupMenu", flat_box(Color(0.45, 0.1, 0.09, 0.6), Color.TRANSPARENT, 0, 6))
	t.set_font_size(&"font_size", &"PopupMenu", 20)

	# Sliders
	var track := flat_box(Color(0.16, 0.17, 0.19), Color.TRANSPARENT, 0, 0, 2)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var fill := flat_box(ACCENT, Color.TRANSPARENT, 0, 0, 2)
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	t.set_stylebox(&"slider", &"HSlider", track)
	t.set_stylebox(&"grabber_area", &"HSlider", fill)
	t.set_stylebox(&"grabber_area_highlight", &"HSlider", fill)

	# Progress bars
	t.set_stylebox(&"background", &"ProgressBar", flat_box(Color(0.12, 0.13, 0.15), Color.TRANSPARENT, 0, 0))
	t.set_stylebox(&"fill", &"ProgressBar", flat_box(ACCENT, Color.TRANSPARENT, 0, 0))
	t.set_color(&"font_color", &"ProgressBar", INK)

	# Scrollbars: thin and dark
	var sb_track := flat_box(Color(1, 1, 1, 0.03), Color.TRANSPARENT, 0, 0, 3)
	var sb_grab := flat_box(Color(1, 1, 1, 0.16), Color.TRANSPARENT, 0, 0, 3)
	var sb_grab_h := flat_box(Color(1, 1, 1, 0.28), Color.TRANSPARENT, 0, 0, 3)
	for sb_type in [&"VScrollBar", &"HScrollBar"]:
		t.set_stylebox(&"scroll", sb_type, sb_track)
		t.set_stylebox(&"grabber", sb_type, sb_grab)
		t.set_stylebox(&"grabber_highlight", sb_type, sb_grab_h)
		t.set_stylebox(&"grabber_pressed", sb_type, sb_grab_h)

	# Tooltips
	t.set_stylebox(&"panel", &"TooltipPanel", flat_box(Color(0.05, 0.055, 0.06, 0.96), PANEL_BORDER, 1, 8))
	t.set_color(&"font_color", &"TooltipLabel", INK)
	t.set_font_size(&"font_size", &"TooltipLabel", 18)

	t.set_color(&"font_color", &"CheckButton", INK)
	t.set_color(&"font_hover_color", &"CheckButton", Color.WHITE)
	t.set_stylebox(&"focus", &"CheckButton", StyleBoxEmpty.new())
	t.set_color(&"default_color", &"RichTextLabel", INK)
	t.set_font(&"normal_font", &"RichTextLabel", sans())
	t.set_font(&"bold_font", &"RichTextLabel", sans_spaced())
	t.set_font(&"italics_font", &"RichTextLabel", serif())
	t.set_font(&"mono_font", &"RichTextLabel", mono())
	t.set_font_size(&"normal_font_size", &"RichTextLabel", 22)
	t.set_font_size(&"bold_font_size", &"RichTextLabel", 22)
	t.set_font_size(&"italics_font_size", &"RichTextLabel", 22)
	t.set_font_size(&"mono_font_size", &"RichTextLabel", 20)
	return t


static func _variation(t: Theme, name: StringName, base: StringName, font: Font, size: int, color: Color) -> void:
	t.set_type_variation(name, base)
	t.set_font(&"font", name, font)
	t.set_font_size(&"font_size", name, size)
	t.set_color(&"font_color", name, color)


## Label helper used by code-built UIs.
static func label(text: String, variation: StringName = &"", size: int = 0, color: Color = Color(0, 0, 0, 0)) -> Label:
	var l := Label.new()
	l.text = text
	if variation != &"":
		l.theme_type_variation = variation
	if size > 0:
		l.add_theme_font_size_override(&"font_size", size)
	if color.a > 0.0:
		l.add_theme_color_override(&"font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func button(text: String, variation: StringName = &"") -> Button:
	var b := Button.new()
	b.text = text
	if variation != &"":
		b.theme_type_variation = variation
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b
