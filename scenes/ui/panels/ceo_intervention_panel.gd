extends ModalPanel
## CEO intervention: Aditya interrupts a serious recruitment mistake. Lines
## from data/dialogue/phase_2_ceo.json are hammered out one by one; Alice
## must choose to REVIEW (reopen the file) or KEEP the decision. Cannot be
## dismissed with Esc. Emits `chose` with "review" or "keep".

signal chose(choice: String)

var _script: Dictionary = {}
var _lines_box: VBoxContainer
var _buttons: HBoxContainer
var _reply: Label


func _init() -> void:
	title = "ADITYA IS IN YOUR OFFICE"
	subtitle = "He did not knock"
	panel_size = Vector2(1180, 720)
	dim_backdrop = false # keep him visible in the doorway behind the dialog
	accent = Color(0.85, 0.08, 0.06)
	closable = false


func _build_content(body: VBoxContainer) -> void:
	_script = Recruitment.intervention_script()
	frame.position.x = 150.0 # leave the door (right side of the room) in view
	frame.add_theme_stylebox_override(&"panel", UITheme.flat_box(Color(0.07, 0.015, 0.015, 0.98), Color(0.7, 0.08, 0.06), 2, 0))
	var head := UITheme.label(str(_script.get("headline", "ALICE.")), &"TitleLabel", 76, Color(1.0, 0.35, 0.3))
	head.name = "Headline"
	body.add_child(head)
	var strike_text := "FINAL WARNING — ONE MORE MISTAKE AND YOU ARE FIRED" if _script.get("final", false) else "WARNING %d OF %d" % [int(_script.get("strike", 1)), Recruitment.MAX_WARNINGS]
	var who := UITheme.label("ADITYA  ·  STANDING IN YOUR DOORWAY  ·  %s" % strike_text, &"DimLabel", 15, Color(0.9, 0.45, 0.4))
	who.name = "StrikeLabel"
	body.add_child(who)
	_lines_box = VBoxContainer.new()
	_lines_box.add_theme_constant_override(&"separation", 14)
	_lines_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_lines_box)
	_reply = UITheme.label("", &"SerifLabel", 22, Color(1, 0.75, 0.7))
	_reply.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_reply)
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override(&"separation", 24)
	_buttons.modulate.a = 0.0
	body.add_child(_buttons)
	var review := UITheme.button(str(_script.get("review_label", "REVIEW")))
	review.name = "ReviewButton"
	review.custom_minimum_size = Vector2(340, 66)
	review.add_theme_stylebox_override(&"normal", UITheme.flat_box(Color(0.5, 0.06, 0.05), Color(1, 0.4, 0.3), 2, 10))
	review.add_theme_stylebox_override(&"hover", UITheme.flat_box(Color(0.7, 0.1, 0.08), Color(1, 0.6, 0.5), 2, 10))
	review.add_theme_font_size_override(&"font_size", 22)
	review.pressed.connect(choose.bind("review"))
	_buttons.add_child(review)
	var keep := UITheme.button(str(_script.get("keep_label", "KEEP")))
	keep.name = "KeepButton"
	keep.custom_minimum_size = Vector2(340, 66)
	keep.add_theme_font_size_override(&"font_size", 22)
	keep.pressed.connect(choose.bind("keep"))
	_buttons.add_child(keep)

	var tw := create_tween()
	tw.tween_interval(0.5)
	for line: String in _script.get("lines", []):
		tw.tween_callback(_add_line.bind(line))
		tw.tween_interval(1.1)
	tw.tween_property(_buttons, "modulate:a", 1.0, 0.4)
	# Headline shudder.
	var shake := create_tween().set_loops(6)
	shake.tween_property(head, "position:x", 6.0, 0.04)
	shake.tween_property(head, "position:x", -6.0, 0.04)


func _add_line(text: String) -> void:
	AudioManager.play_sfx(&"keypress", -2.0, 0.6)
	var l := UITheme.label(text, &"SerifLabel", 30, Color(0.95, 0.88, 0.86))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.modulate.a = 0.0
	_lines_box.add_child(l)
	create_tween().tween_property(l, "modulate:a", 1.0, 0.25)


## Resolves the intervention (also used by tests).
func choose(choice: String) -> void:
	if is_closing():
		return
	_buttons.modulate.a = 0.4
	for b in _buttons.get_children():
		(b as Button).disabled = true
	var reply := Recruitment.resolve_intervention(choice)
	AudioManager.play_sfx(&"phone_hangup")
	_reply.text = "ADITYA: \"%s\"" % reply if not reply.is_empty() else ""
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_callback(func() -> void:
		chose.emit(choice)
		close())
