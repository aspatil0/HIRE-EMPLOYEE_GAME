extends Node2D
## Second ending (perfect recruitment): Aditya's cabin.
## He tells Alice about the missing recruiters and his duty to "protect
## information". If she sent the hired names to the unknown sender, he knows:
## blackout -> MISSING poster -> the email that reveals who the sender was.
## If she kept quiet, she goes home -> the sender's last, desperate email.

const ENDING_PATH := "res://data/dialogue/phase_2_ending.json"
const INTRO_SCENE := "res://scenes/cutscenes/intro_assignment.tscn"

@onready var _rig: LightingRig = $Stage/LightingRig
@onready var _aditya: CharacterFigure = $Stage/Aditya
@onready var _bar_top: ColorRect = %LetterboxTop
@onready var _bar_bottom: ColorRect = %LetterboxBottom
@onready var _overlay: Control = %Overlay

var shared: bool = false
var stage: String = "dialogue" # dialogue -> blackout -> poster -> email -> end
var _data: Dictionary = {}
var _time: float = 0.0
var _glint_on: bool = false


func _ready() -> void:
	if GameManager.mode in [GameManager.Mode.BOOT, GameManager.Mode.TITLE]:
		GameManager.set_mode(GameManager.Mode.EXPLORE)
	_data = DataLoader.load_json(ENDING_PATH)
	shared = Recruitment.shared_names()
	_rig.add_light(&"window", Vector2(960, 330), 1100.0, Color(0.33, 0.4, 0.6), 0.85, 0.55)
	_rig.add_light(&"bankers_lamp", Vector2(470, 690), 620.0, Color(1.0, 0.76, 0.46), 0.95, 0.55, 0.03)
	_rig.add_light(&"desk_fill", Vector2(960, 770), 760.0, Color(0.75, 0.55, 0.38), 0.4, 0.4)
	_aditya.glint_color = Color(1.0, 0.12, 0.06)
	AudioManager.set_soundscape({
		&"rain": [AudioManager.BUS_AMBIENCE, -13.0],
		&"horror_drone": [AudioManager.BUS_MUSIC, -14.0],
	}, 1.5)
	_overlay.visible = false
	DialogueManager.line_started.connect(_on_line)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	var tw := create_tween()
	tw.tween_method(_set_letterbox, 0.0, 1.0, 1.2).set_trans(Tween.TRANS_CUBIC)
	tw.tween_interval(0.6)
	tw.tween_callback(_start_dialogue)


func _exit_tree() -> void:
	if DialogueManager.line_started.is_connected(_on_line):
		DialogueManager.line_started.disconnect(_on_line)
	if DialogueManager.dialogue_ended.is_connected(_on_dialogue_ended):
		DialogueManager.dialogue_ended.disconnect(_on_dialogue_ended)


func _process(delta: float) -> void:
	_time += delta
	if _glint_on:
		_aditya.glint = 0.7 + 0.3 * sin(_time * 5.0)


func _set_letterbox(t: float) -> void:
	_bar_top.size.y = 96.0 * t
	_bar_bottom.size.y = 96.0 * t
	_bar_bottom.position.y = 1080.0 - 96.0 * t


func _start_dialogue() -> void:
	var lines: Array[Dictionary] = []
	for key in ["common", "shared" if shared else "kept_quiet"]:
		for l: Dictionary in _data.get(key, []):
			lines.append(l)
	DialogueManager.start(lines, &"phase2_cabin")


func _on_line(_speaker: String, text: String, _line: Dictionary) -> void:
	if text.contains("protect information"):
		AudioManager.set_loop_volume(&"horror_drone", -7.0, 2.0)
	if shared and text.contains("sent those names"):
		_glint_on = true
		AudioManager.play_sfx(&"stinger", -4.0, 0.8)
		_rig.set_light_intensity(&"bankers_lamp", 0.3, 0.6)


func _on_dialogue_ended(id: StringName) -> void:
	if id == &"phase2_cabin":
		if shared:
			blackout()
		else:
			show_email()


## Shared branch: the lights die, then the MISSING poster (also used by tests).
func blackout() -> void:
	stage = "blackout"
	_glint_on = false
	_aditya.glint = 0.0
	AudioManager.stop_all_loops(0.2)
	AudioManager.play_sfx(&"lamp_switch", 4.0, 0.6)
	_overlay.visible = true
	_clear_overlay()
	var black := _full_rect(Color.BLACK)
	_overlay.add_child(black)
	GameManager.delete_save() # Alice is gone; this run is over
	var tw := create_tween()
	tw.tween_interval(2.6)
	tw.tween_callback(show_poster)


