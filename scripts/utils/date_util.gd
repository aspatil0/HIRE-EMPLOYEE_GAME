class_name DateUtil
extends RefCounted
## Calendar helpers for the in-game date and document dates.
## Day 1 of the story is 20 November 2026. Document dates use "DD-MM-YYYY",
## employment dates use "MM-YYYY".

const START_YEAR := 2026
const START_MONTH := 11
const START_DAY := 20
const MONTHS := ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]


## In-game calendar date for a story day: {"d", "m", "y"}.
static func game_date(story_day: int = 1) -> Dictionary:
	var unix := Time.get_unix_time_from_datetime_dict({"year": START_YEAR, "month": START_MONTH, "day": START_DAY, "hour": 12})
	var dt := Time.get_datetime_dict_from_unix_time(unix + (story_day - 1) * 86400)
	return {"d": int(dt["day"]), "m": int(dt["month"]), "y": int(dt["year"])}


## "29-08-1986" -> {"d": 29, "m": 8, "y": 1986}; {} if invalid.
static func parse_dmy(s: String) -> Dictionary:
	var parts := s.strip_edges().split("-")
	if parts.size() != 3 or not parts[0].is_valid_int() or not parts[1].is_valid_int() or not parts[2].is_valid_int():
		return {}
	return {"d": int(parts[0]), "m": int(parts[1]), "y": int(parts[2])}


## "06-2015" -> {"m": 6, "y": 2015}; {} if invalid.
static func parse_my(s: String) -> Dictionary:
	var parts := s.strip_edges().split("-")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return {}
	return {"m": int(parts[0]), "y": int(parts[1])}


## Completed years between a birth date and a reference date.
static func age_on(dob: Dictionary, on: Dictionary) -> int:
	if dob.is_empty() or on.is_empty():
		return -1
	var age: int = on["y"] - dob["y"]
	if on["m"] < dob["m"] or (on["m"] == dob["m"] and on["d"] < dob["d"]):
		age -= 1
	return age


## True if date a is strictly before date b (DD-MM-YYYY dictionaries).
static func is_before(a: Dictionary, b: Dictionary) -> bool:
	return [a["y"], a["m"], a["d"]] < [b["y"], b["m"], b["d"]]


static func format_long(d: Dictionary) -> String:
	if d.is_empty():
		return "—"
	return "%02d %s %d" % [d["d"], MONTHS[clampi(int(d["m"]) - 1, 0, 11)], d["y"]]


## "06-2015" -> "JUN 2015".
static func format_my(s: String) -> String:
	var d := parse_my(s)
	if d.is_empty():
		return s
	return "%s %d" % [MONTHS[clampi(int(d["m"]) - 1, 0, 11)], d["y"]]


## Minutes since midnight -> "10:15 PM".
static func clock_12h(minutes: int) -> String:
	var h := floori(minutes / 60.0) % 24
	var m := minutes % 60
	var suffix := "AM" if h < 12 else "PM"
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, m, suffix]
