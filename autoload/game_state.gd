extends Node
## Persistent run data: story flags, inventory, clues, location, clock and company stats.
##
## Pure data + change signals. No scene or UI logic lives here, so the whole state
## can be serialized with to_dict()/from_dict() for saving and debugging.
## File I/O for saves is handled by GameManager.

signal flag_changed(flag: StringName, value: Variant)
signal item_added(item_id: StringName)
signal item_removed(item_id: StringName)
signal clue_discovered(clue_id: StringName)
signal state_reset
signal time_changed(minutes: int)
signal stats_changed
signal objective_changed(text: String)

const SAVE_FORMAT_VERSION := 2
const START_TIME_MINUTES := 21 * 60 # shifts start at 21:00
const START_FUNDS := 4_800_000
const START_REPUTATION := 72

var flags: Dictionary[StringName, Variant] = {}
var inventory: Array[StringName] = []
var clues: Array[StringName] = []
var current_location: String = ""
var day: int = 1
## In-game clock, minutes since midnight of the current day.
var time_minutes: int = START_TIME_MINUTES
var objective: String = ""
# Company / recruitment stats (shown on the HUD and the main computer).
var candidates_pending: int = 0
var hires: int = 0
var hire_target: int = 3
var company_funds: int = START_FUNDS
var company_reputation: int = START_REPUTATION


func reset() -> void:
	flags.clear()
	inventory.clear()
	clues.clear()
	current_location = ""
	day = 1
	time_minutes = START_TIME_MINUTES
	objective = ""
	candidates_pending = 0
	hires = 0
	hire_target = 3
	company_funds = START_FUNDS
	company_reputation = START_REPUTATION
	state_reset.emit()


# --- Clock, objective and company stats ---------------------------------------

func advance_time(minutes: int = 1) -> void:
	time_minutes += minutes
	if time_minutes >= 24 * 60:
		time_minutes -= 24 * 60
	time_changed.emit(time_minutes)


func get_time_string() -> String:
	return "%02d:%02d" % [floori(time_minutes / 60.0), time_minutes % 60]


func set_objective(text: String) -> void:
	objective = text
	objective_changed.emit(text)


func set_candidates_pending(count: int) -> void:
	candidates_pending = maxi(count, 0)
	stats_changed.emit()


## Human-readable company condition derived from funds and reputation.
func get_company_status() -> String:
	if company_reputation >= 65 and company_funds >= 2_000_000:
		return "STABLE"
	if company_reputation >= 40 and company_funds >= 500_000:
		return "STRAINED"
	return "CRITICAL"


# --- Flags ------------------------------------------------------------------

func set_flag(flag: StringName, value: Variant = true) -> void:
	flags[flag] = value
	flag_changed.emit(flag, value)


func get_flag(flag: StringName, default: Variant = false) -> Variant:
	return flags.get(flag, default)


func is_flag_set(flag: StringName) -> bool:
	return bool(flags.get(flag, false))


# --- Inventory --------------------------------------------------------------

func add_item(item_id: StringName) -> void:
	if inventory.has(item_id):
		return
	inventory.append(item_id)
	item_added.emit(item_id)


func remove_item(item_id: StringName) -> void:
	if not inventory.has(item_id):
		return
	inventory.erase(item_id)
	item_removed.emit(item_id)


func has_item(item_id: StringName) -> bool:
	return inventory.has(item_id)


# --- Clues ------------------------------------------------------------------

func discover_clue(clue_id: StringName) -> void:
	if clues.has(clue_id):
		return
	clues.append(clue_id)
	clue_discovered.emit(clue_id)


func has_clue(clue_id: StringName) -> bool:
	return clues.has(clue_id)


# --- Serialization ----------------------------------------------------------

func to_dict() -> Dictionary:
	var flag_data := {}
	for key: StringName in flags:
		flag_data[String(key)] = flags[key]
	return {
		"version": SAVE_FORMAT_VERSION,
		"flags": flag_data,
		"inventory": _to_strings(inventory),
		"clues": _to_strings(clues),
		"current_location": current_location,
		"day": day,
		"time_minutes": time_minutes,
		"objective": objective,
		"candidates_pending": candidates_pending,
		"hires": hires,
		"hire_target": hire_target,
		"company_funds": company_funds,
		"company_reputation": company_reputation,
	}


## Restores state from to_dict() output. Note: JSON turns ints into floats,
## so numeric flags come back as float.
func from_dict(data: Dictionary) -> void:
	reset()
	var flag_data: Dictionary = data.get("flags", {})
	for key: String in flag_data:
		flags[StringName(key)] = flag_data[key]
	for item: String in data.get("inventory", []):
		inventory.append(StringName(item))
	for clue: String in data.get("clues", []):
		clues.append(StringName(clue))
	current_location = data.get("current_location", "")
	day = int(data.get("day", data.get("night", 1))) # v1 saves used "night"
	time_minutes = int(data.get("time_minutes", START_TIME_MINUTES))
	objective = str(data.get("objective", ""))
	candidates_pending = int(data.get("candidates_pending", 0))
	hires = int(data.get("hires", 0))
	hire_target = int(data.get("hire_target", 3))
	company_funds = int(data.get("company_funds", START_FUNDS))
	company_reputation = int(data.get("company_reputation", START_REPUTATION))
	time_changed.emit(time_minutes)
	stats_changed.emit()
	objective_changed.emit(objective)


func _to_strings(values: Array[StringName]) -> Array[String]:
	var out: Array[String] = []
	for v in values:
		out.append(String(v))
	return out
