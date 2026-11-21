class_name NightWindow
extends Node2D
## A window onto a rainy night city: skyline with lit windows, an aircraft
## beacon, drifting rain, droplets on the glass, lightning, blinds and frame.
##
## Static layers draw once; rain/flicker/lightning live on a child layer that
## redraws each frame. Reused by the main menu, the intro and Alice's office.
##
## Hook for later horror beats: trigger_event(&"silhouette") briefly shows a
## figure standing in a lit window across the street.

signal lightning_struck(strength: float)

@export var size: Vector2 = Vector2(680, 450)
@export var frame_width: float = 18.0
@export var mullions_x: int = 1
@export var mullions_y: int = 0
## Fraction of the window height covered by the lowered blinds.
@export_range(0.0, 1.0) var blinds: float = 0.22
@export var rain_count: int = 160
@export var seed_value: int = 7
@export var lightning_enabled: bool = true
@export var lightning_interval: Vector2 = Vector2(22.0, 50.0)
@export var skyline_scale: float = 1.0
@export var draw_frame: bool = true
@export var draw_sill: bool = true
@export var frame_color: Color = Color(0.1, 0.095, 0.09)

var _rng := RandomNumberGenerator.new()
var _far: Array[Dictionary] = []
var _near: Array[Dictionary] = []
var _flickers: Array[Dictionary] = []
var _rain: PackedVector3Array = PackedVector3Array()
var _drops: Array[Dictionary] = []
var _beacon: Vector2 = Vector2.ZERO
var _time: float = 0.0
var _flash: float = 0.0
var _next_lightning: float = 0.0
var _event_time: float = 0.0
var _event_spot: Rect2 = Rect2()

var _clip: Control
var _sky: Node2D
var _dynamic: Node2D
var _front: Node2D


func _ready() -> void:
	_rng.seed = seed_value
	_generate()
	# Everything seen through the glass is clipped to the window opening.
	_clip = Control.new()
	_clip.name = "Clip"
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.size = size
	add_child(_clip)
	_sky = Node2D.new()
	_sky.name = "Sky"
	_clip.add_child(_sky)
	_sky.draw.connect(_draw_sky)
	_dynamic = Node2D.new()
	_dynamic.name = "Dynamic"
	_clip.add_child(_dynamic)
	_dynamic.draw.connect(_draw_dynamic)
	_front = Node2D.new()
	_front.name = "Front"
	add_child(_front)
	_front.draw.connect(_draw_front)
	_next_lightning = _rng.randf_range(6.0, lightning_interval.x)


func _process(delta: float) -> void:
	_time += delta
	var fall := Vector2(-0.18, 1.0)
	for i in _rain.size():
		var r := _rain[i]
		r.y += r.z * delta
		r.x += r.z * fall.x * delta
		if r.y > size.y:
			r.y = _rng.randf_range(-60.0, -5.0)
			r.x = _rng.randf_range(0.0, size.x + 80.0)
		_rain[i] = r
	for d in _drops:
		if d["slide"] > 0.0:
			var p: Vector2 = d["pos"]
			p.y += float(d["slide"]) * delta
			if p.y > size.y:
				p = Vector2(_rng.randf_range(0, size.x), _rng.randf_range(0, size.y * 0.3))
			d["pos"] = p
	_flash = maxf(0.0, _flash - delta * 2.6)
	_event_time = maxf(0.0, _event_time - delta)
	if lightning_enabled:
		_next_lightning -= delta
		if _next_lightning <= 0.0:
			strike()
	_dynamic.queue_redraw()


## Triggers a lightning flash now.
func strike(strength: float = -1.0) -> void:
	if strength < 0.0:
		strength = _rng.randf_range(0.5, 1.0)
	_flash = strength
	_next_lightning = _rng.randf_range(lightning_interval.x, lightning_interval.y)
	lightning_struck.emit(strength)


## Plays a scripted visual event in the window. Supported: &"silhouette".
func trigger_event(event_name: StringName, duration: float = 1.6) -> void:
	if event_name == &"silhouette" and not _near.is_empty():
		var b: Dictionary = _near[_rng.randi() % _near.size()]
		var r: Rect2 = b["rect"]
		_event_spot = Rect2(r.position + Vector2(r.size.x * 0.5 - 9, 20), Vector2(18, 26))
		_event_time = duration


