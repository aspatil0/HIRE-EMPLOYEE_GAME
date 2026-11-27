extends ModalPanel
## Desk phone. Incoming calls (Answer / Decline), a working keypad, an office
## directory and the Phase 2 reference directory. Reference calls are limited
## (data/dialogue/phase_2_references.json: max_calls, max_questions), so Alice
## must choose which questions to ask; answers are logged as evidence.
## Expects context["phone_line"]: PhoneLine (optional outside the office).

const LCD_BG := Color(0.33, 0.42, 0.31)
const LCD_INK := Color(0.06, 0.09, 0.05)
const OFFICE_LINES := [
	{"name": "Aditya · Office of the CEO", "number": "100", "outcome": "\"This is Aditya. Leave a message.\"  The line clicks dead."},
	{"name": "Reception · Lobby", "number": "0", "outcome": "Rings out. The lobby closed at 20:00."},
	{"name": "IT Security", "number": "404", "outcome": "\"Security desk. Terminal 13-A is logged. Have a good night.\""},
]

var _line: PhoneLine
var _display: Label
var _status: Label
var _right: VBoxContainer
var _number: String = ""
var _dialing: bool = false
var _dial_tween: Tween
# Active reference call view.
var _transcript: VBoxContainer
var _transcript_scroll: ScrollContainer
var _questions: VBoxContainer
var _call_header: Label
var _call_contact: String = ""


func _init() -> void:
	title = "DESK PHONE"
	subtitle = "Line 1 · Extension 1313 · Reference calls are limited — choose your questions"
	panel_size = Vector2(1560, 900)
	accent = Color(0.75, 0.55, 0.25)


func _build_content(body: VBoxContainer) -> void:
	_line = context.get("phone_line") as PhoneLine
	if _line and _line.is_ringing:
		_build_incoming(body)
		return
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override(&"separation", 40)
	body.add_child(row)
	row.add_child(_build_dialer())
	_right = VBoxContainer.new()
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right.add_theme_constant_override(&"separation", 6)
	row.add_child(_right)
	_show_directory()


# --- Incoming -----------------------------------------------------------------

func _build_incoming(body: VBoxContainer) -> void:
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 18)
	center.add_child(v)
	var label := UITheme.label("INCOMING CALL", &"DimLabel", 18, UITheme.WARM)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(label)
	var who := UITheme.label(_line.caller_name, &"TitleLabel", 72)
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(who)
	var where := UITheme.label("CEO OFFICE  ·  FLOOR 31  ·  EXT. 100", &"DimLabel", 16)
	where.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(where)
	var pulse := create_tween().set_loops()
	pulse.tween_property(who, "modulate:a", 0.55, 0.5)
	pulse.tween_property(who, "modulate:a", 1.0, 0.5)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 30)
	v.add_child(gap)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override(&"separation", 24)
	v.add_child(buttons)
	var decline := UITheme.button("DECLINE")
	decline.custom_minimum_size = Vector2(220, 64)
	decline.pressed.connect(_decline)
	buttons.add_child(decline)
	var answer := UITheme.button("ANSWER")
	answer.name = "AnswerButton"
	answer.custom_minimum_size = Vector2(220, 64)
	var sb := UITheme.flat_box(Color(0.16, 0.32, 0.18), Color(0.4, 0.75, 0.45), 1, 10)
	answer.add_theme_stylebox_override(&"normal", sb)
	var sbh := sb.duplicate() as StyleBoxFlat
	sbh.bg_color = Color(0.2, 0.42, 0.22)
	answer.add_theme_stylebox_override(&"hover", sbh)
	answer.pressed.connect(_answer)
	buttons.add_child(answer)


func _answer() -> void:
	AudioManager.play_sfx(&"ui_click")
	var line := _line
	await close()
	if line:
		line.answer()


func _decline() -> void:
	AudioManager.play_sfx(&"ui_click")
	var line := _line
	await close()
	if line:
		line.decline()


# --- Dialer (left) ------------------------------------------------------------

func _build_dialer() -> Control:
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(420, 0)
	v.add_theme_constant_override(&"separation", 14)
	var lcd := PanelContainer.new()
	lcd.add_theme_stylebox_override(&"panel", UITheme.flat_box(LCD_BG, Color(0, 0, 0, 0.6), 2, 16))
	var lcd_box := VBoxContainer.new()
	lcd.add_child(lcd_box)
	_status = UITheme.label("LINE 1  ·  READY", &"MonoLabel", 15, LCD_INK)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lcd_box.add_child(_status)
	_display = UITheme.label("", &"MonoLabel", 34, LCD_INK)
	_display.custom_minimum_size = Vector2(0, 48)
	lcd_box.add_child(_display)
	v.add_child(lcd)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override(&"h_separation", 10)
	grid.add_theme_constant_override(&"v_separation", 10)
	for k in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "*", "0", "#"]:
		var b := UITheme.button(k)
		b.custom_minimum_size = Vector2(130, 58)
		b.add_theme_font_size_override(&"font_size", 26)
		b.pressed.connect(_press_key.bind(k))
		grid.add_child(b)
	v.add_child(grid)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override(&"separation", 10)
	var clear := UITheme.button("CLEAR")
	clear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clear.custom_minimum_size = Vector2(0, 56)
	clear.pressed.connect(_clear_number)
	actions.add_child(clear)
	var call_btn := UITheme.button("CALL")
	call_btn.name = "CallButton"
	call_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	call_btn.custom_minimum_size = Vector2(0, 56)
	call_btn.add_theme_color_override(&"font_color", Color(0.6, 0.95, 0.65))
	call_btn.pressed.connect(_call_number)
	actions.add_child(call_btn)
	v.add_child(actions)
	return v


