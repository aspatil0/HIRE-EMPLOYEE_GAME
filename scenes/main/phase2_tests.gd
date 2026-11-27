class_name Phase2Tests
extends RefCounted
## Automated checks for the Phase 2 recruitment systems, run by the boot
## scene's --smoke-test. Covers data integrity (every clue reachable), the
## verification logic, calls, research, decisions, CEO interventions,
## save/load (including Phase 1 saves), endings, and the real UI panels.

const OFFICE_SCENE := "res://scenes/locations/alice_office.tscn"

var _main: Node
## Set only when every section ran to the end (a script error aborts the coroutine).
var finished: bool = false


func _init(main: Node) -> void:
	_main = main


func check(ok: bool, what: String) -> void:
	_main.call(&"_check", ok, what)


func frames(n: int) -> void:
	for i in n:
		await _main.get_tree().process_frame


func wait(seconds: float) -> void:
	await _main.get_tree().create_timer(seconds).timeout


func run() -> void:
	_data_integrity()
	_logic()
	_calls_and_research()
	_save_load()
	_endings()
	_anon_emails()
	await _ui()
	finished = true


func _fresh() -> void:
	GameState.reset()
	GameManager.set_mode(GameManager.Mode.EXPLORE)


# --- Data integrity -----------------------------------------------------------

func _data_integrity() -> void:
	check(Recruitment.candidates.size() == 6, "P2: six candidates load")
	var company := DataLoader.company(1)
	var required := ["name", "claimed_age", "dob", "gender", "address", "city", "phone", "email", "position", "education",
		"experience", "total_experience", "skills", "achievements", "references", "expected_salary", "notice_period", "statement"]
	for c in Recruitment.candidates:
		var r := c.resume()
		var missing: Array[String] = []
		for k in required:
			if not r.has(k):
				missing.append(k)
		check(missing.is_empty(), "P2: %s resume has every required section %s" % [c.id, missing])
		var reachable: Dictionary = {}
		for cl in c.resume_clue_ids():
			reachable[cl] = true
		var row_ids := c.all_row_ids(1)
		for row_id: String in c.data.get("row_notes", {}):
			check(row_ids.has(row_id), "P2: %s row note '%s' matches a comparison row" % [c.id, row_id])
			var cl := str(c.row_note(row_id).get("clue", ""))
			if not cl.is_empty():
				reachable[cl] = true
		for res: Dictionary in c.search_results():
			var cl := str(res.get("clue", ""))
			if not cl.is_empty():
				reachable[cl] = true
		for contact_id: String in Recruitment.contacts:
			var info := Recruitment.contact(contact_id)
			if str(info.get("candidate", "")) != c.id:
				continue
			if not str(info.get("clue", "")).is_empty():
				reachable[str(info["clue"])] = true
			for q: Dictionary in info.get("questions", []):
				if not str(q.get("clue", "")).is_empty():
					reachable[str(q["clue"])] = true
		for m: Dictionary in company.get("inbox", []):
			if str(m.get("candidate", "")) == c.id and not str(m.get("clue", "")).is_empty():
				reachable[str(m["clue"])] = true
			for pair: Array in m.get("clues", []):
				if str(pair[0]) == c.id:
					reachable[str(pair[1])] = true
		var unknown: Array[String] = []
		for cl: String in reachable:
			if not c.clues().has(cl):
				unknown.append(cl)
		check(unknown.is_empty(), "P2: %s every referenced clue exists %s" % [c.id, unknown])
		var unreachable: Array[String] = []
		for cl: String in c.clues():
			if not reachable.has(cl):
				unreachable.append(cl)
			var resolver := str(c.clue(cl).get("resolved_by", ""))
			if not resolver.is_empty():
				check(c.clues().has(resolver), "P2: %s resolver %s exists" % [c.id, resolver])
		check(unreachable.is_empty(), "P2: %s every clue is discoverable %s" % [c.id, unreachable])
		check(c.clues().size() >= 10, "P2: %s has a full evidence set (%d clues)" % [c.id, c.clues().size()])
		for k: String in c.truth().get("key_clues", []):
			check(c.clues().has(k), "P2: %s key clue %s exists" % [c.id, k])
		for ref: Dictionary in c.references():
			check(not Recruitment.contact(str(ref.get("contact", ""))).is_empty(), "P2: %s reference '%s' has a phone contact" % [c.id, ref.get("name", "")])


# --- Verification logic -------------------------------------------------------

