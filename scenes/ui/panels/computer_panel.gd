extends ModalPanel
## Main computer: Ashgrove's Recruitment Management System.
## Tabs: DASHBOARD (recruitment statistics + candidate table), REPORTS
## (per-candidate investigation log, in discovery order), INBOX (emails, some
## carrying evidence), COMPANY, and FINAL REPORT once all six are decided.

const SCREEN_BG := Color(0.02, 0.05, 0.09)
const SCREEN_INK := Color(0.72, 0.85, 0.97)
const SCREEN_DIM := Color(0.4, 0.55, 0.7)

var _boot: Label
var _main: HBoxContainer
var _page: VBoxContainer
var _tabs: Array[Button] = []
var _group := ButtonGroup.new()
var _company: Dictionary = {}
var _report_cid: String = ""


func _init() -> void:
	title = "ASHGROVE RMS"
	subtitle = "Recruitment Management System · Terminal 13-A · Signed in as ALICE"
	panel_size = Vector2(1680, 960)
	accent = Color(0.3, 0.55, 0.85)


func _build_content(body: VBoxContainer) -> void:
	_company = DataLoader.company(GameState.day)
	_report_cid = Recruitment.current_id()
	var screen := PanelContainer.new()
	screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen.add_theme_stylebox_override(&"panel", UITheme.flat_box(SCREEN_BG, Color(0.15, 0.3, 0.45, 0.6), 1, 0))
	body.add_child(screen)

	_boot = UITheme.label("", &"MonoLabel", 20, SCREEN_INK)
	_boot.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var boot_margin := MarginContainer.new()
	for side in [&"margin_left", &"margin_top"]:
		boot_margin.add_theme_constant_override(side, 30)
	boot_margin.add_child(_boot)
	screen.add_child(boot_margin)

	_main = HBoxContainer.new()
	_main.add_theme_constant_override(&"separation", 0)
	_main.visible = false
	screen.add_child(_main)

	var side := PanelContainer.new()
	side.custom_minimum_size = Vector2(250, 0)
	side.add_theme_stylebox_override(&"panel", UITheme.flat_box(Color(0.03, 0.08, 0.14), Color.TRANSPARENT, 0, 0))
	_main.add_child(side)
	var side_box := VBoxContainer.new()
	side_box.add_theme_constant_override(&"separation", 2)
	side.add_child(side_box)
	var logo := UITheme.label("  ASHGROVE", &"HeaderLabel", 22, SCREEN_INK)
	logo.custom_minimum_size = Vector2(0, 70)
	logo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	side_box.add_child(logo)
	var tabs: Array = [["DASHBOARD", _page_dashboard], ["REPORTS", _page_reports], ["INBOX  (%d)" % Recruitment.visible_emails(_company).size(), _page_inbox], ["COMPANY", _page_company]]
	if Recruitment.is_complete():
		tabs.append(["FINAL REPORT", _page_final])
	for tab: Array in tabs:
		var b := UITheme.button(tab[0], &"FlatButton")
		b.name = "Tab_%s" % str(tab[0]).get_slice(" ", 0)
		b.toggle_mode = true
		b.button_group = _group
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_override(&"font", UITheme.mono())
		b.add_theme_font_size_override(&"font_size", 18)
		b.add_theme_color_override(&"font_color", SCREEN_DIM)
		b.add_theme_color_override(&"font_pressed_color", SCREEN_INK)
		b.add_theme_color_override(&"font_hover_color", SCREEN_INK)
		b.custom_minimum_size = Vector2(0, 52)
		var builder: Callable = tab[1]
		b.pressed.connect(func() -> void:
			AudioManager.play_sfx(&"keypress", -4.0)
			open_page(builder))
		side_box.add_child(b)
		_tabs.append(b)

	var page_margin := MarginContainer.new()
	page_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		page_margin.add_theme_constant_override(s, 28)
	_main.add_child(page_margin)
	_page = VBoxContainer.new()
	_page.add_theme_constant_override(&"separation", 14)
	page_margin.add_child(_page)
	_run_boot()


