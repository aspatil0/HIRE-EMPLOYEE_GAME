extends Node2D
## Alice's office: the main fixed-camera gameplay location.
##
## This script only orchestrates: lighting setup, soundscape, the arrival beat,
## Aditya's first call, ambient scares and autosaves. Object behaviour lives in
## the prop scenes (scenes/interactables/), picking in InteractionController,
## interfaces in scenes/ui/panels/.

const ARRIVAL_DIALOGUE := "res://data/dialogue/office_arrival.json"
const CALL_DIALOGUE := "res://data/dialogue/call_aditya_day1.json"

const OBJ_SETTLE := "Settle in. The resumes are on your desk."
const OBJ_ANSWER := "The phone is ringing."
const OBJ_REVIEW := "Review the resumes, then check each candidate's documents and online traces."
const OBJ_MISSED := "Aditya will call back. Keep working."

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
	_after(0.7, _arrival_beat)


func _init_state() -> void:
	if not GameState.is_flag_set(&"candidates_received"):
		GameState.set_candidates_pending(DataLoader.candidates(GameState.day).size())
		GameState.set_flag(&"candidates_received")
	_resumes.sheet_count = GameState.candidates_pending
	if GameState.objective.is_empty():
		GameState.set_objective(OBJ_SETTLE)


func _setup_lighting() -> void:
	_rig.add_light(&"lamp_pool", Vector2(1410, 800), 760.0, Color(1.0, 0.74, 0.47), 1.0, 0.55, 0.03)
	_rig.add_light(&"lamp_near", Vector2(1560, 470), 360.0, Color(1.0, 0.76, 0.5), 0.5, 1.0, 0.03)
	_rig.add_light(&"monitor", Vector2(960, 470), 560.0, Color(0.42, 0.6, 0.86), 0.6, 0.75, 0.05)
	_rig.add_light(&"side_monitor", Vector2(300, 470), 380.0, Color(0.6, 0.7, 0.76), 0.45, 0.9, 0.07)
	_rig.add_light(&"window", Vector2(910, 280), 540.0, Color(0.33, 0.4, 0.58), 0.55, 0.8)
	_rig.add_light(&"door_glass", Vector2(1830, 220), 260.0, Color(0.45, 0.55, 0.62), 0.32, 1.2)
	_rig.add_light(&"desk_left", Vector2(400, 860), 420.0, Color(0.62, 0.66, 0.72), 0.3, 0.6)
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


func _draw_glow() -> void:
	# Soft additive halos so screens bloom into the dark room.
	Paint.soft(_glow, Vector2(960, 440), Vector2(440, 290), Color(0.3, 0.5, 0.85, 0.13))
	Paint.soft(_glow, Vector2(300, 450), Vector2(250, 190), Color(0.55, 0.68, 0.78, 0.1))
	Paint.soft(_glow, Vector2(1830, 220), Vector2(120, 160), Color(0.6, 0.7, 0.8, 0.06))
