extends Control
## Pause overlay. Shown whenever GameManager enters PAUSED; runs while the
## tree is paused. Offers resume, settings, manual save and quitting.

const SETTINGS_SCENE := preload("res://scenes/ui/settings_panel.tscn")

@onready var _resume: Button = %Resume
@onready var _settings: Button = %Settings
@onready var _save: Button = %Save
@onready var _menu: Button = %MainMenu
@onready var _quit: Button = %Quit
@onready var _status: Label = %SaveStatus
@onready var _content: Control = %Content

var _busy: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	GameManager.mode_changed.connect(_on_mode_changed)
	_resume.pressed.connect(func() -> void: GameManager.set_paused(false))
	_settings.pressed.connect(_open_settings)
	_save.pressed.connect(_save_game)
	_menu.pressed.connect(_to_menu)
	_quit.pressed.connect(_quit_game)
	_save.disabled = not _can_save()


func _can_save() -> bool:
	# Only the office is a safe resume point in Phase 1.
	var scene := get_tree().current_scene
	return scene != null and scene.is_in_group(&"saveable_location")


func _on_mode_changed(new_mode: int, _old: int) -> void:
	if new_mode == GameManager.Mode.PAUSED:
		_show()
	elif visible:
		_hide()


func _show() -> void:
	visible = true
	_status.text = ""
	_save.disabled = not _can_save()
	modulate.a = 0.0
	_content.position.x = -30.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.2)
	tw.tween_property(_content, "position:x", 0.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_resume.grab_focus()


func _hide() -> void:
	for child in get_children():
		if child is ModalPanel:
			child.queue_free()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	tw.tween_callback(hide)


func _open_settings() -> void:
	var panel := SETTINGS_SCENE.instantiate() as ModalPanel
	panel.closed.connect(panel.queue_free)
	add_child(panel)


func _save_game() -> void:
	if GameManager.save_game():
		_status.text = "PROGRESS SAVED  ·  %s" % GameState.get_time_string()
	else:
		_status.text = "COULD NOT SAVE"


func _to_menu() -> void:
	if _busy:
		return
	var confirm := ConfirmPanel.create("RETURN TO MAIN MENU", "Your progress was saved when you last reached the office. Return to the main menu?", "MAIN MENU")
	add_child(confirm)
	if await confirm.answered:
		_busy = true
		if _can_save():
			GameManager.save_game()
		GameManager.return_to_title()


func _quit_game() -> void:
	var confirm := ConfirmPanel.create("QUIT TO DESKTOP", "Close THE FINAL HIRE? Progress in the office is saved automatically.", "QUIT")
	add_child(confirm)
	if await confirm.answered:
		if _can_save():
			GameManager.save_game()
		GameManager.quit_game()
