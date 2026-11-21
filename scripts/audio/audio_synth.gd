class_name AudioSynth
extends RefCounted
## Procedurally synthesised placeholder sounds (16-bit mono AudioStreamWAV).
##
## AudioManager falls back to these when no recorded file exists for a sound id,
## so the game has a full soundscape with zero audio assets and no missing-file
## errors. Loops are built with whole-number cycles or a crossfaded seam so they
## repeat without clicks.

const RATE := 22050


static func has_sound(id: StringName) -> bool:
	return id in [
		&"ambience_office", &"computer_hum", &"rain", &"horror_drone", &"clock_tick",
		&"phone_ring", &"ringback", &"ui_click", &"ui_hover", &"ui_open", &"ui_close",
		&"paper", &"phone_pickup", &"phone_hangup", &"door", &"thunder", &"stinger",
		&"lamp_switch", &"keypress", &"boot",
	]


static func make(id: StringName) -> AudioStream:
	match id:
		&"ambience_office": return _room_tone()
		&"computer_hum": return _computer_hum()
		&"rain": return _rain()
		&"horror_drone": return _drone()
		&"clock_tick": return _clock()
		&"phone_ring": return _phone_ring()
		&"ringback": return _ringback()
		&"ui_click": return _click(1800.0, 0.05, 0.5)
		&"ui_hover": return _click(3200.0, 0.025, 0.12)
		&"keypress": return _click(900.0, 0.04, 0.35)
		&"lamp_switch": return _click(600.0, 0.06, 0.7)
		&"ui_open": return _sweep(260.0, 900.0, 0.28, 0.35)
		&"ui_close": return _sweep(800.0, 220.0, 0.22, 0.3)
		&"boot": return _sweep(120.0, 1400.0, 0.6, 0.25)
		&"paper": return _paper()
		&"phone_pickup": return _clunk(140.0, 0.12)
		&"phone_hangup": return _clunk(95.0, 0.18)
		&"door": return _door()
		&"thunder": return _thunder()
		&"stinger": return _stinger()
	return null


# --- Building blocks ----------------------------------------------------------

