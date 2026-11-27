extends Node2D
## Alice's office: the main fixed-camera gameplay location.
##
## This script only orchestrates: lighting setup, soundscape, the arrival beat,
## Aditya's first call, Phase 2 staging (CEO interventions, the end-of-review
## call and report), ambient scares and autosaves. Object behaviour lives in
## the prop scenes (scenes/interactables/), picking in InteractionController,
## interfaces in scenes/ui/panels/.

const ARRIVAL_DIALOGUE := "res://data/dialogue/office_arrival.json"
const CALL_DIALOGUE := "res://data/dialogue/call_aditya_day1.json"

const OBJ_SETTLE := "Settle in. The resumes are on your desk."
const OBJ_ANSWER := "The phone is ringing."
const OBJ_REVIEW := "RECRUITMENT REVIEW — investigate all six applicants, then ACCEPT or REJECT each."
const OBJ_MISSED := "Aditya will call back. Keep working."
const OBJ_DONE := "Recruitment complete. The report is on Aditya's desk."
const FIRED_SCENE := "res://scenes/cutscenes/fired.tscn"
const CABIN_SCENE := "res://scenes/cutscenes/ceo_cabin.tscn"
const ENDING_PATH := "res://data/dialogue/phase_2_ending.json"
const OBJ_PHASE1_REVIEW := "Review the resumes, then check each candidate's documents and online traces."

@onready var _rig: LightingRig = $LightingRig
@onready var _glow: Node2D = $Glow
@onready var _controller: InteractionController = $Interaction
@onready var _phone_line: PhoneLine = $PhoneLine
@onready var _hud: GameHUD = $UI/HUD
@onready var _tooltip: InteractionTooltip = $UI/InteractionTooltip
@onready var _window: NightWindow = $Environment/NightWindow
@onready var _lamp: DeskLampProp = $Environment/DeskLamp
@onready var _phone: TelephoneProp = $Environment/Telephone
@onready var _resumes: ResumeStackProp = $Environment/ResumeStack
@onready var _computer: MainComputerProp = $Environment/MainComputer

var _silhouette_done: bool = false
var _staging: bool = false
## Tests set this so the firing sequence stops before changing scene.
var test_no_scene_change: bool = false
@onready var _host: PanelHost = $UI/PanelHost
@onready var _flash: ColorRect = $UI/Flash
@onready var _intruder: CEOIntruder = $Environment/CEOIntruder


func _ready() -> void:
	if GameManager.mode in [GameManager.Mode.BOOT, GameManager.Mode.TITLE]:
		GameManager.set_mode(GameManager.Mode.EXPLORE) # launched directly (F6)
	_init_state()
	_setup_lighting()
	_glow.draw.connect(_draw_glow)
	AudioManager.set_soundscape({
		&"ambience_office": [AudioManager.BUS_AMBIENCE, -8.0],
		&"computer_hum": [AudioManager.BUS_AMBIENCE, -17.0],
		&"rain": [AudioManager.BUS_AMBIENCE, -13.0],
		&"clock_tick": [AudioManager.BUS_AMBIENCE, -19.0],
		&"horror_drone": [AudioManager.BUS_MUSIC, -21.0],
	}, 2.5)

	_controller.context = {"phone_line": _phone_line}
	_tooltip.attach(_controller)
	_lamp.toggled.connect(_on_lamp_toggled)
	_window.lightning_struck.connect(_on_lightning)
	_phone_line.ringing_changed.connect(_on_ringing_changed)
	_phone_line.call_started.connect(func(_id: StringName) -> void: _phone.off_hook = true)
	_phone_line.call_ended.connect(_on_call_ended)
	_phone_line.call_missed.connect(_on_call_missed)
	GameState.stats_changed.connect(_on_stats_changed)
	_host.panel_closed.connect(func(_n: StringName) -> void: _after(0.15, _check_staging))
	Recruitment.recruitment_completed.connect(func() -> void: _after(0.2, _check_staging))
	Recruitment.decision_made.connect(func(_c: String, _a: String) -> void: GameManager.save_game())
	_hud.journal_requested.connect(open_journal)
	Recruitment.email_arrived.connect(_on_email_arrived)
	_after(6.0, _check_staging) # resumes a pending intervention/report after loading
	_after(0.7, _arrival_beat)


