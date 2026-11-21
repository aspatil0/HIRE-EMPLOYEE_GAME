extends ModalPanel
## Desk phone interface. With an incoming call it offers Answer / Decline;
## otherwise it is a working dialler with a directory. Outgoing calls ring
## out and resolve to short in-world outcomes (it is past 9 PM: nobody picks up).
## Expects context["phone_line"]: PhoneLine.

const LCD_BG := Color(0.33, 0.42, 0.31)
const LCD_INK := Color(0.06, 0.09, 0.05)

var _line: PhoneLine
var _display: Label
var _status: Label
var _number: String = ""
var _dialing: bool = false
var _dial_tween: Tween
var _directory: Array[Dictionary] = []


func _init() -> void:
	title = "DESK PHONE"
	subtitle = "Line 1 · Extension 1313"
	panel_size = Vector2(1200, 780)
	accent = Color(0.75, 0.55, 0.25)


func _build_content(body: VBoxContainer) -> void:
	_line = context.get("phone_line") as PhoneLine
	_build_directory()
	if _line and _line.is_ringing:
		_build_incoming(body)
		return
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override(&"separation", 40)
	body.add_child(row)
	row.add_child(_build_dialer())
	row.add_child(_build_directory_list())


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


func _build_dialer() -> Control:
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(420, 0)
	v.add_theme_constant_override(&"separation", 14)
	var lcd := PanelContainer.new()
	lcd.add_theme_stylebox_override(&"panel", UITheme.flat_box(LCD_BG, Color(0, 0, 0, 0.6), 2, 16))
	var lcd_box := VBoxContainer.new()
	lcd.add_child(lcd_box)
	_status = UITheme.label("LINE 1  ·  READY", &"MonoLabel", 15, LCD_INK)
	lcd_box.add_child(_status)
	_display = UITheme.label("", &"MonoLabel", 38, LCD_INK)
	_display.custom_minimum_size = Vector2(0, 52)
	lcd_box.add_child(_display)
	v.add_child(lcd)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override(&"h_separation", 10)
	grid.add_theme_constant_override(&"v_separation", 10)
	for k in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "*", "0", "#"]:
		var b := UITheme.button(k)
		b.custom_minimum_size = Vector2(130, 62)
		b.add_theme_font_size_override(&"font_size", 26)
		b.pressed.connect(_press_key.bind(k))
		grid.add_child(b)
	v.add_child(grid)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override(&"separation", 10)
	var clear := UITheme.button("CLEAR")
	clear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clear.custom_minimum_size = Vector2(0, 58)
	clear.pressed.connect(_clear_number)
	actions.add_child(clear)
	var call_btn := UITheme.button("CALL")
	call_btn.name = "CallButton"
	call_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	call_btn.custom_minimum_size = Vector2(0, 58)
	call_btn.add_theme_color_override(&"font_color", Color(0.6, 0.95, 0.65))
	call_btn.pressed.connect(_call_number)
	actions.add_child(call_btn)
	v.add_child(actions)
	return v


func _build_directory_list() -> Control:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override(&"separation", 4)
	v.add_child(ModalPanel.section_label("Directory"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override(&"separation", 2)
	scroll.add_child(list)
	for entry in _directory:
		var b := UITheme.button("", &"FlatButton")
		b.custom_minimum_size = Vector2(0, 58)
		var h := HBoxContainer.new()
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.set_anchors_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 18
		h.offset_right = -18
		var n := UITheme.label(str(entry["name"]), &"SerifLabel", 21)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(n)
		h.add_child(UITheme.label(str(entry["number"]), &"MonoLabel", 17, UITheme.DIM))
		b.add_child(h)
		var number := str(entry["number"])
		b.pressed.connect(func() -> void:
			_number = number
			_refresh_display()
			_call_number())
		list.add_child(b)
	return v


func _build_directory() -> void:
	_directory = [
		{"name": "Aditya · Office of the CEO", "number": "100", "outcome": "\"This is Aditya. Leave a message.\"  The line clicks dead."},
		{"name": "Reception · Lobby", "number": "0", "outcome": "Rings out. The lobby closed at 20:00."},
		{"name": "IT Security", "number": "404", "outcome": "\"Security desk. Terminal 13-A is logged. Have a good night.\""},
	]
	for c in DataLoader.candidates(GameState.day):
		_directory.append({
			"name": "%s · Applicant" % c.get("name", ""),
			"number": str(c.get("phone", "")).replace(" ", ""),
			"outcome": "No answer. It is past 21:00. Candidate interviews begin tomorrow.",
		})


# --- Actions ------------------------------------------------------------------

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


func _press_key(k: String) -> void:
	if _dialing:
		return
	AudioManager.play_sfx(&"keypress", -2.0, 0.9 + randf() * 0.2)
	if _number.length() < 14:
		_number += k
	_refresh_display()


func _clear_number() -> void:
	AudioManager.play_sfx(&"keypress", -4.0)
	_hang_up()
	_number = ""
	_refresh_display()
	_status.text = "LINE 1  ·  READY"


func _refresh_display() -> void:
	_display.text = _number


func _call_number() -> void:
	if _dialing or _number.is_empty():
		return
	_dialing = true
	_status.text = "DIALLING  %s" % _number
	AudioManager.play_loop(&"ringback", AudioManager.BUS_SFX, -6.0, 0.05)
	var outcome := "Number not recognised."
	var known := false
	for entry in _directory:
		if str(entry["number"]) == _number or str(entry["number"]).ends_with(_number) and _number.length() >= 10:
			outcome = str(entry["outcome"])
			known = true
	_dial_tween = create_tween()
	_dial_tween.tween_interval(3.2 if known else 1.2)
	_dial_tween.tween_callback(_finish_call.bind(outcome))


func _finish_call(outcome: String) -> void:
	_hang_up()
	_status.text = outcome
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	GameState.set_flag(&"used_phone")


func _hang_up() -> void:
	if _dial_tween and _dial_tween.is_valid():
		_dial_tween.kill()
	if _dialing:
		AudioManager.stop_loop(&"ringback", 0.05)
		AudioManager.play_sfx(&"phone_hangup", -6.0)
	_dialing = false


func _on_closing() -> void:
	_hang_up()