func _run_boot() -> void:
	AudioManager.play_sfx(&"boot", -4.0)
	var lines := [
		"ASHGROVE HOLDINGS  //  RMS v4.2.1",
		"> establishing secure session ........ OK",
		"> authenticating ALICE ............... OK",
		"> loading recruitment queue .......... %d records" % Recruitment.candidates.size(),
		"> last login: 03:13  (terminal 13-A)",
	]
	var tw := create_tween()
	for line: String in lines:
		tw.tween_callback(func() -> void: _boot.text += line + char(10))
		tw.tween_interval(0.12)
	tw.tween_interval(0.2)
	tw.tween_callback(_show_desktop)


func _show_desktop() -> void:
	_boot.get_parent().visible = false
	_main.visible = true
	_tabs[0].set_pressed_no_signal(true)
	open_page(_page_dashboard)


## Shows a page by builder (also used by tests).
func open_page(builder: Callable) -> void:
	for c in _page.get_children():
		_page.remove_child(c)
		c.queue_free()
	builder.call()


func _mono(text: String, font_size: int = 18, col: Color = SCREEN_INK, wrap: bool = true) -> Label:
	var l := UITheme.label(text, &"MonoLabel", font_size, col)
	if wrap: # never wrap inside grids: wrapped labels collapse grid columns
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


# --- Dashboard ----------------------------------------------------------------

func _page_dashboard() -> void:
	var s := Recruitment.dashboard_stats()
	_page.add_child(_mono("RECRUITMENT REVIEW  ·  DAY %d  ·  %s" % [GameState.day, DateUtil.clock_12h(GameState.time_minutes)], 16, SCREEN_DIM))
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override(&"separation", 10)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override(&"separation", 10)
	row1.add_child(RecruitUI.stat_box("Total applications", str(s["total"]), SCREEN_INK))
	row1.add_child(RecruitUI.stat_box("Investigated", str(s["investigated"]), SCREEN_INK))
	row1.add_child(RecruitUI.stat_box("Pending decision", str(s["pending"]), RecruitUI.YELLOW))
	row1.add_child(RecruitUI.stat_box("Accepted", str(s["accepted"]), RecruitUI.GREEN))
	row2.add_child(RecruitUI.stat_box("Rejected", str(s["rejected"]), RecruitUI.RED))
	row2.add_child(RecruitUI.stat_box("Flagged", str(s["flagged"]), UITheme.ACCENT_SOFT))
	row2.add_child(RecruitUI.stat_box("Verified documents", str(s["verified_docs"]), SCREEN_INK))
	row2.add_child(RecruitUI.stat_box("Outstanding contradictions", str(s["contradictions"]), RecruitUI.RED if s["contradictions"] > 0 else SCREEN_INK))
	_page.add_child(row1)
	_page.add_child(row2)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override(&"h_separation", 28)
	grid.add_theme_constant_override(&"v_separation", 8)
	for h in ["#", "CANDIDATE", "POSITION", "EVIDENCE", "OPEN CONTRADICTIONS", "STATUS"]:
		grid.add_child(_mono(h, 13, SCREEN_DIM, false))
	for c in Recruitment.candidates:
		grid.add_child(_mono("%02d" % c.index, 17, SCREEN_DIM, false))
		var link := UITheme.button(c.display_name().to_upper(), &"FlatButton")
		link.add_theme_font_override(&"font", UITheme.mono())
		link.add_theme_font_size_override(&"font_size", 17)
		link.add_theme_color_override(&"font_color", SCREEN_INK)
		link.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var cid := c.id
		link.pressed.connect(func() -> void:
			_report_cid = cid
			_select_tab(1)
			open_page(_page_reports))
		grid.add_child(link)
		grid.add_child(_mono(c.position(), 16, SCREEN_DIM, false))
		grid.add_child(_mono("%d items" % Recruitment.discovered_clues(c.id).size(), 16, SCREEN_INK, false))
		var oc := Recruitment.open_contradictions(c.id).size()
		grid.add_child(_mono(str(oc), 16, RecruitUI.RED if oc > 0 else SCREEN_DIM, false))
		grid.add_child(RecruitUI.status_chip(c.id))
	_page.add_child(RecruitUI.scroll(grid))
	var hint := _mono("Click a candidate to open the investigation report. Decisions are made from the candidate's file (resume stack).", 14, SCREEN_DIM)
	_page.add_child(hint)


