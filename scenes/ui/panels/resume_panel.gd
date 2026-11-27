extends ModalPanel
## Candidate file viewer (resume stack). Only applications still awaiting a
## decision are in the stack (decided files live in the journal/dashboard).
## One printed CV at a time, with
## the investigation sidebar: flag, follow-up, notes, evidence progress and
## the way into the decision screen. Never reveals whether a candidate is good.
## Context: "candidate_id" (optional) opens that file first.

const PAPER_DIM := Color(0.38, 0.35, 0.31)

var _cid: String = ""
var _counter: Label
var _status_holder: HBoxContainer
var _paper_scroll: ScrollContainer
var _paper_body: VBoxContainer
var _flag: CheckButton
var _follow: CheckButton
var _notes: TextEdit
var _progress: Label
var _decide_btn: Button


func _init() -> void:
	title = "CANDIDATE FILES"
	subtitle = "Printed applications · Day 1 · Recruitment review"
	panel_size = Vector2(1680, 960)


func _build_content(body: VBoxContainer) -> void:
	var stack := Recruitment.remaining()
	if stack.is_empty():
		_build_empty(body)
		return
	_cid = str(context.get("candidate_id", Recruitment.current_id()))
	if Recruitment.get_candidate(_cid) == null or Recruitment.is_decided(_cid):
		_cid = stack[0].id

	var top := HBoxContainer.new()
	top.add_theme_constant_override(&"separation", 18)
	body.add_child(top)
	_counter = UITheme.label("", &"MonoLabel", 26, UITheme.WARM)
	top.add_child(_counter)
	_status_holder = HBoxContainer.new()
	top.add_child(_status_holder)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var prev := UITheme.button("◀  PREVIOUS")
	prev.name = "PrevButton"
	prev.pressed.connect(func() -> void: _step(-1))
	top.add_child(prev)
	var next := UITheme.button("NEXT  ▶")
	next.name = "NextButton"
	next.pressed.connect(func() -> void: _step(1))
	top.add_child(next)

	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override(&"separation", 26)
	body.add_child(row)

	# The printed resume.
	var paper := PanelContainer.new()
	paper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := UITheme.flat_box(UITheme.PAPER, Color(0, 0, 0, 0.3), 1, 0)
	sb.content_margin_left = 54
	sb.content_margin_right = 40
	sb.content_margin_top = 30
	sb.content_margin_bottom = 30
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(4, 6)
	paper.add_theme_stylebox_override(&"panel", sb)
	row.add_child(paper)
	_paper_body = VBoxContainer.new()
	_paper_body.add_theme_constant_override(&"separation", 10)
	_paper_scroll = RecruitUI.scroll(_paper_body)
	paper.add_child(_paper_scroll)

	row.add_child(_build_sidebar())
	_show(_cid)


func _build_sidebar() -> Control:
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(430, 0)
	side.add_theme_constant_override(&"separation", 12)
	side.add_child(ModalPanel.section_label("Investigation"))
	_progress = UITheme.label("", &"", 17, UITheme.DIM)
	_progress.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(_progress)
	_flag = CheckButton.new()
	_flag.name = "FlagToggle"
	_flag.text = "FLAG CANDIDATE"
	_flag.focus_mode = Control.FOCUS_NONE
	_flag.toggled.connect(func(on: bool) -> void:
		AudioManager.play_sfx(&"ui_click")
		Recruitment.set_flagged(_cid, on)
		_refresh_meta())
	side.add_child(_flag)
	_follow = CheckButton.new()
	_follow.name = "FollowUpToggle"
	_follow.text = "MARK FOR FOLLOW-UP"
	_follow.focus_mode = Control.FOCUS_NONE
	_follow.toggled.connect(func(on: bool) -> void:
		AudioManager.play_sfx(&"ui_click")
		Recruitment.set_follow_up(_cid, on)
		_refresh_meta())
	side.add_child(_follow)
	side.add_child(ModalPanel.section_label("Investigation notes"))
	_notes = TextEdit.new()
	_notes.name = "Notes"
	_notes.placeholder_text = "Write what you suspect, what you've checked, who to call..."
	_notes.custom_minimum_size = Vector2(0, 230)
	_notes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_notes.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	var nsb := UITheme.flat_box(Color(0.82, 0.78, 0.55), Color(0, 0, 0, 0.4), 1, 14)
	_notes.add_theme_stylebox_override(&"normal", nsb)
	_notes.add_theme_stylebox_override(&"focus", nsb)
	_notes.add_theme_color_override(&"font_color", Color(0.15, 0.15, 0.3))
	_notes.add_theme_color_override(&"caret_color", Color(0.15, 0.15, 0.3))
	_notes.add_theme_color_override(&"font_placeholder_color", Color(0.4, 0.38, 0.3))
	_notes.add_theme_font_override(&"font", UITheme.serif())
	_notes.add_theme_font_size_override(&"font_size", 19)
	_notes.text_changed.connect(func() -> void: Recruitment.set_notes(_cid, _notes.text))
	side.add_child(_notes)
	var log_btn := UITheme.button("OPEN EVIDENCE LOG")
	log_btn.name = "LogButton"
	log_btn.pressed.connect(func() -> void: switch_panel(load(RecruitUI.JOURNAL_SCENE), {"candidate_id": _cid}))
	side.add_child(log_btn)
	_decide_btn = UITheme.button("DECISION  ▶")
	_decide_btn.name = "DecisionButton"
	_decide_btn.custom_minimum_size = Vector2(0, 56)
	_decide_btn.add_theme_color_override(&"font_color", UITheme.WARM)
	_decide_btn.pressed.connect(func() -> void: switch_panel(load(RecruitUI.DECISION_SCENE), {"candidate_id": _cid}))
	side.add_child(_decide_btn)
	var back := UITheme.button("RETURN TO OFFICE")
	back.name = "ReturnButton"
	back.pressed.connect(close)
	side.add_child(back)
	return side


