class_name Candidate
extends RefCounted
## Read-only model of one applicant, built from data/candidates/candidate_XX.json.
##
## Holds the resume, submitted documents, clues, search results and the hidden
## truth, and computes resume-vs-document comparisons. It never stores player
## progress: investigation state lives in GameState.recruitment and is managed
## by the Recruitment autoload.

const MATCH := "match"
const MISMATCH := "mismatch"
const PARTIAL := "partial"
const MISSING := "missing"

const TAB_IDENTITY := "identity"
const TAB_EMPLOYMENT := "employment"
const TAB_EDUCATION := "education"
const IDENTITY_DOCS: Array[String] = ["aadhaar", "pan", "passport"]
const DOC_TITLES := {
	"aadhaar": "Aadhaar-style ID", "pan": "PAN-style card", "passport": "Passport",
	"employment": "Employment record", "education": "Education certificate",
}

var id: String
var index: int
var data: Dictionary


func _init(source: Dictionary) -> void:
	data = source
	id = str(source.get("id", ""))
	index = int(source.get("index", 0))


# --- Accessors ----------------------------------------------------------------

func resume() -> Dictionary:
	return data.get("resume", {})


func display_name() -> String:
	return str(resume().get("name", id))


func position() -> String:
	return str(resume().get("position", ""))


func education() -> Dictionary:
	return resume().get("education", {})


func experience() -> Array:
	return resume().get("experience", [])


func latest_job() -> Dictionary:
	var exp := experience()
	return exp[0] if not exp.is_empty() else {}


func references() -> Array:
	return resume().get("references", [])


## Submitted document by key, or {} if it was not submitted.
func document(key: String) -> Dictionary:
	var d: Variant = data.get("documents", {}).get(key)
	return d if d is Dictionary else {}


func has_document(key: String) -> bool:
	return not document(key).is_empty()


func clues() -> Dictionary:
	return data.get("clues", {})


func clue(clue_id: String) -> Dictionary:
	return clues().get(clue_id, {})


func search_results() -> Array:
	return data.get("search", [])


func truth() -> Dictionary:
	return data.get("truth", {})


func row_note(row_id: String) -> Dictionary:
	return data.get("row_notes", {}).get(row_id, {})


func resume_clue_ids() -> Array[String]:
	var out: Array[String] = []
	for cid: String in clues():
		if str(clues()[cid].get("source", "")) == "resume":
			out.append(cid)
	return out


func claimed_age() -> int:
	return int(resume().get("claimed_age", -1))


## Age calculated from the ID card's date of birth on the given story day.
func document_age(story_day: int = 1) -> int:
	var dob_text := str(document("aadhaar").get("dob", resume().get("dob", "")))
	return DateUtil.age_on(DateUtil.parse_dmy(dob_text), DateUtil.game_date(story_day))


# --- Comparisons --------------------------------------------------------------

## Comparison rows for a verification tab. Each row:
## {id, label, doc, doc_title, resume, document, result, detail}
func comparison_rows(tab: String, story_day: int = 1) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var r := resume()
	match tab:
		TAB_IDENTITY:
			for key in IDENTITY_DOCS:
				var d := document(key)
				if d.is_empty():
					continue
				rows.append(_row("%s.name" % key, "Name", key, r.get("name", ""), d.get("name", ""), _cmp_name(r.get("name", ""), d.get("name", ""))))
				rows.append(_row("%s.dob" % key, "Date of birth", key, r.get("dob", ""), d.get("dob", ""), _cmp_exact(r.get("dob", ""), d.get("dob", ""))))
				if d.has("city"):
					rows.append(_row("%s.address" % key, "Address", key, "%s, %s" % [r.get("address", ""), r.get("city", "")], d.get("address", ""), _cmp_city(r.get("city", ""), d.get("city", ""))))
				if d.has("expiry"):
					var exp_date := DateUtil.parse_dmy(str(d.get("expiry", "")))
					var expired := not exp_date.is_empty() and DateUtil.is_before(exp_date, DateUtil.game_date(story_day))
					var row := _row("%s.expiry" % key, "Validity", key, "Valid document expected", "Expires %s" % d.get("expiry", ""), PARTIAL if expired else MATCH)
					row["detail"] = "Expired" if expired else "Valid"
					rows.append(row)
				if key == "aadhaar":
					# Age is checked right after the ID card it is calculated from.
					var calc := document_age(story_day)
					rows.append(_row("age", "Age (claimed vs. calculated)", "aadhaar", str(claimed_age()), "%d (from DOB %s)" % [calc, d.get("dob", "")], MATCH if calc == claimed_age() else MISMATCH))
		TAB_EMPLOYMENT:
			var job := latest_job()
			var d := document("employment")
			var fields := [["company", "Employer"], ["designation", "Designation"], ["joined", "Joining date"], ["left", "Leaving date"]]
			for f: Array in fields:
				var rv := str(job.get(f[0], ""))
				if d.is_empty():
					rows.append(_row("employment.%s" % f[0], f[1], "employment", rv, "Not submitted", MISSING))
					continue
				var dv := str(d.get(f[0], ""))
				var res := _cmp_exact(rv, dv) if f[0] in ["joined", "left"] else _cmp_text(rv, dv)
				if f[0] in ["joined", "left"]:
					rv = DateUtil.format_my(rv)
					dv = DateUtil.format_my(dv)
				rows.append(_row("employment.%s" % f[0], f[1], "employment", rv, dv, res))
		TAB_EDUCATION:
			var e := education()
			var d := document("education")
			var fields := [["institution", "Institution"], ["qualification", "Qualification"], ["year", "Graduation year"], ["score", "Marks / CGPA"]]
			for f: Array in fields:
				var rv := str(e.get(f[0], ""))
				if d.is_empty():
					rows.append(_row("education.%s" % f[0], f[1], "education", rv, "Not submitted", MISSING))
					continue
				var dv := str(d.get(f[0], ""))
				var res := _cmp_exact(rv, dv) if f[0] in ["year", "score"] else _cmp_text(rv, dv)
				rows.append(_row("education.%s" % f[0], f[1], "education", rv, dv, res))
	return rows


