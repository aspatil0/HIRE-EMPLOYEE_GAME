class_name GameHUD
extends Control
## Minimal in-game HUD: day + clock and objective (top-left), candidate count
## and company status (top-right), pause button, control hints, location card
## and short toasts. Everything except the pause button ignores the mouse so
## the office stays clickable underneath.

@onready var _day: Label = %Day
@onready var _time: Label = %Time
@onready var _objective: Label = %Objective
@onready var _candidates: Label = %Candidates
@onready var _status: Label = %Status
@onready var _status_dot: ColorRect = %StatusDot
@onready var _pause: Button = %PauseButton
@onready var _hint: Label = %Hint
@onready var _card: VBoxContainer = %LocationCard
@onready var _card_title: Label = %CardTitle
@onready var _card_sub: Label = %CardSubtitle
@onready var _toast: Label = %Toast

var _toast_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause.focus_mode = Control.FOCUS_NONE
	_pause.pressed.connect(func() -> void:
		AudioManager.play_sfx(&"ui_click")
		GameManager.set_paused(true))
	GameState.time_changed.connect(func(_m: int) -> void: _refresh())
	GameState.stats_changed.connect(_refresh)
	GameState.objective_changed.connect(_on_objective)
	_card.modulate.a = 0.0
	_toast.modulate.a = 0.0
	_hint.modulate.a = 0.0
	_on_objective(GameState.objective)
	_refresh()


func _refresh() -> void:
	_day.text = "DAY %d" % GameState.day
	_time.text = GameState.get_time_string()
	_candidates.text = "CANDIDATES   %d PENDING   ·   %d / %d HIRED" % [GameState.candidates_pending, GameState.hires, GameState.hire_target]
	var status := GameState.get_company_status()
	_status.text = "COMPANY   %s" % status
	var col := Color(0.45, 0.75, 0.5)
	if status == "STRAINED":
		col = Color(0.9, 0.7, 0.3)
	elif status == "CRITICAL":
		col = UITheme.ACCENT_SOFT
	_status_dot.color = col


func _on_objective(text: String) -> void:
	_objective.visible = not text.is_empty()
	_objective.text = "◆  %s" % text
	if is_inside_tree() and not text.is_empty():
		var tw := create_tween()
		_objective.modulate = Color(1.6, 1.3, 1.0, 0.0)
		tw.tween_property(_objective, "modulate", Color.WHITE, 0.8)


func show_location_card(title: String, subtitle: String, hold: float = 3.0) -> void:
	_card_title.text = title
	_card_sub.text = subtitle
	var tw := create_tween()
	tw.tween_property(_card, "modulate:a", 1.0, 1.2)
	tw.tween_interval(hold)
	tw.tween_property(_card, "modulate:a", 0.0, 1.4)


func show_hint(hold: float = 9.0) -> void:
	var tw := create_tween()
	tw.tween_property(_hint, "modulate:a", 0.85, 1.0)
	tw.tween_interval(hold)
	tw.tween_property(_hint, "modulate:a", 0.0, 1.5)


func toast(text: String) -> void:
	_toast.text = text
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.25)
	_toast_tween.tween_interval(1.8)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.6)