func _logic() -> void:
	_fresh()
	var dob := DateUtil.parse_dmy("29-08-1986")
	check(DateUtil.age_on(dob, DateUtil.game_date(1)) == 40, "P2: DOB 29-08-1986 is age 40 in Nov 2026")
	check(DateUtil.age_on(DateUtil.parse_dmy("21-11-1986"), DateUtil.game_date(1)) == 39, "P2: birthday tomorrow -> not yet 40")
	var sham := Recruitment.get_candidate("c01")
	check(sham.find_row("age")["result"] == Candidate.MISMATCH, "P2: Sham Mathur claimed age 56 vs 40 is a MISMATCH")
	check(sham.find_row("aadhaar.name")["result"] == Candidate.MATCH, "P2: Sham name matches ID")
	check(sham.find_row("aadhaar.dob")["result"] == Candidate.MATCH, "P2: Sham DOB matches ID")
	check(sham.find_row("aadhaar.address")["result"] == Candidate.MATCH, "P2: Sham address matches ID")
	var arjun := Recruitment.get_candidate("c02")
	check(arjun.find_row("employment.left")["result"] == Candidate.MISMATCH, "P2: Arjun leaving date conflicts with bureau record")
	check(arjun.find_row("education.year")["result"] == Candidate.MATCH, "P2: Arjun graduation year verified")
	var ravi := Recruitment.get_candidate("c03")
	check(ravi.find_row("aadhaar.name")["result"] == Candidate.PARTIAL, "P2: 'Ravi S. Shetty' is a partial name match")
	var farah := Recruitment.get_candidate("c04")
	check(farah.find_row("aadhaar.address")["result"] == Candidate.MISMATCH, "P2: Farah address differs on ID")
	check(farah.find_row("passport.name")["result"] == Candidate.PARTIAL, "P2: 'Farha' spelling flagged for review")
	check(farah.find_row("passport.expiry")["result"] == Candidate.PARTIAL, "P2: expired passport flagged")
	check(Recruitment.get_candidate("c06").find_row("employment.company")["result"] == Candidate.MISSING, "P2: Ira has no employment document")

	# Evidence log and contradiction resolution.
	Recruitment.view_resume("c01")
	check(Recruitment.has_clue("c01", "c01_age_claim"), "P2: reading a resume logs its visible clues")
	var company := DataLoader.company(1)
	check(not _email_visible(company, "m_careernest"), "P2: agency correction email hidden before the age mismatch is found")
	var row := Recruitment.verify_row("c01", "age")
	check(row["result"] == Candidate.MISMATCH and Recruitment.has_clue("c01", "c01_age_mismatch"), "P2: verifying age records the discrepancy")
	check(Recruitment.open_contradictions("c01").has("c01_age_mismatch"), "P2: age discrepancy is an open contradiction")
	check(_email_visible(company, "m_careernest"), "P2: agency correction email appears after the mismatch")
	for m in Recruitment.visible_emails(company):
		if m.get("id", "") == "m_careernest":
			Recruitment.read_email(m)
	check(Recruitment.is_resolved("c01", "c01_age_mismatch") and Recruitment.open_contradictions("c01").is_empty(), "P2: agency email explains the age discrepancy")
	var entries: Array = Recruitment.state("c01")["log"]
	check(str(entries[0]["text"]) == "Resume reviewed.", "P2: log starts with the resume review")
	var ordered := true
	for i in range(1, entries.size()):
		if int(entries[i]["minutes"]) < int(entries[i - 1]["minutes"]):
			ordered = false
	check(ordered and entries.size() >= 6, "P2: evidence log preserves discovery order (%d entries)" % entries.size())
	Recruitment.verify_row("c01", "age")
	check(Recruitment.state("c01")["log"].size() == entries.size(), "P2: re-checking a field does not duplicate evidence")
	for id in sham.all_row_ids(1):
		if id.begins_with("aadhaar"):
			Recruitment.verify_row("c01", id)
	check(Recruitment.verified_documents("c01").has("aadhaar"), "P2: a document counts as verified once all its fields are checked")
	Recruitment.set_flagged("c01", true)
	Recruitment.set_notes("c01", "Ask agency about age.")
	check(Recruitment.dashboard_stats()["flagged"] == 1, "P2: dashboard counts flagged candidates")


func _email_visible(company: Dictionary, id: String) -> bool:
	for m in Recruitment.visible_emails(company):
		if m.get("id", "") == id:
			return true
	return false


func _calls_and_research() -> void:
	_fresh()
	var t0 := GameState.time_minutes
	var res := Recruitment.start_call("ref_c02_zentrix")
	check(res["ok"] and res["reason"] == "answers", "P2: Zentrix HR answers")
	check(GameState.time_minutes > t0, "P2: calls take in-game time")
	var answer := Recruitment.ask("rehire")
	check(answer.contains("ineligible") and Recruitment.has_clue("c02", "c02_zentrix_termination"), "P2: asking about rehire reveals the termination")
	Recruitment.ask("dates")
	check(Recruitment.questions_left() == 0 and Recruitment.ask("role").is_empty(), "P2: questions per call are limited")
	Recruitment.end_call()
	check(Recruitment.calls_left("ref_c02_zentrix") == 0 and not Recruitment.start_call("ref_c02_zentrix")["ok"], "P2: calls per contact are limited")
	Recruitment.start_call("ref_c02_sen")
	Recruitment.ask("skill")
	check(Recruitment.has_clue("c02", "c02_sen_praise") and not Recruitment.has_clue("c02", "c02_sen_conflict"), "P2: different questions give different evidence")
	Recruitment.end_call()
	check(Recruitment.find_contact_by_number("+91 20 4113 1313") == "ref_c06_self", "P2: dialling Ira's resume number reaches her listed contact")
	var auto := Recruitment.start_call("ref_c06_self")
	check(auto["reason"] == "automated" and Recruitment.has_clue("c06", "c06_phone_1313"), "P2: Ira's number is internal line 1313")
	check(Recruitment.start_call("ref_c06_college")["reason"] == "no_answer", "P2: some contacts never answer")

	var hits := Recruitment.search("Sham Mathur")
	var ids: Array[String] = []
	for h in hits:
		ids.append(str(h["result"].get("id", "")))
	check(ids.has("s01_news") and ids.has("s01_followup"), "P2: searching a name returns both the misleading and the correcting article")
	check(Recruitment.search("zzzz nothing").is_empty(), "P2: unrelated searches return nothing")
	for h in Recruitment.search("Ravi Shetty"):
		if h["result"].get("id", "") == "s03_ransom":
			Recruitment.open_result(h["candidate_id"], h["result"])
	check(Recruitment.has_clue("c03", "c03_ransomware"), "P2: opening a news result records its evidence")
	check(not Recruitment.search("Halden").is_empty(), "P2: searching an employer finds results")


