extends Node
## Phase 2 recruitment logic: evidence discovery, document verification,
## reference calls, research, hiring decisions, CEO interventions and the
## final report.
##
## Stateless itself: everything the player does is written to
## GameState.recruitment so it saves/loads with the existing save system.
## Static content comes from:
##   data/candidates/candidate_XX.json      (Candidate model)
##   data/dialogue/phase_2_references.json  (phone contacts)
##   data/dialogue/phase_2_ceo.json         (CEO interventions)
##   data/dialogue/phase_2_candidates.json  (decision responses, endings)

signal evidence_added(candidate_id: String, entry: Dictionary)
signal candidate_changed(candidate_id: String)
signal decision_made(candidate_id: String, action: String)
signal intervention_requested(candidate_id: String, kind: String)
signal recruitment_completed
## An email from the unknown sender has just arrived.
signal email_arrived(email: Dictionary)

const CANDIDATE_COUNT := 6
const CANDIDATE_PATH := "res://data/candidates/candidate_%02d.json"
const REFERENCES_PATH := "res://data/dialogue/phase_2_references.json"
const CEO_PATH := "res://data/dialogue/phase_2_ceo.json"
const NARRATIVE_PATH := "res://data/dialogue/phase_2_candidates.json"
const CALL_MINUTES := 4
const SEARCH_MINUTES := 1
const DECIDED := ["accepted", "rejected"]
## Every wrong decision (accepting a bad candidate / rejecting a good one) is a
## strike. Strikes 1 and 2: Aditya walks in with a warning and Alice may review.
## Strike 3: Alice is summoned to the CEO's office and fired (game over).
const MAX_WARNINGS := 2

var candidates: Array[Candidate] = []
var contacts: Dictionary = {}
var ceo: Dictionary = {}
var narrative: Dictionary = {}

var _by_id: Dictionary[String, Candidate] = {}
var _active_call: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(1, CANDIDATE_COUNT + 1):
		var data := DataLoader.load_json(CANDIDATE_PATH % i)
		if data.is_empty():
			continue
		var c := Candidate.new(data)
		candidates.append(c)
		_by_id[c.id] = c
	contacts = DataLoader.load_json(REFERENCES_PATH).get("contacts", {})
	ceo = DataLoader.load_json(CEO_PATH)
	narrative = DataLoader.load_json(NARRATIVE_PATH)
	GameState.state_reset.connect(func() -> void: _active_call = {})


func get_candidate(candidate_id: String) -> Candidate:
	return _by_id.get(candidate_id)


# --- State --------------------------------------------------------------------

func root() -> Dictionary:
	var r := GameState.recruitment
	if r.is_empty():
		r["version"] = 1
		r["candidates"] = {}
		r["ceo_tokens"] = 1
		r["ceo_history"] = []
		r["current"] = candidates[0].id if not candidates.is_empty() else ""
		r["calls"] = {}
		r["emails_read"] = []
		r["completed"] = false
		r["effects_applied"] = false
	if not r.has("strikes"):
		# Older saves: every past CEO visit was a mistake.
		var past: Array = []
		for h: Dictionary in r.get("ceo_history", []):
			past.append({"candidate": h.get("candidate", ""), "action": "reject" if h.get("kind", "") == "reject_good" else "accept", "time": h.get("time", ""), "kind": h.get("kind", "")})
		r["strikes"] = past.size()
		r["mistakes"] = past
		r["fired"] = false
	if not r.has("anon"):
		r["anon"] = {"arrived": {}, "replies": {}, "shared": false, "shared_names": []}
	return r


func state(candidate_id: String) -> Dictionary:
	var all: Dictionary = root()["candidates"]
	if not all.has(candidate_id):
		all[candidate_id] = {
			"status": "pending", "resume_viewed": false, "clues": [], "log": [], "rows": {},
			"docs_viewed": [], "results_opened": [], "notes": "", "flagged": false, "follow_up": false,
			"decision": {}, "history": [], "mistake_kept": false,
		}
	return all[candidate_id]


func status(candidate_id: String) -> String:
	return str(state(candidate_id)["status"])


func is_decided(candidate_id: String) -> bool:
	return status(candidate_id) in DECIDED


## Candidates still waiting for a decision, in file order.
func remaining() -> Array[Candidate]:
	var out: Array[Candidate] = []
	for c in candidates:
		if not is_decided(c.id):
			out.append(c)
	return out


