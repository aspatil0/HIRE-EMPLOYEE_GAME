class_name RecruitUI
extends RefCounted
## Shared builders for the Phase 2 recruitment interfaces: verification
## result chips, status labels, candidate tab strips and the evidence log.

# Panel scenes are loaded by path (not preloaded) so panels can link to each
# other without circular preloads.
const RESUME_SCENE := "res://scenes/ui/panels/resume_panel.tscn"
const DECISION_SCENE := "res://scenes/ui/panels/decision_panel.tscn"
const JOURNAL_SCENE := "res://scenes/ui/panels/journal_panel.tscn"
const DOCUMENT_SCENE := "res://scenes/ui/panels/document_panel.tscn"
const CEO_SCENE := "res://scenes/ui/panels/ceo_intervention_panel.tscn"
const REPORT_SCENE := "res://scenes/ui/panels/report_panel.tscn"

const GREEN := Color(0.36, 0.72, 0.45)
const RED := Color(0.86, 0.3, 0.26)
const YELLOW := Color(0.92, 0.74, 0.32)
const GREY := Color(0.45, 0.47, 0.5)

const STATUS_TEXT := {
	"pending": "NOT STARTED", "investigating": "INVESTIGATING", "under_review": "UNDER REVIEW",
	"accepted": "ACCEPTED", "rejected": "REJECTED",
}
const CATEGORY_TEXT := {
	"identity": "IDENTITY", "employment": "EMPLOYMENT", "education": "EDUCATION",
	"reference": "REFERENCE", "conduct": "CONDUCT",
}


static func result_color(result: String) -> Color:
	match result:
		Candidate.MATCH:
			return GREEN
		Candidate.MISMATCH:
			return RED
		Candidate.PARTIAL:
			return YELLOW
	return GREY


static func result_text(result: String) -> String:
	return {"match": "VERIFIED", "mismatch": "CONTRADICTION", "partial": "INVESTIGATE", "missing": "NOT SUBMITTED"}.get(result, "NOT VERIFIED")


static func chip(text: String, col: Color, font_size: int = 13) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := UITheme.flat_box(Color(col, 0.16), Color(col, 0.75), 1, 0, 2)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	p.add_theme_stylebox_override(&"panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := UITheme.label(text, &"DimLabel", font_size, col.lightened(0.15))
	p.add_child(l)
	return p


static func status_color(status: String) -> Color:
	match status:
		"accepted":
			return GREEN
		"rejected":
			return RED
		"investigating", "under_review":
			return YELLOW
	return GREY


static func status_chip(candidate_id: String) -> PanelContainer:
	var s := Recruitment.status(candidate_id)
	return chip(STATUS_TEXT.get(s, s.to_upper()), status_color(s))


## Horizontal strip of candidate buttons ("01 SHAM MATHUR"). Calls on_select(id).
## only_remaining hides candidates who already have a final decision.
static func candidate_tabs(selected_id: String, on_select: Callable, only_remaining: bool = false) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	for c in (Recruitment.remaining() if only_remaining else Recruitment.candidates):
		var b := UITheme.button("%02d  %s" % [c.index, c.display_name().to_upper()], &"FlatButton")
		b.toggle_mode = true
		b.button_pressed = c.id == selected_id
		b.add_theme_font_size_override(&"font_size", 15)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cid := c.id
		b.pressed.connect(func() -> void: on_select.call(cid))
		row.add_child(b)
	return row


## The candidate's evidence log, oldest first. Clue entries carry a category
## tag; contradictions are red (or marked EXPLAINED once resolved).
static func evidence_log(candidate_id: String, font_size: int = 18, newest_first: bool = false) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 6)
	var c := Recruitment.get_candidate(candidate_id)
	var entries: Array = (Recruitment.state(candidate_id)["log"] as Array).duplicate()
	if newest_first:
		entries.reverse()
	if entries.is_empty():
		v.add_child(UITheme.label("No evidence recorded yet.", &"DimLabel", 15))
		return v
	for e: Dictionary in entries:
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 12)
		var t := UITheme.label("[%s]" % e.get("time", ""), &"MonoLabel", font_size - 3, UITheme.DIM)
		t.custom_minimum_size = Vector2(110, 0)
		row.add_child(t)
		var clue_id := str(e.get("clue", ""))
		var col := UITheme.INK
		if not clue_id.is_empty():
			var info := c.clue(clue_id)
			var cat := str(info.get("category", ""))
			var tag := UITheme.label(CATEGORY_TEXT.get(cat, cat.to_upper()), &"DimLabel", 11, UITheme.WARM)
			tag.custom_minimum_size = Vector2(98, 0)
			row.add_child(tag)
			if info.get("contradiction", false):
				col = YELLOW if Recruitment.is_resolved(candidate_id, clue_id) else RED.lightened(0.2)
		else:
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(98, 0)
			row.add_child(spacer)
			col = UITheme.DIM
		var text := str(e.get("text", ""))
		if not clue_id.is_empty() and Recruitment.is_resolved(candidate_id, clue_id):
			text += "   [EXPLAINED]"
		var l := UITheme.label(text, &"", font_size, col)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		v.add_child(row)
	return v


static func scroll(child: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(child)
	return s


static func stat_box(title: String, value: String, col: Color = UITheme.INK) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override(&"panel", UITheme.flat_box(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.08), 1, 14))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 2)
	v.add_child(UITheme.label(title.to_upper(), &"DimLabel", 12))
	v.add_child(UITheme.label(value, &"HeaderLabel", 34, col))
	p.add_child(v)
	return p
