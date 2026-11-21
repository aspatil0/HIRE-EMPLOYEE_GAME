extends Node
## Player preferences (volume per bus, fullscreen), persisted to user://settings.cfg.
## Also installs the shared UI theme on the root window so every Control uses it.
## Loaded after AudioManager, which creates the audio buses.

signal settings_changed

const PATH := "user://settings.cfg"
const BUSES: Array[StringName] = [&"Master", &"Music", &"SFX", &"Ambience"]

var volumes: Dictionary[StringName, float] = {
	&"Master": 0.85,
	&"Music": 0.7,
	&"SFX": 0.8,
	&"Ambience": 0.75,
}
var fullscreen: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_install_theme()
	load_settings()
	_apply_all()


## Merges the game theme into Godot's default theme. A theme set on the root
## Window does not reach Controls under a CanvasLayer (propagation stops at
## non-Control nodes), but the default theme is the fallback for every Control.
func _install_theme() -> void:
	var game_theme := UITheme.get_theme()
	var default_theme := ThemeDB.get_default_theme()
	default_theme.merge_with(game_theme)
	default_theme.default_font = game_theme.default_font
	default_theme.default_font_size = game_theme.default_font_size


func set_volume(bus: StringName, value: float) -> void:
	volumes[bus] = clampf(value, 0.0, 1.0)
	_apply_volume(bus)
	settings_changed.emit()


func get_volume(bus: StringName) -> float:
	return volumes.get(bus, 1.0)


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	_apply_window()
	settings_changed.emit()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for bus in BUSES:
		cfg.set_value("audio", String(bus), volumes[bus])
	cfg.set_value("display", "fullscreen", fullscreen)
	var err := cfg.save(PATH)
	if err != OK:
		push_warning("GameSettings: could not save settings (%s)" % error_string(err))


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return # first launch: keep defaults
	for bus in BUSES:
		volumes[bus] = clampf(float(cfg.get_value("audio", String(bus), volumes[bus])), 0.0, 1.0)
	fullscreen = bool(cfg.get_value("display", "fullscreen", fullscreen))


func _apply_all() -> void:
	for bus in BUSES:
		_apply_volume(bus)
	_apply_window()


func _apply_volume(bus: StringName) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx == -1:
		return
	var v: float = volumes[bus]
	AudioServer.set_bus_mute(idx, v <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.001)))


func _apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var target := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != target:
		DisplayServer.window_set_mode(target)


func _unhandled_input(event: InputEvent) -> void:
	# F11 toggles fullscreen anywhere.
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_F11:
		set_fullscreen(not fullscreen)
		save_settings()
		get_viewport().set_input_as_handled()
