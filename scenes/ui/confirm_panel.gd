class_name ConfirmPanel
extends ModalPanel
## Yes/No confirmation. Create with ConfirmPanel.create(...), add to a UI
## parent, then await `answered` (true = confirmed).

signal answered(confirmed: bool)

var message: String = ""
var confirm_text: String = "CONFIRM"
var cancel_text: String = "CANCEL"
var _answer: bool = false


static func create(p_title: String, p_message: String, p_confirm: String = "CONFIRM", p_cancel: String = "CANCEL") -> ConfirmPanel:
	var c := ConfirmPanel.new()
	c.name = "ConfirmPanel"
	c.title = p_title
	c.message = p_message
	c.confirm_text = p_confirm
	c.cancel_text = p_cancel
	c.panel_size = Vector2(820, 330)
	return c


func _build_content(body: VBoxContainer) -> void:
	var msg := UITheme.label(message, &"SerifLabel", 24)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(msg)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override(&"separation", 16)
	body.add_child(row)
	var cancel := UITheme.button(cancel_text)
	cancel.pressed.connect(func() -> void: _respond(false))
	row.add_child(cancel)
	var ok := UITheme.button(confirm_text)
	ok.add_theme_color_override(&"font_color", UITheme.ACCENT_SOFT)
	ok.pressed.connect(func() -> void: _respond(true))
	row.add_child(ok)
	closed.connect(func() -> void:
		answered.emit(_answer)
		queue_free())


func _respond(yes: bool) -> void:
	AudioManager.play_sfx(&"ui_click")
	_answer = yes
	close()