func current_id() -> String:
	return str(root().get("current", ""))


func set_current(candidate_id: String) -> void:
	if _by_id.has(candidate_id):
		root()["current"] = candidate_id


func _now() -> String:
	return DateUtil.clock_12h(GameState.time_minutes)


# --- Evidence log -------------------------------------------------------------

func log_event(candidate_id: String, text: String, clue_id: String = "") -> Dictionary:
	var entry := {"time": _now(), "minutes": GameState.time_minutes, "text": text, "clue": clue_id}
	(state(candidate_id)["log"] as Array).append(entry)
	if status(candidate_id) == "pending":
		state(candidate_id)["status"] = "investigating"
	evidence_added.emit(candidate_id, entry)
	candidate_changed.emit(candidate_id)
	return entry


func has_clue(candidate_id: String, clue_id: String) -> bool:
	return (state(candidate_id)["clues"] as Array).has(clue_id)


## Records a clue (once). Returns true if it was new.
func discover(candidate_id: String, clue_id: String) -> bool:
	var c := get_candidate(candidate_id)
	if c == null or clue_id.is_empty() or c.clue(clue_id).is_empty() or has_clue(candidate_id, clue_id):
		return false
	(state(candidate_id)["clues"] as Array).append(clue_id)
	GameState.discover_clue(StringName(clue_id))
	log_event(candidate_id, str(c.clue(clue_id).get("text", clue_id)), clue_id)
	return true


func discovered_clues(candidate_id: String) -> Array:
	return state(candidate_id)["clues"]


## Discovered contradictions that nothing discovered so far explains.
func open_contradictions(candidate_id: String) -> Array[String]:
	var c := get_candidate(candidate_id)
	var out: Array[String] = []
	for cl: String in discovered_clues(candidate_id):
		var info := c.clue(cl)
		if not info.get("contradiction", false):
			continue
		var resolver := str(info.get("resolved_by", ""))
		if resolver.is_empty() or not has_clue(candidate_id, resolver):
			out.append(cl)
	return out


func is_resolved(candidate_id: String, clue_id: String) -> bool:
	var resolver := str(get_candidate(candidate_id).clue(clue_id).get("resolved_by", ""))
	return not resolver.is_empty() and has_clue(candidate_id, resolver)


func progress(candidate_id: String) -> float:
	var c := get_candidate(candidate_id)
	var total := c.clues().size()
	return float(discovered_clues(candidate_id).size()) / float(maxi(total, 1))


# --- Resume -------------------------------------------------------------------

func view_resume(candidate_id: String) -> void:
	set_current(candidate_id)
	var st := state(candidate_id)
	if st["resume_viewed"]:
		return
	st["resume_viewed"] = true
	log_event(candidate_id, "Resume reviewed.")
	for cl in get_candidate(candidate_id).resume_clue_ids():
		discover(candidate_id, cl)


func set_notes(candidate_id: String, text: String) -> void:
	state(candidate_id)["notes"] = text


func set_flagged(candidate_id: String, on: bool) -> void:
	state(candidate_id)["flagged"] = on
	log_event(candidate_id, "Candidate flagged." if on else "Flag removed.")


func set_follow_up(candidate_id: String, on: bool) -> void:
	state(candidate_id)["follow_up"] = on
	log_event(candidate_id, "Marked for follow-up." if on else "Follow-up cleared.")


# --- Documents ----------------------------------------------------------------

func view_document(candidate_id: String, doc_key: String) -> void:
	var viewed: Array = state(candidate_id)["docs_viewed"]
	if viewed.has(doc_key):
		return
	viewed.append(doc_key)
	var title: String = Candidate.DOC_TITLES.get(doc_key, doc_key)
	if get_candidate(candidate_id).has_document(doc_key):
		log_event(candidate_id, "Examined %s." % title)
	else:
		log_event(candidate_id, "%s: not submitted." % title)


func row_result(candidate_id: String, row_id: String) -> String:
	return str(state(candidate_id)["rows"].get(row_id, ""))