# --- Save / load --------------------------------------------------------------

func _save_load() -> void:
	_fresh()
	Recruitment.view_resume("c05")
	Recruitment.verify_row("c05", "employment.left")
	Recruitment.start_call("ref_c05_halden")
	Recruitment.ask("rehire")
	Recruitment.end_call()
	Recruitment.set_follow_up("c05", true)
	Recruitment.decide("c04", "reject", "Forged letter")
	Recruitment.decide("c03", "reject") # uses the CEO token
	Recruitment.resolve_intervention("keep")
	var clues_before: int = Recruitment.discovered_clues("c05").size()
	# Through JSON exactly like the save file (ints come back as floats).
	var parsed: Variant = JSON.parse_string(JSON.stringify(GameState.to_dict()))
	GameState.reset()
	GameState.from_dict(parsed)
	check(Recruitment.discovered_clues("c05").size() == clues_before, "P2 save: discovered clues persist")
	check(Recruitment.row_result("c05", "employment.left") == Candidate.MATCH, "P2 save: verified fields persist")
	check(Recruitment.calls_left("ref_c05_halden") == 0, "P2 save: completed calls persist")
	check(Recruitment.state("c05")["follow_up"], "P2 save: follow-up marks persist")
	check(Recruitment.status("c04") == "rejected" and Recruitment.status("c03") == "rejected", "P2 save: decisions persist")
	check(Recruitment.strikes() == 1 and Recruitment.warnings_left() == 1 and Recruitment.root()["ceo_history"].size() == 1, "P2 save: strikes and warnings persist")
	check(Recruitment.state("c03")["mistake_kept"], "P2 save: kept mistakes persist")
	check(GameState.candidates_pending == 4, "P2 save: pending count persists")

	# A Phase 1 (v2) save has no recruitment block at all.
	var v2 := {"version": 2, "flags": {"intro_seen": true, "arrival_seen": true, "call_day1_done": true, "candidates_received": true, "flagged_rohan_mehta": true},
		"inventory": [], "clues": [], "current_location": OFFICE_SCENE, "day": 1, "time_minutes": 1275,
		"objective": "Review the resumes, then check each candidate's documents and online traces.",
		"candidates_pending": 6, "hires": 0, "hire_target": 3, "company_funds": 4800000, "company_reputation": 72}
	GameState.reset()
	GameState.from_dict(JSON.parse_string(JSON.stringify(v2)))
	check(GameState.recruitment.is_empty() and Recruitment.status("c01") == "pending", "P2 save: Phase 1 save loads with fresh recruitment state")
	check(Recruitment.warnings_left() == 2 and Recruitment.strikes() == 0 and GameState.time_minutes == 1275, "P2 save: Phase 1 save keeps its clock and starts with two warnings")

	# A save from the old one-token rule: Sham was rejected (Aditya came), then
	# Arjun was accepted with no visit. Loading must catch Arjun up.
	GameState.reset()
	GameState.recruitment = {"version": 1, "ceo_tokens": 0, "current": "c02", "calls": {}, "emails_read": [], "completed": false, "effects_applied": false,
		"ceo_history": [{"candidate": "c01", "kind": "reject_good", "choice": "review", "time": "9:04 PM", "warned": false}],
		"candidates": {"c01": {"status": "accepted"}, "c02": {"status": "accepted"}}}
	for cid in ["c01", "c02"]:
		var st := Recruitment.state(cid)
		for k: String in ["resume_viewed", "clues", "log", "rows", "docs_viewed", "results_opened", "notes", "flagged", "follow_up", "decision", "history", "mistake_kept"]:
			if not st.has(k):
				st[k] = {"resume_viewed": false, "notes": "", "flagged": false, "follow_up": false, "mistake_kept": false, "rows": {}, "decision": {}}.get(k, [])
	check(Recruitment.ensure_interventions() and Recruitment.pending_intervention().get("candidate", "") == "c02", "P2 save: old save gets the missed intervention for accepting Arjun")
	check(Recruitment.pending_intervention().get("kind", "") == "accept_dangerous", "P2 save: catch-up uses the dangerous-hire intervention")
	check(Recruitment.strikes() == 2 and Recruitment.pending_intervention().get("final", false), "P2 save: the earlier visit counts, so Arjun is the FINAL warning")


# --- Decisions, CEO and endings ------------------------------------------------

func _decide_all(plan: Dictionary, keep_on_ceo: bool = true) -> void:
	for cid: String in plan:
		Recruitment.decide(cid, plan[cid])
		if not Recruitment.pending_intervention().is_empty():
			Recruitment.resolve_intervention("keep" if keep_on_ceo else "review")
			if not keep_on_ceo:
				Recruitment.decide(cid, "accept" if plan[cid] == "reject" else "reject")


