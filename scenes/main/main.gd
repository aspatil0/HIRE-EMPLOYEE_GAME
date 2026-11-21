extends Control
## Boot scene (project main scene). Verifies core systems, then opens the
## title screen.
##
## Command-line user args (after `--`):
##   --smoke-test              run automated checks and exit with code 0/1
##   --scene=res://path.tscn   skip the menu and open a scene directly (dev)
##   --activate=<id>           with --scene: after 2.5 s, click the interactable
##                             with that interaction_id (dev/screenshot helper)
##   --capture=<s>:<file.png>[,<s>:<file.png>...]
##                             save screenshots at those times, then quit (dev QA)

const MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const OFFICE_SCENE := "res://scenes/locations/alice_office.tscn"
const INTRO_SCENE := "res://scenes/cutscenes/intro_assignment.tscn"

@onready var _status: Label = %Status

var _failures: Array[String] = []


func _ready() -> void:
	var report := _check_systems()
	_status.text = report.text
	print("[THE FINAL HIRE] Boot OK — Godot %s — %s" % [Engine.get_version_info().string, report.text])
	GameManager.set_mode(GameManager.Mode.TITLE)

	var args := OS.get_cmdline_user_args()
	if "--smoke-test" in args:
		_run_smoke_test.call_deferred(report.ok)
		return
	var target := MENU_SCENE
	var activate := ""
	for a in args:
		if a.begins_with("--scene="):
			target = a.trim_prefix("--scene=")
		elif a.begins_with("--activate="):
			activate = a.trim_prefix("--activate=")
		elif a.begins_with("--capture="):
			_dev_capture.call_deferred(a.trim_prefix("--capture="))
	if target != MENU_SCENE:
		GameManager.set_mode(GameManager.Mode.EXPLORE)
	if not activate.is_empty():
		_dev_activate(activate) # static coroutine: survives this scene being freed
	SceneManager.change_scene(target, 0.25)


func _check_systems() -> Dictionary:
	var missing: Array[String] = []
	for autoload_name in ["GameState", "DialogueManager", "SceneManager", "GameManager", "AudioManager", "GameSettings"]:
		if not has_node("/root/" + autoload_name):
			missing.append(autoload_name)
	var actions_missing: Array[String] = []
	for action in ["interact", "inspect", "inventory_toggle", "journal_toggle", "dialogue_advance", "pause"]:
		if not InputMap.has_action(action):
			actions_missing.append(action)
	var ok := missing.is_empty() and actions_missing.is_empty()
	var text := "Systems online" if ok else "Missing autoloads %s, actions %s" % [missing, actions_missing]
	return {"ok": ok, "text": text}


