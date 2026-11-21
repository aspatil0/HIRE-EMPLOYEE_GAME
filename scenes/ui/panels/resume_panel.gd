extends ModalPanel
## Physical resume viewer: applicant list on the left, the printed resume
## on the right. Flagging a candidate stores a GameState flag
## ("flagged_<id>") for the verification phase to build on.

var _candidates: Array[Dictionary] = []
var _index: int = 0
var _list_buttons: Array[Button] = []
var _group := ButtonGroup.new()

var _name: Label
var _position: Label
var _fields: GridContainer
var _summary: Label
var _skills: Label
var _counter: Label
var _flag_btn: Button
var _stamp: Label
var _paper: PanelContainer


func _init() -> void:
	title = "CANDIDATE RESUMES"
	subtitle = "Printed applications · Day 1"
	panel_size = Vector2(1500, 900)


func _build_content(body: VBoxContainer) -> void:
	_candidates = DataLoader.candidates(GameState.day)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override(&"separation", 28)
	body.add_child(row)

	# Applicant list.
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(360, 0)
	left.add_theme_constant_override(&"separation", 4)
	row.add_child(left)
	left.add_child(ModalPanel.section_label("Applicants  ·  %d" % _candidates.size()))
	for i in _candidates.size():
		var c := _candidates[i]
		var b := UITheme.button("", &"FlatButton")
		b.toggle_mode = true
		b.button_group = _group
		b.custom_minimum_size = Vector2(0, 66)
		var box := VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.set_anchors_preset(Control.PRESET_FULL_RECT)
		box.offset_left = 18
		box.offset_top = 10
		box.add_theme_constant_override(&"separation", 0)
		box.add_child(UITheme.label(str(c.get("name", "Unknown")), &"SerifLabel", 22))
		box.add_child(UITheme.label(str(c.get("position", "")).to_upper(), &"DimLabel", 13))
		b.add_child(box)
		b.pressed.connect(_show.bind(i))
		left.add_child(b)
		_list_buttons.append(b)

	# Paper.
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override(&"separation", 14)
	row.add_child(right)
	_paper = PanelContainer.new()
	_paper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var paper_sb := UITheme.flat_box(UITheme.PAPER, Color(0, 0, 0, 0.3), 1, 0)
	paper_sb.content_margin_left = 48
	paper_sb.content_margin_right = 48
	paper_sb.content_margin_top = 34
	paper_sb.content_margin_bottom = 30
	paper_sb.shadow_color = Color(0, 0, 0, 0.5)
	paper_sb.shadow_size = 14
	paper_sb.shadow_offset = Vector2(4, 6)
	_paper.add_theme_stylebox_override(&"panel", paper_sb)
	right.add_child(_paper)
	_paper.add_child(_build_paper())

	# Footer controls.
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override(&"separation", 14)
	right.add_child(foot)
	var prev := UITheme.button("◀  PREVIOUS")
	prev.pressed.connect(func() -> void: _show(wrapi(_index - 1, 0, maxi(_candidates.size(), 1))))
	foot.add_child(prev)
	_counter = UITheme.label("", &"MonoLabel", 18, UITheme.DIM)
	_counter.custom_minimum_size = Vector2(90, 0)
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_counter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(_counter)
	var next := UITheme.button("NEXT  ▶")
	next.pressed.connect(func() -> void: _show(wrapi(_index + 1, 0, maxi(_candidates.size(), 1))))
	foot.add_child(next)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(spacer)
	_flag_btn = UITheme.button("")
	_flag_btn.pressed.connect(_toggle_flag)
	foot.add_child(_flag_btn)

	if _candidates.is_empty():
		_name.text = "No applications received."
		prev.disabled = true
		next.disabled = true
		_flag_btn.disabled = true
		return
	_show(0, false)


