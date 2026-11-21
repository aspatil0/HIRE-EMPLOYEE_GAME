extends Node
## Plays one-shot sounds and crossfading ambience/music loops by id.
##
## Sound ids resolve in this order:
##   1. A real file: res://assets/audio/{sfx,ambience,music}/<id>.(ogg|wav|mp3)
##   2. A synthesised placeholder from AudioSynth
##   3. Silence (logged once, never an error)
## So dropping e.g. assets/audio/ambience/rain.ogg in later replaces the
## placeholder with no code changes.
##
## Buses (created at runtime if the project has no bus layout):
##   Master -> Music, SFX, Ambience

const BUS_MUSIC := &"Music"
const BUS_SFX := &"SFX"
const BUS_AMBIENCE := &"Ambience"
const SEARCH_DIRS := ["res://assets/audio/sfx/", "res://assets/audio/ambience/", "res://assets/audio/music/"]
const EXTENSIONS := ["ogg", "wav", "mp3"]
const POOL_SIZE := 10

var _cache: Dictionary[StringName, AudioStream] = {}
var _missing_logged: Dictionary[StringName, bool] = {}
var _loops: Dictionary[StringName, AudioStreamPlayer] = {}
var _loop_tweens: Dictionary[StringName, Tween] = {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_next: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # UI sounds must play while paused
	for bus in [BUS_MUSIC, BUS_SFX, BUS_AMBIENCE]:
		_ensure_bus(bus)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.name = "Sfx%d" % i
		p.bus = BUS_SFX
		add_child(p)
		_pool.append(p)


func _ensure_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, &"Master")


# --- Stream lookup ------------------------------------------------------------

func get_stream(id: StringName) -> AudioStream:
	if _cache.has(id):
		return _cache[id]
	var stream: AudioStream = null
	for dir: String in SEARCH_DIRS:
		for ext: String in EXTENSIONS:
			var path := "%s%s.%s" % [dir, id, ext]
			if ResourceLoader.exists(path):
				stream = load(path) as AudioStream
				break
		if stream:
			break
	if stream == null and AudioSynth.has_sound(id):
		stream = AudioSynth.make(id)
	if stream == null and not _missing_logged.has(id):
		_missing_logged[id] = true
		print_verbose("AudioManager: no sound for '%s' (silent placeholder)" % id)
	_cache[id] = stream
	return stream


## Builds streams ahead of time (e.g. while the screen is faded to black).
func warm_up(ids: Array[StringName]) -> void:
	for id in ids:
		get_stream(id)


# --- One-shots ----------------------------------------------------------------

func play_sfx(id: StringName, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var stream := get_stream(id)
	if stream == null:
		return
	var p := _pool[_pool_next]
	_pool_next = (_pool_next + 1) % _pool.size()
	p.stop()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


# --- Loops --------------------------------------------------------------------

func play_loop(id: StringName, bus: StringName = BUS_AMBIENCE, volume_db: float = 0.0, fade: float = 1.5) -> void:
	var player: AudioStreamPlayer = _loops.get(id)
	if player == null:
		var stream := get_stream(id)
		if stream == null:
			return
		_make_looping(stream)
		player = AudioStreamPlayer.new()
		player.name = "Loop_%s" % id
		player.stream = stream
		add_child(player)
		_loops[id] = player
	player.bus = bus
	if not player.playing:
		player.volume_db = -60.0 if fade > 0.0 else volume_db
		player.play()
	_fade(id, player, volume_db, fade, false)


func stop_loop(id: StringName, fade: float = 1.5) -> void:
	var player: AudioStreamPlayer = _loops.get(id)
	if player == null:
		return
	_fade(id, player, -60.0, fade, true)


func is_loop_playing(id: StringName) -> bool:
	return _loops.has(id) and _loops[id].playing


func set_loop_volume(id: StringName, volume_db: float, fade: float = 0.5) -> void:
	var player: AudioStreamPlayer = _loops.get(id)
	if player:
		_fade(id, player, volume_db, fade, false)


## Crossfades to exactly this set of loops: {id: [bus, volume_db]}. Others fade out.
func set_soundscape(loops: Dictionary, fade: float = 2.0) -> void:
	for id: StringName in _loops.keys():
		if not loops.has(id):
			stop_loop(id, fade)
	for id: StringName in loops:
		var cfg: Array = loops[id]
		play_loop(id, cfg[0], cfg[1], fade)


func stop_all_loops(fade: float = 1.0) -> void:
	for id: StringName in _loops.keys():
		stop_loop(id, fade)


func _fade(id: StringName, player: AudioStreamPlayer, target_db: float, time: float, stop_after: bool) -> void:
	if _loop_tweens.has(id) and _loop_tweens[id].is_valid():
		_loop_tweens[id].kill()
	if time <= 0.0:
		player.volume_db = target_db
		if stop_after:
			player.stop()
		return
	var tw := create_tween()
	tw.tween_property(player, "volume_db", target_db, time).set_trans(Tween.TRANS_SINE)
	if stop_after:
		tw.tween_callback(player.stop)
	_loop_tweens[id] = tw


func _make_looping(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		if wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_end = wav.data.size() / (2 if wav.format == AudioStreamWAV.FORMAT_16_BITS else 1)
	elif "loop" in stream:
		stream.set("loop", true)