## Dev helper: click an interactable in the current scene by id.
static func _dev_activate(id: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	await tree.create_timer(2.5).timeout
	var scene := tree.current_scene
	if scene == null:
		return
	var controller := scene.find_child("Interaction", true, false) as InteractionController
	for node in tree.get_nodes_in_group(&"interactables"):
		var it := node as Interactable
		if it and String(it.interaction_id) == id and controller:
			print("[DEV] activating %s" % it.get_path())
			controller.activate(it)
			return
	push_warning("--activate: no interactable '%s'" % id)


## Dev helper: timed screenshots of the real rendered viewport, then quit.
static func _dev_capture(spec: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var elapsed := 0.0
	for shot in spec.split(","):
		var at := float(shot.get_slice(":", 0))
		var path := shot.substr(shot.find(":") + 1)
		await tree.create_timer(maxf(at - elapsed, 0.0), true, false, true).timeout
		elapsed = at
		await RenderingServer.frame_post_draw
		var err := tree.root.get_texture().get_image().save_png(path)
		print("[CAPTURE] %s -> %s (%s)" % [at, path, error_string(err)])
	tree.quit()


# --- Smoke test ---------------------------------------------------------------

func _check(ok: bool, what: String) -> void:
	print("[SMOKE] %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures.append(what)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run_smoke_test(systems_ok: bool) -> void:
	GameManager.saving_enabled = false
	_check(systems_ok, "autoloads and input actions")

	# State + serialization round trip.
	GameState.set_flag(&"smoke_flag")
	GameState.add_item(&"keycard")
	GameState.discover_clue(&"memo")
	GameState.advance_time(5)
	var snapshot := GameState.to_dict()
	GameState.reset()
	GameState.from_dict(snapshot)
	_check(GameState.is_flag_set(&"smoke_flag") and GameState.has_item(&"keycard") and GameState.has_clue(&"memo"), "GameState round trip")
	_check(GameState.get_time_string() == "21:05", "in-game clock")

	# Dialogue flow drives GameManager mode.
	GameManager.set_mode(GameManager.Mode.EXPLORE)
	DialogueManager.start_from_file("res://data/dialogue/_format_example.json")
	_check(GameManager.mode == GameManager.Mode.DIALOGUE, "dialogue enters DIALOGUE mode")
	while DialogueManager.is_active:
		DialogueManager.advance()
	_check(GameManager.mode == GameManager.Mode.EXPLORE, "dialogue restores EXPLORE mode")
	_check(GameState.is_flag_set(&"met_hr"), "dialogue set_flag")
	GameState.reset()

	# Data files.
	_check(DataLoader.candidates(1).size() == 6, "candidate data loads")
	_check(not DataLoader.company(1).is_empty(), "company data loads")
	for path in ["res://data/dialogue/intro_assignment.json", "res://data/dialogue/call_aditya_day1.json", "res://data/dialogue/office_arrival.json"]:
		_check(not DialogueManager.load_dialogue_file(path).is_empty(), "dialogue file %s" % path.get_file())

	# Audio: every placeholder sound can be produced.
	for id: StringName in [&"ui_click", &"phone_ring", &"rain", &"horror_drone", &"clock_tick", &"door", &"stinger"]:
		_check(AudioManager.get_stream(id) != null, "sound '%s'" % id)

	await _test_office()
	await _test_scene_boots(MENU_SCENE)
	await _test_intro()

	GameState.reset()
	var ok := _failures.is_empty()
	print("[SMOKE] %s%s" % ["PASS" if ok else "FAIL: ", "" if ok else ", ".join(_failures)])
	get_tree().quit(0 if ok else 1)


func _test_scene_boots(path: String) -> void:
	var scene := (load(path) as PackedScene)
	_check(scene != null, "scene loads: %s" % path.get_file())
	if scene == null:
		return
	var inst := scene.instantiate()
	get_tree().root.add_child(inst)
	await _frames(5)
	_check(inst.is_inside_tree(), "scene runs: %s" % path.get_file())
	inst.queue_free()
	await _frames(2)


func _test_office() -> void:
	GameState.reset()
	GameState.set_flag(&"arrival_seen") # skip the arrival beat for the test
	GameState.set_flag(&"call_day1_done")
	GameManager.set_mode(GameManager.Mode.EXPLORE)
	var office := (load(OFFICE_SCENE) as PackedScene).instantiate()
	get_tree().root.add_child(office)
	await _frames(3)
	var controller := office.get_node("Interaction") as InteractionController
	var host := office.get_node("UI/PanelHost") as PanelHost
	_check(controller != null and host != null, "office: controller + panel host")
	var by_id: Dictionary[String, Interactable] = {}
	for n in get_tree().get_nodes_in_group(&"interactables"):
		var it := n as Interactable
		by_id[String(it.interaction_id)] = it
	for id in ["main_computer", "side_computer", "resume_stack", "telephone", "document_tray", "desk_lamp", "wall_clock", "window", "door", "corkboard", "bookshelf"]:
		_check(by_id.has(id), "office: interactable '%s' present" % id)
	_check(GameState.candidates_pending == 6, "office: candidate count initialised")

	# Picking hits the right objects at their on-screen positions.
	var picks := {"resume_stack": Vector2(1420, 770), "main_computer": Vector2(960, 420), "telephone": Vector2(1745, 880),
		"side_computer": Vector2(300, 440), "document_tray": Vector2(330, 850), "wall_clock": Vector2(1475, 150)}
	for id: String in picks:
		var hit := controller.pick(picks[id])
		_check(hit != null and String(hit.interaction_id) == id, "office: click at %s picks %s" % [picks[id], id])

	# Every panel opens, blocks interaction, and closes cleanly.
	for id in ["resume_stack", "main_computer", "side_computer", "telephone", "document_tray"]:
		if not by_id.has(id):
			continue
		controller.activate(by_id[id])
		await _frames(2)
		var panel := host.current_panel
		_check(panel != null and GameManager.mode == GameManager.Mode.INSPECT, "panel opens: %s" % id)
		_check(not GameManager.can_interact(), "hotspots inert while %s open" % id)
		if panel:
			await get_tree().create_timer(0.4).timeout
			await panel.close()
			await _frames(2)
		_check(host.current_panel == null and GameManager.mode == GameManager.Mode.EXPLORE, "panel closes: %s" % id)

	# Right-click inspection runs a one-line thought through DialogueManager.
	controller.inspect(by_id["window"])
	_check(DialogueManager.is_active and GameManager.mode == GameManager.Mode.DIALOGUE, "inspect shows a thought")
	DialogueManager.end()
	_check(GameManager.mode == GameManager.Mode.EXPLORE, "inspect returns to EXPLORE")

	# Lamp toggles.
	var lamp := office.get_node("Environment/DeskLamp") as DeskLampProp
	controller.activate(by_id["desk_lamp"])
	_check(not lamp.is_on, "lamp switches off")
	controller.activate(by_id["desk_lamp"])
	_check(lamp.is_on, "lamp switches on")

	# Incoming call: ring -> answer -> dialogue -> hang up.
	GameState.set_flag(&"call_day1_done", false)
	var line := office.get_node("PhoneLine") as PhoneLine
	line.ring(&"aditya", "ADITYA", "res://data/dialogue/call_aditya_day1.json")
	_check(line.is_ringing, "phone rings")
	controller.activate(by_id["telephone"])
	await _frames(2)
	_check(host.current_panel != null, "phone panel opens while ringing")
	var answer := host.current_panel.find_child("AnswerButton", true, false) as Button
	_check(answer != null, "incoming call shows ANSWER")
	if answer:
		answer.pressed.emit()
		await get_tree().create_timer(0.6).timeout
	_check(DialogueManager.is_active and line.in_call, "answering starts the call dialogue")
	while DialogueManager.is_active:
		DialogueManager.advance()
	await _frames(2)
	_check(GameState.is_flag_set(&"call_day1_done") and not line.in_call, "call completes and sets flag")
	_check(GameManager.mode == GameManager.Mode.EXPLORE, "back to EXPLORE after call")

	# Pause round trip.
	GameManager.set_paused(true)
	await _frames(2)
	_check(get_tree().paused and (office.get_node("UI/PauseMenu") as Control).visible, "pause menu shows")
	GameManager.set_paused(false)
	await _frames(2)
	_check(not get_tree().paused, "unpause")

	office.queue_free()
	await _frames(3)
	AudioManager.stop_all_loops(0.0)


func _test_intro() -> void:
	GameState.reset()
	GameManager.set_mode(GameManager.Mode.EXPLORE)
	var intro := (load(INTRO_SCENE) as PackedScene).instantiate()
	get_tree().root.add_child(intro)
	await _frames(3)
	DialogueManager.start_from_file("res://data/dialogue/intro_assignment.json")
	_check(DialogueManager.is_active, "intro dialogue starts")
	var lines := 0
	while DialogueManager.is_active and lines < 50:
		DialogueManager.advance()
		lines += 1
		await _frames(1)
	_check(lines == 8 and GameState.is_flag_set(&"intro_seen"), "intro dialogue plays 8 lines")
	intro.queue_free()
	await _frames(3)
	AudioManager.stop_all_loops(0.0)