## Verifies one comparison row: stores the result, logs it, and discovers any
## clue attached to that row. Returns the row dictionary (with "note").
func verify_row(candidate_id: String, row_id: String) -> Dictionary:
	var c := get_candidate(candidate_id)
	var row := c.find_row(row_id, GameState.day)
	if row.is_empty():
		return {}
	var rows: Dictionary = state(candidate_id)["rows"]
	var note_info := c.row_note(row_id)
	row["note"] = str(note_info.get("note", _default_note(row)))
	if not rows.has(row_id):
		rows[row_id] = row["result"]
		log_event(candidate_id, "Verified %s against %s: %s." % [str(row["label"]).to_lower(), row["doc_title"], _result_word(row["result"])])
		discover(candidate_id, str(note_info.get("clue", "")))
	return row


func _default_note(row: Dictionary) -> String:
	match str(row["result"]):
		Candidate.MATCH:
			return "The resume and the %s agree." % str(row["doc_title"]).to_lower()
		Candidate.PARTIAL:
			return "Close, but not identical. Worth a second look."
		Candidate.MISSING:
			return "No document was submitted to verify this against."
	return "The resume and the document disagree."


static func _result_word(result: String) -> String:
	return {"match": "MATCH", "mismatch": "MISMATCH", "partial": "NEEDS REVIEW", "missing": "NOT SUBMITTED"}.get(result, "?")


## Documents whose every comparison row has been verified.
func verified_documents(candidate_id: String) -> Array[String]:
	var c := get_candidate(candidate_id)
	var rows: Dictionary = state(candidate_id)["rows"]
	var per_doc: Dictionary = {}
	for row_id in c.all_row_ids(GameState.day):
		var row := c.find_row(row_id, GameState.day)
		var doc: String = row["doc"]
		if not c.has_document(doc):
			continue
		if not per_doc.has(doc):
			per_doc[doc] = true
		if not rows.has(row_id):
			per_doc[doc] = false
	var out: Array[String] = []
	for doc: String in per_doc:
		if per_doc[doc]:
			out.append(doc)
	return out


func submitted_documents(candidate_id: String) -> Array[String]:
	var c := get_candidate(candidate_id)
	var out: Array[String] = []
	for key in ["aadhaar", "pan", "passport", "employment", "education"]:
		if c.has_document(key):
			out.append(key)
	return out


# --- Research (side computer) -------------------------------------------------

## Results for a query: [{candidate_id, result}] — local data only.
func search(query: String) -> Array[Dictionary]:
	var q := query.strip_edges().to_lower()
	var out: Array[Dictionary] = []
	if q.length() < 2:
		return out
	for c in candidates:
		for r: Dictionary in c.search_results():
			for term: String in r.get("terms", []):
				if q.contains(term) or (q.length() >= 4 and term.contains(q)):
					out.append({"candidate_id": c.id, "result": r})
					break
	GameState.advance_time(SEARCH_MINUTES)
	return out


func open_result(candidate_id: String, result: Dictionary) -> void:
	var opened: Array = state(candidate_id)["results_opened"]
	if opened.has(result.get("id", "")):
		return
	opened.append(result.get("id", ""))
	log_event(candidate_id, "Researched online: \"%s\" (%s)." % [result.get("title", ""), result.get("source", "")])
	discover(candidate_id, str(result.get("clue", "")))


# --- Telephone ----------------------------------------------------------------

func contact(contact_id: String) -> Dictionary:
	return contacts.get(contact_id, {})


func calls_made(contact_id: String) -> int:
	return int(root()["calls"].get(contact_id, 0))


func calls_left(contact_id: String) -> int:
	return maxi(int(contact(contact_id).get("max_calls", 1)) - calls_made(contact_id), 0)


func find_contact_by_number(number: String) -> String:
	var digits := _digits(number)
	if digits.is_empty():
		return ""
	for cid: String in contacts:
		var n := _digits(str(contacts[cid].get("number", "")))
		# Exact match, or the same subscriber number written with/without a
		# country or area prefix (+91 20 4113 1313 == 020 4113 1313).
		if n == digits or (mini(n.length(), digits.length()) >= 8 and n.right(8) == digits.right(8)):
			return cid
	return ""


static func _digits(s: String) -> String:
	var out := ""
	for ch in s:
		if ch.is_valid_int():
			out += ch
	return out


