class_name MenuButtonFx
extends Button
## Text-only menu button with a sliding red accent bar and hover/click sounds.
## Use with theme_type_variation = "MenuTextButton".

const SLIDE := 22.0

var _bar: ColorRect
var _styles: Array[StyleBoxEmpty] = []
var _tween: Tween
var _lit: bool = false


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus", &"disabled"]:
		var sb := StyleBoxEmpty.new()
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		sb.content_margin_left = 0
		add_theme_stylebox_override(state, sb)
		_styles.append(sb)
	_bar = ColorRect.new()
	_bar.color = UITheme.ACCENT
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.size = Vector2(0, 3)
	add_child(_bar)
	mouse_entered.connect(_set_lit.bind(true))
	mouse_exited.connect(func() -> void: _set_lit(has_focus() and not disabled))
	focus_entered.connect(_set_lit.bind(true))
	focus_exited.connect(_set_lit.bind(false))
	pressed.connect(func() -> void: AudioManager.play_sfx(&"ui_click"))
	resized.connect(_place_bar)
	_place_bar()


func _place_bar() -> void:
	_bar.position = Vector2(0, size.y * 0.5 - 1.5)


func _set_lit(on: bool) -> void:
	if disabled:
		on = false
	if on == _lit:
		return
	_lit = on
	if on:
		AudioManager.play_sfx(&"ui_hover", -10.0)
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_bar, "size:x", SLIDE - 6.0 if on else 0.0, 0.2)
	for sb in _styles:
		_tween.tween_property(sb, "content_margin_left", SLIDE + 8.0 if on else 0.0, 0.2)