func _press_key(k: String) -> void:
	if _dialing:
		return
	AudioManager.play_sfx(&"keypress", -2.0, 0.9 + randf() * 0.2)
	if _number.length() < 16:
		_number += k
	_display.text = _number


func _clear_number() -> void:
	AudioManager.play_sfx(&"keypress", -4.0)
	_hang_up()
	_number = ""
	_display.text = ""
	_status.text = "LINE 1  ·  READY"
	_show_directory()


func _call_number() -> void:
	if _dialing or _number.is_empty():
		return
	var contact_id := Recruitment.find_contact_by_number(_number)
	if not contact_id.is_empty():
		call_contact(contact_id)
		return
	var outcome := "Number not recognised."
	var known := false
	for entry: Dictionary in OFFICE_LINES:
		if str(entry["number"]) == _number:
			outcome = str(entry["outcome"])
			known = true
	_ring_then(3.0 if known else 1.2, func() -> void:
		_status.text = outcome
		GameState.set_flag(&"used_phone"))


func _ring_then(seconds: float, then: Callable) -> void:
	_dialing = true
	_status.text = "DIALLING  %s" % _number
	AudioManager.play_loop(&"ringback", AudioManager.BUS_SFX, -6.0, 0.05)
	_dial_tween = create_tween()
	_dial_tween.tween_interval(seconds)
	_dial_tween.tween_callback(func() -> void:
		_hang_up(false)
		then.call())


func _hang_up(play_click: bool = true) -> void:
	if _dial_tween and _dial_tween.is_valid():
		_dial_tween.kill()
	if _dialing:
		AudioManager.stop_loop(&"ringback", 0.05)
		if play_click:
			AudioManager.play_sfx(&"phone_hangup", -6.0)
	_dialing = false


# --- Directory (right) --------------------------------------------------------

func _show_directory() -> void:
	Recruitment.end_call()
	_call_contact = ""
	for c in _right.get_children():
		_right.remove_child(c)
		c.queue_free()
	_right.add_child(ModalPanel.section_label("Directory"))
	var list := VBoxContainer.new()
	list.add_theme_constant_override(&"separation", 2)
	_right.add_child(RecruitUI.scroll(list))
	list.add_child(_group_label("OFFICE"))
	for entry: Dictionary in OFFICE_LINES:
		list.add_child(_dir_button(str(entry["name"]), str(entry["number"]), "", func() -> void:
			_number = str(entry["number"])
			_display.text = _number
			_call_number()))
	for c in Recruitment.candidates:
		var ids: Array[String] = []
		for cid: String in Recruitment.contacts:
			if str(Recruitment.contacts[cid].get("candidate", "")) == c.id:
				ids.append(cid)
		if ids.is_empty():
			continue
		list.add_child(_group_label("%02d · %s" % [c.index, c.display_name().to_upper()]))
		for cid in ids:
			var info := Recruitment.contact(cid)
			var left := Recruitment.calls_left(cid)
			var contact_id := cid
			var b := _dir_button(str(info.get("name", "")), str(info.get("number", "")), "%d CALL%s LEFT" % [left, "" if left == 1 else "S"], func() -> void: call_contact(contact_id))
			b.name = "Contact_%s" % cid
			if left <= 0:
				b.modulate.a = 0.45
			list.add_child(b)


func _group_label(text: String) -> Control:
	var l := UITheme.label(text, &"DimLabel", 13, UITheme.WARM)
	l.custom_minimum_size = Vector2(0, 30)
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return l


func _dir_button(label_text: String, number: String, extra: String, on_press: Callable) -> Button:
	var b := UITheme.button("", &"FlatButton")
	b.custom_minimum_size = Vector2(0, 46)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 18
	h.offset_right = -18
	h.add_theme_constant_override(&"separation", 16)
	var n := UITheme.label(label_text, &"SerifLabel", 19)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	n.size_flags_vertical = Control.SIZE_FILL
	h.add_child(n)
	if not extra.is_empty():
		var e := UITheme.label(extra, &"DimLabel", 11)
		e.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(e)
	var num := UITheme.label(number, &"MonoLabel", 16, UITheme.DIM)
	num.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(num)
	b.add_child(h)
	b.pressed.connect(on_press)
	return b


