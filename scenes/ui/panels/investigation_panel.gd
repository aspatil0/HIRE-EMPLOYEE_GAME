extends ModalPanel
## Side computer: a public web browser for looking candidates up. Searching a
## candidate's name returns their public traces from the candidate JSON
## ("online" entries); anything else returns no results. Deeper cross-checks
## arrive with the verification mechanics in Phase 2.

const PAGE_BG := Color(0.87, 0.89, 0.9)
const PAGE_INK := Color(0.12, 0.13, 0.15)
const LINK := Color(0.12, 0.3, 0.65)

var _query: LineEdit
var _results: VBoxContainer
var _address: Label
var _search_tween: Tween


func _init() -> void:
	title = "NETLINK BROWSER"
	subtitle = "Public search · Connection not secure"
	panel_size = Vector2(1400, 860)
	accent = Color(0.45, 0.6, 0.65)


func _build_content(body: VBoxContainer) -> void:
	# Browser chrome.
	var chrome := PanelContainer.new()
	chrome.add_theme_stylebox_override(&"panel", UITheme.flat_box(Color(0.2, 0.22, 0.24), Color.TRANSPARENT, 0, 10))
	body.add_child(chrome)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override(&"separation", 12)
	chrome.add_child(bar)
	for glyph in ["◀", "▶", "⟳"]:
		var g := UITheme.label(glyph, &"", 20, Color(0.6, 0.63, 0.66))
		g.custom_minimum_size = Vector2(24, 0)
		bar.add_child(g)
	var addr_box := PanelContainer.new()
	addr_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	addr_box.add_theme_stylebox_override(&"panel", UITheme.flat_box(Color(0.94, 0.95, 0.96), Color.TRANSPARENT, 0, 8))
	_address = UITheme.label("http://search.netlink.in/", &"MonoLabel", 17, Color(0.25, 0.28, 0.32))
	addr_box.add_child(_address)
	bar.add_child(addr_box)

	# Page.
	var page := PanelContainer.new()
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var page_sb := UITheme.flat_box(PAGE_BG, Color.TRANSPARENT, 0, 0)
	page_sb.content_margin_left = 60
	page_sb.content_margin_right = 60
	page_sb.content_margin_top = 34
	page_sb.content_margin_bottom = 24
	page.add_theme_stylebox_override(&"panel", page_sb)
	body.add_child(page)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 14)
	page.add_child(v)

	var logo := UITheme.label("netlink", &"HeaderLabel", 40, Color(0.55, 0.14, 0.12))
	v.add_child(logo)
	var search_row := HBoxContainer.new()
	search_row.add_theme_constant_override(&"separation", 10)
	v.add_child(search_row)
	_query = LineEdit.new()
	_query.placeholder_text = "Search people, companies, news..."
	_query.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var le := UITheme.flat_box(Color(1, 1, 1), Color(0.6, 0.62, 0.65), 1, 12)
	_query.add_theme_stylebox_override(&"normal", le)
	_query.add_theme_stylebox_override(&"focus", le)
	_query.add_theme_color_override(&"font_color", PAGE_INK)
	_query.add_theme_color_override(&"caret_color", PAGE_INK)
	_query.text_submitted.connect(func(_t: String) -> void: _search())
	search_row.add_child(_query)
	var go := UITheme.button("SEARCH")
	go.pressed.connect(_search)
	search_row.add_child(go)

	var quick := HBoxContainer.new()
	quick.add_theme_constant_override(&"separation", 8)
	v.add_child(quick)
	quick.add_child(UITheme.label("Recent applicants:", &"", 16, Color(0.35, 0.37, 0.4)))
	for c in DataLoader.candidates(GameState.day):
		var chip := UITheme.button(str(c.get("name", "")), &"FlatButton")
		chip.add_theme_color_override(&"font_color", LINK)
		chip.add_theme_color_override(&"font_hover_color", Color(0.5, 0.1, 0.1))
		chip.add_theme_font_size_override(&"font_size", 16)
		var cname := str(c.get("name", ""))
		chip.pressed.connect(func() -> void:
			_query.text = cname
			_search())
		quick.add_child(chip)

	var rule := ColorRect.new()
	rule.color = Color(0, 0, 0, 0.12)
	rule.custom_minimum_size = Vector2(0, 1)
	v.add_child(rule)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_results = VBoxContainer.new()
	_results.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_results.add_theme_constant_override(&"separation", 22)
	scroll.add_child(_results)
	_note("Type a name and press SEARCH.")

	var foot := UITheme.label("Deep record search requires clearance level 2.", &"DimLabel", 14, Color(0.45, 0.47, 0.5))
	v.add_child(foot)
	_query.call_deferred(&"grab_focus")


func _search() -> void:
	var q := _query.text.strip_edges()
	if q.is_empty():
		return
	AudioManager.play_sfx(&"keypress", -2.0)
	_address.text = "http://search.netlink.in/?q=%s" % q.uri_encode()
	_clear()
	_note("Searching...")
	if _search_tween and _search_tween.is_valid():
		_search_tween.kill()
	_search_tween = create_tween()
	_search_tween.tween_interval(randf_range(0.5, 0.9))
	_search_tween.tween_callback(_show_results.bind(q))


func _show_results(q: String) -> void:
	_clear()
	var needle := q.to_lower()
	var hits: Array[Dictionary] = []
	for c in DataLoader.candidates(GameState.day):
		var cname := str(c.get("name", "")).to_lower()
		if cname.contains(needle) or needle.contains(cname):
			GameState.set_flag(StringName("searched_%s" % c.get("id", "")))
			for entry: Dictionary in c.get("online", []):
				hits.append(entry)
	if hits.is_empty():
		_note("No results found for \"%s\"." % q)
		return
	_note("About %d results" % hits.size())
	for h in hits:
		var box := VBoxContainer.new()
		box.add_theme_constant_override(&"separation", 2)
		box.add_child(UITheme.label(str(h.get("source", "")), &"", 15, Color(0.25, 0.45, 0.3)))
		box.add_child(UITheme.label(str(h.get("title", "")), &"SerifLabel", 25, LINK))
		var snip := UITheme.label(str(h.get("snippet", "")), &"", 18, Color(0.3, 0.31, 0.34))
		snip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(snip)
		_results.add_child(box)


func _clear() -> void:
	for c in _results.get_children():
		c.queue_free()


func _note(text: String) -> void:
	_results.add_child(UITheme.label(text, &"", 17, Color(0.4, 0.42, 0.45)))
