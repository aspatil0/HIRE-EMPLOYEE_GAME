extends ModalPanel
## Hiring decision screen for one candidate (context["candidate_id"]).
## Shows the case so far — progress, verified documents, unresolved
## contradictions, evidence, notes — then ACCEPT / REJECT (with confirmation)
## or INVESTIGATE FURTHER. A final decision can only be reopened by the CEO.

var _cid: String
var _reason: LineEdit


func _init() -> void:
	title = "HIRING DECISION"
	subtitle = "Every decision is recorded"
	panel_size = Vector2(1600, 940)
	accent = UITheme.ACCENT


func _build_content(body: VBoxContainer) -> void:
	_cid = str(context.get("candidate_id", Recruitment.current_id()))
	_build_summary(body)


func _build_summary(body: VBoxContainer) -> void:
	var c := Recruitment.get_candidate(_cid)
	var st := Recruitment.state(_cid)
	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 18)
	body.add_child(head)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_child(UITheme.label("CANDIDATE %02d / %02d" % [c.index, Recruitment.candidates.size()], &"MonoLabel", 18, UITheme.WARM))
	names.add_child(UITheme.label(c.display_name(), &"TitleLabel", 54))
	names.add_child(UITheme.label("Applied for: %s" % c.position(), &"SerifLabel", 22, UITheme.DIM))
	head.add_child(names)
	head.add_child(RecruitUI.status_chip(_cid))

	var stats := HBoxContainer.new()
	stats.add_theme_constant_override(&"separation", 10)
	body.add_child(stats)
	var oc := Recruitment.open_contradictions(_cid)
	stats.add_child(RecruitUI.stat_box("Investigation progress", "%d%%" % roundi(Recruitment.progress(_cid) * 100.0)))
	stats.add_child(RecruitUI.stat_box("Verified documents", "%d / %d" % [Recruitment.verified_documents(_cid).size(), Recruitment.submitted_documents(_cid).size()]))
	stats.add_child(RecruitUI.stat_box("Unresolved contradictions", str(oc.size()), RecruitUI.RED if not oc.is_empty() else UITheme.INK))
	stats.add_child(RecruitUI.stat_box("Evidence discovered", str(Recruitment.discovered_clues(_cid).size())))

	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override(&"separation", 28)
	body.add_child(cols)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override(&"separation", 8)
	cols.add_child(left)
	left.add_child(ModalPanel.section_label("Unresolved contradictions"))
	if oc.is_empty():
		left.add_child(UITheme.label("None outstanding — or none found yet.", &"", 17, UITheme.DIM))
	for cl in oc:
		var l := UITheme.label("■  " + str(c.clue(cl).get("text", "")), &"", 17, RecruitUI.RED.lightened(0.2))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		left.add_child(l)
	left.add_child(ModalPanel.section_label("Evidence log"))
	left.add_child(RecruitUI.scroll(RecruitUI.evidence_log(_cid, 16, true)))

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(520, 0)
	right.add_theme_constant_override(&"separation", 10)
	cols.add_child(right)
	right.add_child(ModalPanel.section_label("Your notes"))
	var notes_text := str(st["notes"])
	var notes := UITheme.label(notes_text if not notes_text.is_empty() else "(no notes written)", &"SerifLabel", 18, UITheme.INK if not notes_text.is_empty() else UITheme.FAINT)
	notes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(notes)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(spacer)

	if Recruitment.is_decided(_cid):
		var d: Dictionary = st["decision"]
		right.add_child(UITheme.label("DECISION RECORDED: %s at %s" % [Recruitment.status(_cid).to_upper(), d.get("time", "")], &"HeaderLabel", 22, RecruitUI.status_color(Recruitment.status(_cid))))
		if not str(d.get("reason", "")).is_empty():
			right.add_child(UITheme.label("Reason: %s" % d["reason"], &"", 17, UITheme.DIM))
		right.add_child(UITheme.label("Final decisions cannot be changed from this terminal.", &"DimLabel", 13))
	else:
		right.add_child(ModalPanel.section_label("Reason (recorded with the decision)"))
		_reason = LineEdit.new()
		_reason.name = "Reason"
		_reason.placeholder_text = "e.g. Employment dates contradicted by the bureau report"
		right.add_child(_reason)
		var accept := _decision_button("ACCEPT", RecruitUI.GREEN, "AcceptButton")
		accept.pressed.connect(_confirm.bind("accept"))
		right.add_child(accept)
		var reject := _decision_button("REJECT", RecruitUI.RED, "RejectButton")
		reject.pressed.connect(_confirm.bind("reject"))
		right.add_child(reject)
		var more := _decision_button("INVESTIGATE FURTHER", RecruitUI.YELLOW, "InvestigateButton")
		more.pressed.connect(func() -> void: _commit("investigate"))
		right.add_child(more)
	var back := UITheme.button("◀  BACK TO CANDIDATE FILE")
	back.name = "BackButton"
	back.pressed.connect(func() -> void: switch_panel(load(RecruitUI.RESUME_SCENE), {"candidate_id": _cid}))
	right.add_child(back)


