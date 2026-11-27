extends ModalPanel
## Document verification tray: identity, employment and education checks.
##
## Left: the physical document(s) as submitted. Right: a comparison table of
## resume vs. document. Every row starts NOT VERIFIED (grey); clicking it
## checks that field, colours it (green verified / red contradiction /
## yellow investigate), shows the inspection note and logs any evidence.
## A mismatch is evidence, never an automatic verdict.

const TABS := [["identity", "IDENTITY"], ["employment", "EMPLOYMENT"], ["education", "EDUCATION"]]
const CARD_COLORS := {
	"aadhaar": Color(0.85, 0.55, 0.25), "pan": Color(0.3, 0.45, 0.65), "passport": Color(0.5, 0.15, 0.18),
	"employment": Color(0.35, 0.4, 0.45), "education": Color(0.45, 0.35, 0.18),
}

var _cid: String = ""
var _tab: String = "identity"
var _tabs_row: HBoxContainer
var _cand_row_holder: VBoxContainer
var _docs: VBoxContainer
var _table: GridContainer
var _note_title: Label
var _note: Label
var _summary: Label


func _init() -> void:
	title = "DOCUMENT VERIFICATION"
	subtitle = "Resume vs. submitted documents · click a field to verify it"
	panel_size = Vector2(1720, 970)
	accent = Color(0.85, 0.6, 0.3)


func _build_content(body: VBoxContainer) -> void:
	if Recruitment.remaining().is_empty():
		var done := UITheme.label("The tray is empty. Every application has a decision.", &"SerifLabel", 26, UITheme.DIM)
		done.size_flags_vertical = Control.SIZE_EXPAND_FILL
		done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		done.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		body.add_child(done)
		return
	_cid = str(context.get("candidate_id", Recruitment.current_id()))
	if Recruitment.get_candidate(_cid) == null or Recruitment.is_decided(_cid):
		_cid = Recruitment.remaining()[0].id
	body.add_theme_constant_override(&"separation", 12)
	_cand_row_holder = VBoxContainer.new()
	body.add_child(_cand_row_holder)
	_tabs_row = HBoxContainer.new()
	_tabs_row.add_theme_constant_override(&"separation", 8)
	body.add_child(_tabs_row)

	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override(&"separation", 26)
	body.add_child(row)
	_docs = VBoxContainer.new()
	_docs.add_theme_constant_override(&"separation", 10)
	var doc_scroll := RecruitUI.scroll(_docs)
	doc_scroll.custom_minimum_size = Vector2(560, 0)
	doc_scroll.size_flags_horizontal = Control.SIZE_FILL
	row.add_child(doc_scroll)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override(&"separation", 10)
	row.add_child(right)
	_summary = UITheme.label("", &"DimLabel", 14)
	right.add_child(_summary)
	_table = GridContainer.new()
	_table.columns = 4
	_table.add_theme_constant_override(&"h_separation", 18)
	_table.add_theme_constant_override(&"v_separation", 4)
	right.add_child(RecruitUI.scroll(_table))
	var inspect := PanelContainer.new()
	inspect.custom_minimum_size = Vector2(0, 150)
	inspect.add_theme_stylebox_override(&"panel", UITheme.flat_box(Color(0.02, 0.025, 0.03), Color(1, 1, 1, 0.08), 1, 16))
	var iv := VBoxContainer.new()
	iv.add_theme_constant_override(&"separation", 6)
	inspect.add_child(iv)
	_note_title = UITheme.label("INSPECTION", &"DimLabel", 13, UITheme.WARM)
	iv.add_child(_note_title)
	_note = UITheme.label("Select a field to compare the resume against the document.", &"SerifLabel", 21)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	iv.add_child(_note)
	right.add_child(inspect)
	_refresh_all()


func _refresh_all() -> void:
	for c in _cand_row_holder.get_children():
		_cand_row_holder.remove_child(c)
		c.queue_free()
	_cand_row_holder.add_child(RecruitUI.candidate_tabs(_cid, func(id: String) -> void:
		AudioManager.play_sfx(&"paper", -4.0)
		_cid = id
		Recruitment.set_current(id)
		_note.text = "Select a field to compare the resume against the document."
		_refresh_all(), true))
	for c in _tabs_row.get_children():
		_tabs_row.remove_child(c)
		c.queue_free()
	for t: Array in TABS:
		var b := UITheme.button(t[1])
		b.name = "Tab_%s" % t[0]
		b.toggle_mode = true
		b.button_pressed = t[0] == _tab
		var key: String = t[0]
		b.pressed.connect(func() -> void:
			AudioManager.play_sfx(&"paper", -6.0, 1.2)
			_tab = key
			_refresh_all())
		_tabs_row.add_child(b)
	_build_documents()
	_build_table()


# --- Documents (left) ---------------------------------------------------------

func _build_documents() -> void:
	for c in _docs.get_children():
		_docs.remove_child(c)
		c.queue_free()
	var cand := Recruitment.get_candidate(_cid)
	var keys: Array[String] = []
	if _tab == "identity":
		keys = ["aadhaar", "pan", "passport"]
	else:
		keys = [_tab]
	for key in keys:
		Recruitment.view_document(_cid, key)
		_docs.add_child(_doc_card(key, cand.document(key)))


