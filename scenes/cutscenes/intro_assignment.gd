extends Node2D
## Opening cinematic: Aditya assigns Alice tonight's recruitment task.
##
## Flow: title card -> letterbox + slow camera push -> dialogue (DialogueManager,
## data/dialogue/intro_assignment.json) whose lines carry "cue" keys that drive
## staging -> fade to black -> location card -> Alice's office.

const DIALOGUE := "res://data/dialogue/intro_assignment.json"
const NEXT_SCENE := "res://scenes/locations/alice_office.tscn"
const PIVOT := Vector2(960, 520)
const LETTERBOX_H := 96.0

@onready var _stage: Node2D = $Stage
@onready var _rig: LightingRig = $Stage/LightingRig
@onready var _window: NightWindow = $Stage/NightWindow
@onready var _desk: Node2D = $Stage/Desk
@onready var _aditya: CharacterFigure = $Stage/Aditya
@onready var _alice: CharacterFigure = $Stage/Alice
@onready var _bar_top: ColorRect = %LetterboxTop
@onready var _bar_bottom: ColorRect = %LetterboxBottom
@onready var _card: Control = %TitleCard
@onready var _end_fade: ColorRect = %EndFade
@onready var _end_title: Label = %EndTitle
@onready var _end_sub: Label = %EndSubtitle
@onready var _skip: Button = %Skip

var _push: float = 0.0
var _finished: bool = false
var _aditya_home: Vector2


func _ready() -> void:
	if GameManager.mode in [GameManager.Mode.BOOT, GameManager.Mode.TITLE]:
		GameManager.set_mode(GameManager.Mode.EXPLORE)
	_aditya_home = _aditya.position
	_setup_lighting()
	AudioManager.set_soundscape({
		&"rain": [AudioManager.BUS_AMBIENCE, -15.0],
		&"ambience_office": [AudioManager.BUS_AMBIENCE, -14.0],
		&"horror_drone": [AudioManager.BUS_MUSIC, -13.0],
	}, 2.0)
	AudioManager.warm_up([&"computer_hum", &"clock_tick", &"phone_ring", &"paper", &"thunder"])
	DialogueManager.line_started.connect(_on_line)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	_window.lightning_struck.connect(func(s: float) -> void: _rig.flash(s * 0.5))
	_skip.pressed.connect(_skip_intro)
	_skip.modulate.a = 0.0
	_end_fade.modulate.a = 0.0
	_end_title.modulate.a = 0.0
	_end_sub.modulate.a = 0.0
	_set_letterbox(0.0)
	_alice.modulate = Color(0.8, 0.8, 0.85)
	_run_opening()


func _exit_tree() -> void:
	if DialogueManager.line_started.is_connected(_on_line):
		DialogueManager.line_started.disconnect(_on_line)
	if DialogueManager.dialogue_ended.is_connected(_on_dialogue_ended):
		DialogueManager.dialogue_ended.disconnect(_on_dialogue_ended)


func _setup_lighting() -> void:
	_rig.add_light(&"window", Vector2(960, 330), 1100.0, Color(0.34, 0.42, 0.62), 0.95, 0.55)
	_rig.add_light(&"aditya_back", Vector2(960, 420), 360.0, Color(0.45, 0.52, 0.7), 0.35)
	_rig.add_light(&"bankers_lamp", Vector2(470, 690), 640.0, Color(1.0, 0.78, 0.48), 1.0, 0.55, 0.03)
	_rig.add_light(&"desk_fill", Vector2(960, 770), 800.0, Color(0.78, 0.58, 0.4), 0.45, 0.4)
	_rig.add_light(&"alice_rim", Vector2(1600, 760), 520.0, Color(0.8, 0.62, 0.45), 0.35)


func _run_opening() -> void:
	var tw := create_tween()
	tw.tween_interval(3.4)
	tw.tween_property(_card, "modulate:a", 0.0, 1.6)
	tw.parallel().tween_method(_set_letterbox, 0.0, 1.0, 1.6).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(_skip, "modulate:a", 0.7, 1.0)
	tw.tween_callback(_card.hide)
	tw.tween_interval(0.6)
	tw.tween_callback(_start_dialogue)
	# Slow push-in for the whole conversation.
	var push := create_tween()
	push.tween_property(self, "_push", 1.0, 48.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _start_dialogue() -> void:
	if _finished:
		return
	DialogueManager.start_from_file(DIALOGUE)


func _process(_delta: float) -> void:
	var s := 1.0 + 0.06 * _push
	_stage.scale = Vector2(s, s)
	_stage.position = PIVOT * (1.0 - s) + Vector2(0, -12.0 * _push)


func _set_letterbox(t: float) -> void:
	_bar_top.size.y = LETTERBOX_H * t
	_bar_bottom.size.y = LETTERBOX_H * t
	_bar_bottom.position.y = 1080.0 - LETTERBOX_H * t


# --- Dialogue staging ---------------------------------------------------------

func _on_line(speaker: String, _text: String, line: Dictionary) -> void:
	_focus(speaker.begins_with("ALICE"))
	match str(line.get("cue", "")):
		"slide_folder":
			AudioManager.play_sfx(&"paper", -4.0, 0.8)
			create_tween().tween_property(_desk, "folder_offset", Vector2(-60, 34), 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		"lean_in":
			var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
			tw.tween_property(_aditya, "position", _aditya_home + Vector2(0, 14), 1.6)
			tw.tween_property(_aditya, "scale", Vector2(1.05, 1.05), 1.6)
			AudioManager.set_loop_volume(&"horror_drone", -7.0, 2.0)
		"glint":
			_glint()


func _focus(alice: bool) -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_alice, "modulate", Color(1.15, 1.1, 1.05) if alice else Color(0.8, 0.8, 0.85), 0.5)
	tw.tween_property(_aditya, "modulate", Color(0.82, 0.82, 0.88) if alice else Color.WHITE, 0.5)


func _glint() -> void:
	AudioManager.play_sfx(&"stinger", -6.0)
	_window.strike(0.9)
	_rig.set_light_intensity(&"bankers_lamp", 0.2, 0.08)
	var tw := create_tween()
	tw.tween_property(_aditya, "glint", 1.0, 0.25)
	tw.tween_property(_aditya, "glint", 0.55, 1.2)
	tw.parallel().tween_callback(func() -> void: _rig.set_light_intensity(&"bankers_lamp", 0.95, 0.6)).set_delay(0.5)


func _on_dialogue_ended(id: StringName) -> void:
	if id == &"intro_assignment":
		_finish()


func _skip_intro() -> void:
	AudioManager.play_sfx(&"ui_click")
	if DialogueManager.is_active:
		DialogueManager.end() # emits dialogue_ended -> _finish()
	else:
		_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	GameState.set_flag(&"intro_seen")
	_skip.disabled = true
	_end_title.text = "RECRUITMENT OFFICE"
	_end_sub.text = "FLOOR 13   ·   DAY %d   ·   21:00" % GameState.day
	var tw := create_tween()
	tw.tween_property(_skip, "modulate:a", 0.0, 0.3)
	tw.tween_interval(0.6)
	tw.tween_property(_end_fade, "modulate:a", 1.0, 1.6).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_callback(func() -> void: AudioManager.stop_all_loops(2.5))
	tw.tween_property(_end_title, "modulate:a", 1.0, 1.2)
	tw.parallel().tween_property(_end_sub, "modulate:a", 1.0, 1.2).set_delay(0.4)
	tw.tween_interval(1.6)
	tw.tween_callback(func() -> void: SceneManager.change_scene(NEXT_SCENE, 0.9))
