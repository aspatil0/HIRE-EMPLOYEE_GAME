extends ModalPanel
## Side computer: NETLINK, a public browser for background research. Queries
## are matched against each candidate's local search results (no internet).
## Results range from reliable records to gossip and name-alike confusion;
## opening a page logs it and records whatever it shows as evidence. The
## browser never says which sources are trustworthy.

const PAGE_BG := Color(0.87, 0.89, 0.9)
const PAGE_INK := Color(0.12, 0.13, 0.15)
const LINK := Color(0.12, 0.3, 0.65)

var _query: LineEdit
var _results: VBoxContainer
var _address: Label
var _search_tween: Tween
var _last_hits: Array[Dictionary] = []
var _last_query: String = ""


func _init() -> void:
	title = "NETLINK BROWSER"
	subtitle = "Public research terminal · Connection not secure · Not every source is credible"
	panel_size = Vector2(1520, 900)
	accent = Color(0.45, 0.6, 0.65)


func _build_content(body: VBoxContainer) -> void:
	var chrome := PanelContainer.new()
	chrome.add_theme_stylebox_override(&"panel", UITheme.flat_box(Color(0.2, 0.22, 0.24), Color.TRANSPARENT, 0, 10))
	body.add_child(chrome)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override(&"separation", 12)
	chrome.add_child(bar)
	var back := UITheme.button("◀", &"FlatButton")
	back.name = "BackButton"
	back.pressed.connect(func() -> void:
		if not _last_query.is_empty():
			_render_results(_last_query, _last_hits))
	bar.add_child(back)
	var addr_box := PanelContainer.new()
	addr_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	addr_box.add_theme_stylebox_override(&"panel", UITheme.flat_box(Color(0.94, 0.95, 0.96), Color.TRANSPARENT, 0, 8))
	_address = UITheme.label("http://search.netlink.in/", &"MonoLabel", 17, Color(0.25, 0.28, 0.32))
	addr_box.add_child(_address)
	bar.add_child(addr_box)

	var page := PanelContainer.new()
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var page_sb := UITheme.flat_box(PAGE_BG, Color.TRANSPARENT, 0, 0)
	page_sb.content_margin_left = 60
	page_sb.content_margin_right = 60
	page_sb.content_margin_top = 28
	page_sb.content_margin_bottom = 20
	page.add_theme_stylebox_override(&"panel", page_sb)
	body.add_child(page)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 12)
	page.add_child(v)
	v.add_child(UITheme.label("netlink", &"HeaderLabel", 40, Color(0.55, 0.14, 0.12)))
	var search_row := HBoxContainer.new()
	search_row.add_theme_constant_override(&"separation", 10)
	v.add_child(search_row)
	_query = LineEdit.new()
	_query.name = "Query"
	_query.placeholder_text = "Search people, companies, news, certificates..."
	_query.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var le := UITheme.flat_box(Color(1, 1, 1), Color(0.6, 0.62, 0.65), 1, 12)
	_query.add_theme_stylebox_override(&"normal", le)
	_query.add_theme_stylebox_override(&"focus", le)
	_query.add_theme_color_override(&"font_color", PAGE_INK)
	_query.add_theme_color_override(&"caret_color", PAGE_INK)
	_query.text_submitted.connect(func(_t: String) -> void: search(_query.text))
	search_row.add_child(_query)
	var go := UITheme.button("SEARCH")
	go.name = "SearchButton"
	go.pressed.connect(func() -> void: search(_query.text))
	search_row.add_child(go)

	var quick := HFlowContainer.new()
	quick.add_theme_constant_override(&"h_separation", 6)
	v.add_child(quick)
	quick.add_child(UITheme.label("Applicants:", &"", 15, Color(0.35, 0.37, 0.4)))
	for c in Recruitment.candidates:
		var chip := UITheme.button(c.display_name(), &"FlatButton")
		chip.add_theme_color_override(&"font_color", LINK)
		chip.add_theme_color_override(&"font_hover_color", Color(0.5, 0.1, 0.1))
		chip.add_theme_font_size_override(&"font_size", 15)
		var cname := c.display_name()
		chip.pressed.connect(func() -> void:
			_query.text = cname
			search(cname))
		quick.add_child(chip)
	var rule := ColorRect.new()
	rule.color = Color(0, 0, 0, 0.12)
	rule.custom_minimum_size = Vector2(0, 1)
	v.add_child(rule)
	_results = VBoxContainer.new()
	_results.add_theme_constant_override(&"separation", 18)
	v.add_child(RecruitUI.scroll(_results))
	_note("Tip: search names, former employers, colleges or reference names. Then judge the source.")
	_query.call_deferred(&"grab_focus")


