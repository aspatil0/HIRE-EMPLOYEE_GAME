extends Node2D
## Game over: Alice has made a third recruitment mistake. Aditya has called her
## up to his office. He fires her, his eyes burning red, then the TERMINATED
## screen offers a new game or the main menu. The save is deleted — being
## fired ends this run.

const CEO_PATH := "res://data/dialogue/phase_2_ceo.json"
const INTRO_SCENE := "res://scenes/cutscenes/intro_assignment.tscn"

@onready var _rig: LightingRig = $Stage/LightingRig
@onready var _window: NightWindow = $Stage/NightWindow
@onready var _aditya: CharacterFigure = $Stage/Aditya
@onready var _bar_top: ColorRect = %LetterboxTop
@onready var _bar_bottom: ColorRect = %LetterboxBottom
@onready var _game_over: Control = %GameOver
@onready var _summary: Label = %Summary
@onready var _mistakes: Label = %Mistakes
@onready var _retry: Button = %Retry
@onready var _menu: Button = %MainMenu

var _ended: bool = false
var _time: float = 0.0


func _ready() -> void:
	if GameManager.mode in [GameManager.Mode.BOOT, GameManager.Mode.TITLE]:
		GameManager.set_mode(GameManager.Mode.EXPLORE)
	_rig.add_light(&"window", Vector2(960, 330), 1100.0, Color(0.3, 0.36, 0.55), 0.8, 0.55)
	_rig.add_light(&"bankers_lamp", Vector2(470, 690), 600.0, Color(1.0, 0.5, 0.35), 0.75, 0.55, 0.08)
	_rig.add_light(&"red", Vector2(960, 500), 900.0, Color(0.7, 0.08, 0.05), 0.45, 0.7)
	_aditya.glint_color = Color(1.0, 0.12, 0.06)
	_window.lightning_struck.connect(func(s: float) -> void: _rig.flash(s * 0.5, Color(0.9, 0.2, 0.15)))
	AudioManager.set_soundscape({
		&"rain": [AudioManager.BUS_AMBIENCE, -12.0],
		&"horror_drone": [AudioManager.BUS_MUSIC, -5.0],
	}, 1.5)
	_game_over.visible = false
	_retry.pressed.connect(func() -> void:
		AudioManager.stop_all_loops(1.0)
		GameManager.new_game(INTRO_SCENE, 1.0))
	_menu.pressed.connect(func() -> void:
		AudioManager.stop_all_loops(1.0)
		GameManager.return_to_title())
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	var tw := create_tween()
	tw.tween_method(_set_letterbox, 0.0, 1.0, 1.2).set_trans(Tween.TRANS_CUBIC)
	tw.tween_interval(0.6)
	tw.tween_callback(_start_dialogue)


func _exit_tree() -> void:
	if DialogueManager.dialogue_ended.is_connected(_on_dialogue_ended):
		DialogueManager.dialogue_ended.disconnect(_on_dialogue_ended)


func _process(delta: float) -> void:
	_time += delta
	# Eyes burn the whole scene.
	_aditya.glint = 0.75 + 0.25 * sin(_time * 6.0)


func _set_letterbox(t: float) -> void:
	_bar_top.size.y = 96.0 * t
	_bar_bottom.size.y = 96.0 * t
	_bar_bottom.position.y = 1080.0 - 96.0 * t


func mistake_names() -> String:
	var names: PackedStringArray = []
	for m: Dictionary in Recruitment.mistakes():
		var c := Recruitment.get_candidate(str(m.get("candidate", "")))
		if c:
			names.append("%s %s" % ["accepted" if m.get("action", "") == "accept" else "rejected", c.display_name()])
	return ", ".join(names)


func _start_dialogue() -> void:
	var lines: Array[Dictionary] = []
	for l: Dictionary in DataLoader.load_json(CEO_PATH).get("fired", []):
		var line := l.duplicate()
		line["text"] = str(line.get("text", "")).replace("{mistakes}", mistake_names())
		lines.append(line)
	AudioManager.play_sfx(&"stinger", -2.0, 0.7)
	DialogueManager.start(lines, &"phase2_fired")


func _on_dialogue_ended(id: StringName) -> void:
	if id == &"phase2_fired":
		show_game_over()


## Shows the TERMINATED screen (also used by tests).
func show_game_over() -> void:
	if _ended:
		return
	_ended = true
	GameManager.delete_save()
	AudioManager.play_sfx(&"door", 0.0, 0.7)
	AudioManager.play_sfx(&"thunder", -2.0, 0.8)
	var go: Dictionary = DataLoader.load_json(CEO_PATH).get("game_over", {})
	_summary.text = str(go.get("text", ""))
	_mistakes.text = "Mistakes: %s." % mistake_names()
	_game_over.visible = true
	_game_over.modulate.a = 0.0
	create_tween().tween_property(_game_over, "modulate:a", 1.0, 1.6)
	_retry.grab_focus()