func _init_state() -> void:
	if not GameState.is_flag_set(&"candidates_received"):
		GameState.set_flag(&"candidates_received")
	Recruitment.refresh_stats() # also upgrades Phase 1 saves to the Phase 2 counts
	Recruitment.ensure_interventions() # a serious decision that never got Aditya's visit
	_resumes.sheet_count = GameState.candidates_pending
	if GameState.objective.is_empty():
		GameState.set_objective(OBJ_SETTLE)
	elif GameState.objective == OBJ_PHASE1_REVIEW:
		GameState.set_objective(OBJ_REVIEW) # Phase 1 save loaded into Phase 2
	if Recruitment.is_complete():
		GameState.set_objective(OBJ_DONE)


func _setup_lighting() -> void:
	_rig.add_light(&"lamp_pool", Vector2(1410, 800), 760.0, Color(1.0, 0.74, 0.47), 1.0, 0.55, 0.03)
	_rig.add_light(&"lamp_near", Vector2(1560, 470), 360.0, Color(1.0, 0.76, 0.5), 0.5, 1.0, 0.03)
	_rig.add_light(&"monitor", Vector2(960, 470), 560.0, Color(0.42, 0.6, 0.86), 0.6, 0.75, 0.05)
	_rig.add_light(&"side_monitor", Vector2(300, 470), 380.0, Color(0.6, 0.7, 0.76), 0.45, 0.9, 0.07)
	_rig.add_light(&"window", Vector2(910, 280), 540.0, Color(0.33, 0.4, 0.58), 0.55, 0.8)
	_rig.add_light(&"door_glass", Vector2(1830, 220), 260.0, Color(0.45, 0.55, 0.62), 0.32, 1.2)
	_rig.add_light(&"desk_left", Vector2(400, 860), 420.0, Color(0.62, 0.66, 0.72), 0.3, 0.6)
	_rig.add_light(&"corridor", Vector2(1800, 360), 520.0, Color(0.62, 0.72, 0.85), 0.0, 1.0)
	if GameState.is_flag_set(&"lamp_off"):
		_lamp.set_on(false)
		_on_lamp_toggled(false)


## Runs `callable` after `seconds`, bound to this scene (cancelled if it is freed).
func _after(seconds: float, callable: Callable) -> void:
	var tw := create_tween()
	tw.tween_interval(seconds)
	tw.tween_callback(callable)


# --- Story beats --------------------------------------------------------------

func _arrival_beat() -> void:
	_hud.show_location_card("RECRUITMENT OFFICE", "FLOOR 13   ·   DAY %d   ·   %s" % [GameState.day, GameState.get_time_string()], 2.0)
	if not GameState.is_flag_set(&"arrival_seen"):
		_after(4.8, func() -> void:
			DialogueManager.dialogue_ended.connect(_on_arrival_done, CONNECT_ONE_SHOT)
			DialogueManager.start_from_file(ARRIVAL_DIALOGUE))
	else:
		_hud.show_hint(6.0)
		_schedule_call(12.0)


func _on_arrival_done(_id: StringName) -> void:
	_hud.show_hint()
	GameManager.save_game()
	_schedule_call(9.0)


func _schedule_call(delay: float) -> void:
	if GameState.is_flag_set(&"call_day1_done"):
		_schedule_ambient_events()
		return
	_after(delay, _try_ring)


func _try_ring() -> void:
	# Don't interrupt dialogue or an open interface; try again shortly.
	if GameManager.mode != GameManager.Mode.EXPLORE:
		_after(3.0, _try_ring)
		return
	_phone.caller_label = "ADITYA"
	_phone_line.ring(&"aditya", "ADITYA", CALL_DIALOGUE)


func _on_ringing_changed(ringing: bool) -> void:
	_phone.ringing = ringing
	if ringing:
		GameState.set_objective(OBJ_ANSWER)