static func _buffer(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b


static func _to_wav(s: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(s.size() * 2)
	for i in s.size():
		bytes.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = s.size()
	return w


## Blends the last `fade` seconds into the start so a noise loop is seamless.
static func _seam(s: PackedFloat32Array, fade: float) -> PackedFloat32Array:
	var n := int(fade * RATE)
	var out := s.slice(0, s.size() - n)
	for i in n:
		var t := float(i) / float(n)
		out[i] = out[i] * t + s[s.size() - n + i] * (1.0 - t)
	return out


static func _normalize(s: PackedFloat32Array, peak: float) -> void:
	var m := 0.0001
	for v in s:
		m = maxf(m, absf(v))
	var k := peak / m
	for i in s.size():
		s[i] *= k


# --- Loops --------------------------------------------------------------------

static func _room_tone() -> AudioStreamWAV:
	var s := _buffer(4.5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var brown := 0.0
	var lp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		brown = (brown + 0.02 * rng.randf_range(-1.0, 1.0)) / 1.02
		lp += 0.08 * (brown - lp)
		# 50 Hz mains hum + harmonic: whole cycles over the loop length.
		s[i] = lp * 3.2 + sin(TAU * 50.0 * t) * 0.035 + sin(TAU * 100.0 * t) * 0.015
	s = _seam(s, 0.5)
	_normalize(s, 0.5)
	return _to_wav(s, true)


static func _computer_hum() -> AudioStreamWAV:
	var s := _buffer(3.25)
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var lp := 0.0
	var bp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var n := rng.randf_range(-1.0, 1.0)
		lp += 0.25 * (n - lp)
		bp += 0.05 * (lp - bp)
		s[i] = (lp - bp) * 0.5 + sin(TAU * 120.0 * t) * 0.12 + sin(TAU * 240.0 * t) * 0.04 + sin(TAU * 3000.0 * t) * 0.004
	s = _seam(s, 0.25)
	_normalize(s, 0.4)
	return _to_wav(s, true)


static func _rain() -> AudioStreamWAV:
	var s := _buffer(5.5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 37
	var lp := 0.0
	var lp2 := 0.0
	var drop := 0.0
	var drop_f := 0.0
	var phase := 0.0
	for i in s.size():
		var n := rng.randf_range(-1.0, 1.0)
		lp += 0.35 * (n - lp)
		lp2 += 0.02 * (lp - lp2)
		if rng.randf() < 0.0016:
			drop = rng.randf_range(0.15, 0.45)
			drop_f = rng.randf_range(1500.0, 4200.0)
		phase += TAU * drop_f / RATE
		drop *= 0.996
		s[i] = (lp - lp2) * 0.55 + lp2 * 0.9 + sin(phase) * drop * 0.25
	s = _seam(s, 0.5)
	_normalize(s, 0.55)
	return _to_wav(s, true)


static func _drone() -> AudioStreamWAV:
	var len_s := 8.0
	var s := _buffer(len_s)
	var rng := RandomNumberGenerator.new()
	rng.seed = 51
	var brown := 0.0
	# Frequencies chosen so freq * 8 s is an integer (seamless loop).
	var freqs := [55.0, 55.25, 82.5, 110.125, 164.875, 233.0]
	var amps := [0.32, 0.32, 0.16, 0.12, 0.05, 0.025]
	for i in s.size():
		var t := float(i) / RATE
		var v := 0.0
		for k in freqs.size():
			v += sin(TAU * freqs[k] * t) * amps[k]
		brown = (brown + 0.02 * rng.randf_range(-1.0, 1.0)) / 1.02
		var swell := 0.6 + 0.4 * sin(TAU * t / len_s - PI * 0.5)
		s[i] = v * swell + brown * 1.5
	s = _seam(s, 0.6)
	_normalize(s, 0.6)
	return _to_wav(s, true)


static func _clock() -> AudioStreamWAV:
	var s := _buffer(2.0)
	_add_tick(s, 0, 3300.0, 0.5)
	_add_tick(s, RATE, 2500.0, 0.42)
	return _to_wav(s, true)


static func _add_tick(s: PackedFloat32Array, at: int, freq: float, amp: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = at + 7
	var n := int(0.03 * RATE)
	for i in n:
		var t := float(i) / RATE
		var env := exp(-t * 260.0)
		s[at + i] += (sin(TAU * freq * t) * 0.7 + rng.randf_range(-1.0, 1.0) * 0.5) * env * amp


static func _phone_ring() -> AudioStreamWAV:
	# Double ring: 0.4 on, 0.2 off, 0.4 on, 2.0 off — a classic office handset trill.
	var s := _buffer(3.0)
	for i in s.size():
		var t := float(i) / RATE
		var on := (t < 0.4) or (t >= 0.6 and t < 1.0)
		if not on:
			continue
		var trill := 0.5 + 0.5 * signf(sin(TAU * 18.0 * t))
		var local_t := t if t < 0.4 else t - 0.6
		var env := minf(1.0, local_t * 60.0) * minf(1.0, (0.4 - local_t) * 60.0)
		s[i] = (sin(TAU * 800.0 * t) * 0.5 + sin(TAU * 1000.0 * t) * 0.35 + sin(TAU * 1600.0 * t) * 0.1) * trill * env * 0.6
	return _to_wav(s, true)


static func _ringback() -> AudioStreamWAV:
	var s := _buffer(3.0)
	for i in s.size():
		var t := float(i) / RATE
		var on := (t < 0.4) or (t >= 0.6 and t < 1.0)
		if on:
			s[i] = (sin(TAU * 400.0 * t) + sin(TAU * 450.0 * t)) * 0.18
	return _to_wav(s, true)


# --- One-shots ----------------------------------------------------------------

static func _click(freq: float, length: float, amp: float) -> AudioStreamWAV:
	var s := _buffer(length)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(freq)
	for i in s.size():
		var t := float(i) / RATE
		var env := exp(-t * 90.0)
		s[i] = (sin(TAU * freq * t) * 0.6 + rng.randf_range(-1.0, 1.0) * 0.4 * exp(-t * 400.0)) * env * amp
	return _to_wav(s, false)


static func _sweep(f0: float, f1: float, length: float, amp: float) -> AudioStreamWAV:
	var s := _buffer(length)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(f0 + f1)
	var phase := 0.0
	var lp := 0.0
	for i in s.size():
		var u := float(i) / s.size()
		var f := lerpf(f0, f1, u * u)
		phase += TAU * f / RATE
		lp += 0.1 * (rng.randf_range(-1.0, 1.0) - lp)
		var env := sin(PI * u) * (1.0 - u * 0.5)
		s[i] = (sin(phase) * 0.35 + lp * 0.9) * env * amp
	return _to_wav(s, false)


static func _paper() -> AudioStreamWAV:
	var s := _buffer(0.38)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var hp := 0.0
	var gate := 1.0
	for i in s.size():
		var u := float(i) / s.size()
		var n := rng.randf_range(-1.0, 1.0)
		hp += 0.3 * (n - hp)
		if rng.randf() < 0.004:
			gate = rng.randf_range(0.3, 1.0)
		s[i] = (n - hp) * gate * sin(PI * u) * 0.5
	return _to_wav(s, false)


static func _clunk(freq: float, length: float) -> AudioStreamWAV:
	var s := _buffer(length)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(freq)
	for i in s.size():
		var t := float(i) / RATE
		s[i] = (sin(TAU * freq * t) * exp(-t * 30.0) * 0.8 + rng.randf_range(-1.0, 1.0) * exp(-t * 180.0) * 0.5) * 0.7
	return _to_wav(s, false)


static func _door() -> AudioStreamWAV:
	var s := _buffer(1.6)
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	var phase := 0.0
	var lp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var v := 0.0
		if t < 1.1: # creak: wobbling sawtooth through a low-pass
			var f := 170.0 + 60.0 * sin(t * 7.0) + 25.0 * sin(t * 23.0)
			phase = fmod(phase + f / RATE, 1.0)
			lp += 0.06 * ((phase * 2.0 - 1.0) - lp)
			v += lp * 0.35 * sin(PI * t / 1.1)
		if t >= 1.15: # latch thud
			var tt := t - 1.15
			v += sin(TAU * 62.0 * tt) * exp(-tt * 14.0) * 0.9 + rng.randf_range(-1.0, 1.0) * exp(-tt * 70.0) * 0.4
		s[i] = v
	_normalize(s, 0.7)
	return _to_wav(s, false)


static func _thunder() -> AudioStreamWAV:
	var s := _buffer(4.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 101
	var brown := 0.0
	var crack := 0.0
	for i in s.size():
		var t := float(i) / RATE
		brown = (brown + 0.03 * rng.randf_range(-1.0, 1.0)) / 1.02
		crack += 0.4 * (rng.randf_range(-1.0, 1.0) - crack)
		var env := minf(1.0, t * 3.0) * exp(-t * 0.9) * (0.75 + 0.25 * sin(t * 9.0 + sin(t * 3.1) * 2.0))
		s[i] = brown * 4.0 * env + crack * exp(-t * 6.0) * 0.12
	_normalize(s, 0.85)
	return _to_wav(s, false)


static func _stinger() -> AudioStreamWAV:
	var s := _buffer(3.2)
	for i in s.size():
		var t := float(i) / RATE
		var boom := sin(TAU * (48.0 - t * 6.0) * t) * exp(-t * 1.6) * 0.8
		var shimmer := (sin(TAU * 1046.5 * t) + sin(TAU * 1108.7 * t) + sin(TAU * 1567.0 * t) * 0.5) * 0.08 * minf(1.0, t * 2.0) * exp(-t * 0.9)
		s[i] = boom + shimmer
	_normalize(s, 0.8)
	return _to_wav(s, false)