func _build_empty(body: VBoxContainer) -> void:
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 18)
	center.add_child(v)
	var t := UITheme.label("THE STACK IS EMPTY", &"TitleLabel", 54)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s := UITheme.label("Every application has a decision. The records are in the evidence journal and on the main computer.", &"SerifLabel", 22, UITheme.DIM)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	var back := UITheme.button("RETURN TO OFFICE")
	back.name = "ReturnButton"
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(close)
	v.add_child(back)


func _step(dir: int) -> void:
	var stack := Recruitment.remaining()
	var n := stack.size()
	if n == 0:
		return
	var i := 0
	for k in n:
		if stack[k].id == _cid:
			i = k
	_show(stack[wrapi(i + dir, 0, n)].id)


func _show(cid: String, with_sound: bool = true) -> void:
	_cid = cid
	var c := Recruitment.get_candidate(cid)
	if c == null:
		return
	if with_sound:
		AudioManager.play_sfx(&"paper", -2.0, randf_range(0.9, 1.1))
	Recruitment.view_resume(cid)
	var stack := Recruitment.remaining()
	var pos := 1
	for k in stack.size():
		if stack[k].id == cid:
			pos = k + 1
	_counter.text = "CANDIDATE %02d  ·  %d OF %d REMAINING" % [c.index, pos, stack.size()]
	_notes.text = str(Recruitment.state(cid)["notes"])
	_flag.set_pressed_no_signal(Recruitment.state(cid)["flagged"])
	_follow.set_pressed_no_signal(Recruitment.state(cid)["follow_up"])
	for child in _paper_body.get_children():
		_paper_body.remove_child(child)
		child.queue_free()
	_build_resume(c)
	_paper_scroll.scroll_vertical = 0
	_refresh_meta()
	_paper_body.modulate.a = 0.5
	create_tween().tween_property(_paper_body, "modulate:a", 1.0, 0.18)


func _refresh_meta() -> void:
	for child in _status_holder.get_children():
		_status_holder.remove_child(child)
		child.queue_free()
	_status_holder.add_child(RecruitUI.status_chip(_cid))
	if Recruitment.state(_cid)["flagged"]:
		_status_holder.add_child(RecruitUI.chip("FLAGGED", UITheme.ACCENT_SOFT))
	if Recruitment.state(_cid)["follow_up"]:
		_status_holder.add_child(RecruitUI.chip("FOLLOW-UP", RecruitUI.YELLOW))
	var c := Recruitment.get_candidate(_cid)
	_progress.text = "Evidence logged: %d   ·   Open contradictions: %d   ·   Documents fully verified: %d / %d" % [
		Recruitment.discovered_clues(_cid).size(), Recruitment.open_contradictions(_cid).size(),
		Recruitment.verified_documents(_cid).size(), Recruitment.submitted_documents(_cid).size()]
	_decide_btn.text = "VIEW DECISION  ▶" if Recruitment.is_decided(_cid) else "DECISION  ▶"
	if c == null:
		return


# --- Printed resume -----------------------------------------------------------