## Starts a call. Returns {ok, reason, contact}. Consumes one of the contact's calls.
func start_call(contact_id: String) -> Dictionary:
	var info := contact(contact_id)
	if info.is_empty():
		return {"ok": false, "reason": "unknown"}
	if calls_left(contact_id) <= 0:
		return {"ok": false, "reason": "no_calls_left", "contact": info}
	root()["calls"][contact_id] = calls_made(contact_id) + 1
	GameState.advance_time(CALL_MINUTES)
	var cand := str(info.get("candidate", ""))
	var availability := str(info.get("availability", "answers"))
	if not cand.is_empty():
		log_event(cand, "Telephoned %s — %s." % [info.get("name", ""), "answered" if availability == "answers" else ("automated line" if availability == "automated" else "no answer")])
		discover(cand, str(info.get("clue", "")))
	_active_call = {"contact": contact_id, "asked": []} if availability == "answers" else {}
	return {"ok": true, "reason": availability, "contact": info}


func questions_left() -> int:
	if _active_call.is_empty():
		return 0
	var max_q := int(contact(_active_call["contact"]).get("max_questions", 2))
	return maxi(max_q - (_active_call["asked"] as Array).size(), 0)


func active_call_id() -> String:
	return str(_active_call.get("contact", ""))


## Asks a question on the active call. Returns the response text ("" if not allowed).
func ask(question_id: String) -> String:
	if _active_call.is_empty() or questions_left() <= 0:
		return ""
	var info := contact(_active_call["contact"])
	for q: Dictionary in info.get("questions", []):
		if q.get("id", "") == question_id and not (_active_call["asked"] as Array).has(question_id):
			(_active_call["asked"] as Array).append(question_id)
			var cand := str(info.get("candidate", ""))
			if not cand.is_empty():
				log_event(cand, "Asked %s: \"%s\"" % [info.get("name", ""), q.get("text", "")])
				discover(cand, str(q.get("clue", "")))
			return str(q.get("response", ""))
	return ""


func end_call() -> void:
	_active_call = {}


# --- Email (main computer) ----------------------------------------------------

