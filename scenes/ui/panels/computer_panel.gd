extends ModalPanel
## Main computer: Ashgrove's Recruitment Management System. Boots with a short
## login sequence, then offers Inbox, Candidates and Company tabs. The hiring
## module is locked in-fiction until verification tools arrive (Phase 2).

const SCREEN_BG := Color(0.02, 0.05, 0.09)
const SCREEN_INK := Color(0.72, 0.85, 0.97)
const SCREEN_DIM := Color(0.4, 0.55, 0.7)

var _boot: Label
var _main: HBoxContainer
var _page: VBoxContainer
var _tabs: Array[Button] = []
var _group := ButtonGroup.new()
var _company: Dictionary = {}


func _init() -> void:
	title = "ASHGROVE RMS"
	subtitle = "Recruitment Management System · Terminal 13-A · Signed in as ALICE"
	panel_size = Vector2(1480, 880)
	accent = Color(0.3, 0.55, 0.85)


func _build_content(body: VBoxContainer) -> void:
	_company = DataLoader.company(GameState.day)
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
	var inbox_count := (_company.get("inbox", []) as Array).size()
	for tab: Array in [["INBOX  (%d)" % inbox_count, _page_inbox], ["CANDIDATES", _page_candidates], ["COMPANY", _page_company]]:
		var b := UITheme.button(tab[0], &"FlatButton")
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
			_open_page(builder))
		side_box.add_child(b)
		_tabs.append(b)

	var page_margin := MarginContainer.new()
	page_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		page_margin.add_theme_constant_override(s, 30)
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
		"> loading recruitment queue .......... %d records" % GameState.candidates_pending,
		"> last login: 03:13  (terminal 13-A)",
	]
	# Tween-driven so it stops cleanly if the panel closes mid-boot.
	var tw := create_tween()
	for line: String in lines:
		tw.tween_callback(func() -> void: _boot.text += line + char(10))
		tw.tween_interval(0.16)
	tw.tween_interval(0.25)
	tw.tween_callback(_show_desktop)


func _show_desktop() -> void:
	_boot.get_parent().visible = false
	_main.visible = true
	_tabs[0].set_pressed_no_signal(true)
	_open_page(_page_inbox)


func _open_page(builder: Callable) -> void:
	for c in _page.get_children():
		c.queue_free()
	builder.call()


func _mono(text: String, font_size: int = 18, col: Color = SCREEN_INK) -> Label:
	var l := UITheme.label(text, &"MonoLabel", font_size, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


# --- Pages --------------------------------------------------------------------

func _page_inbox() -> void:
	_page.add_child(_mono("INBOX", 16, SCREEN_DIM))
	var mails: Array = _company.get("inbox", [])
	var reader := _mono("", 19)
	var list := VBoxContainer.new()
	list.add_theme_constant_override(&"separation", 2)
	_page.add_child(list)
	for m: Dictionary in mails:
		var b := UITheme.button("", &"FlatButton")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_override(&"font", UITheme.mono())
		b.add_theme_font_size_override(&"font_size", 17)
		var unknown := str(m.get("from", "")).begins_with("(")
		b.add_theme_color_override(&"font_color", Color(0.95, 0.5, 0.45) if unknown else SCREEN_INK)
		b.text = "%s   %-28s  %s" % [m.get("time", ""), str(m.get("from", "")).left(28), m.get("subject", "")]
		b.pressed.connect(func() -> void:
			AudioManager.play_sfx(&"keypress", -4.0)
			reader.text = "FROM:     %s\nSUBJECT:  %s\nRECEIVED: %s\n\n%s" % [m.get("from", ""), m.get("subject", ""), m.get("time", ""), m.get("body", "")]
			if unknown:
				GameState.set_flag(&"read_anonymous_mail"))
		list.add_child(b)
	_page.add_child(ModalPanel.hsep())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	reader.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reader.text = "Select a message."
	scroll.add_child(reader)
	_page.add_child(scroll)


func _page_candidates() -> void:
	_page.add_child(_mono("RECRUITMENT QUEUE  ·  DAY %d" % GameState.day, 16, SCREEN_DIM))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override(&"h_separation", 40)
	grid.add_theme_constant_override(&"v_separation", 12)
	_page.add_child(grid)
	for h in ["CANDIDATE", "POSITION", "DOCUMENTS", "STATUS"]:
		grid.add_child(_mono(h, 15, SCREEN_DIM))
	for c: Dictionary in DataLoader.candidates(GameState.day):
		grid.add_child(_mono(str(c.get("name", "")).to_upper(), 18))
		grid.add_child(_mono(str(c.get("position", "")), 18, SCREEN_DIM))
		var docs: Dictionary = c.get("documents", {})
		var have := 0
		for k: String in docs:
			if docs[k] != null:
				have += 1
		grid.add_child(_mono("%d / 3 received" % have, 18, SCREEN_INK if have == 3 else Color(0.95, 0.7, 0.4)))
		var flagged := GameState.is_flag_set(StringName("flagged_%s" % c.get("id", "")))
		grid.add_child(_mono("FLAGGED" if flagged else "PENDING", 18, Color(0.95, 0.5, 0.45) if flagged else Color(0.95, 0.8, 0.45)))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page.add_child(spacer)
	var lock := PanelContainer.new()
	lock.add_theme_stylebox_override(&"panel", UITheme.flat_box(Color(0.35, 0.08, 0.07, 0.35), Color(0.7, 0.2, 0.15, 0.6), 1, 16))
	lock.add_child(_mono("HIRING MODULE LOCKED  ·  Every candidate must complete identity verification before an offer can be issued.", 17, Color(1, 0.8, 0.75)))
	_page.add_child(lock)


func _page_company() -> void:
	_page.add_child(_mono("COMPANY OVERVIEW  ·  %s" % str(_company.get("company", "Ashgrove Holdings")).to_upper(), 16, SCREEN_DIM))
	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override(&"h_separation", 60)
	stats.add_theme_constant_override(&"v_separation", 14)
	_page.add_child(stats)
	stats.add_child(_mono("OPERATING FUNDS", 16, SCREEN_DIM))
	stats.add_child(_mono("₹ %s" % _format_inr(GameState.company_funds), 26))
	stats.add_child(_mono("REPUTATION", 16, SCREEN_DIM))
	var rep_row := HBoxContainer.new()
	rep_row.add_theme_constant_override(&"separation", 16)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(360, 14)
	bar.show_percentage = false
	bar.value = GameState.company_reputation
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rep_row.add_child(bar)
	rep_row.add_child(_mono("%d / 100" % GameState.company_reputation, 22))
	stats.add_child(rep_row)
	stats.add_child(_mono("STATUS", 16, SCREEN_DIM))
	stats.add_child(_mono(GameState.get_company_status(), 22, Color(0.55, 0.9, 0.6)))
	stats.add_child(_mono("HIRES THIS CYCLE", 16, SCREEN_DIM))
	stats.add_child(_mono("%d of %d" % [GameState.hires, GameState.hire_target], 22))
	_page.add_child(ModalPanel.hsep())
	_page.add_child(_mono("OPEN POSITIONS", 16, SCREEN_DIM))
	for p: Dictionary in _company.get("open_positions", []):
		_page.add_child(_mono("■ %-24s %-20s %s" % [p.get("title", ""), p.get("department", ""), p.get("salary", "")], 18))


## 4800000 -> "48,00,000" (Indian digit grouping).
static func _format_inr(value: int) -> String:
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
	return ",".join(groups) + "," + last3