func _endings() -> void:
	# Investigate further, then decide.
	_fresh()
	Recruitment.decide("c04", "investigate")
	check(Recruitment.status("c04") == "investigating" and not Recruitment.is_decided("c04"), "P2: INVESTIGATE FURTHER keeps the file open")
	Recruitment.decide("c04", "reject", "Letter forged")
	check(Recruitment.status("c04") == "rejected" and Recruitment.state("c04")["history"].size() == 2, "P2: decision history keeps every step")
	check(GameState.candidates_pending == 5, "P2: rejecting updates the pending count")

	# Scenario A: rejecting a strong candidate triggers the CEO; review reopens it.
	var r := Recruitment.decide("c03", "reject")
	check(r["intervention"] == "reject_good", "P2 CEO: rejecting Ravi Shetty triggers an intervention")
	check(not Recruitment.intervention_script().get("lines", []).is_empty(), "P2 CEO: intervention has dialogue")
	check(str(Recruitment.intervention_script()["lines"][1]).contains("Ravi Shetty"), "P2 CEO: dialogue names the candidate")
	Recruitment.resolve_intervention("review")
	check(Recruitment.status("c03") == "under_review" and not Recruitment.is_decided("c03"), "P2 CEO: REVIEW reopens the file")
	check(Recruitment.decide("c03", "accept")["intervention"] == "", "P2 CEO: decision can be changed after review")
	check(Recruitment.strikes() == 1 and Recruitment.warnings_left() == 1, "P2 CEO: reviewing still counts the mistake (1 warning left)")
	var r2 := Recruitment.decide("c05", "accept")
	check(r2["intervention"] == "accept_dangerous", "P2 CEO: accepting Karan brings Aditya in")
	check(Recruitment.pending_intervention().get("final", false), "P2 CEO: the second mistake is the FINAL warning")
	check(str(Recruitment.intervention_script()["lines"]).contains("FINAL warning"), "P2 CEO: final warning dialogue")
	Recruitment.resolve_intervention("keep")
	check(Recruitment.decide("c06", "reject")["intervention"] == "", "P2 CEO: Ira Mehra has no right answer and never counts")
	var r3 := Recruitment.decide("c01", "reject")
	check(r3["intervention"] == "fired" and Recruitment.is_fired(), "P2 CEO: the third mistake gets Alice fired")
	check(Recruitment.intervention_script().is_empty() and not Recruitment.is_complete(), "P2 CEO: no review is offered once fired")

	# Every bad candidate counts, not just the first two.
	for case: Array in [["c01", "reject"], ["c02", "accept"], ["c03", "reject"], ["c04", "accept"], ["c05", "accept"]]:
		_fresh()
		check(Recruitment.decide(case[0], case[1])["intervention"] != "", "P2 CEO: wrong decision on %s (%s) brings Aditya in" % [Recruitment.get_candidate(case[0]).display_name(), case[1]])
	for case: Array in [["c01", "accept"], ["c02", "reject"], ["c03", "accept"], ["c04", "reject"], ["c05", "reject"], ["c06", "accept"], ["c06", "reject"]]:
		_fresh()
		check(Recruitment.decide(case[0], case[1])["intervention"] == "", "P2 CEO: correct decision on %s (%s) passes quietly" % [Recruitment.get_candidate(case[0]).display_name(), case[1]])

	# Perfect run.
	_fresh()
	_decide_all({"c01": "accept", "c02": "reject", "c03": "accept", "c04": "reject", "c05": "reject", "c06": "accept"})
	var rep := Recruitment.build_report()
	check(Recruitment.is_complete() and rep["ending"] == "perfect" and rep["correct"] == 5, "P2 ending: all correct -> THE FINAL HIRE")
	check(GameState.company_reputation > GameState.START_REPUTATION, "P2 ending: good hiring improves reputation (applied at the end)")
	# Dangerous hire kept despite the CEO.
	_fresh()
	_decide_all({"c05": "accept", "c01": "accept", "c02": "reject", "c03": "accept", "c04": "reject", "c06": "reject"})
	rep = Recruitment.build_report()
	check(rep["ending"] == "breach" and rep["ceo_used"] == 1, "P2 ending: keeping a dangerous hire -> THE BREACH")
	check(GameState.get_company_status() != "STABLE" or GameState.company_reputation < GameState.START_REPUTATION, "P2 ending: a breach damages the company")
	_fresh()
	_decide_all({"c03": "reject", "c02": "accept"})
	check(Recruitment.root()["ceo_history"].size() == 2, "P2 CEO: Aditya can intervene for both kinds of mistake in one playthrough")
	# Good people turned away.
	_fresh()
	_decide_all({"c01": "reject", "c03": "reject", "c02": "reject", "c04": "reject", "c05": "reject", "c06": "reject"})
	rep = Recruitment.build_report()
	check(rep["ending"] == "empty_desks", "P2 ending: rejecting strong candidates -> EMPTY DESKS")
	# Mixed.
	_fresh()
	_decide_all({"c01": "accept", "c02": "reject", "c03": "accept", "c04": "accept", "c05": "reject", "c06": "reject"})
	rep = Recruitment.build_report()
	check(rep["ending"] == "acceptable_losses" and not str(rep["ira_text"]).is_empty() and not str(rep["hook"]).is_empty(), "P2 ending: mixed -> ACCEPTABLE LOSSES, with the Phase 3 hook")
	check(rep["missed"].size() > 0, "P2 report: lists important clues that were missed")


