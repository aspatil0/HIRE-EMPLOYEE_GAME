extends Node
## Runs linear dialogue sequences and broadcasts each line.
##
## This manager owns *flow only*; a dialogue box UI (later, in scenes/ui/) listens to
## line_started / dialogue_ended and draws the text. Dialogue data lives in
## data/dialogue/*.json — see data/dialogue/_format_example.json.
##
## Line dictionary keys:
##   "speaker"  (String)  name shown above the text, may be empty for narration
##   "text"     (String)  the line itself
##   "set_flag" (String)  optional GameState flag set to true when the line is shown

signal dialogue_started(dialogue_id: StringName)
signal line_started(speaker: String, text: String, line: Dictionary)
signal dialogue_ended(dialogue_id: StringName)

var is_active: bool = false
var current_id: StringName = &""
## Set by a dialogue UI (scenes/ui/dialogue_box.gd) while it is in the tree, so it
## can finish its typewriter effect before advancing. When false, this manager
## advances on the dialogue_advance action itself.
var ui_owns_input: bool = false

var _lines: Array[Dictionary] = []
var _index: int = -1


func _ready() -> void:
	# Dialogue must keep working while gameplay input is blocked.
	process_mode = Node.PROCESS_MODE_ALWAYS


## Convenience for one-off lines (e.g. right-click inspection thoughts).
func say(speaker: String, text: String, dialogue_id: StringName = &"say") -> void:
	var lines: Array[Dictionary] = [{"speaker": speaker, "text": text}]
	start(lines, dialogue_id)


func start(lines: Array[Dictionary], dialogue_id: StringName = &"") -> void:
	if lines.is_empty():
		push_warning("DialogueManager.start: no lines for '%s'" % dialogue_id)
		return
	if is_active:
		end()
	_lines = lines
	_index = -1
	current_id = dialogue_id
	is_active = true
	dialogue_started.emit(current_id)
	advance()


func start_from_file(path: String) -> void:
	var data := load_dialogue_file(path)
	if data.is_empty():
		return
	var lines: Array[Dictionary] = []
	for line: Dictionary in data.get("lines", []):
		lines.append(line)
	start(lines, StringName(data.get("id", path.get_file().get_basename())))


## Shows the next line, or ends the dialogue if there are none left.
func advance() -> void:
	if not is_active:
		return
	_index += 1
	if _index >= _lines.size():
		end()
		return
	var line := _lines[_index]
	if line.has("set_flag"):
		GameState.set_flag(StringName(line["set_flag"]))
	line_started.emit(str(line.get("speaker", "")), str(line.get("text", "")), line)


func end() -> void:
	if not is_active:
		return
	var finished_id := current_id
	is_active = false
	_lines = []
	_index = -1
	current_id = &""
	dialogue_ended.emit(finished_id)


func load_dialogue_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("DialogueManager: file not found: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is not Dictionary:
		push_error("DialogueManager: invalid dialogue JSON: %s" % path)
		return {}
	return parsed


func _unhandled_input(event: InputEvent) -> void:
	# Fallback for scenes without a dialogue UI; DialogueBox takes over otherwise.
	if is_active and not ui_owns_input and event.is_action_pressed(&"dialogue_advance"):
		get_viewport().set_input_as_handled()
		advance()