func _on_call_ended(_id: StringName) -> void:
	_phone.off_hook = false
	if GameState.is_flag_set(&"call_day1_done"):
		GameState.set_objective(OBJ_REVIEW)
		GameManager.save_game()
		_hud.toast("PROGRESS SAVED")
		_schedule_ambient_events()


func _on_call_missed(_id: StringName) -> void:
	GameState.set_objective(OBJ_MISSED)
	_schedule_call(25.0)


## One-off unsettling moments once the night is under way.
func _schedule_ambient_events() -> void:
	if _silhouette_done:
		return
	_silhouette_done = true
	_after(randf_range(45.0, 75.0), func() -> void:
		if GameManager.mode == GameManager.Mode.EXPLORE:
			_window.trigger_event(&"silhouette", 2.2)
			AudioManager.play_sfx(&"stinger", -16.0))
	_after(randf_range(110.0, 160.0), func() -> void:
		AudioManager.play_sfx(&"door", -14.0, 0.85))


# --- Reactions ----------------------------------------------------------------

func _on_lamp_toggled(on: bool) -> void:
	GameState.set_flag(&"lamp_off", not on)
	for id in [&"lamp_pool", &"lamp_near"]:
		_rig.set_light_intensity(id, _rig.get_base_intensity(id) if on else 0.0, 0.08)
	AudioManager.set_loop_volume(&"horror_drone", -21.0 if on else -11.0, 1.5)


func _on_lightning(strength: float) -> void:
	_rig.flash(strength * 0.55)
	_after(randf_range(0.8, 2.2), func() -> void:
		AudioManager.play_sfx(&"thunder", lerpf(-16.0, -6.0, strength), randf_range(0.85, 1.05)))


func _on_stats_changed() -> void:
	_resumes.sheet_count = GameState.candidates_pending
	_computer.refresh()


# --- Phase 2 staging ----------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"journal_toggle"):
		if _host.current_panel and _host.current_panel.scene_file_path == RecruitUI.JOURNAL_SCENE:
			get_viewport().set_input_as_handled()
			_host.close_current()
		elif GameManager.mode == GameManager.Mode.EXPLORE and not _host.is_open():
			get_viewport().set_input_as_handled()
			open_journal()


func open_journal() -> void:
	AudioManager.play_sfx(&"paper", -4.0)
	_host.open(load(RecruitUI.JOURNAL_SCENE))


## Runs whatever Phase 2 beat is waiting: a CEO intervention first, then the
## end-of-review call and report. Retries while the player is busy.
func _check_staging() -> void:
	if _staging:
		return
	var cabin_due := Recruitment.is_perfect() and GameState.is_flag_set(&"phase2_report_seen") and not GameState.is_flag_set(&"phase2_cabin_seen")
	var waiting := cabin_due or not Recruitment.pending_intervention().is_empty() or (Recruitment.is_complete() and not GameState.is_flag_set(&"phase2_report_seen"))
	if not waiting:
		return
	if _host.is_open() or GameManager.mode != GameManager.Mode.EXPLORE or _phone_line.is_ringing or _phone_line.in_call:
		_after(2.0, _check_staging)
		return
	if Recruitment.pending_intervention().get("kind", "") == "fired":
		_stage_firing()
	elif not Recruitment.pending_intervention().is_empty():
		_stage_ceo_intervention()
	elif not GameState.is_flag_set(&"phase2_report_seen"):
		_stage_report()
	else:
		_stage_cabin_summons()


func _on_email_arrived(email: Dictionary) -> void:
	_after(1.2, func() -> void:
		AudioManager.play_sfx(&"boot", -6.0, 1.6)
		_hud.toast("NEW EMAIL  ·  %s  ·  \"%s\"" % [str(email.get("from", "")).to_upper(), email.get("subject", "")]))