# --- Generation ---------------------------------------------------------------

func _generate() -> void:
	_far = _make_row(size.y * 0.32, size.y * 0.72, 26.0, 70.0, 0.16)
	_near = _make_row(size.y * 0.18, size.y * 0.5, 60.0, 150.0, 0.09)
	var tallest: Dictionary = {}
	for b in _far:
		if tallest.is_empty() or (b["rect"] as Rect2).position.y < (tallest["rect"] as Rect2).position.y:
			tallest = b
	if not tallest.is_empty():
		var tr: Rect2 = tallest["rect"]
		_beacon = Vector2(tr.get_center().x, tr.position.y - 14.0)
	for b in _far + _near:
		for w: Dictionary in b["windows"]:
			if _rng.randf() < 0.08:
				_flickers.append(w)
	for i in rain_count:
		_rain.append(Vector3(_rng.randf_range(0, size.x + 80), _rng.randf_range(0, size.y), _rng.randf_range(700.0, 1100.0)))
	for i in int(size.x * size.y / 5200.0):
		var big := _rng.randf() < 0.25
		_drops.append({
			"pos": Vector2(_rng.randf_range(0, size.x), _rng.randf_range(0, size.y)),
			"r": _rng.randf_range(2.5, 5.5) if big else _rng.randf_range(1.0, 2.4),
			"slide": _rng.randf_range(8.0, 40.0) if big and _rng.randf() < 0.5 else 0.0,
		})


func _make_row(min_h: float, max_h: float, min_w: float, max_w: float, lit_chance: float) -> Array[Dictionary]:
	var row: Array[Dictionary] = []
	var x := -20.0
	while x < size.x + 20.0:
		var w := _rng.randf_range(min_w, max_w) * skyline_scale
		var h := _rng.randf_range(min_h, max_h) * skyline_scale
		var rect := Rect2(x, size.y - h, w, h + 4.0)
		var windows: Array[Dictionary] = []
		var cols := maxi(1, int((w - 10.0) / 11.0))
		var rows := maxi(1, int((h - 16.0) / 15.0))
		for cx in cols:
			for cy in rows:
				if _rng.randf() < lit_chance:
					var warm := _rng.randf() < 0.65
					var col := Color(1.0, 0.78, 0.48) if warm else Color(0.62, 0.78, 0.95)
					col.a = _rng.randf_range(0.35, 0.95)
					windows.append({
						"rect": Rect2(rect.position + Vector2(6.0 + cx * 11.0, 10.0 + cy * 15.0), Vector2(5, 8) * skyline_scale),
						"color": col, "phase": _rng.randf() * TAU,
					})
		row.append({"rect": rect, "windows": windows, "antenna": _rng.randf() < 0.2})
		x += w + _rng.randf_range(-6.0, 4.0)
	return row


# --- Drawing ------------------------------------------------------------------

