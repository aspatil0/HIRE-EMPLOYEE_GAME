extends ModalPanel
## End-of-phase recruitment report. Appears once all six decisions stand.
## Shows the numbers, each decision's outcome, missed key evidence, the
## ending and the thread that leads into Phase 3.

func _init() -> void:
	title = "RECRUITMENT REPORT — DAY 1"
	subtitle = "Filed to the Office of the CEO"
	panel_size = Vector2(1680, 980)
	accent = UITheme.ACCENT


func _build_content(body: VBoxContainer) -> void:
	var r := Recruitment.build_report()
	var page := VBoxContainer.new()
	page.add_theme_constant_override(&"separation", 14)
	body.add_child(RecruitUI.scroll(page))

	var stats := HBoxContainer.new()
	stats.add_theme_constant_override(&"separation", 8)
	stats.add_child(RecruitUI.stat_box("Applications", str(r["total"])))
	stats.add_child(RecruitUI.stat_box("Accepted", str(r["accepted"]), RecruitUI.GREEN))
	stats.add_child(RecruitUI.stat_box("Rejected", str(r["rejected"]), RecruitUI.RED))
	stats.add_child(RecruitUI.stat_box("Investigated", str(r["investigated"])))
	stats.add_child(RecruitUI.stat_box("Documents verified", str(r["docs_verified"])))
	stats.add_child(RecruitUI.stat_box("Contradictions found", str(r["contradictions"])))
	stats.add_child(RecruitUI.stat_box("CEO interventions", str(r["ceo_used"]), UITheme.ACCENT_SOFT))
	page.add_child(stats)

	var perf := HBoxContainer.new()
	perf.add_theme_constant_override(&"separation", 30)
	var grade := UITheme.label(str(r["grade"]), &"TitleLabel", 120, RecruitUI.GREEN if r["grade"] in ["A", "B"] else (RecruitUI.YELLOW if r["grade"] == "C" else RecruitUI.RED))
	grade.name = "Grade"
	perf.add_child(grade)
	var pv := VBoxContainer.new()
	pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pv.add_child(UITheme.label("OVERALL RECRUITMENT PERFORMANCE  ·  %d / 100" % r["score"], &"DimLabel", 15))
	pv.add_child(UITheme.label("Correct decisions: %d of %d   ·   Incorrect: %d   ·   Key evidence found: %d of %d" % [r["correct"], r["judged"], r["incorrect"], r["key_found"], r["key_total"]], &"SerifLabel", 24))
	perf.add_child(pv)
	page.add_child(perf)

	page.add_child(ModalPanel.section_label("Decisions"))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override(&"h_separation", 34)
	grid.add_theme_constant_override(&"v_separation", 8)
	for h in ["CANDIDATE", "POSITION", "DECISION", "ASSESSMENT", "EVIDENCE GATHERED"]:
		grid.add_child(UITheme.label(h, &"DimLabel", 12))
	for row: Dictionary in r["rows"]:
		grid.add_child(UITheme.label(str(row["name"]), &"SerifLabel", 21))
		grid.add_child(UITheme.label(str(row["position"]), &"", 17, UITheme.DIM))
		grid.add_child(RecruitUI.chip(RecruitUI.STATUS_TEXT.get(row["status"], str(row["status"]).to_upper()), RecruitUI.status_color(row["status"])))
		var verdict: String = row["verdict"]
		var vtext: String = {"correct": "CORRECT", "incorrect": "INCORRECT", "judgement": "JUDGEMENT CALL"}[verdict]
		var vcol: Color = {"correct": RecruitUI.GREEN, "incorrect": RecruitUI.RED, "judgement": RecruitUI.YELLOW}[verdict]
		if row.get("mistake_kept", false):
			vtext += " · KEPT AGAINST CEO"
		grid.add_child(RecruitUI.chip(vtext, vcol))
		grid.add_child(UITheme.label("%d%%" % roundi(float(row["progress"]) * 100.0), &"MonoLabel", 17, UITheme.INK))
	page.add_child(grid)

	var missed: Array = r["missed"]
	page.add_child(ModalPanel.section_label("Important evidence missed  ·  %d" % missed.size()))
	if missed.is_empty():
		page.add_child(UITheme.label("You found every key piece of evidence.", &"", 17, RecruitUI.GREEN))
	for m: String in missed:
		var l := UITheme.label("■  " + m, &"", 16, UITheme.DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		page.add_child(l)

	page.add_child(ModalPanel.hsep())
	var ending := UITheme.label(str(r["ending_title"]), &"TitleLabel", 58, UITheme.WARM)
	ending.name = "EndingTitle"
	page.add_child(ending)
	for key in ["ending_text", "ira_text"]:
		var t := UITheme.label(str(r[key]), &"SerifLabel", 23)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		page.add_child(t)
	var hook := UITheme.label(str(r["hook"]), &"MonoLabel", 20, Color(0.95, 0.4, 0.35))
	hook.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(hook)
	page.add_child(UITheme.label("END OF PHASE 2  ·  The night is not over.", &"DimLabel", 14, UITheme.WARM))
	var close_btn := UITheme.button("FILE THE REPORT")
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	close_btn.pressed.connect(close)
	page.add_child(close_btn)
	GameState.set_flag(&"phase2_report_seen")
