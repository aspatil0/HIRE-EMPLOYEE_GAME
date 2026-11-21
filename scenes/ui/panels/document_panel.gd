extends ModalPanel
## Document tray: each candidate's submitted identity papers (Aadhaar, PAN,
## passport) as cards. Selecting a card shows its details and a manual
## checklist; ticks are stored as GameState flags so the Phase 2 verification
## system can read them ("doc_<candidate>_<doc>_<check>").

const DOCS := [
	{"key": "aadhaar", "title": "AADHAAR", "sub": "UNIQUE IDENTITY NUMBER", "color": Color(0.85, 0.55, 0.25)},
	{"key": "pan", "title": "PAN CARD", "sub": "PERMANENT ACCOUNT NUMBER", "color": Color(0.3, 0.45, 0.65)},
	{"key": "passport", "title": "PASSPORT", "sub": "TRAVEL DOCUMENT", "color": Color(0.5, 0.15, 0.18)},
]
const CHECKS := [
	["name", "Name matches the resume"],
	["dob", "Date of birth matches the resume"],
	["photo", "Photograph matches the applicant"],
	["format", "Number format looks valid"],
]

var _candidates: Array[Dictionary] = []
var _cand_index: int = 0
var _doc_index: int = 0
var _picker: OptionButton
var _cards: HBoxContainer
var _details: VBoxContainer


func _init() -> void:
	title = "DOCUMENT VERIFICATION"
	subtitle = "Identity papers received with applications"
	panel_size = Vector2(1500, 880)
	accent = Color(0.85, 0.6, 0.3)


func _build_content(body: VBoxContainer) -> void:
	_candidates = DataLoader.candidates(GameState.day)
	var top := HBoxContainer.new()
	top.add_theme_constant_override(&"separation", 18)
	body.add_child(top)
	top.add_child(UITheme.label("APPLICANT", &"DimLabel", 15))
	_picker = OptionButton.new()
	_picker.custom_minimum_size = Vector2(420, 50)
	_picker.focus_mode = Control.FOCUS_NONE
	_picker.add_theme_font_size_override(&"font_size", 20)
	for c in _candidates:
		_picker.add_item("%s  ·  %s" % [c.get("name", ""), c.get("position", "")])
	_picker.item_selected.connect(func(i: int) -> void:
		AudioManager.play_sfx(&"paper", -4.0)
		_cand_index = i
		_doc_index = 0
		_refresh())
	top.add_child(_picker)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var status := UITheme.label("ALL DOCUMENTS  ·  UNVERIFIED", &"DimLabel", 15, UITheme.ACCENT_SOFT)
	status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(status)

	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override(&"separation", 26)
	_cards.custom_minimum_size = Vector2(0, 290)
	body.add_child(_cards)
	body.add_child(ModalPanel.hsep())
	_details = VBoxContainer.new()
	_details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_details.add_theme_constant_override(&"separation", 10)
	body.add_child(_details)
	if _candidates.is_empty():
		_details.add_child(UITheme.label("The tray is empty.", &"SerifLabel"))
		return
	_refresh()


func _refresh() -> void:
	for c in _cards.get_children():
		c.queue_free()
	for c in _details.get_children():
		c.queue_free()
	var cand := _candidates[_cand_index]
	var docs: Dictionary = cand.get("documents", {})
	for i in DOCS.size():
		_cards.add_child(_make_card(i, DOCS[i], docs.get(DOCS[i]["key"]), cand))
	_build_details(cand, DOCS[_doc_index], docs.get(DOCS[_doc_index]["key"]))


func _make_card(i: int, doc: Dictionary, number: Variant, cand: Dictionary) -> Control:
	var selected := i == _doc_index
	var missing := number == null
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.custom_minimum_size = Vector2(440, 280)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col: Color = doc["color"]
	var card_bg := Color(0.9, 0.88, 0.83) if not missing else Color(0.12, 0.13, 0.14)
	var border := UITheme.WARM if selected else Color(0, 0, 0, 0.4)
	for state in [&"normal", &"hover", &"pressed", &"hover_pressed"]:
		var sb := UITheme.flat_box(card_bg.lightened(0.04) if state == &"hover" else card_bg, border, 3 if selected else 1, 0, 10)
		btn.add_theme_stylebox_override(state, sb)
	btn.pressed.connect(func() -> void:
		AudioManager.play_sfx(&"paper", -4.0, 1.2)
		_doc_index = i
		_refresh())

	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override(&"separation", 8)
	btn.add_child(v)
	var band := ColorRect.new()
	band.color = col if not missing else Color(0.25, 0.25, 0.27)
	band.custom_minimum_size = Vector2(0, 44)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(band)
	var head := UITheme.label("  %s" % doc["title"], &"HeaderLabel", 22, Color(1, 0.97, 0.92))
	head.set_anchors_preset(Control.PRESET_FULL_RECT)
	head.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	band.add_child(head)
	if missing:
		var none := UITheme.label("NOT SUBMITTED", &"HeaderLabel", 26, UITheme.ACCENT_SOFT)
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none.size_flags_vertical = Control.SIZE_EXPAND_FILL
		none.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		v.add_child(none)
		return btn
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 18)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override(&"margin_left", 18)
	margin.add_theme_constant_override(&"margin_right", 18)
	margin.add_child(row)
	v.add_child(margin)
	var photo := ColorRect.new()
	photo.color = Color(0.5, 0.5, 0.52)
	photo.custom_minimum_size = Vector2(96, 120)
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(photo)
	var info := VBoxContainer.new()
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_theme_constant_override(&"separation", 2)
	row.add_child(info)
	info.add_child(UITheme.label(str(doc["sub"]), &"DimLabel", 11, Color(0.35, 0.33, 0.3)))
	info.add_child(UITheme.label(str(cand.get("name", "")).to_upper(), &"PaperLabel", 20))
	info.add_child(UITheme.label("DOB  %s" % cand.get("dob", "—"), &"MonoLabel", 15, UITheme.PAPER_INK))
	info.add_child(UITheme.label(str(number), &"MonoLabel", 24, UITheme.PAPER_INK))
	var spec := UITheme.label("SPECIMEN · GAME PROP", &"DimLabel", 11, Color(0.6, 0.2, 0.15, 0.6))
	spec.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(spec)
	return btn


func _build_details(cand: Dictionary, doc: Dictionary, number: Variant) -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 20)
	_details.add_child(head)
	head.add_child(UITheme.label("%s  ·  %s" % [doc["title"], cand.get("name", "")], &"SerifLabel", 26))
	if number == null:
		_details.add_child(UITheme.label("This document was not included with the application.", &"", 20, UITheme.DIM))
		return
	_details.add_child(UITheme.label("Manual checklist. Tick what you have confirmed.", &"DimLabel", 14))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 60)
	_details.add_child(grid)
	for check: Array in CHECKS:
		var key := StringName("doc_%s_%s_%s" % [cand.get("id", ""), doc["key"], check[0]])
		var cb := CheckBox.new()
		cb.text = check[1]
		cb.focus_mode = Control.FOCUS_NONE
		cb.add_theme_font_size_override(&"font_size", 19)
		cb.button_pressed = GameState.is_flag_set(key)
		cb.toggled.connect(func(on: bool) -> void:
			AudioManager.play_sfx(&"keypress", -6.0)
			GameState.set_flag(key, on))
		grid.add_child(cb)
