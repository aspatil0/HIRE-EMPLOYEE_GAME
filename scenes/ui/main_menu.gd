extends Control
## Title screen: rainy city through an office window, animated title,
## New Game / Continue / Settings / Exit.

const INTRO_SCENE := "res://scenes/cutscenes/intro_assignment.tscn"
const SETTINGS_SCENE := preload("res://scenes/ui/settings_panel.tscn")
const TITLE_TEXT := "THE FINAL HIRE"

@onready var _rig: LightingRig = $World/LightingRig
@onready var _window: NightWindow = $World/NightWindow
@onready var _ui: Control = $UI/Root
@onready var _title_row: HBoxContainer = %TitleRow
@onready var _rule: ColorRect = %Rule
@onready var _tagline: Label = %Tagline
@onready var _buttons: VBoxContainer = %Buttons
@onready var _new_game: Button = %NewGame
@onready var _continue: Button = %Continue
@onready var _settings: Button = %Settings
@onready var _exit: Button = %Exit
@onready var _footer: Control = %Footer
@onready var _toast: Label = %Toast

var _letters: Array[Label] = []
var _busy: bool = false
var _glitch_timer: float = 6.0


func _ready() -> void:
	GameManager.set_mode(GameManager.Mode.TITLE)
	get_tree().paused = false
	_rig.add_light(&"window", Vector2(1000, 380), 1400.0, Color(0.36, 0.44, 0.64), 1.1, 0.6)
	_rig.add_light(&"lamp", Vector2(1620, 900), 520.0, Color(1.0, 0.72, 0.45), 0.9, 0.6, 0.04)
	_window.lightning_struck.connect(_on_lightning)
	AudioManager.set_soundscape({
		&"rain": [AudioManager.BUS_AMBIENCE, -9.0],
		&"horror_drone": [AudioManager.BUS_MUSIC, -9.0],
	}, 2.5)

	_continue.disabled = not GameManager.has_save()
	_continue.tooltip_text = "" if GameManager.has_save() else "No saved game yet"
	_new_game.pressed.connect(_on_new_game)
	_continue.pressed.connect(_on_continue)
	_settings.pressed.connect(_on_settings)
	_exit.pressed.connect(_on_exit)
	_build_title()
	_animate_in()


func _build_title() -> void:
	for ch in TITLE_TEXT:
		var l := Label.new()
		l.text = ch if ch != " " else "  "
		l.theme_type_variation = &"TitleLabel"
		l.add_theme_font_size_override(&"font_size", 112)
		l.modulate.a = 0.0
		_title_row.add_child(l)
		_letters.append(l)


func _animate_in() -> void:
	_rule.custom_minimum_size.x = 0.0
	_tagline.modulate.a = 0.0
	_buttons.modulate.a = 0.0
	_footer.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_interval(0.8)
	# Letters flicker on one at a time, like failing office tubes.
	for i in _letters.size():
		var l := _letters[i]
		var delay := 0.8 + i * 0.09 + randf() * 0.25
		var flick := create_tween()
		flick.tween_interval(delay)
		flick.tween_property(l, "modulate:a", 0.8, 0.05)
		flick.tween_property(l, "modulate:a", 0.1, 0.06)
		flick.tween_property(l, "modulate:a", 1.0, 0.35)
	tw.tween_interval(1.9)
	tw.tween_callback(func() -> void: AudioManager.play_sfx(&"stinger", -12.0))
	tw.tween_property(_rule, "custom_minimum_size:x", 560.0, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_tagline, "modulate:a", 1.0, 1.2)
	tw.tween_property(_buttons, "modulate:a", 1.0, 0.8)
	tw.parallel().tween_property(_footer, "modulate:a", 1.0, 1.2)
	tw.tween_callback(func() -> void:
		if not _busy:
			_new_game.grab_focus())


func _process(delta: float) -> void:
	# Occasional glitch: a letter blinks out, the title shudders.
	_glitch_timer -= delta
	if _glitch_timer <= 0.0 and not _letters.is_empty():
		_glitch_timer = randf_range(4.0, 9.0)
		var l := _letters[randi() % _letters.size()]
		if l.modulate.a > 0.9:
			var tw := create_tween()
			tw.tween_property(l, "modulate:a", 0.15, 0.04)
			tw.tween_property(l, "modulate:a", 1.0, 0.04)
			tw.tween_property(l, "modulate:a", 0.3, 0.05)
			tw.tween_property(l, "modulate:a", 1.0, 0.2)


func _on_lightning(strength: float) -> void:
	_rig.flash(strength * 0.6)
	var tw := create_tween()
	tw.tween_interval(randf_range(0.9, 2.0))
	tw.tween_callback(func() -> void: AudioManager.play_sfx(&"thunder", lerpf(-14.0, -5.0, strength)))


func _set_buttons_enabled(on: bool) -> void:
	for b: Button in [_new_game, _continue, _settings, _exit]:
		b.disabled = not on if b != _continue else (not on or not GameManager.has_save())


func _on_new_game() -> void:
	if _busy:
		return
	if GameManager.has_save():
		var confirm := ConfirmPanel.create("START A NEW GAME", "Starting over will replace your saved progress. Continue?", "NEW GAME")
		_ui.add_child(confirm)
		if not await confirm.answered:
			_new_game.grab_focus()
			return
	_busy = true
	_set_buttons_enabled(false)
	AudioManager.play_sfx(&"stinger", -4.0)
	AudioManager.stop_all_loops(1.6)
	var tw := create_tween()
	tw.tween_property(_ui, "modulate:a", 0.0, 0.9)
	await tw.finished
	GameManager.new_game(INTRO_SCENE, 1.0)


func _on_continue() -> void:
	if _busy or not GameManager.has_save():
		return
	_busy = true
	_set_buttons_enabled(false)
	AudioManager.stop_all_loops(1.0)
	var ok: bool = await GameManager.load_game()
	if not ok:
		_busy = false
		_set_buttons_enabled(true)
		_show_toast("The saved game could not be loaded.")


func _on_settings() -> void:
	if _busy:
		return
	var panel := SETTINGS_SCENE.instantiate() as ModalPanel
	panel.closed.connect(func() -> void:
		panel.queue_free()
		_settings.grab_focus())
	_ui.add_child(panel)


func _on_exit() -> void:
	if _busy:
		return
	_busy = true
	_set_buttons_enabled(false)
	AudioManager.stop_all_loops(0.6)
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color.BLACK, 0.6)
	await tw.finished
	GameManager.quit_game()


func _show_toast(text: String) -> void:
	_toast.text = text
	var tw := create_tween()
	tw.tween_property(_toast, "modulate:a", 1.0, 0.2)
	tw.tween_interval(2.5)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.5)
