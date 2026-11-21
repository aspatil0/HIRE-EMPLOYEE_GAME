class_name ModalPanel
extends Control
## Base class for every in-game interface window (resume viewer, computers,
## phone, document tray, settings...).
##
## Builds a consistent dark corporate frame (dimmed backdrop, header with title,
## subtitle and close button) and animates opening/closing. Subclasses override
## _build_content(content) to fill the body and may read `context`, which the
## opener (PanelHost) fills in.
##
## Closing: close button, Escape, or calling close(). Emits `closed` after the
## close animation; the owner frees the panel.

signal closed

@export var title: String = "PANEL"
@export var subtitle: String = ""
@export var panel_size: Vector2 = Vector2(1300, 780)
@export var accent: Color = UITheme.ACCENT
@export var dim_backdrop: bool = true

var context: Dictionary = {}
var content: VBoxContainer
var frame: PanelContainer
var header_title: Label
var header_subtitle: Label

var _backdrop: ColorRect
var _closing: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_frame()
	_build_content(content)
	_animate_open()


## Override in subclasses.
func _build_content(_body: VBoxContainer) -> void:
	pass


## Override to react right before the close animation (stop sounds, timers).
func _on_closing() -> void:
	pass


func close() -> void:
	if _closing:
		return
	_closing = true
	_on_closing()
	AudioManager.play_sfx(&"ui_close", -6.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween().set_parallel(true)
	tw.tween_property(frame, "modulate:a", 0.0, 0.18)
	tw.tween_property(frame, "scale", Vector2(0.97, 0.97), 0.18).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_backdrop, "modulate:a", 0.0, 0.22)
	await tw.finished
	closed.emit()


func is_closing() -> bool:
	return _closing


func _unhandled_input(event: InputEvent) -> void:
	if _closing:
		return
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _build_frame() -> void:
	_backdrop = ColorRect.new()
	_backdrop.name = "Backdrop"
	_backdrop.color = Color(0.0, 0.0, 0.01, 0.62 if dim_backdrop else 0.0)
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)

	frame = PanelContainer.new()
	frame.name = "Frame"
	var sb := UITheme.flat_box(UITheme.PANEL_BG, UITheme.PANEL_BORDER, 1, 0)
	sb.border_width_top = 3
	sb.border_color = UITheme.PANEL_BORDER
	sb.shadow_color = Color(0, 0, 0, 0.7)
	sb.shadow_size = 40
	frame.add_theme_stylebox_override(&"panel", sb)
	frame.custom_minimum_size = panel_size
	frame.size = panel_size
	frame.position = (Vector2(1920, 1080) - panel_size) * 0.5
	frame.pivot_offset = panel_size * 0.5
	add_child(frame)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override(&"separation", 0)
	frame.add_child(outer)

	# Accent strip along the top edge.
	var strip := ColorRect.new()
	strip.color = accent
	strip.custom_minimum_size = Vector2(0, 3)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(strip)

	var header_margin := MarginContainer.new()
	header_margin.add_theme_constant_override(&"margin_left", 36)
	header_margin.add_theme_constant_override(&"margin_right", 24)
	header_margin.add_theme_constant_override(&"margin_top", 22)
	header_margin.add_theme_constant_override(&"margin_bottom", 16)
	outer.add_child(header_margin)

	var header := HBoxContainer.new()
	header.add_theme_constant_override(&"separation", 20)
	header_margin.add_child(header)

	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override(&"separation", 2)
	header.add_child(titles)

	header_title = UITheme.label(title, &"HeaderLabel")
	titles.add_child(header_title)
	header_subtitle = UITheme.label(subtitle.to_upper(), &"DimLabel", 15)
	header_subtitle.visible = not subtitle.is_empty()
	titles.add_child(header_subtitle)

	var close_btn := UITheme.button("CLOSE  ✕")
	close_btn.name = "CloseButton"
	close_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_btn.add_theme_font_size_override(&"font_size", 17)
	close_btn.pressed.connect(close)
	header.add_child(close_btn)

	var rule := ColorRect.new()
	rule.color = Color(1, 1, 1, 0.07)
	rule.custom_minimum_size = Vector2(0, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(rule)

	var body_margin := MarginContainer.new()
	body_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in [&"margin_left", &"margin_right"]:
		body_margin.add_theme_constant_override(side, 36)
	body_margin.add_theme_constant_override(&"margin_top", 24)
	body_margin.add_theme_constant_override(&"margin_bottom", 28)
	outer.add_child(body_margin)

	content = VBoxContainer.new()
	content.name = "Content"
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override(&"separation", 16)
	body_margin.add_child(content)


func _animate_open() -> void:
	AudioManager.play_sfx(&"ui_open", -6.0)
	_backdrop.modulate.a = 0.0
	frame.modulate.a = 0.0
	frame.scale = Vector2(0.96, 0.96)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_backdrop, "modulate:a", 1.0, 0.25)
	tw.tween_property(frame, "modulate:a", 1.0, 0.25)
	tw.tween_property(frame, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


# --- Small builders shared by panels -----------------------------------------

static func section_label(text: String) -> Label:
	var l := UITheme.label(text.to_upper(), &"DimLabel", 15)
	return l


static func hsep() -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(1, 1, 1, 0.06)
	r.custom_minimum_size = Vector2(0, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func boxed(child: Control, bg: Color = Color(0.03, 0.035, 0.04, 1), border: Color = Color(0.16, 0.18, 0.2), margin: float = 18.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override(&"panel", UITheme.flat_box(bg, border, 1, margin))
	p.add_child(child)
	return p