func _build_resume(c: Candidate) -> void:
	var r := c.resume()
	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 24)
	_paper_body.add_child(head)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(names)
	names.add_child(UITheme.label("CURRICULUM VITAE  ·  APPLICATION %02d" % c.index, &"DimLabel", 13, PAPER_DIM))
	names.add_child(UITheme.label(c.display_name(), &"PaperLabel", 46))
	names.add_child(UITheme.label("Applying for: %s" % c.position(), &"PaperLabel", 22, Color(0.45, 0.16, 0.12)))
	var photo := PanelContainer.new()
	photo.custom_minimum_size = Vector2(118, 144)
	photo.add_theme_stylebox_override(&"panel", UITheme.flat_box(Color(0.56, 0.56, 0.57), Color(0.25, 0.25, 0.25), 1, 0))
	var ph := UITheme.label("PHOTO\nATTACHED", &"DimLabel", 11, Color(0.3, 0.3, 0.32))
	ph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	photo.add_child(ph)
	head.add_child(photo)

	_section("Personal details")
	_grid([
		["Full name", r.get("name", "")], ["Age", str(int(r.get("claimed_age", 0)))],
		["Date of birth", r.get("dob", "")], ["Gender", r.get("gender", "")],
		["Address", r.get("address", "")], ["City", r.get("city", "")],
		["Contact number", r.get("phone", "")], ["Email", r.get("email", "")],
		["Position applied for", r.get("position", "")], ["", ""],
	])

	var e := c.education()
	_section("Education")
	var certs: Array = e.get("certifications", [])
	_grid([
		["Highest qualification", e.get("qualification", "")], ["University / college", e.get("institution", "")],
		["Graduation year", e.get("year", "")], ["Percentage / CGPA", e.get("score", "")],
		["Certifications", ", ".join(PackedStringArray(certs)) if not certs.is_empty() else "None listed"], ["", ""],
	])

	_section("Professional experience  ·  total %s" % r.get("total_experience", "—"))
	for job: Dictionary in c.experience():
		var block := VBoxContainer.new()
		block.add_theme_constant_override(&"separation", 2)
		block.add_child(UITheme.label("%s — %s" % [job.get("company", ""), job.get("designation", "")], &"PaperLabel", 22))
		block.add_child(UITheme.label("%s  to  %s     ·     Last drawn salary: %s" % [DateUtil.format_my(str(job.get("joined", ""))), DateUtil.format_my(str(job.get("left", ""))), job.get("salary", "—")], &"PaperLabel", 18, PAPER_DIM))
		var why := UITheme.label("Reason for leaving: %s" % job.get("reason", "—"), &"PaperLabel", 18, PAPER_DIM)
		why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		block.add_child(why)
		_paper_body.add_child(block)

	_section("Skills")
	_para("  ·  ".join(PackedStringArray(r.get("skills", []))))
	_section("Professional achievements")
	for a: String in r.get("achievements", []):
		_para("•  " + a)
	_section("References")
	var refs: Array = r.get("references", [])
	if refs.is_empty():
		_para("None provided.")
	for ref: Dictionary in refs:
		var num := str(Recruitment.contact(str(ref.get("contact", ""))).get("number", ""))
		_para("•  %s — %s%s" % [ref.get("name", ""), ref.get("relation", ""), ("   (tel. %s)" % num) if not num.is_empty() else ""])
	_section("Terms")
	_grid([["Expected salary", r.get("expected_salary", "")], ["Notice period", r.get("notice_period", "")]])
	_section("Personal statement")
	var st := UITheme.label("“%s”" % r.get("statement", ""), &"PaperLabel", 21)
	st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_paper_body.add_child(st)
	var footer := str(r.get("footer", ""))
	if not footer.is_empty():
		var f := UITheme.label(footer, &"DimLabel", 13, PAPER_DIM)
		f.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_paper_body.add_child(f)


func _section(text: String) -> void:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	_paper_body.add_child(gap)
	_paper_body.add_child(UITheme.label(text.to_upper(), &"DimLabel", 13, PAPER_DIM))
	var rule := ColorRect.new()
	rule.color = Color(0.2, 0.18, 0.16, 0.35)
	rule.custom_minimum_size = Vector2(0, 1)
	_paper_body.add_child(rule)


func _grid(pairs: Array) -> void:
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override(&"h_separation", 22)
	g.add_theme_constant_override(&"v_separation", 6)
	for p: Array in pairs:
		g.add_child(UITheme.label(str(p[0]).to_upper(), &"DimLabel", 12, PAPER_DIM))
		var v := UITheme.label(str(p[1]), &"PaperLabel", 19)
		v.custom_minimum_size = Vector2(300, 0)
		v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		g.add_child(v)
	_paper_body.add_child(g)


func _para(text: String) -> void:
	var l := UITheme.label(text, &"PaperLabel", 19)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_paper_body.add_child(l)


func get_candidate_id() -> String:
	return _cid