## Runs a search (also used by tests). Results appear after a short delay.
func search(text: String) -> void:
	var q := text.strip_edges()
	if q.is_empty():
		return
	AudioManager.play_sfx(&"keypress", -2.0)
	_address.text = "http://search.netlink.in/?q=%s" % q.uri_encode()
	_clear()
	_note("Searching...")
	if _search_tween and _search_tween.is_valid():
		_search_tween.kill()
	_search_tween = create_tween()
	_search_tween.tween_interval(randf_range(0.4, 0.7))
	_search_tween.tween_callback(func() -> void: _render_results(q, Recruitment.search(q)))


func _render_results(q: String, hits: Array[Dictionary]) -> void:
	_last_query = q
	_last_hits = hits
	_address.text = "http://search.netlink.in/?q=%s" % q.uri_encode()
	_clear()
	if hits.is_empty():
		_note("No results found for \"%s\"." % q)
		return
	_note("About %d results for \"%s\"" % [hits.size(), q])
	for h in hits:
		var r: Dictionary = h["result"]
		var cid: String = h["candidate_id"]
		var box := VBoxContainer.new()
		box.add_theme_constant_override(&"separation", 1)
		var opened := (Recruitment.state(cid)["results_opened"] as Array).has(r.get("id", ""))
		box.add_child(UITheme.label("%s   ·   %s" % [r.get("source", ""), r.get("url", "")], &"", 14, Color(0.25, 0.45, 0.3)))
		var link := UITheme.button(str(r.get("title", "")), &"FlatButton")
		link.name = "Result_%s" % r.get("id", "")
		link.alignment = HORIZONTAL_ALIGNMENT_LEFT
		link.add_theme_font_override(&"font", UITheme.serif())
		link.add_theme_font_size_override(&"font_size", 24)
		link.add_theme_color_override(&"font_color", Color(0.4, 0.2, 0.5) if opened else LINK)
		link.add_theme_color_override(&"font_hover_color", Color(0.6, 0.12, 0.1))
		link.pressed.connect(open_result.bind(cid, r))
		box.add_child(link)
		var snip := UITheme.label(str(r.get("snippet", "")), &"", 17, Color(0.3, 0.31, 0.34))
		snip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(snip)
		_results.add_child(box)


## Opens one result page (also used by tests).
func open_result(candidate_id: String, r: Dictionary) -> void:
	AudioManager.play_sfx(&"ui_click", -6.0)
	Recruitment.open_result(candidate_id, r)
	_address.text = "http://%s" % r.get("url", "")
	_clear()
	_results.add_child(UITheme.label(str(r.get("source", "")).to_upper(), &"DimLabel", 13, Color(0.25, 0.45, 0.3)))
	var t := UITheme.label(str(r.get("title", "")), &"SerifLabel", 32, PAGE_INK)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_results.add_child(t)
	var b := UITheme.label(str(r.get("body", "")), &"SerifLabel", 22, Color(0.22, 0.23, 0.26))
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_results.add_child(b)
	_results.add_child(UITheme.label("Recorded in %s's investigation log." % Recruitment.get_candidate(candidate_id).display_name(), &"DimLabel", 12, Color(0.45, 0.47, 0.5)))
	var back := UITheme.button("◀  BACK TO RESULTS")
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(func() -> void: _render_results(_last_query, _last_hits))
	_results.add_child(back)


func _clear() -> void:
	for c in _results.get_children():
		_results.remove_child(c)
		c.queue_free()


func _note(text: String) -> void:
	_results.add_child(UITheme.label(text, &"", 17, Color(0.4, 0.42, 0.45)))