func all_row_ids(story_day: int = 1) -> Array[String]:
	var ids: Array[String] = []
	for tab in [TAB_IDENTITY, TAB_EMPLOYMENT, TAB_EDUCATION]:
		for row in comparison_rows(tab, story_day):
			ids.append(str(row["id"]))
	return ids


func find_row(row_id: String, story_day: int = 1) -> Dictionary:
	for tab in [TAB_IDENTITY, TAB_EMPLOYMENT, TAB_EDUCATION]:
		for row in comparison_rows(tab, story_day):
			if row["id"] == row_id:
				return row
	return {}


func _row(row_id: String, label: String, doc_key: String, resume_value: Variant, doc_value: Variant, result: String) -> Dictionary:
	return {
		"id": row_id, "label": label, "doc": doc_key, "doc_title": DOC_TITLES.get(doc_key, doc_key),
		"resume": str(resume_value), "document": str(doc_value), "result": result, "detail": "",
	}


static func normalize(s: String) -> String:
	var out := ""
	for ch in s.to_lower():
		if ch.is_valid_identifier() or ch.is_valid_int():
			out += ch
	return out


static func _cmp_exact(a: Variant, b: Variant) -> String:
	return MATCH if normalize(str(a)) == normalize(str(b)) else MISMATCH


static func _cmp_city(a: Variant, b: Variant) -> String:
	return MATCH if normalize(str(a)) == normalize(str(b)) else MISMATCH


## Names: exact -> match; initials or a small spelling difference -> partial.
static func _cmp_name(a: Variant, b: Variant) -> String:
	var na := normalize(str(a))
	var nb := normalize(str(b))
	if na == nb:
		return MATCH
	var wa := str(a).to_lower().replace(".", "").split(" ", false)
	var wb := str(b).to_lower().replace(".", "").split(" ", false)
	if not wa.is_empty() and not wb.is_empty() and wa[0] == wb[0] and wa[wa.size() - 1] == wb[wb.size() - 1]:
		return PARTIAL # same first and last name, extra/missing middle name or initial
	if levenshtein(na, nb) <= 2:
		return PARTIAL
	return MISMATCH


static func _cmp_text(a: Variant, b: Variant) -> String:
	var na := normalize(str(a))
	var nb := normalize(str(b))
	if na == nb:
		return MATCH
	if na.is_empty() or nb.is_empty():
		return MISMATCH
	return PARTIAL if na.contains(nb) or nb.contains(na) else MISMATCH


static func levenshtein(a: String, b: String) -> int:
	var prev := PackedInt32Array()
	prev.resize(b.length() + 1)
	for j in b.length() + 1:
		prev[j] = j
	for i in range(1, a.length() + 1):
		var cur := PackedInt32Array()
		cur.resize(b.length() + 1)
		cur[0] = i
		for j in range(1, b.length() + 1):
			var cost := 0 if a[i - 1] == b[j - 1] else 1
			cur[j] = mini(mini(prev[j] + 1, cur[j - 1] + 1), prev[j - 1] + cost)
		prev = cur
	return prev[b.length()]