## Perfect recruitment: Aditya calls Alice up to his cabin (the second ending).
func _stage_cabin_summons() -> void:
	_staging = true
	GameState.set_flag(&"phase2_cabin_seen")
	GameManager.save_game()
	_phone.caller_label = "ADITYA"
	_phone.ringing = true
	AudioManager.play_loop(&"phone_ring", AudioManager.BUS_SFX, -4.0, 0.02)
	_after(2.0, func() -> void:
		AudioManager.stop_loop(&"phone_ring", 0.05)
		AudioManager.play_sfx(&"phone_pickup")
		_phone.ringing = false
		_phone.off_hook = true
		var lines: Array[Dictionary] = []
		for l: Dictionary in DataLoader.load_json(ENDING_PATH).get("summon", []):
			lines.append(l)
		DialogueManager.dialogue_ended.connect(_on_cabin_summons_ended, CONNECT_ONE_SHOT)
		DialogueManager.start(lines, &"phase2_cabin_summons"))


func _on_cabin_summons_ended(_id: StringName) -> void:
	AudioManager.play_sfx(&"phone_hangup")
	_phone.off_hook = false
	if test_no_scene_change:
		_staging = false
		return
	AudioManager.stop_all_loops(1.5)
	SceneManager.change_scene(CABIN_SCENE, 1.4)


## Third mistake: Aditya comes to the door once more, summons Alice upstairs,
## and the game cuts to his office for the dismissal.
func _stage_firing() -> void:
	_staging = true
	GameManager.save_game()
	AudioManager.play_sfx(&"door", 3.0, 1.1)
	AudioManager.set_loop_volume(&"horror_drone", -4.0, 0.8)
	_rig.set_light_intensity(&"corridor", 0.9, 0.5)
	_rig.set_light_intensity(&"lamp_pool", 0.0, 0.3)
	_rig.set_light_intensity(&"lamp_near", 0.0, 0.3)
	_intruder.enter(1.4)
	_after(1.6, func() -> void:
		AudioManager.play_sfx(&"stinger", 0.0, 0.7)
		_flash.color = Color(0.75, 0.02, 0.02, 0.0)
		var flash := create_tween()
		flash.tween_property(_flash, "color:a", 0.55, 0.06)
		flash.tween_property(_flash, "color:a", 0.0, 1.4)
		_shake($Environment, 0.8, 18.0)
		var lines: Array[Dictionary] = []
		for l: Dictionary in Recruitment.ceo.get("summon", []):
			lines.append(l)
		DialogueManager.dialogue_ended.connect(_on_summon_ended, CONNECT_ONE_SHOT)
		DialogueManager.start(lines, &"phase2_summon"))


func _on_summon_ended(_id: StringName) -> void:
	_intruder.leave(1.0)
	AudioManager.play_sfx(&"door", -2.0, 0.8)
	if test_no_scene_change:
		return
	AudioManager.stop_all_loops(1.5)
	SceneManager.change_scene(FIRED_SCENE, 1.4)


## Aditya walks into the office: the door bangs open, corridor light floods
## in, the desk lamp dies and he stands in the doorway with burning red eyes.
func _stage_ceo_intervention() -> void:
	_staging = true
	var cid: String = Recruitment.pending_intervention()["candidate"]
	GameManager.save_game()
	AudioManager.play_sfx(&"door", 2.0, 1.15)
	AudioManager.set_loop_volume(&"horror_drone", -6.0, 0.8)
	_rig.set_light_intensity(&"corridor", 0.9, 0.5)
	# The lamp stutters and goes out as he steps in.
	var lamp_base := _rig.get_base_intensity(&"lamp_pool") if not GameState.is_flag_set(&"lamp_off") else 0.0
	var flicker := create_tween()
	for i in 5:
		flicker.tween_callback(_rig.set_light_intensity.bind(&"lamp_pool", lamp_base * 0.15))
		flicker.tween_interval(0.07)
		flicker.tween_callback(_rig.set_light_intensity.bind(&"lamp_pool", lamp_base))
		flicker.tween_interval(0.09)
	flicker.tween_callback(_rig.set_light_intensity.bind(&"lamp_pool", lamp_base * 0.25))
	_intruder.enter(1.6)
	_after(1.7, _confront.bind(cid))