func _decision_button(text: String, col: Color, node_name: String) -> Button:
	var b := UITheme.button(text)
	b.name = node_name
	b.custom_minimum_size = Vector2(0, 58)
	var sb := UITheme.flat_box(Color(col, 0.12), Color(col, 0.7), 1, 10)
	var sbh := UITheme.flat_box(Color(col, 0.28), col, 2, 10)
	b.add_theme_stylebox_override(&"normal", sb)
	b.add_theme_stylebox_override(&"hover", sbh)
	b.add_theme_color_override(&"font_color", col.lightened(0.3))
	b.add_theme_font_size_override(&"font_size", 22)
	return b


func _confirm(action: String) -> void:
	AudioManager.play_sfx(&"ui_click")
	var cname := Recruitment.get_candidate(_cid).display_name()
	var verb := "accept" if action == "accept" else "reject"
	var dialog := ConfirmPanel.create(
		"CONFIRM %s" % ("ACCEPTANCE" if action == "accept" else "REJECTION"),
		"Are you sure you want to %s %s?" % [verb, cname],
		"CONFIRM %s" % ("ACCEPTANCE" if action == "accept" else "REJECTION"), "GO BACK")
	dialog.name = "ConfirmDecision"
	add_child(dialog)
	if await dialog.answered:
		_commit(action)


## Records the decision and shows the narrative response (also used by tests).
func _commit(action: String) -> void:
	var reason := _reason.text.strip_edges() if _reason else ""
	var result := Recruitment.decide(_cid, action, reason)
	AudioManager.play_sfx(&"stinger" if action != "investigate" else &"paper", -10.0 if action != "investigate" else -4.0)
	clear_content()
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(center)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(1000, 0)
	v.add_theme_constant_override(&"separation", 22)
	center.add_child(v)
	var label: String = {"accept": "ACCEPTED", "reject": "REJECTED", "investigate": "INVESTIGATION CONTINUES"}[action]
	var col: Color = {"accept": RecruitUI.GREEN, "reject": RecruitUI.RED, "investigate": RecruitUI.YELLOW}[action]
	var stamp := UITheme.label(label, &"TitleLabel", 64, col)
	stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(stamp)
	var name_label := UITheme.label(Recruitment.get_candidate(_cid).display_name(), &"HeaderLabel", 30)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_label)
	var text := UITheme.label(Recruitment.response_text(_cid, action), &"SerifLabel", 24)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(text)
	var cont := UITheme.button("CONTINUE")
	cont.name = "ContinueButton"
	cont.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cont.custom_minimum_size = Vector2(260, 56)
	cont.pressed.connect(close)
	v.add_child(cont)
	stamp.modulate.a = 0.0
	stamp.scale = Vector2(1.3, 1.3)
	stamp.pivot_offset = Vector2(500, 40)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(stamp, "modulate:a", 1.0, 0.25)
	tw.tween_property(stamp, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# If this triggered a CEO intervention (result["intervention"]), the office
	# stages it as soon as this panel closes (Recruitment.pending_intervention()).
	if not str(result.get("intervention", "")).is_empty():
		cont.text = "CONTINUE  ·  LINE 1 IS RINGING"