func show_poster() -> void:
	stage = "poster"
	_overlay.visible = true
	AudioManager.play_sfx(&"stinger", -2.0, 0.6)
	AudioManager.play_loop(&"rain", AudioManager.BUS_AMBIENCE, -10.0, 2.0)
	_clear_overlay()
	_overlay.add_child(_full_rect(Color(0.03, 0.03, 0.035)))
	var info: Dictionary = _data.get("missing_poster", {})
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var paper := PanelContainer.new()
	paper.name = "MissingPoster"
	paper.custom_minimum_size = Vector2(620, 820)
	var sb := UITheme.flat_box(Color(0.86, 0.83, 0.74), Color(0.3, 0.27, 0.22), 2, 40)
	sb.shadow_color = Color(0, 0, 0, 0.8)
	sb.shadow_size = 30
	paper.add_theme_stylebox_override(&"panel", sb)
	paper.rotation = -0.03
	paper.pivot_offset = Vector2(310, 410)
	center.add_child(paper)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 14)
	paper.add_child(v)
	var title := UITheme.label(str(info.get("title", "MISSING")), &"TitleLabel", 110, Color(0.62, 0.08, 0.06))
	title.name = "PosterTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var photo := PanelContainer.new()
	photo.custom_minimum_size = Vector2(300, 330)
	photo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	photo.add_theme_stylebox_override(&"panel", UITheme.flat_box(Color(0.18, 0.18, 0.2), Color(0.1, 0.1, 0.1), 2, 0))
	var face := UITheme.label("?", &"TitleLabel", 160, Color(0.35, 0.35, 0.38))
	face.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	face.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	photo.add_child(face)
	v.add_child(photo)
	var name_label := UITheme.label(str(info.get("name", "ALICE")), &"TitleLabel", 64, UITheme.PAPER_INK)
	name_label.name = "PosterName"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_label)
	for text in [str(info.get("details", "")), "LAST SEEN: %s  ·  %s" % [DateUtil.format_long(DateUtil.game_date(GameState.day)), DateUtil.clock_12h(GameState.time_minutes)]]:
		var l := UITheme.label(text, &"PaperLabel", 22)
		l.name = "LastSeen" if text.begins_with("LAST") else "Details"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
	var foot := UITheme.label(str(info.get("footer", "")), &"DimLabel", 13, Color(0.35, 0.3, 0.25))
	foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(foot)
	paper.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(paper, "modulate:a", 1.0, 1.6)
	tw.tween_interval(4.5)
	tw.tween_callback(show_email)


## The final shot: an email on Alice's screen (also used by tests).
func show_email() -> void:
	stage = "email"
	AudioManager.play_sfx(&"boot", -6.0, 1.6)
	_clear_overlay()
	_overlay.visible = true
	_overlay.add_child(_full_rect(Color(0.01, 0.015, 0.025)))
	var email: Dictionary = _data.get("final_email_shared" if shared else "final_email_quiet", {})
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 26)
	center.add_child(v)
	var screen := PanelContainer.new()
	screen.name = "EmailScreen"
	screen.custom_minimum_size = Vector2(1100, 560)
	screen.add_theme_stylebox_override(&"panel", UITheme.flat_box(Color(0.02, 0.05, 0.09), Color(0.2, 0.4, 0.6), 2, 40))
	v.add_child(screen)
	var ev := VBoxContainer.new()
	ev.add_theme_constant_override(&"separation", 10)
	screen.add_child(ev)
	ev.add_child(UITheme.label("ASHGROVE RMS  //  INBOX  //  TERMINAL 13-A", &"MonoLabel", 16, Color(0.4, 0.55, 0.7)))
	ev.add_child(UITheme.label("FROM:     %s" % email.get("from", ""), &"MonoLabel", 22, Color(0.95, 0.5, 0.45)))
	ev.add_child(UITheme.label("TO:       Alice", &"MonoLabel", 22, Color(0.72, 0.85, 0.97)))
	ev.add_child(UITheme.label("SUBJECT:  %s" % email.get("subject", ""), &"MonoLabel", 22, Color(0.72, 0.85, 0.97)))
	ev.add_child(UITheme.label("RECEIVED: %s" % DateUtil.clock_12h(GameState.time_minutes + 7), &"MonoLabel", 22, Color(0.72, 0.85, 0.97)))
	var rule := ColorRect.new()
	rule.color = Color(0.2, 0.4, 0.6, 0.5)
	rule.custom_minimum_size = Vector2(0, 2)
	ev.add_child(rule)
	var body := UITheme.label(str(email.get("body", "")), &"MonoLabel", 34, Color(0.9, 0.95, 1.0))
	body.name = "EmailBody"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ev.add_child(body)
	var cap := UITheme.label("END OF PHASE 2" + ("  ·  ALICE WAS NEVER SEEN AGAIN" if shared else "  ·  THE NIGHT IS NOT OVER"), &"DimLabel", 16, UITheme.WARM)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(cap)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override(&"separation", 60)
	v.add_child(buttons)
	var retry := UITheme.button("START A NEW NIGHT", &"MenuTextButton")
	retry.name = "Retry"
	retry.pressed.connect(func() -> void:
		AudioManager.stop_all_loops(1.0)
		GameManager.new_game(INTRO_SCENE, 1.0))
	buttons.add_child(retry)
	var menu := UITheme.button("MAIN MENU", &"MenuTextButton")
	menu.name = "MainMenu"
	menu.pressed.connect(func() -> void:
		AudioManager.stop_all_loops(1.0)
		GameManager.return_to_title())
	buttons.add_child(menu)
	screen.modulate.a = 0.0
	create_tween().tween_property(screen, "modulate:a", 1.0, 1.2)
	stage = "end"
	if not shared:
		GameState.set_flag(&"phase2_ending_quiet")
		GameManager.save_game()


func _full_rect(col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = col
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	return r


func _clear_overlay() -> void:
	for c in _overlay.get_children():
		_overlay.remove_child(c)
		c.queue_free()