func _select_tab(i: int) -> void:
	if i < _tabs.size():
		_tabs[i].set_pressed_no_signal(true)


# --- Reports ------------------------------------------------------------------

func _page_reports() -> void:
	_page.add_child(RecruitUI.candidate_tabs(_report_cid, func(id: String) -> void:
		_report_cid = id
		open_page(_page_reports)))
	var c := Recruitment.get_candidate(_report_cid)
	if c == null:
		return
	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 16)
	head.add_child(_mono("INVESTIGATION LOG — %s" % c.display_name().to_upper(), 22))
	head.add_child(RecruitUI.status_chip(c.id))
	_page.add_child(head)
	_page.add_child(_mono("%s  ·  documents verified %d/%d  ·  evidence %d  ·  open contradictions %d" % [
		c.position(), Recruitment.verified_documents(c.id).size(), Recruitment.submitted_documents(c.id).size(),
		Recruitment.discovered_clues(c.id).size(), Recruitment.open_contradictions(c.id).size()], 15, SCREEN_DIM))
	_page.add_child(RecruitUI.scroll(RecruitUI.evidence_log(c.id, 17)))
	var hist: Array = Recruitment.state(c.id)["history"]
	if not hist.is_empty():
		var parts: PackedStringArray = []
		for h: Dictionary in hist:
			parts.append("[%s] %s" % [h.get("time", ""), str(h.get("action", "")).to_upper().replace("_", " ")])
		_page.add_child(_mono("DECISION HISTORY:  " + "   ·   ".join(parts), 14, UITheme.WARM))


# --- Inbox --------------------------------------------------------------------

func _page_inbox() -> void:
	_page.add_child(_mono("INBOX", 16, SCREEN_DIM))
	var reader := _mono("Select a message.", 19)
	var replies := HBoxContainer.new()
	replies.name = "Replies"
	replies.add_theme_constant_override(&"separation", 12)
	var list := VBoxContainer.new()
	list.add_theme_constant_override(&"separation", 2)
	_page.add_child(list)
	for m: Dictionary in Recruitment.visible_emails(_company):
		var b := UITheme.button("", &"FlatButton")
		b.name = "Mail_%s" % m.get("id", "")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_override(&"font", UITheme.mono())
		b.add_theme_font_size_override(&"font_size", 17)
		var unknown := str(m.get("from", "")).begins_with("(")
		var unread := not Recruitment.is_email_read(str(m.get("id", "")))
		b.add_theme_color_override(&"font_color", Color(0.95, 0.5, 0.45) if unknown else SCREEN_INK)
		b.text = "%s %s   %-30s  %s" % ["●" if unread else " ", m.get("time", ""), str(m.get("from", "")).left(30), m.get("subject", "")]
		b.pressed.connect(func() -> void:
			AudioManager.play_sfx(&"keypress", -4.0)
			Recruitment.read_email(m)
			b.text = "  " + b.text.substr(2)
			reader.text = "FROM:     %s\nSUBJECT:  %s\nRECEIVED: %s\n\n%s" % [m.get("from", ""), m.get("subject", ""), m.get("time", ""), m.get("body", "")]
			_show_replies(m, replies, reader))
		list.add_child(b)
	_page.add_child(ModalPanel.hsep())
	reader.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page.add_child(RecruitUI.scroll(reader))
	_page.add_child(replies)