func visible_emails(company: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var arrived: Dictionary = root()["anon"]["arrived"]
	var anon: Array = company.get("anon_emails", []).duplicate()
	anon.reverse()
	for m: Dictionary in anon:
		if arrived.has(m.get("id", "")):
			var copy := m.duplicate()
			copy["time"] = arrived[m["id"]]
			out.append(copy)
	for m: Dictionary in company.get("inbox", []):
		var req := str(m.get("requires", ""))
		if not req.is_empty():
			var email_owner := str(m.get("candidate", ""))
			if email_owner.is_empty() or not has_clue(email_owner, req):
				continue
		out.append(m)
	return out


func read_email(email: Dictionary) -> void:
	var read: Array = root()["emails_read"]
	var eid := str(email.get("id", ""))
	if read.has(eid):
		return
	read.append(eid)
	var cand := str(email.get("candidate", ""))
	if not cand.is_empty():
		log_event(cand, "Read email: \"%s\"." % email.get("subject", ""))
		discover(cand, str(email.get("clue", "")))
	for pair: Array in email.get("clues", []):
		discover(str(pair[0]), str(pair[1]))


# --- The unknown sender --------------------------------------------------------

func decided_count() -> int:
	var n := 0
	for c in candidates:
		if is_decided(c.id):
			n += 1
	return n


## Delivers anonymous emails whose decision threshold has been reached (once each).
func _check_anon_emails() -> void:
	var arrived: Dictionary = root()["anon"]["arrived"]
	for m: Dictionary in DataLoader.company(GameState.day).get("anon_emails", []):
		var eid := str(m.get("id", ""))
		if arrived.has(eid) or decided_count() < int(m.get("after_decisions", 99)):
			continue
		arrived[eid] = GameState.get_time_string()
		var copy := m.duplicate()
		copy["time"] = arrived[eid]
		email_arrived.emit(copy)


func reply_of(email_id: String) -> String:
	return str(root()["anon"]["replies"].get(email_id, ""))


## Alice answers the unknown sender. A reply with action "share" sends the
## names of everyone she has accepted so far. Returns the text Alice sent.
func reply_email(email: Dictionary, reply_id: String) -> String:
	var eid := str(email.get("id", ""))
	if not reply_of(eid).is_empty():
		return ""
	for r: Dictionary in email.get("replies", []):
		if r.get("id", "") != reply_id:
			continue
		root()["anon"]["replies"][eid] = reply_id
		if r.get("action", "") == "share":
			var names: Array = []
			for c in candidates:
				if status(c.id) == "accepted":
					names.append(c.display_name())
			root()["anon"]["shared"] = true
			root()["anon"]["shared_names"] = names
			return "Hired so far: %s." % (", ".join(PackedStringArray(names)) if not names.is_empty() else "nobody yet")
		if r.get("action", "") == "ignore":
			return ""
		return str(r.get("text", ""))
	return ""


func shared_names() -> bool:
	return bool(root()["anon"].get("shared", false))


## True when every scored candidate got the right decision (Ira never counts).
func is_perfect() -> bool:
	if not is_complete():
		return false
	for c in candidates:
		var want := str(c.truth().get("correct_decision", ""))
		if not want.is_empty() and status(c.id) != ("accepted" if want == "accept" else "rejected"):
			return false
	return true


func is_email_read(email_id: String) -> bool:
	return (root()["emails_read"] as Array).has(email_id)


# --- Decisions ----------------------------------------------------------------

## action: "accept" | "reject" | "investigate". Returns {"intervention": kind or ""}.
func decide(candidate_id: String, action: String, reason: String = "") -> Dictionary:
	var c := get_candidate(candidate_id)
	var st := state(candidate_id)
	var entry := {"action": action, "reason": reason, "time": _now(), "minutes": GameState.time_minutes,
		"clues": discovered_clues(candidate_id).size(), "open_contradictions": open_contradictions(candidate_id).size()}
	(st["history"] as Array).append(entry)
	if action == "investigate":
		st["status"] = "investigating"
		log_event(candidate_id, "Decision deferred: investigate further.%s" % (" Reason: %s" % reason if not reason.is_empty() else ""))
		decision_made.emit(candidate_id, action)
		return {"intervention": ""}
	st["status"] = "accepted" if action == "accept" else "rejected"
	st["decision"] = entry
	log_event(candidate_id, "DECISION: %s.%s" % [st["status"].to_upper(), (" Reason: %s" % reason if not reason.is_empty() else "")])
	refresh_stats()
	var kind := _register_mistake(c, action)
	decision_made.emit(candidate_id, action)
	_check_anon_emails()
	if not kind.is_empty():
		intervention_requested.emit(candidate_id, kind)
	else:
		_check_complete()
	return {"intervention": kind}


func response_text(candidate_id: String, action: String) -> String:
	return str(narrative.get("responses", {}).get(candidate_id, {}).get(action, ""))


func strikes() -> int:
	return int(root().get("strikes", 0))


func mistakes() -> Array:
	return root().get("mistakes", [])


## Warnings Aditya will still give before firing Alice.
func warnings_left() -> int:
	return maxi(MAX_WARNINGS - strikes(), 0)


## Kept for older callers: same as warnings_left().
func ceo_tokens(_kind: String = "") -> int:
	return warnings_left()


func is_fired() -> bool:
	return bool(root().get("fired", false))


## "reject_good" / "accept_dangerous" if this decision is wrong, else "".
## Candidates without a correct answer (Ira Mehra) never count.
func mistake_kind(c: Candidate, action: String) -> String:
	var want := str(c.truth().get("correct_decision", ""))
	if want.is_empty() or action == want or not action in ["accept", "reject"]:
		return ""
	return "reject_good" if action == "reject" else "accept_dangerous"


## Records a strike for a wrong decision and queues Aditya's response:
## a warning (strikes 1-2) or the firing (strike 3). Returns the kind queued.
func _register_mistake(c: Candidate, action: String) -> String:
	var kind := mistake_kind(c, action)
	if kind.is_empty():
		return ""
	var st := state(c.id)
	st["mistake_counted"] = true
	root()["strikes"] = strikes() + 1
	(root()["mistakes"] as Array).append({"candidate": c.id, "action": action, "time": _now(), "kind": kind})
	if strikes() > MAX_WARNINGS:
		root()["fired"] = true
		root()["pending_intervention"] = {"candidate": c.id, "kind": "fired", "warned": false}
		GameState.stats_changed.emit()
		return "fired"
	var warned := _was_warned(c)
	root()["ceo_tokens"] = warnings_left()
	root()["pending_intervention"] = {"candidate": c.id, "kind": kind, "warned": warned, "final": strikes() == MAX_WARNINGS}
	(root()["ceo_history"] as Array).append({"candidate": c.id, "kind": kind, "time": _now(), "choice": "pending", "warned": warned, "strike": strikes()})
	GameState.stats_changed.emit()
	return kind


## Catches up a wrong decision that never got its strike (e.g. made under an
## older rule). Returns true if Aditya now has something to say.
func ensure_interventions() -> bool:
	if not pending_intervention().is_empty():
		return true
	var counted: Dictionary = {}
	for m: Dictionary in mistakes():
		counted[str(m.get("candidate", ""))] = str(m.get("action", ""))
	for c in candidates:
		if not is_decided(c.id) or state(c.id).get("mistake_counted", false):
			continue
		var action := "accept" if status(c.id) == "accepted" else "reject"
		if counted.get(c.id, "") == action:
			continue
		var kind := _register_mistake(c, action)
		if not kind.is_empty():
			intervention_requested.emit(c.id, kind)
			return true
	return false


func pending_intervention() -> Dictionary:
	return root().get("pending_intervention", {})


## True if Alice had already found at least one key warning clue.
func _was_warned(c: Candidate) -> bool:
	for k: String in c.truth().get("key_clues", []):
		if has_clue(c.id, k):
			return true
	return false


## CEO dialogue for the pending intervention: {headline, lines, review_label, keep_label}.
func intervention_script() -> Dictionary:
	var p := pending_intervention()
	if p.is_empty() or p["kind"] == "fired":
		return {}
	var cfg: Dictionary = ceo.get("interventions", {}).get(p["kind"], {})
	var lines: Array = cfg.get("lines_if_warned", cfg.get("lines", [])) if p.get("warned", false) and cfg.has("lines_if_warned") else cfg.get("lines", [])
	var headline := str(cfg.get("headline", "ALICE."))
	if p.get("final", false):
		lines = cfg.get("final_lines", lines)
		headline = str(cfg.get("final_headline", headline))
	var cand_name := get_candidate(p["candidate"]).display_name()
	var out_lines: Array[String] = []
	for l in lines:
		out_lines.append(str(l).replace("{name}", cand_name))
	return {"candidate": p["candidate"], "kind": p["kind"], "headline": headline, "lines": out_lines, "final": p.get("final", false), "strike": strikes(),
		"review_label": cfg.get("review_label", "REVIEW"), "keep_label": cfg.get("keep_label", "KEEP")}


## choice: "review" reopens the file; "keep" stands by the decision.
func resolve_intervention(choice: String) -> String:
	var p := pending_intervention()
	if p.is_empty():
		return ""
	var cid: String = p["candidate"]
	var st := state(cid)
	var hist: Array = root()["ceo_history"]
	if not hist.is_empty():
		hist[hist.size() - 1]["choice"] = choice
	root().erase("pending_intervention")
	if choice == "review":
		st["mistake_counted"] = false
		st["status"] = "under_review"
		st["decision"] = {}
		(st["history"] as Array).append({"action": "reopened_by_ceo", "reason": "", "time": _now(), "minutes": GameState.time_minutes})
		log_event(cid, "CEO intervention: file reopened for review.")
		refresh_stats()
	else:
		st["mistake_kept"] = true
		(st["history"] as Array).append({"action": "kept_after_ceo", "reason": "", "time": _now(), "minutes": GameState.time_minutes})
		log_event(cid, "CEO intervention: decision kept.")
		_check_complete()
	candidate_changed.emit(cid)
	return str(ceo.get("after_%s" % choice, {}).get(p["kind"], ""))


func refresh_stats() -> void:
	var undecided := 0
	var accepted := 0
	for c in candidates:
		var s := status(c.id)
		if s == "accepted":
			accepted += 1
		elif s != "rejected":
			undecided += 1
	GameState.hires = accepted
	GameState.set_candidates_pending(undecided)


func is_complete() -> bool:
	return bool(root().get("completed", false))


func _check_complete() -> void:
	if is_complete() or not pending_intervention().is_empty():
		return
	for c in candidates:
		if not is_decided(c.id):
			return
	root()["completed"] = true
	_apply_effects()
	recruitment_completed.emit()


## Company consequences are applied only once recruitment is complete, so the
## HUD never leaks whether an individual decision was right.
func _apply_effects() -> void:
	if root().get("effects_applied", false):
		return
	root()["effects_applied"] = true
	for c in candidates:
		var correct := str(c.truth().get("correct_decision", ""))
		if correct.is_empty():
			continue
		var right := status(c.id) == ("accepted" if correct == "accept" else "rejected")
		var quality := str(c.truth().get("quality", ""))
		if right:
			GameState.company_reputation += 3
		elif quality == "dangerous":
			GameState.company_reputation -= 18
			GameState.company_funds -= 1_200_000
		elif quality in ["good", "excellent"]:
			GameState.company_reputation -= 6
			GameState.company_funds -= 300_000
		else:
			GameState.company_reputation -= 8
	GameState.company_reputation = clampi(GameState.company_reputation, 0, 100)
	GameState.stats_changed.emit()


# --- Dashboard & report -------------------------------------------------------

func dashboard_stats() -> Dictionary:
	var s := {"total": candidates.size(), "investigated": 0, "pending": 0, "accepted": 0, "rejected": 0,
		"flagged": 0, "verified_docs": 0, "contradictions": 0}
	for c in candidates:
		var st := state(c.id)
		var stat := status(c.id)
		if stat != "pending":
			s["investigated"] += 1
		if stat == "accepted":
			s["accepted"] += 1
		elif stat == "rejected":
			s["rejected"] += 1
		else:
			s["pending"] += 1
		if st["flagged"]:
			s["flagged"] += 1
		s["verified_docs"] += verified_documents(c.id).size()
		s["contradictions"] += open_contradictions(c.id).size()
	return s


func build_report() -> Dictionary:
	var rows: Array[Dictionary] = []
	var correct := 0
	var incorrect := 0
	var judged := 0
	var key_total := 0
	var key_found := 0
	var missed: Array[String] = []
	var contradictions_found := 0
	var docs_verified := 0
	var breach := false
	var empty_desks := false
	for c in candidates:
		var stat := status(c.id)
		var truth := c.truth()
		var want := str(truth.get("correct_decision", ""))
		var verdict := "judgement"
		if not want.is_empty():
			judged += 1
			if stat == ("accepted" if want == "accept" else "rejected"):
				correct += 1
				verdict = "correct"
			else:
				incorrect += 1
				verdict = "incorrect"
				if stat == "accepted" and truth.get("quality", "") == "dangerous":
					breach = true
				if stat == "rejected" and truth.get("quality", "") in ["good", "excellent"]:
					empty_desks = true
		for k: String in truth.get("key_clues", []):
			key_total += 1
			if has_clue(c.id, k):
				key_found += 1
			else:
				missed.append("%s — %s" % [c.display_name(), c.clue(k).get("text", k)])
		for cl: String in discovered_clues(c.id):
			if c.clue(cl).get("contradiction", false):
				contradictions_found += 1
		docs_verified += verified_documents(c.id).size()
		rows.append({"id": c.id, "name": c.display_name(), "position": c.position(), "status": stat,
			"verdict": verdict, "progress": progress(c.id), "mistake_kept": state(c.id)["mistake_kept"]})
	var ending := "acceptable_losses"
	if breach:
		ending = "breach"
	elif judged > 0 and correct == judged:
		ending = "perfect"
	elif empty_desks:
		ending = "empty_desks"
	var score := roundi(80.0 * correct / maxf(judged, 1.0) + 20.0 * key_found / maxf(key_total, 1.0))
	var grade := "A" if score >= 90 else ("B" if score >= 75 else ("C" if score >= 55 else ("D" if score >= 35 else "F")))
	var ira := status("c06")
	var ira_key := "accept" if ira == "accepted" else ("reject" if ira == "rejected" else "none")
	var used := (root()["ceo_history"] as Array).size()
	var endings: Dictionary = narrative.get("endings", {})
	return {
		"rows": rows, "total": candidates.size(), "accepted": dashboard_stats()["accepted"], "rejected": dashboard_stats()["rejected"],
		"investigated": dashboard_stats()["investigated"], "docs_verified": docs_verified, "contradictions": contradictions_found,
		"key_found": key_found, "key_total": key_total, "missed": missed, "ceo_used": used, "correct": correct,
		"incorrect": incorrect, "judged": judged, "score": score, "grade": grade, "ending": ending,
		"ending_title": endings.get(ending, {}).get("title", ""), "ending_text": endings.get(ending, {}).get("text", ""),
		"ira_text": narrative.get("ira_thread", {}).get(ira_key, ""), "hook": narrative.get("phase3_hook", ""),
	}