func _doc_card(key: String, d: Dictionary) -> Control:
	var col: Color = CARD_COLORS.get(key, UITheme.DIM)
	var title_text: String = Candidate.DOC_TITLES.get(key, key)
	var card := PanelContainer.new()
	var missing := d.is_empty()
	card.add_theme_stylebox_override(&"panel", UITheme.flat_box(Color(0.12, 0.13, 0.14) if missing else Color(0.9, 0.88, 0.83), Color(0, 0, 0, 0.5), 1, 0, 6))
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 4)
	card.add_child(v)
	var band := PanelContainer.new()
	band.add_theme_stylebox_override(&"panel", UITheme.flat_box(col if not missing else Color(0.25, 0.25, 0.27), Color.TRANSPARENT, 0, 10))
	band.add_child(UITheme.label(title_text.to_upper() + ("   ·   %s" % d.get("kind", "") if d.has("kind") else ""), &"HeaderLabel", 18, Color(1, 0.97, 0.92)))
	v.add_child(band)
	var m := MarginContainer.new()
	for s in [&"margin_left", &"margin_right"]:
		m.add_theme_constant_override(s, 18)
	m.add_theme_constant_override(&"margin_bottom", 12)
	v.add_child(m)
	var fields := VBoxContainer.new()
	fields.add_theme_constant_override(&"separation", 2)
	m.add_child(fields)
	if missing:
		fields.add_child(UITheme.label("NOT SUBMITTED", &"HeaderLabel", 22, UITheme.ACCENT_SOFT))
		return card
	var order := ["name", "dob", "gender", "address", "number", "issued", "expiry", "issuer", "company", "designation", "joined", "left", "signed_by", "institution", "qualification", "year", "score"]
	for f: String in order:
		if not d.has(f):
			continue
		var line := HBoxContainer.new()
		line.add_theme_constant_override(&"separation", 12)
		var k := UITheme.label(f.replace("_", " ").to_upper(), &"DimLabel", 11, Color(0.35, 0.33, 0.3))
		k.custom_minimum_size = Vector2(120, 0)
		line.add_child(k)
		var val := str(d[f])
		if f in ["joined", "left"]:
			val = DateUtil.format_my(val)
		var vl := UITheme.label(val, &"MonoLabel" if f in ["number", "dob", "expiry"] else &"PaperLabel", 18, UITheme.PAPER_INK)
		vl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(vl)
		fields.add_child(line)
	fields.add_child(UITheme.label("FICTIONAL SPECIMEN · GAME PROP", &"DimLabel", 10, Color(0.6, 0.2, 0.15, 0.6)))
	return card


# --- Comparison table (right) -------------------------------------------------

func _build_table() -> void:
	for c in _table.get_children():
		_table.remove_child(c)
		c.queue_free()
	for h in ["FIELD", "RESUME", "DOCUMENT", "RESULT"]:
		_table.add_child(UITheme.label(h, &"DimLabel", 12))
	var cand := Recruitment.get_candidate(_cid)
	var rows := cand.comparison_rows(_tab, GameState.day)
	var checked := 0
	for row in rows:
		var row_id: String = row["id"]
		var done := not Recruitment.row_result(_cid, row_id).is_empty()
		if done:
			checked += 1
		var field_btn := UITheme.button("%s  ·  %s" % [row["label"], row["doc_title"]], &"FlatButton")
		field_btn.name = "Row_%s" % row_id.replace(".", "_")
		field_btn.custom_minimum_size = Vector2(300, 46)
		field_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		field_btn.add_theme_font_size_override(&"font_size", 16)
		field_btn.pressed.connect(_inspect.bind(row_id))
		_table.add_child(field_btn)
		var rv := UITheme.label(str(row["resume"]), &"", 17)
		rv.custom_minimum_size = Vector2(230, 0)
		rv.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_table.add_child(rv)
		var dv := UITheme.label(str(row["document"]) if done else "· · ·", &"", 17, UITheme.INK if done else UITheme.FAINT)
		dv.custom_minimum_size = Vector2(250, 0)
		dv.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_table.add_child(dv)
		var res := Recruitment.row_result(_cid, row_id)
		_table.add_child(RecruitUI.chip(RecruitUI.result_text(res), RecruitUI.result_color(res)))
	_summary.text = "%s  ·  %s CHECK  ·  %d OF %d FIELDS VERIFIED" % [cand.display_name().to_upper(), _tab.to_upper(), checked, rows.size()]


func _inspect(row_id: String) -> void:
	AudioManager.play_sfx(&"keypress", -4.0)
	var row := Recruitment.verify_row(_cid, row_id)
	if row.is_empty():
		return
	var res: String = row["result"]
	_note_title.text = "INSPECTION  ·  %s  ·  %s" % [str(row["label"]).to_upper(), RecruitUI.result_text(res)]
	_note_title.add_theme_color_override(&"font_color", RecruitUI.result_color(res).lightened(0.1))
	_note.text = "Resume: %s\n%s: %s\n\n%s" % [row["resume"], row["doc_title"], row["document"], row.get("note", "")]
	if res == Candidate.MISMATCH:
		AudioManager.play_sfx(&"stinger", -22.0, 1.6)
	_build_table()


func get_candidate_id() -> String:
	return _cid
