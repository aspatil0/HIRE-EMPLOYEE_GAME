class_name InteractionController
extends Node2D
## Mouse picking for every Interactable in the current location.
##
## Picking is polygon-based (not physics picking) so it is deterministic,
## respects GameManager.can_interact() and never fights the GUI: clicks that a
## Control consumed never reach _unhandled_input here.

signal hover_changed(target: Interactable)

@export var panel_host_path: NodePath
@export var inspect_speaker: String = "ALICE"

## Extra data handed to every panel opened from an interactable (e.g. the phone line).
var context: Dictionary = {}
var current: Interactable

var _panel_host: PanelHost


func _ready() -> void:
	_panel_host = get_node_or_null(panel_host_path) as PanelHost
	GameManager.mode_changed.connect(_on_mode_changed)


func _exit_tree() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _process(_delta: float) -> void:
	var target: Interactable = null
	if GameManager.can_interact():
		target = pick(get_global_mouse_position())
	_set_current(target)


## Topmost enabled interactable under a global point, or null.
func pick(point: Vector2) -> Interactable:
	var best: Interactable = null
	for node in get_tree().get_nodes_in_group(&"interactables"):
		var it := node as Interactable
		if it == null or not it.contains_global_point(point):
			continue
		# Later in the tree draws on top; explicit priority beats tree order.
		if best == null or it.pick_priority >= best.pick_priority:
			best = it
	return best


func _unhandled_input(event: InputEvent) -> void:
	if current == null or not GameManager.can_interact():
		return
	if event.is_action_pressed(&"interact"):
		get_viewport().set_input_as_handled()
		activate(current)
	elif event.is_action_pressed(&"inspect"):
		get_viewport().set_input_as_handled()
		inspect(current)


func activate(target: Interactable) -> void:
	AudioManager.play_sfx(target.interact_sound, -4.0)
	_set_current(null)
	target.activate()
	if target.panel_scene and _panel_host:
		var ctx := context.duplicate()
		ctx["source"] = target
		_panel_host.open(target.panel_scene, ctx)
	elif target.activate_inspects:
		inspect(target)


func inspect(target: Interactable) -> void:
	_set_current(null)
	target.inspect()
	if not target.inspect_text.is_empty():
		DialogueManager.say(inspect_speaker, target.inspect_text, StringName("inspect_%s" % target.interaction_id))


func _set_current(target: Interactable) -> void:
	if target == current:
		return
	if is_instance_valid(current):
		current.set_hovered(false)
	current = target
	if target:
		target.set_hovered(true)
		AudioManager.play_sfx(&"ui_hover", -18.0)
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if target else Input.CURSOR_ARROW)
	hover_changed.emit(target)


func _on_mode_changed(new_mode: int, _old: int) -> void:
	if new_mode != GameManager.Mode.EXPLORE:
		_set_current(null)
