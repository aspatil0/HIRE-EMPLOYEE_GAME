class_name DataLoader
extends RefCounted
## Read-only access to the JSON content under res://data/, cached per path.
## Missing or malformed files return empty data (with an error logged once),
## so UIs degrade to "no records" instead of crashing.

const CANDIDATES_PATH := "res://data/candidates/day%d_candidates.json"
const COMPANY_PATH := "res://data/company/company_day%d.json"

static var _cache: Dictionary[String, Dictionary] = {}


static func load_json(path: String) -> Dictionary:
	if _cache.has(path):
		return _cache[path]
	var data: Dictionary = {}
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			data = parsed
		else:
			push_error("DataLoader: invalid JSON in %s" % path)
	else:
		push_error("DataLoader: missing data file %s" % path)
	_cache[path] = data
	return data


static func candidates(day: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c: Variant in load_json(CANDIDATES_PATH % day).get("candidates", []):
		if c is Dictionary:
			out.append(c)
	return out


static func company(day: int) -> Dictionary:
	return load_json(COMPANY_PATH % day)