func _confront(cid: String) -> void:
	# The outburst: stinger, red flash, the room shakes.
	AudioManager.play_sfx(&"stinger", 0.0, 0.85)
	AudioManager.play_sfx(&"thunder", -4.0, 0.7)
	_flash.color = Color(0.75, 0.02, 0.02, 0.0)
	var flash := create_tween()
	flash.tween_property(_flash, "color:a", 0.5, 0.06)
	flash.tween_property(_flash, "color:a", 0.1, 0.35)
	flash.tween_property(_flash, "color:a", 0.0, 1.2)
	_rig.flash(0.6, Color(0.9, 0.15, 0.1))
	_shake($Environment, 1.0, 16.0)
	_after(0.5, _open_ceo_panel.bind(cid))


func _ceo_leaves() -> void:
	_intruder.leave(1.4)
	AudioManager.play_sfx(&"door", -2.0, 0.9)
	AudioManager.set_loop_volume(&"horror_drone", -21.0 if not GameState.is_flag_set(&"lamp_off") else -11.0, 2.0)
	_rig.set_light_intensity(&"corridor", 0.0, 1.4)
	if not GameState.is_flag_set(&"lamp_off"):
		_rig.set_light_intensity(&"lamp_pool", _rig.get_base_intensity(&"lamp_pool"), 1.5)


func _open_ceo_panel(cid: String) -> void:
	var panel := _host.open(load(RecruitUI.CEO_SCENE))
	if panel == null:
		_ceo_leaves()
		_staging = false
		return
	var choice := {"value": "keep"}
	panel.connect(&"chose", func(c: String) -> void: choice["value"] = c)
	panel.closed.connect(func() -> void:
		_ceo_leaves()
		_staging = false
		GameManager.save_game()
		if choice["value"] == "review":
			_hud.toast("FILE REOPENED — %s" % Recruitment.get_candidate(cid).display_name().to_upper())
			_host.open(load(RecruitUI.RESUME_SCENE), {"candidate_id": cid})
		else:
			_after(0.5, _check_staging))


func _shake(node: Node2D, duration: float, strength: float) -> void:
	var home := node.position
	var tw := create_tween()
	var steps := int(duration / 0.05)
	for i in steps:
		var falloff := 1.0 - float(i) / steps
		tw.tween_property(node, "position", home + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength * falloff, 0.05)
	tw.tween_property(node, "position", home, 0.05)


func _stage_report() -> void:
	_staging = true
	GameState.set_objective(OBJ_DONE)
	GameManager.save_game()
	_phone.caller_label = "ADITYA"
	_phone.ringing = true
	AudioManager.play_loop(&"phone_ring", AudioManager.BUS_SFX, -4.0, 0.02)
	_after(2.2, _report_call)


func _report_call() -> void:
	AudioManager.stop_loop(&"phone_ring", 0.05)
	AudioManager.play_sfx(&"phone_pickup")
	_phone.ringing = false
	_phone.off_hook = true
	var lines: Array[Dictionary] = []
	for l: Dictionary in Recruitment.ceo.get("report_call", []):
		lines.append(l)
	DialogueManager.dialogue_ended.connect(_on_report_call_ended, CONNECT_ONE_SHOT)
	DialogueManager.start(lines, &"phase2_report_call")


func _on_report_call_ended(_id: StringName) -> void:
	AudioManager.play_sfx(&"phone_hangup")
	_phone.off_hook = false
	_after(0.6, func() -> void:
		_staging = false
		_host.open(load(RecruitUI.REPORT_SCENE))
		GameManager.save_game())


func _draw_glow() -> void:
	# Soft additive halos so screens bloom into the dark room.
	Paint.soft(_glow, Vector2(960, 440), Vector2(440, 290), Color(0.3, 0.5, 0.85, 0.13))
	Paint.soft(_glow, Vector2(300, 450), Vector2(250, 190), Color(0.55, 0.68, 0.78, 0.1))
	Paint.soft(_glow, Vector2(1830, 220), Vector2(120, 160), Color(0.6, 0.7, 0.8, 0.06))
