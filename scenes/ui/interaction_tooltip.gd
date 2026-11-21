class_name InteractionTooltip
extends PanelContainer
## Small label that follows the cursor over interactable objects:
## object name plus what left/right click will do.

const OFFSET := Vector2(26, 22)

var _name: Label
var _hint: Label
var _target: Interactable


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override(&"panel", UITheme.flat_box(Color(0.03, 0.035, 0.04, 0.9), Color(1, 1, 1, 0.1), 1, 12))
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_name = UITheme.label("", &"SerifLabel", 22)
	box.add_child(_name)
	_hint = UITheme.label("", &"DimLabel", 13)
	box.add_child(_hint)
	modulate.a = 0.0
	visible = false


## Connects to an InteractionController's hover_changed signal.
func attach(controller: InteractionController) -> void:
	controller.hover_changed.connect(_on_hover_changed)


func _on_hover_changed(target: Interactable) -> void:
	_target = target
	if target == null:
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.12)
		tw.tween_callback(hide)
		return
	_name.text = target.display_name
	var hints: PackedStringArray = []
	if target.panel_scene or not target.activated.get_connections().is_empty():
		hints.append("LMB  %s" % target.action_verb.to_upper())
	elif target.activate_inspects:
		hints.append("LMB  LOOK")
	if not target.inspect_text.is_empty():
		hints.append("RMB  INSPECT")
	_hint.text = "     ".join(hints)
	reset_size()
	visible = true
	_follow()
	create_tween().tween_property(self, "modulate:a", 1.0, 0.12)


func _process(_delta: float) -> void:
	if visible:
		_follow()


func _follow() -> void:
	var vp := get_viewport_rect().size
	var p := get_global_mouse_position() + OFFSET
	p.x = minf(p.x, vp.x - size.x - 16.0)
	p.y = minf(p.y, vp.y - size.y - 16.0)
	global_position = p