# --- UI -----------------------------------------------------------------------

func _ui() -> void:
	_fresh()
	GameState.set_flag(&"arrival_seen")
	GameState.set_flag(&"call_day1_done")
	var office := (load(OFFICE_SCENE) as PackedScene).instantiate()
	_main.get_tree().root.add_child(office)
	await frames(3)
	var host := office.get_node("UI/PanelHost") as PanelHost
	var ctrl := office.get_node("Interaction") as InteractionController

	# Resume viewer.
	host.open(load(RecruitUI.RESUME_SCENE))
	await wait(0.4)
	var resume := host.current_panel
	check(resume != null and resume.call(&"get_candidate_id") == "c01", "P2 UI: resume viewer opens on candidate 01")
	(resume.find_child("NextButton", true, false) as Button).pressed.emit()
	await frames(2)
	check(resume.call(&"get_candidate_id") == "c02", "P2 UI: NEXT shows candidate 02")
	(resume.find_child("PrevButton", true, false) as Button).pressed.emit()
	(resume.find_child("PrevButton", true, false) as Button).pressed.emit()
	await frames(2)
	check(resume.call(&"get_candidate_id") == "c06", "P2 UI: PREVIOUS wraps around to candidate 06")
	(resume.find_child("FlagToggle", true, false) as CheckButton).button_pressed = true
	check(Recruitment.state("c06")["flagged"], "P2 UI: FLAG toggle records the flag")
	var notes := resume.find_child("Notes", true, false) as TextEdit
	notes.text = "Line 1313?"
	notes.text_changed.emit()
	check(Recruitment.state("c06")["notes"] == "Line 1313?", "P2 UI: notes are saved")
	# Into the decision screen and back out via the evidence log button chain.
	(resume.find_child("DecisionButton", true, false) as Button).pressed.emit()
	await wait(0.8)
	check(host.current_panel != null and host.current_panel.scene_file_path == RecruitUI.DECISION_SCENE, "P2 UI: DECISION opens the decision screen")
	var decision := host.current_panel
	(decision.find_child("AcceptButton", true, false) as Button).pressed.emit()
	await wait(0.4)
	var confirm := decision.find_child("ConfirmDecision", true, false) as ConfirmPanel
	check(confirm != null, "P2 UI: ACCEPT asks for confirmation")
	if confirm:
		for b in confirm.find_children("*", "Button", true, false):
			if (b as Button).text == "CONFIRM ACCEPTANCE":
				(b as Button).pressed.emit()
		await wait(0.6)
	check(Recruitment.status("c06") == "accepted", "P2 UI: confirming records the acceptance")
	check(decision.find_child("ContinueButton", true, false) != null, "P2 UI: a narrative response follows the decision")
	await decision.close()
	await frames(2)

	# Document comparison by clicking a field.
	host.open(load(RecruitUI.DOCUMENT_SCENE), {"candidate_id": "c01"})
	await wait(0.4)
	var docs := host.current_panel
	var age_btn := docs.find_child("Row_age", true, false) as Button
	check(age_btn != null, "P2 UI: document panel lists the age comparison")
	if age_btn:
		age_btn.pressed.emit()
	check(Recruitment.row_result("c01", "age") == Candidate.MISMATCH, "P2 UI: clicking a field verifies it")
	(docs.find_child("Tab_employment", true, false) as Button).pressed.emit()
	await frames(2)
	check(docs.find_child("Row_employment_left", true, false) != null, "P2 UI: employment verification tab works")
	(docs.find_child("Tab_education", true, false) as Button).pressed.emit()
	await frames(2)
	check(docs.find_child("Row_education_year", true, false) != null, "P2 UI: education verification tab works")
	await docs.close()
	await frames(2)

	# Phone call with question choice.
	ctrl.activate(_by_id("telephone"))
	await wait(0.4)
	var phone := host.current_panel
	phone.call(&"call_contact", "ref_c01_careernest")
	await wait(3.0)
	var ask := phone.find_child("Ask_age", true, false) as Button
	check(ask != null, "P2 UI: reference call offers questions")
	if ask:
		ask.pressed.emit()
	check(Recruitment.has_clue("c01", "c01_agency_error"), "P2 UI: asking the right question records the clue")
	await phone.close()
	await frames(2)

	# Browser research.
	ctrl.activate(_by_id("side_computer"))
	await wait(0.4)
	var browser := host.current_panel
	browser.call(&"search", "Arjun Malhotra")
	await wait(1.2)
	var res_btn := browser.find_child("Result_s02_sen", true, false) as Button
	check(res_btn != null, "P2 UI: search results are listed")
	if res_btn:
		res_btn.pressed.emit()
	check(Recruitment.has_clue("c02", "c02_sen_left"), "P2 UI: opening a result records the clue")
	await browser.close()
	await frames(2)

	# Dashboard + journal.
	ctrl.activate(_by_id("main_computer"))
	await wait(1.4)
	var pc := host.current_panel
	check(pc.find_child("Tab_REPORTS", true, false) != null, "P2 UI: computer has DASHBOARD/REPORTS tabs")
	await pc.close()
	await frames(2)
	(office as Node).call(&"open_journal")
	await wait(0.3)
	check(host.current_panel != null and host.current_panel.scene_file_path == RecruitUI.JOURNAL_SCENE, "P2 UI: J opens the evidence journal")
	(host.current_panel.find_child("Filter_identity", true, false) as Button).pressed.emit()
	await frames(2)
	await host.current_panel.close()
	await frames(2)

	# The resume stack only holds undecided applications.
	host.open(load(RecruitUI.RESUME_SCENE), {"candidate_id": "c06"})
	await wait(0.4)
	var stack_panel := host.current_panel
	check(stack_panel.call(&"get_candidate_id") != "c06", "P2 UI: a decided candidate's resume is no longer in the stack")
	var seen: Dictionary = {}
	for i in 8:
		seen[stack_panel.call(&"get_candidate_id")] = true
		(stack_panel.find_child("NextButton", true, false) as Button).pressed.emit()
		await frames(1)
	check(seen.size() == Recruitment.remaining().size() and not seen.has("c06"), "P2 UI: NEXT cycles only the %d remaining resumes" % Recruitment.remaining().size())
	await stack_panel.close()
	await frames(2)

	# CEO intervention staged in the office.
	Recruitment.decide("c03", "reject")
	office.call(&"_check_staging")
	await wait(1.0)
	var intruder := office.get_node("Environment/CEOIntruder") as CEOIntruder
	check(intruder.visible and intruder.presence > 0.2, "P2 UI: Aditya walks into the office")
	await wait(1.9)
	var ceo := host.current_panel
	check(ceo != null and ceo.scene_file_path == RecruitUI.CEO_SCENE, "P2 UI: rejecting Ravi Shetty brings the CEO into the office")
	check(intruder.presence > 0.95, "P2 UI: he stays in the doorway, red-eyed, during the confrontation")
	check(str(Recruitment.intervention_script()["lines"][-1]).contains("see what I do with you"), "P2 UI: the CEO gives the last-chance warning")
	if ceo:
		var esc := InputEventAction.new()
		esc.action = &"pause"
		esc.pressed = true
		ceo.call(&"_unhandled_input", esc)
		check(host.current_panel == ceo and not ceo.is_closing(), "P2 UI: the CEO cannot be dismissed with Esc")
		ceo.call(&"choose", "review")
		await wait(2.4)
	check(Recruitment.status("c03") == "under_review", "P2 UI: REVIEW CANDIDATE reopens the file")
	await wait(1.6)
	check(intruder.presence < 0.05, "P2 UI: Aditya leaves after the decision")
	check(host.current_panel != null and host.current_panel.call(&"get_candidate_id") == "c03", "P2 UI: the reopened file is shown")
	if host.current_panel:
		await host.current_panel.close()
		await frames(2)

	# Finish recruitment: report call -> report.
	for plan: Array in [["c01", "accept"], ["c02", "reject"], ["c03", "accept"], ["c04", "reject"], ["c05", "reject"]]:
		Recruitment.decide(plan[0], plan[1])
	check(Recruitment.is_complete(), "P2 UI: all six decided -> recruitment complete")
	office.call(&"_check_staging")
	await wait(2.6)
	check(DialogueManager.is_active, "P2 UI: Aditya calls for the report")
	while DialogueManager.is_active:
		DialogueManager.advance()
	await wait(1.2)
	var report := host.current_panel
	check(report != null and report.scene_file_path == RecruitUI.REPORT_SCENE, "P2 UI: recruitment report opens")
	if report:
		var title := report.find_child("EndingTitle", true, false) as Label
		check(title != null and title.text == "THE FINAL HIRE", "P2 UI: report shows the earned ending")
		await report.close()
	check(GameState.objective.begins_with("Recruitment complete"), "P2 UI: objective updates at the end")
	office.queue_free()
	await frames(3)
	AudioManager.stop_all_loops(0.0)
	await _ui_firing()
	await _ui_cabin()


