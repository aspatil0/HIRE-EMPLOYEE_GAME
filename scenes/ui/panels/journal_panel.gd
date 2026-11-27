extends ModalPanel
## Evidence journal (J): every candidate's investigation log in discovery
## order, filterable by investigation category, with the open contradictions
## summarised at the top.

const FILTERS := [["all", "ALL"], ["identity", "IDENTITY"], ["employment", "EMPLOYMENT"], ["education", "EDUCATION"], ["reference", "REFERENCES"], ["conduct", "CONDUCT"]]

var _cid: String
var _filter: String = "all"


func _init() -> void:
	title = "EVIDENCE JOURNAL"
	subtitle = "Everything you have found, in the order you found it"
	panel_size = Vector2(1560, 920)
	accent = UITheme.WARM


func _build_content(_body: VBoxContainer) -> void:
	_cid = str(context.get("candidate_id", Recruitment.current_id()))
	_rebuild()


func _rebuild() -> void:
	clear_content()
	content.add_child(RecruitUI.candidate_tabs(_cid, func(id: String) -> void:
		AudioManager.play_sfx(&"paper", -6.0)
		_cid = id
		Recruitment.set_current(id)
		_rebuild()))
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override(&"separation", 6)
	for f: Array in FILTERS:
		var b := UITheme.button(f[1], &"FlatButton")
		b.name = "Filter_%s" % f[0]
		b.toggle_mode = true
		b.button_pressed = f[0] == _filter
		b.add_theme_font_size_override(&"font_size", 15)
		var key: String = f[0]
		b.pressed.connect(func() -> void:
			_filter = key
			_rebuild())
		filters.add_child(b)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filters.add_child(spacer)
	filters.add_child(RecruitUI.status_chip(_cid))
	content.add_child(filters)

	var c := Recruitment.get_candidate(_cid)
	var oc := Recruitment.open_contradictions(_cid)
	content.add_child(UITheme.label("%s  ·  %s  ·  %d evidence items  ·  %d unresolved contradiction%s" % [
		c.display_name().to_upper(), c.position(), Recruitment.discovered_clues(_cid).size(), oc.size(), "" if oc.size() == 1 else "s"], &"DimLabel", 14))
	if _filter == "all":
		content.add_child(RecruitUI.scroll(RecruitUI.evidence_log(_cid, 18)))
		return
	var list := VBoxContainer.new()
	list.add_theme_constant_override(&"separation", 8)
	for cl: String in Recruitment.discovered_clues(_cid):
		var info := c.clue(cl)
		if str(info.get("category", "")) != _filter:
			continue
		var col := UITheme.INK
		var suffix := ""
		if info.get("contradiction", false):
			if Recruitment.is_resolved(_cid, cl):
				col = RecruitUI.YELLOW
				suffix = "   [EXPLAINED]"
			else:
				col = RecruitUI.RED.lightened(0.2)
		var l := UITheme.label("■  %s%s" % [info.get("text", ""), suffix], &"", 18, col)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(l)
	if list.get_child_count() == 0:
		list.add_child(UITheme.label("Nothing in this category yet.", &"DimLabel", 15))
	content.add_child(RecruitUI.scroll(list))
