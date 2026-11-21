extends Node
## Location/scene transitions with a fade to black.
##
## Always change scenes through SceneManager.change_scene() rather than
## get_tree().change_scene_to_file(), so clicks are blocked during the fade
## and GameState.current_location stays correct.

signal transition_started(target_path: String)
signal scene_changed(scene: Node)

const DEFAULT_FADE_TIME := 0.4
const FADE_LAYER := 100

var is_transitioning: bool = false

var _fade_rect: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.name = "FadeLayer"
	layer.layer = FADE_LAYER
	add_child(layer)

	_fade_rect = ColorRect.new()
	_fade_rect.name = "Fade"
	_fade_rect.color = Color.BLACK
	_fade_rect.modulate.a = 0.0
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade_rect)


func change_scene(path: String, fade_time: float = DEFAULT_FADE_TIME) -> void:
	if is_transitioning:
		push_warning("SceneManager: already transitioning, ignoring '%s'" % path)
		return
	if not ResourceLoader.exists(path):
		push_error("SceneManager: scene not found: %s" % path)
		return

	is_transitioning = true
	transition_started.emit(path)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP # swallow clicks mid-transition

	await _fade_to(1.0, fade_time)
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("SceneManager: failed to change to %s (error %d)" % [path, err])
	else:
		await get_tree().scene_changed
		GameState.current_location = path
		scene_changed.emit(get_tree().current_scene)
	await _fade_to(0.0, fade_time)

	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	is_transitioning = false


func reload_current_scene(fade_time: float = DEFAULT_FADE_TIME) -> void:
	var current := get_tree().current_scene
	if current and not current.scene_file_path.is_empty():
		await change_scene(current.scene_file_path, fade_time)


func _fade_to(alpha: float, duration: float) -> void:
	if duration <= 0.0:
		_fade_rect.modulate.a = alpha
		return
	var tween := create_tween()
	tween.tween_property(_fade_rect, "modulate:a", alpha, duration)
	await tween.finished
