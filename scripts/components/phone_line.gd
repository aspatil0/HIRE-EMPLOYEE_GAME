class_name PhoneLine
extends Node
## The office phone line: incoming calls ring until answered or declined;
## answering plays a dialogue file through DialogueManager.

signal ringing_changed(is_ringing: bool)
signal call_started(caller_id: StringName)
signal call_ended(caller_id: StringName)
signal call_missed(caller_id: StringName)

@export var ring_timeout: float = 30.0

var is_ringing: bool = false
var in_call: bool = false
var caller_id: StringName = &""
var caller_name: String = ""

var _dialogue_path: String = ""
var _ring_timer: SceneTreeTimer


func ring(id: StringName, display_name: String, dialogue_path: String) -> void:
	if is_ringing or in_call:
		return
	caller_id = id
	caller_name = display_name
	_dialogue_path = dialogue_path
	is_ringing = true
	AudioManager.play_loop(&"phone_ring", AudioManager.BUS_SFX, -4.0, 0.05)
	ringing_changed.emit(true)
	_ring_timer = get_tree().create_timer(ring_timeout, false)
	_ring_timer.timeout.connect(_on_ring_timeout.bind(id))


func answer() -> void:
	if not is_ringing:
		return
	_stop_ringing()
	in_call = true
	AudioManager.play_sfx(&"phone_pickup")
	call_started.emit(caller_id)
	DialogueManager.dialogue_ended.connect(_on_call_dialogue_ended, CONNECT_ONE_SHOT)
	DialogueManager.start_from_file(_dialogue_path)
	if not DialogueManager.is_active: # bad/missing file: end the call cleanly
		if DialogueManager.dialogue_ended.is_connected(_on_call_dialogue_ended):
			DialogueManager.dialogue_ended.disconnect(_on_call_dialogue_ended)
		_on_call_dialogue_ended(&"")


func decline() -> void:
	if not is_ringing:
		return
	_stop_ringing()
	AudioManager.play_sfx(&"phone_hangup")
	call_missed.emit(caller_id)


func _stop_ringing() -> void:
	is_ringing = false
	AudioManager.stop_loop(&"phone_ring", 0.05)
	ringing_changed.emit(false)


func _on_ring_timeout(id: StringName) -> void:
	if is_ringing and caller_id == id:
		_stop_ringing()
		call_missed.emit(id)


func _on_call_dialogue_ended(_id: StringName) -> void:
	in_call = false
	AudioManager.play_sfx(&"phone_hangup")
	call_ended.emit(caller_id)