## Reply buttons for the unknown sender's emails (also used by tests).
func _show_replies(m: Dictionary, box: HBoxContainer, reader: Label) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	var options: Array = m.get("replies", [])
	if options.is_empty():
		return
	var done := Recruitment.reply_of(str(m.get("id", "")))
	if not done.is_empty():
		for r: Dictionary in options:
			if r.get("id", "") == done:
				box.add_child(_mono("YOUR RESPONSE:  %s" % r.get("text", ""), 15, UITheme.WARM, false))
		return
	box.add_child(_mono("REPLY:", 15, SCREEN_DIM, false))
	for r: Dictionary in options:
		var rb := UITheme.button(str(r.get("text", "")))
		rb.name = "Reply_%s" % r.get("id", "")
		rb.add_theme_font_size_override(&"font_size", 16)
		var rid := str(r.get("id", ""))
		rb.pressed.connect(func() -> void:
			AudioManager.play_sfx(&"keypress", -2.0)
			var sent := Recruitment.reply_email(m, rid)
			if not sent.is_empty():
				reader.text += "\n\n— — —\nSENT TO (unknown sender):\n%s" % sent
				AudioManager.play_sfx(&"ui_open", -8.0, 1.4)
			_show_replies(m, box, reader))
		box.add_child(rb)


# --- Company ------------------------------------------------------------------

func _page_company() -> void:
	_page.add_child(_mono("COMPANY OVERVIEW  ·  %s" % str(_company.get("company", "Ashgrove Holdings")).to_upper(), 16, SCREEN_DIM))
	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override(&"h_separation", 60)
	stats.add_theme_constant_override(&"v_separation", 14)
	_page.add_child(stats)
	stats.add_child(_mono("OPERATING FUNDS", 16, SCREEN_DIM, false))
	stats.add_child(_mono("₹ %s" % format_inr(GameState.company_funds), 26, SCREEN_INK, false))
	stats.add_child(_mono("REPUTATION", 16, SCREEN_DIM, false))
	var rep_row := HBoxContainer.new()
	rep_row.add_theme_constant_override(&"separation", 16)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(360, 14)
	bar.show_percentage = false
	bar.value = GameState.company_reputation
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rep_row.add_child(bar)
	rep_row.add_child(_mono("%d / 100" % GameState.company_reputation, 22, SCREEN_INK, false))
	stats.add_child(rep_row)
	stats.add_child(_mono("STATUS", 16, SCREEN_DIM, false))
	stats.add_child(_mono(GameState.get_company_status(), 22, Color(0.55, 0.9, 0.6), false))
	stats.add_child(_mono("HIRES THIS CYCLE", 16, SCREEN_DIM, false))
	stats.add_child(_mono("%d of %d" % [GameState.hires, GameState.hire_target], 22, SCREEN_INK, false))
	_page.add_child(ModalPanel.hsep())
	_page.add_child(_mono("OPEN POSITIONS", 16, SCREEN_DIM))
	for p: Dictionary in _company.get("open_positions", []):
		_page.add_child(_mono("■ %-24s %-20s %s" % [p.get("title", ""), p.get("department", ""), p.get("salary", "")], 18))


func _page_final() -> void:
	_page.add_child(_mono("FINAL RECRUITMENT REPORT IS AVAILABLE.", 18))
	var open_btn := UITheme.button("OPEN REPORT")
	open_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	open_btn.pressed.connect(func() -> void: switch_panel(load(RecruitUI.REPORT_SCENE)))
	_page.add_child(open_btn)


## 4800000 -> "48,00,000" (Indian digit grouping).
static func format_inr(value: int) -> String:
	var s := str(absi(value))
	if s.length() <= 3:
		return s
	var last3 := s.right(3)
	var rest := s.left(s.length() - 3)
	var groups: PackedStringArray = []
	while rest.length() > 2:
		groups.insert(0, rest.right(2))
		rest = rest.left(rest.length() - 2)
	if not rest.is_empty():
		groups.insert(0, rest)
	return ("-" if value < 0 else "") + ",".join(groups) + "," + last3