## Three strikes: Aditya comes to the door, summons Alice, and the firing scene
## ends in the TERMINATED game-over screen.
func _ui_firing() -> void:
	_fresh()
	GameState.set_flag(&"arrival_seen")
	GameState.set_flag(&"call_day1_done")
	var office := (load(OFFICE_SCENE) as PackedScene).instantiate()
	_main.get_tree().root.add_child(office)
	office.set(&"test_no_scene_change", true)
	await frames(3)
	var hud_status := office.find_child("Status", true, false) as Label
	check(hud_status != null and hud_status.text.contains("CEO WARNINGS LEFT   2"), "P2 fired: HUD shows two warnings left")
	Recruitment.decide("c01", "reject")
	Recruitment.resolve_intervention("keep")
	await frames(1)
	check(hud_status.text.contains("CEO WARNINGS LEFT   1"), "P2 fired: HUD counts down warnings")
	Recruitment.decide("c04", "accept")
	Recruitment.resolve_intervention("keep")
	Recruitment.decide("c02", "accept")
	check(Recruitment.pending_intervention().get("kind", "") == "fired", "P2 fired: third mistake queues the dismissal")
	office.call(&"_check_staging")
	await wait(2.4)
	var intruder := office.get_node("Environment/CEOIntruder") as CEOIntruder
	check(intruder.presence > 0.8, "P2 fired: Aditya comes to Alice's door")
	check(DialogueManager.is_active, "P2 fired: Aditya summons Alice to his office")
	while DialogueManager.is_active:
		DialogueManager.advance()
	await frames(2)
	office.queue_free()
	await frames(3)

	var fired := (load("res://scenes/cutscenes/fired.tscn") as PackedScene).instantiate()
	_main.get_tree().root.add_child(fired)
	await wait(2.3)
	check(DialogueManager.is_active, "P2 fired: the dismissal plays in the CEO's office")
	var lines := 0
	var said_fired := false
	while DialogueManager.is_active and lines < 20:
		var box := fired.find_child("Text", true, false) as Label
		if box and box.text.contains("you're fired"):
			said_fired = true
		DialogueManager.advance()
		lines += 1
		await frames(1)
	check(said_fired, "P2 fired: Aditya says \"you're fired\"")
	await wait(0.3)
	var go := fired.find_child("GameOver", true, false) as Control
	check(go != null and go.visible, "P2 fired: GAME OVER — TERMINATED screen appears")
	var mistakes_label := fired.find_child("Mistakes", true, false) as Label
	check(mistakes_label != null and mistakes_label.text.contains("Sham Mathur") and mistakes_label.text.contains("Arjun Malhotra"), "P2 fired: the termination lists her three mistakes")
	check(fired.find_child("Retry", true, false) != null and fired.find_child("MainMenu", true, false) != null, "P2 fired: new game / main menu offered")
	fired.queue_free()
	await frames(3)
	AudioManager.stop_all_loops(0.0)