func _draw_sky() -> void:
	var s := _sky
	var inner := Rect2(Vector2.ZERO, size)
	# Sky: near-black navy fading to a sodium-lit haze over the city.
	Paint.vgrad(s, Rect2(0, 0, size.x, size.y * 0.6), Color(0.015, 0.02, 0.04), Color(0.06, 0.055, 0.08))
	Paint.vgrad(s, Rect2(0, size.y * 0.6, size.x, size.y * 0.4), Color(0.06, 0.055, 0.08), Color(0.16, 0.1, 0.09))
	Paint.soft(s, Vector2(size.x * 0.5, size.y * 1.05), Vector2(size.x * 0.7, size.y * 0.45), Color(0.55, 0.3, 0.18, 0.28))
	# A moon smothered by cloud.
	Paint.soft(s, Vector2(size.x * 0.78, size.y * 0.16), Vector2(90, 90) * skyline_scale, Color(0.55, 0.6, 0.75, 0.16))
	Paint.soft(s, Vector2(size.x * 0.78, size.y * 0.16), Vector2(14, 14) * skyline_scale, Color(0.8, 0.82, 0.9, 0.35), true)
	var cloud_rng := RandomNumberGenerator.new()
	cloud_rng.seed = seed_value + 3
	for i in 9:
		var c := Vector2(cloud_rng.randf_range(0, size.x), cloud_rng.randf_range(0, size.y * 0.35))
		Paint.soft(s, c, Vector2(cloud_rng.randf_range(120, 260), cloud_rng.randf_range(25, 50)) * skyline_scale, Color(0.0, 0.0, 0.01, 0.55))

	_draw_row(s, _far, Color(0.045, 0.05, 0.075), 0.75)
	# Haze between layers.
	Paint.vgrad(s, Rect2(0, size.y * 0.55, size.x, size.y * 0.45), Color(0.1, 0.08, 0.1, 0.0), Color(0.16, 0.12, 0.13, 0.45))
	_draw_row(s, _near, Color(0.02, 0.022, 0.032), 1.0)
	Paint.vgrad(s, Rect2(0, size.y * 0.82, size.x, size.y * 0.18), Color(0.1, 0.08, 0.09, 0.0), Color(0.12, 0.09, 0.09, 0.5))
	# Glass: faint diagonal reflection band.
	var g := PackedVector2Array([
		Vector2(size.x * 0.15, 0), Vector2(size.x * 0.32, 0),
		Vector2(size.x * 0.12, size.y), Vector2(-size.x * 0.05, size.y)])
	s.draw_colored_polygon(g, Color(0.7, 0.8, 1.0, 0.025))
	s.draw_rect(inner, Color(0.2, 0.25, 0.32, 0.06))


func _draw_row(s: CanvasItem, row: Array[Dictionary], base: Color, light_mult: float) -> void:
	for b in row:
		var r: Rect2 = b["rect"]
		Paint.vgrad(s, r, base.lightened(0.04), base)
		s.draw_line(r.position, Vector2(r.position.x, r.end.y), Color(1, 1, 1, 0.025), 1.0)
		if b["antenna"]:
			s.draw_line(Vector2(r.get_center().x, r.position.y), Vector2(r.get_center().x, r.position.y - 18.0), base.lightened(0.05), 2.0)
		for w: Dictionary in b["windows"]:
			var c: Color = w["color"]
			c.a *= light_mult
			s.draw_rect(w["rect"], c)


func _draw_dynamic() -> void:
	var d := _dynamic
	# Flickering apartment windows.
	for w in _flickers:
		var on := sin(_time * 0.7 + float(w["phase"])) > 0.2 or fmod(_time + float(w["phase"]), 5.0) < 0.1
		if not on:
			d.draw_rect(w["rect"], Color(0.03, 0.03, 0.045))
	# Scripted event: a figure in a lit window, watching.
	if _event_time > 0.0:
		var a := clampf(_event_time, 0.0, 0.6) / 0.6
		d.draw_rect(_event_spot, Color(1.0, 0.82, 0.55, 0.9 * a))
		var head := _event_spot.position + Vector2(_event_spot.size.x * 0.5, 8)
		d.draw_circle(head, 3.4, Color(0, 0, 0, a))
		d.draw_rect(Rect2(head + Vector2(-5, 3), Vector2(10, _event_spot.size.y - 11)), Color(0, 0, 0, a))
	# Aircraft beacon.
	if _beacon != Vector2.ZERO:
		var blink := maxf(0.0, sin(_time * 2.2))
		Paint.soft(d, _beacon, Vector2(16, 16), Color(1.0, 0.15, 0.1, 0.55 * blink), true)
		d.draw_circle(_beacon, 1.8, Color(1.0, 0.3, 0.25, 0.4 + 0.6 * blink))
	# Rain.
	var streak := Vector2(-0.18, 1.0).normalized()
	for r in _rain:
		var p := Vector2(r.x, r.y)
		var streak_len := r.z * 0.035
		var a := p
		var b := p + streak * streak_len
		if b.y < 0.0 or a.y > size.y or a.x < 0.0 or b.x > size.x or b.x < 0.0:
			continue
		a.y = maxf(a.y, 0.0)
		b.y = minf(b.y, size.y)
		d.draw_line(a, b, Color(0.65, 0.72, 0.85, 0.16), 1.0)
	# Droplets on glass.
	for drop in _drops:
		var pos: Vector2 = drop["pos"]
		var rad: float = drop["r"]
		d.draw_circle(pos, rad, Color(0.04, 0.05, 0.07, 0.35))
		d.draw_circle(pos + Vector2(-rad * 0.3, -rad * 0.3), rad * 0.35, Color(0.8, 0.85, 0.95, 0.22))
		if drop["slide"] > 0.0:
			d.draw_line(pos - Vector2(0, rad * 6.0), pos - Vector2(0, rad), Color(0.6, 0.7, 0.85, 0.06), rad * 0.8)
	# Lightning.
	if _flash > 0.0:
		d.draw_rect(Rect2(Vector2.ZERO, size), Color(0.78, 0.84, 1.0, 0.55 * _flash * _flash))


