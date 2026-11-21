extends Control
## On-screen dialogue presenter for DialogueManager.
##
## Shows the speaker (with role and accent colour) and types the line out.
## Click / Space / Enter first completes the line, then advances. While this
## node is in the tree it owns advance input (DialogueManager.ui_owns_input).

const SPEAKERS := {
	"ADITYA": {"color": Color(0.78, 0.24, 0.2), "role": "CHIEF EXECUTIVE OFFICER"},
	"ALICE": {"color": Color(0.58, 0.71, 0.84), "role": "RECRUITMENT & VERIFICATION"},
}

@export var chars_per_second: float = 52.0

var _typing: bool = false
var _shown: float = 0.0
var _total: int = 0
var _blink: float = 0.0
var _fade: Tween

@onready var _name_row: HBoxContainer = %NameRow
@onready var _name: Label = %Name
@onready var _role: Label = %Role
@onready var _accent: ColorRect = %Accent
@onready var _text: Label = %Text
@onready var _continue: Label = %Continue


func _enter_tree() -> void:
	DialogueManager.ui_owns_input = true


func _exit_tree() -> void:
	DialogueManager.ui_owns_input = false


func _ready() -> void:
	visible = false
	modulate.a = 0.0
	DialogueManager.line_started.connect(_on_line_started)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)


func is_typing() -> bool:
	return _typing


func _on_line_started(speaker: String, text: String, _line: Dictionary) -> void:
	_show_box()
	var key := speaker.get_slice(" ", 0).to_upper()
	var info: Dictionary = SPEAKERS.get(key, {})
	var narration := speaker.is_empty()
	_name_row.visible = not narration
	_name.text = speaker.to_upper()
	_role.text = str(info.get("role", ""))
	var col: Color = info.get("color", UITheme.WARM)
	_accent.color = col
	_name.add_theme_color_override(&"font_color", col.lightened(0.25))
	_text.add_theme_color_override(&"font_color", UITheme.DIM if narration else UITheme.INK)
	_text.text = text
	_total = text.length()
	_shown = 0.0
	_text.visible_characters = 0
	_typing = true
	_continue.visible = false


func _process(delta: float) -> void:
	if _typing:
		_shown += chars_per_second * delta
		_text.visible_characters = int(_shown)
		if int(_shown) >= _total:
			_finish_typing()
	elif _continue.visible:
		_blink += delta
		_continue.modulate.a = 0.45 + 0.55 * absf(sin(_blink * 3.0))
		_continue.position.y = sin(_blink * 3.0) * 2.0


func _finish_typing() -> void:
	_typing = false
	_text.visible_characters = -1
	_continue.visible = true
	_blink = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if not DialogueManager.is_active or not visible:
		return
	if event.is_action_pressed(&"dialogue_advance"):
		get_viewport().set_input_as_handled()
		if _typing:
			_finish_typing()
		else:
			AudioManager.play_sfx(&"ui_click", -14.0, 0.8)
			DialogueManager.advance()


func _show_box() -> void:
	if visible and modulate.a >= 0.99:
		return
	visible = true
	if _fade and _fade.is_valid():
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", 1.0, 0.25)


func _on_dialogue_ended(_id: StringName) -> void:
	_typing = false
	if _fade and _fade.is_valid():
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", 0.0, 0.25)
	_fade.tween_callback(hide)