# --- The unknown sender + the cabin ending -----------------------------------

func _anon_visible(company: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for m in Recruitment.visible_emails(company):
		if str(m.get("id", "")).begins_with("anon_"):
			out.append(m)
	return out


func _anon(company: Dictionary, id: String) -> Dictionary:
	for m in _anon_visible(company):
		if m.get("id", "") == id:
			return m
	return {}


func _perfect_run(share: bool) -> void:
	var company := DataLoader.company(1)
	for plan: Array in [["c01", "accept"], ["c02", "reject"], ["c03", "accept"], ["c04", "reject"]]:
		Recruitment.decide(plan[0], plan[1])
	Recruitment.reply_email(_anon(company, "anon_3"), "share" if share else "ignore")
	Recruitment.decide("c05", "reject")
	Recruitment.decide("c06", "accept")


func _anon_emails() -> void:
	_fresh()
	var company := DataLoader.company(1)
	check(_anon_visible(company).is_empty(), "P2 mail: no unknown-sender email before any decision")
	var arrivals: Array[String] = []
	var on_arrive := func(e: Dictionary) -> void: arrivals.append(str(e.get("id", "")))
	Recruitment.email_arrived.connect(on_arrive)
	Recruitment.decide("c01", "accept")
	check(arrivals == ["anon_1"] and str(_anon(company, "anon_1").get("body", "")).contains("Don't do this"), "P2 mail: 1st decision -> 'Don't do this... you will get into trouble'")
	var e1 := _anon(company, "anon_1")
	check(Recruitment.reply_email(e1, "who") == "Who is this?" and Recruitment.reply_of("anon_1") == "who", "P2 mail: Alice can reply to the unknown sender")
	check(Recruitment.reply_email(e1, "stop").is_empty(), "P2 mail: one reply per email")
	Recruitment.decide("c02", "reject")
	check(arrivals.size() == 2 and str(_anon(company, "anon_2").get("body", "")).contains("He will make trouble for you"), "P2 mail: 2nd decision -> 'he will make trouble for you'")
	check(Recruitment.reply_email(_anon(company, "anon_2"), "what") == "What happened to you?", "P2 mail: Alice can reply to the second email")
	Recruitment.decide("c03", "accept")
	check(arrivals.size() == 2, "P2 mail: no email after the 3rd decision")
	Recruitment.decide("c04", "reject")
	check(arrivals.size() == 3 and str(_anon(company, "anon_3").get("body", "")).contains("whom you hired"), "P2 mail: 4th decision -> 'share whom you hired'")
	var sent := Recruitment.reply_email(_anon(company, "anon_3"), "share")
	check(Recruitment.shared_names() and sent.contains("Sham Mathur") and sent.contains("Ravi Shetty") and not sent.contains("Arjun"), "P2 mail: SEND THE NAMES sends the accepted candidates")
	Recruitment.decide("c05", "reject")
	Recruitment.decide("c06", "accept")
	check(arrivals.size() == 3, "P2 mail: no email after the 5th and 6th decisions")
	check(Recruitment.is_perfect(), "P2 ending 2: all scored candidates correct -> perfect")
	Recruitment.email_arrived.disconnect(on_arrive)

	_fresh()
	_perfect_run(false)
	check(Recruitment.is_perfect() and not Recruitment.shared_names() and Recruitment.reply_of("anon_3") == "ignore", "P2 mail: Alice can ignore the request")
	_fresh()
	Recruitment.decide("c01", "accept")
	Recruitment.decide("c01", "accept")
	check(_anon_visible(company).size() == 1, "P2 mail: each email arrives only once")
	_fresh()
	Recruitment.decide("c01", "reject")
	Recruitment.resolve_intervention("review")
	Recruitment.decide("c01", "accept")
	for plan: Array in [["c02", "reject"], ["c03", "accept"], ["c04", "reject"], ["c05", "reject"], ["c06", "reject"]]:
		Recruitment.decide(plan[0], plan[1])
	check(Recruitment.is_perfect(), "P2 ending 2: fixing a mistake after the CEO's warning still earns the cabin")
	_fresh()
	_decide_all({"c01": "accept", "c02": "reject", "c03": "accept", "c04": "accept", "c05": "reject", "c06": "accept"})
	check(not Recruitment.is_perfect(), "P2 ending 2: one wrong decision -> no cabin")


func _ui_cabin() -> void:
	# Email notification + replying from the main computer.
	_fresh()
	GameState.set_flag(&"arrival_seen")
	GameState.set_flag(&"call_day1_done")
	var office := (load(OFFICE_SCENE) as PackedScene).instantiate()
	_main.get_tree().root.add_child(office)
	office.set(&"test_no_scene_change", true)
	await frames(3)
	var host := office.get_node("UI/PanelHost") as PanelHost
	Recruitment.decide("c01", "accept")
	await wait(1.6)
	var toast := office.find_child("Toast", true, false) as Label
	check(toast != null and toast.text.contains("NEW EMAIL"), "P2 mail UI: a NEW EMAIL notification appears")
	host.open(load("res://scenes/ui/panels/computer_panel.tscn"))
	await wait(1.4)
	var pc := host.current_panel
	(pc.find_child("Tab_INBOX", true, false) as Button).pressed.emit()
	await frames(2)
	var mail := pc.find_child("Mail_anon_1", true, false) as Button
	check(mail != null, "P2 mail UI: the unknown sender's email is in the inbox")
	if mail:
		mail.pressed.emit()
		await frames(2)
		var reply := pc.find_child("Reply_who", true, false) as Button
		check(reply != null, "P2 mail UI: reply options are shown")
		if reply:
			reply.pressed.emit()
	check(Recruitment.reply_of("anon_1") == "who", "P2 mail UI: replying from the inbox is recorded")
	await pc.close()
	await frames(2)

	# Perfect run -> report -> Aditya calls Alice to his cabin.
	for plan: Array in [["c02", "reject"], ["c03", "accept"], ["c04", "reject"]]:
		Recruitment.decide(plan[0], plan[1])
	Recruitment.reply_email(_anon(DataLoader.company(1), "anon_3"), "share")
	Recruitment.decide("c05", "reject")
	Recruitment.decide("c06", "reject")
	GameState.set_flag(&"phase2_report_seen")
	office.call(&"_check_staging")
	await wait(2.4)
	check(DialogueManager.is_active, "P2 cabin: Aditya calls Alice up to his cabin")
	var said := ""
	while DialogueManager.is_active:
		var box := office.find_child("Text", true, false) as Label
		if box:
			said += box.text + " "
		DialogueManager.advance()
		await frames(1)
	check(said.contains("cabin") and GameState.is_flag_set(&"phase2_cabin_seen"), "P2 cabin: summons line plays once")
	office.queue_free()
	await frames(3)

	# Branch A: she shared the names.
	var cabin := (load("res://scenes/cutscenes/ceo_cabin.tscn") as PackedScene).instantiate()
	_main.get_tree().root.add_child(cabin)
	var spoken := await _play_cabin(cabin)
	check(spoken.contains("Sit down") and spoken.contains("gone missing") and spoken.contains("protect information"), "P2 cabin: Aditya's speech about missing recruiters")
	check(spoken.contains("sent those names") and spoken.contains("No worries"), "P2 cabin (shared): he knows about the email")
	check(cabin.get(&"stage") == "blackout", "P2 cabin (shared): blackout")
	await wait(3.2)
	var poster_title := cabin.find_child("PosterTitle", true, false) as Label
	var poster_name := cabin.find_child("PosterName", true, false) as Label
	var last_seen := cabin.find_child("LastSeen", true, false) as Label
	check(poster_title != null and poster_title.text == "MISSING" and poster_name.text == "ALICE" and last_seen.text.contains("LAST SEEN"), "P2 cabin (shared): MISSING: ALICE poster with the time")
	cabin.call(&"show_email")
	await frames(2)
	var body := cabin.find_child("EmailBody", true, false) as Label
	check(body != null and body.text.contains("It's your boss"), "P2 cabin (shared): final email — 'don't share the details... it's your boss'")
	cabin.queue_free()
	await frames(3)

	# Branch B: she kept quiet.
	_fresh()
	_perfect_run(false)
	cabin = (load("res://scenes/cutscenes/ceo_cabin.tscn") as PackedScene).instantiate()
	_main.get_tree().root.add_child(cabin)
	spoken = await _play_cabin(cabin)
	check(spoken.contains("You said nothing") and not spoken.contains("sent those names"), "P2 cabin (quiet): Aditya lets her go")
	await frames(3)
	body = cabin.find_child("EmailBody", true, false) as Label
	check(body != null and body.text.contains("please reply") and cabin.find_child("PosterTitle", true, false) == null, "P2 cabin (quiet): final email — 'Alice, please reply to me', no poster")
	cabin.queue_free()
	await frames(3)
	AudioManager.stop_all_loops(0.0)


func _play_cabin(cabin: Node) -> String:
	await wait(2.3)
	var spoken := ""
	var guard := 0
	while DialogueManager.is_active and guard < 30:
		var box := cabin.find_child("Text", true, false) as Label
		if box:
			spoken += box.text + " "
		DialogueManager.advance()
		guard += 1
		await frames(1)
	return spoken


func _by_id(id: String) -> Interactable:
	for n in _main.get_tree().get_nodes_in_group(&"interactables"):
		if String((n as Interactable).interaction_id) == id:
			return n
	return null