func _draw_front() -> void:
	var f := _front
	# Venetian blinds, lowered from the top.
	if blinds > 0.0:
		var bottom := size.y * blinds
		var y := 0.0
		while y < bottom:
			var h := minf(15.0, bottom - y)
			Paint.vgrad(f, Rect2(0, y, size.x, h), Color(0.34, 0.32, 0.29), Color(0.18, 0.17, 0.155))
			f.draw_line(Vector2(0, y + h), Vector2(size.x, y + h), Color(0, 0, 0, 0.5), 1.0)
			y += 18.0
		Paint.vgrad(f, Rect2(0, bottom - 2.0, size.x, 9.0), Color(0.3, 0.28, 0.25), Color(0.12, 0.11, 0.1))
		f.draw_line(Vector2(size.x * 0.12, bottom + 7.0), Vector2(size.x * 0.12, bottom + 70.0), Color(0.5, 0.47, 0.42, 0.7), 1.5)
		f.draw_circle(Vector2(size.x * 0.12, bottom + 72.0), 3.0, Color(0.45, 0.42, 0.38))
	if not draw_frame:
		return
	var fw := frame_width
	var fc := frame_color
	var hi := fc.lightened(0.18)
	# Outer frame.
	Paint.vgrad(f, Rect2(-fw, -fw, size.x + fw * 2, fw), fc.lightened(0.05), fc)
	Paint.hgrad(f, Rect2(-fw, 0, fw, size.y), fc, fc.darkened(0.2))
	Paint.hgrad(f, Rect2(size.x, 0, fw, size.y), fc.darkened(0.25), fc)
	Paint.vgrad(f, Rect2(-fw, size.y, size.x + fw * 2, fw * 0.6), fc, fc.darkened(0.3))
	f.draw_rect(Rect2(-fw, -fw, size.x + fw * 2, size.y + fw * 1.6), Color(0, 0, 0, 0.7), false, 2.0)
	f.draw_line(Vector2(0, 0), Vector2(size.x, 0), Color(0, 0, 0, 0.6), 3.0)
	f.draw_line(Vector2(-fw, -fw + 1), Vector2(size.x + fw, -fw + 1), hi, 1.0)
	# Mullions.
	var mw := fw * 0.55
	for i in mullions_x:
		var x := size.x * float(i + 1) / float(mullions_x + 1)
		Paint.hgrad(f, Rect2(x - mw * 0.5, 0, mw, size.y), fc.lightened(0.06), fc.darkened(0.2))
	for i in mullions_y:
		var y := size.y * float(i + 1) / float(mullions_y + 1)
		Paint.vgrad(f, Rect2(0, y - mw * 0.5, size.x, mw), fc.lightened(0.06), fc.darkened(0.2))
	if draw_sill:
		var sill := Rect2(-fw - 22.0, size.y + fw * 0.6, size.x + fw * 2 + 44.0, 16.0)
		Paint.vgrad(f, sill, Color(0.2, 0.18, 0.16), Color(0.1, 0.09, 0.085))
		f.draw_line(sill.position, Vector2(sill.end.x, sill.position.y), Color(0.42, 0.38, 0.33, 0.6), 1.5)
		Paint.vgrad(f, Rect2(sill.position.x + 6.0, sill.end.y, sill.size.x - 12.0, 14.0), Color(0, 0, 0, 0.5), Color(0, 0, 0, 0))