func _build_paper() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 14)
	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 24)
	v.add_child(head)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(names)
	names.add_child(UITheme.label("CURRICULUM VITAE", &"DimLabel", 14, Color(0.35, 0.32, 0.28)))
	_name = UITheme.label("", &"PaperLabel", 44)
	names.add_child(_name)
	_position = UITheme.label("", &"PaperLabel", 22, Color(0.45, 0.16, 0.12))
	names.add_child(_position)
	# Photo placeholder.
	var photo := PanelContainer.new()
	photo.custom_minimum_size = Vector2(120, 146)
	photo.add_theme_stylebox_override(&"panel", UITheme.flat_box(Color(0.55, 0.55, 0.56), Color(0.25, 0.25, 0.25), 1, 0))
	var silhouette := UITheme.label("PHOTO\nATTACHED", &"DimLabel", 12, Color(0.3, 0.3, 0.32))
	silhouette.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	silhouette.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	photo.add_child(silhouette)
	head.add_child(photo)

	var rule := ColorRect.new()
	rule.color = Color(0.2, 0.18, 0.16, 0.5)
	rule.custom_minimum_size = Vector2(0, 2)
	v.add_child(rule)

	_fields = GridContainer.new()
	_fields.columns = 4
	_fields.add_theme_constant_override(&"h_separation", 26)
	_fields.add_theme_constant_override(&"v_separation", 8)
	v.add_child(_fields)

	v.add_child(UITheme.label("PROFILE", &"DimLabel", 14, Color(0.35, 0.32, 0.28)))
	_summary = UITheme.label("", &"PaperLabel", 21)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_summary)
	v.add_child(UITheme.label("SKILLS", &"DimLabel", 14, Color(0.35, 0.32, 0.28)))
	_skills = UITheme.label("", &"PaperLabel", 20)
	_skills.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_skills)

	var stamp_row := HBoxContainer.new()
	stamp_row.alignment = BoxContainer.ALIGNMENT_END
	stamp_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(stamp_row)
	_stamp = UITheme.label("VERIFICATION PENDING", &"HeaderLabel", 24, Color(0.68, 0.12, 0.1, 0.8))
	var stamp_box := PanelContainer.new()
	var sb := UITheme.flat_box(Color(0, 0, 0, 0), Color(0.68, 0.12, 0.1, 0.75), 3, 10)
	stamp_box.add_theme_stylebox_override(&"panel", sb)
	stamp_box.size_flags_vertical = Control.SIZE_SHRINK_END
	stamp_box.rotation = -0.08
	stamp_box.add_child(_stamp)
	stamp_row.add_child(stamp_box)
	return v


func _show(i: int, with_sound: bool = true) -> void:
	if _candidates.is_empty():
		return
	_index = i
	var c := _candidates[i]
	if with_sound:
		AudioManager.play_sfx(&"paper", -2.0, randf_range(0.9, 1.1))
	_list_buttons[i].set_pressed_no_signal(true)
	_name.text = str(c.get("name", ""))
	_position.text = "Applying for: %s" % c.get("position", "")
	for child in _fields.get_children():
		child.queue_free()
	var pairs := [
		["AGE", str(int(c.get("age", 0)))], ["DATE OF BIRTH", str(c.get("dob", "—"))],
		["LOCATION", str(c.get("city", ""))], ["PHONE", str(c.get("phone", ""))],
		["EMAIL", str(c.get("email", ""))], ["EXPERIENCE", "%d years" % int(c.get("experience_years", 0))],
		["EDUCATION", str(c.get("education", ""))], ["LAST EMPLOYER", str(c.get("previous_employer", ""))],
	]
	for p: Array in pairs:
		_fields.add_child(UITheme.label(p[0], &"DimLabel", 13, Color(0.38, 0.35, 0.31)))
		var val := UITheme.label(p[1], &"PaperLabel", 19)
		val.custom_minimum_size = Vector2(300, 0)
		_fields.add_child(val)
	_summary.text = str(c.get("summary", ""))
	var skills: Array = c.get("skills", [])
	_skills.text = "  ·  ".join(PackedStringArray(skills))
	_counter.text = "%d / %d" % [i + 1, _candidates.size()]
	GameState.set_flag(StringName("resume_read_%s" % c.get("id", i)))
	_update_flag()
	# Small "page turn" settle.
	_paper.modulate.a = 0.6
	create_tween().tween_property(_paper, "modulate:a", 1.0, 0.18)


func _flag_key() -> StringName:
	return StringName("flagged_%s" % _candidates[_index].get("id", _index))


func _toggle_flag() -> void:
	if _candidates.is_empty():
		return
	AudioManager.play_sfx(&"ui_click")
	GameState.set_flag(_flag_key(), not GameState.is_flag_set(_flag_key()))
	_update_flag()


func _update_flag() -> void:
	var flagged := GameState.is_flag_set(_flag_key())
	_flag_btn.text = "⚑  FLAGGED FOR FOLLOW-UP" if flagged else "⚐  FLAG FOR FOLLOW-UP"
	_flag_btn.add_theme_color_override(&"font_color", UITheme.ACCENT_SOFT if flagged else UITheme.INK)
	_stamp.text = "FLAGGED · FOLLOW UP" if flagged else "VERIFICATION PENDING"