# --- Reference call -----------------------------------------------------------

## Places a call to a reference contact (also used by tests).
func call_contact(contact_id: String) -> void:
	if _dialing:
		return
	var info := Recruitment.contact(contact_id)
	_number = str(info.get("number", ""))
	_display.text = _number
	if Recruitment.calls_left(contact_id) <= 0:
		_status.text = "You have already called %s tonight. They will not pick up again." % info.get("name", "")
		AudioManager.play_sfx(&"phone_hangup", -8.0)
		return
	_ring_then(2.4, func() -> void: _connect(contact_id))


func _connect(contact_id: String) -> void:
	var result := Recruitment.start_call(contact_id)
	if not result.get("ok", false):
		_status.text = "The call did not go through."
		return
	var info: Dictionary = result["contact"]
	_call_contact = contact_id
	for c in _right.get_children():
		_right.remove_child(c)
		c.queue_free()
	_call_header = UITheme.label(str(info.get("name", "")).to_upper(), &"HeaderLabel", 26)
	_right.add_child(_call_header)
	_transcript = VBoxContainer.new()
	_transcript.add_theme_constant_override(&"separation", 10)
	_transcript_scroll = RecruitUI.scroll(_transcript)
	_right.add_child(_transcript_scroll)
	_questions = VBoxContainer.new()
	_questions.add_theme_constant_override(&"separation", 6)
	_right.add_child(_questions)
	match str(result["reason"]):
		"answers":
			AudioManager.play_sfx(&"phone_pickup", -4.0)
			_status.text = "CONNECTED  ·  %s" % info.get("number", "")
			_say(str(info.get("name", "")), str(info.get("greeting", "")))
			_refresh_questions()
		"automated":
			AudioManager.play_sfx(&"phone_pickup", -4.0)
			AudioManager.play_sfx(&"stinger", -10.0, 0.8)
			_status.text = "LINE 1  ·  1313"
			_say("", str(info.get("greeting", "")))
			_say("", str(info.get("goodbye", "")))
			_end_buttons()
		_:
			_status.text = "NO ANSWER"
			_say("", str(info.get("greeting", "No answer.")))
			_end_buttons()


func _say(speaker: String, text: String) -> void:
	if text.is_empty():
		return
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 0)
	if not speaker.is_empty():
		v.add_child(UITheme.label(speaker.to_upper(), &"DimLabel", 12, Color(0.58, 0.71, 0.84) if speaker == "ALICE" else UITheme.WARM))
	var l := UITheme.label(text, &"SerifLabel", 21, UITheme.INK if not speaker.is_empty() else UITheme.DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	_transcript.add_child(v)
	_scroll_to_end.call_deferred()


func _scroll_to_end() -> void:
	if is_instance_valid(_transcript_scroll):
		_transcript_scroll.scroll_vertical = int(_transcript_scroll.get_v_scroll_bar().max_value)


func _refresh_questions() -> void:
	for c in _questions.get_children():
		_questions.remove_child(c)
		c.queue_free()
	var info := Recruitment.contact(_call_contact)
	var left := Recruitment.questions_left()
	if left <= 0:
		_say(str(info.get("name", "")), "I have to go." + (" " + str(info.get("goodbye", "")) if not str(info.get("goodbye", "")).is_empty() else ""))
		_end_buttons()
		return
	_questions.add_child(UITheme.label("ASK (%d QUESTION%s LEFT ON THIS CALL)" % [left, "" if left == 1 else "S"], &"DimLabel", 12, UITheme.WARM))
	for q: Dictionary in info.get("questions", []):
		var qid := str(q.get("id", ""))
		var b := UITheme.button("“%s”" % q.get("text", ""), &"FlatButton")
		b.name = "Ask_%s" % qid
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override(&"font_size", 17)
		b.pressed.connect(_ask.bind(qid, str(q.get("text", ""))))
		_questions.add_child(b)
	var hang := UITheme.button("HANG UP")
	hang.name = "HangUp"
	hang.pressed.connect(func() -> void:
		AudioManager.play_sfx(&"phone_hangup", -4.0)
		_show_directory())
	_questions.add_child(hang)


func _ask(question_id: String, question_text: String) -> void:
	AudioManager.play_sfx(&"keypress", -6.0)
	var response := Recruitment.ask(question_id)
	if response.is_empty():
		return
	_say("ALICE", question_text)
	_say(str(Recruitment.contact(_call_contact).get("name", "")), response)
	_refresh_questions()


func _end_buttons() -> void:
	Recruitment.end_call()
	for c in _questions.get_children():
		_questions.remove_child(c)
		c.queue_free()
	var back := UITheme.button("HANG UP  ·  BACK TO DIRECTORY")
	back.name = "BackToDirectory"
	back.pressed.connect(func() -> void:
		AudioManager.play_sfx(&"phone_hangup", -4.0)
		_show_directory())
	_questions.add_child(back)


func _on_closing() -> void:
	_hang_up()
	Recruitment.end_call()
