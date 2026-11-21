extends Node
## Top-level game flow: current mode, pause, new game, save/load.
##
## Interactables should check GameManager.can_interact() before reacting to clicks,
## so hotspots stay inert during dialogue, inspection, pause and scene transitions.
## Loaded after GameState, DialogueManager and SceneManager (see project.godot).

enum Mode { BOOT, TITLE, EXPLORE, DIALOGUE, INSPECT, PAUSED }

signal mode_changed(new_mode: Mode, old_mode: Mode)

const SAVE_PATH := "user://savegame.json"
const TITLE_SCENE := "res://scenes/ui/main_menu.tscn"

var mode: Mode = Mode.BOOT
## Turned off by automated tests so they never touch the player's save.
var saving_enabled: bool = true

var _mode_before_pause: Mode = Mode.BOOT
var _mode_before_dialogue: Mode = Mode.EXPLORE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # must run while the tree is paused
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)


func set_mode(new_mode: Mode) -> void:
	if new_mode == mode:
		return
	var old := mode
	mode = new_mode
	mode_changed.emit(mode, old)


func can_interact() -> bool:
	return mode == Mode.EXPLORE and not SceneManager.is_transitioning


# --- Pause ------------------------------------------------------------------

func set_paused(paused: bool) -> void:
	if paused == get_tree().paused:
		return
	if paused:
		_mode_before_pause = mode
		get_tree().paused = true
		set_mode(Mode.PAUSED)
	else:
		get_tree().paused = false
		set_mode(_mode_before_pause)


func toggle_pause() -> void:
	set_paused(not get_tree().paused)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") and mode not in [Mode.BOOT, Mode.TITLE]:
		get_viewport().set_input_as_handled()
		toggle_pause()


# --- Game lifecycle ---------------------------------------------------------

func new_game(start_scene: String, fade_time: float = 0.4) -> void:
	set_paused(false)
	GameState.reset()
	set_mode(Mode.EXPLORE)
	await SceneManager.change_scene(start_scene, fade_time)


func return_to_title(fade_time: float = 0.8) -> void:
	set_paused(false)
	if DialogueManager.is_active:
		DialogueManager.end()
	set_mode(Mode.TITLE)
	await SceneManager.change_scene(TITLE_SCENE, fade_time)


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> bool:
	if not saving_enabled:
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("GameManager: cannot write save (%s)" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(GameState.to_dict(), "\t"))
	return true


func load_game() -> bool:
	if not has_save():
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if parsed is not Dictionary:
		push_error("GameManager: save file is corrupt")
		return false
	GameState.from_dict(parsed)
	set_paused(false)
	set_mode(Mode.EXPLORE)
	if not GameState.current_location.is_empty():
		await SceneManager.change_scene(GameState.current_location)
	return true


func quit_game() -> void:
	print("[GameManager] quit requested")
	get_tree().quit()


# --- Signal handlers --------------------------------------------------------

func _on_dialogue_started(_id: StringName) -> void:
	_mode_before_dialogue = mode
	set_mode(Mode.DIALOGUE)


func _on_dialogue_ended(_id: StringName) -> void:
	set_mode(_mode_before_dialogue)
