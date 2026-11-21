class_name TelephoneProp
extends Node2D
## Multi-line office telephone. Shakes and flashes its message light while
## ringing; the handset disappears from the cradle during a call.

const BODY_TOP := Color(0.17, 0.17, 0.18)
const BODY_BOTTOM := Color(0.07, 0.07, 0.075)

var ringing: bool = false:
	set(v):
		ringing = v
		if _lcd:
			_lcd.queue_redraw()
		if not v:
			position = _rest_position
			rotation = 0.0
var off_hook: bool = false:
	set(v):
		off_hook = v
		queue_redraw()
var caller_label: String = ""

var _rest_position: Vector2
var _time: float = 0.0
var _lcd: Node2D


func _ready() -> void:
	_rest_position = position
	_lcd = Node2D.new()
	_lcd.name = "Display"
	_lcd.z_index = 60
	add_child(_lcd)
	_lcd.draw.connect(_draw_lcd)


func _process(delta: float) -> void:
	_time += delta
	if ringing:
		# Rattle only during the "on" part of the ring cadence.
		var phase := fmod(_time, 3.0)
		var on := phase < 0.4 or (phase >= 0.6 and phase < 1.0)
		position = _rest_position + (Vector2(randf_range(-1.6, 1.6), randf_range(-1.0, 1.0)) if on else Vector2.ZERO)
		rotation = randf_range(-0.006, 0.006) if on else 0.0
		_lcd.queue_redraw()


func _draw() -> void:
	Paint.soft(self, Vector2(10, 40), Vector2(200, 80), Color(0, 0, 0, 0.65))
	_draw_cord()
	# Body.
	var body := PackedVector2Array([Vector2(-96, -66), Vector2(96, -66), Vector2(126, 74), Vector2(-126, 74)])
	Paint.poly_vgrad(self, body, BODY_TOP, BODY_BOTTOM)
	Paint.quad_v(self, Vector2(-126, 74), Vector2(126, 74), Vector2(122, 88), Vector2(-122, 88), Color(0.06, 0.06, 0.065), Color(0.02, 0.02, 0.025))
	draw_line(Vector2(-96, -66), Vector2(96, -66), Color(0.45, 0.45, 0.48, 0.5), 1.5)
	# Sloped key panel.
	var panel := PackedVector2Array([Vector2(-86, 2), Vector2(86, 2), Vector2(108, 66), Vector2(-108, 66)])
	Paint.poly_vgrad(self, panel, Color(0.12, 0.12, 0.13), Color(0.09, 0.09, 0.1))
	for row in 4:
		for col in 3:
			var u := 0.3 + col * 0.15
			var v := 0.1 + row * 0.22
			var k := Paint.quad_rect(panel, Rect2(u, v, 0.11, 0.16))
			Paint.poly_vgrad(self, k, Color(0.62, 0.61, 0.58), Color(0.45, 0.44, 0.42))
	for row in 4:
		var k := Paint.quad_rect(panel, Rect2(0.06, 0.1 + row * 0.22, 0.16, 0.14))
		Paint.poly_vgrad(self, k, Color(0.3, 0.3, 0.32), Color(0.2, 0.2, 0.22))
		var k2 := Paint.quad_rect(panel, Rect2(0.78, 0.1 + row * 0.22, 0.16, 0.14))
		Paint.poly_vgrad(self, k2, Color(0.3, 0.3, 0.32), Color(0.2, 0.2, 0.22))
	# Display bezel.
	draw_rect(Rect2(-56, -18, 112, 22), Color(0.04, 0.04, 0.045))
	# Cradle.
	Paint.quad_v(self, Vector2(-92, -64), Vector2(92, -64), Vector2(88, -26), Vector2(-88, -26), Color(0.1, 0.1, 0.11), Color(0.13, 0.13, 0.14))
	if off_hook:
		for x in [-58.0, 58.0]:
			draw_rect(Rect2(x - 10, -50, 20, 10), Color(0.35, 0.35, 0.37))
	else:
		_draw_handset()


func _draw_handset() -> void:
	Paint.soft(self, Vector2(4, -34), Vector2(130, 30), Color(0, 0, 0, 0.6))
	var bar := PackedVector2Array([Vector2(-70, -68), Vector2(70, -68), Vector2(66, -46), Vector2(-66, -46)])
	Paint.poly_vgrad(self, bar, Color(0.19, 0.19, 0.2), Color(0.09, 0.09, 0.1))
	for x in [-74.0, 74.0]:
		Paint.ellipse(self, Vector2(x, -50), Vector2(30, 18), Color(0.08, 0.08, 0.09))
		Paint.ellipse(self, Vector2(x, -56), Vector2(28, 15), Color(0.17, 0.17, 0.18))
		draw_arc(Vector2(x, -56), 26.0, PI * 1.15, PI * 1.85, 12, Color(0.5, 0.5, 0.55, 0.4), 1.5, true)
	draw_line(Vector2(-60, -67), Vector2(60, -67), Color(0.5, 0.5, 0.55, 0.45), 1.5)


func _draw_cord() -> void:
	# Coiled cord from the handset's end, curling off the desk edge.
	var pts := PackedVector2Array()
	var start := Vector2(-110, -40)
	var end := Vector2(-200, 170)
	for i in 120:
		var t := i / 119.0
		var p := start.lerp(Vector2(-210, 10), t).lerp(Vector2(-210, 10).lerp(end, t), t)
		p += Vector2(cos(t * 70.0), sin(t * 70.0)) * 6.0
		pts.append(p)
	draw_polyline(pts, Color(0.05, 0.05, 0.055), 3.0, true)
	draw_polyline(pts, Color(0.3, 0.3, 0.33, 0.25), 1.0, true)


func _draw_lcd() -> void:
	var r := Rect2(-52, -15, 104, 16)
	var lit := ringing or off_hook
	Paint.vgrad(_lcd, r, Color(0.45, 0.6, 0.42) if lit else Color(0.2, 0.24, 0.19), Color(0.35, 0.5, 0.33) if lit else Color(0.15, 0.18, 0.14))
	var text := "LINE 1  IDLE"
	if ringing:
		text = "CALL: %s" % caller_label if fmod(_time, 1.0) < 0.6 else ""
	elif off_hook:
		text = "CONNECTED"
	_lcd.draw_string(UITheme.mono(), Vector2(r.position.x + 4, r.end.y - 3), text, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 8, 11, Color(0.05, 0.08, 0.05, 0.9))
	# Message light.
	var light_on := ringing and fmod(_time, 0.5) < 0.25
	_lcd.draw_circle(Vector2(76, -7), 5.0, Color(1.0, 0.15, 0.1) if light_on else Color(0.25, 0.06, 0.05))
	if light_on:
		Paint.soft(_lcd, Vector2(76, -7), Vector2(26, 26), Color(1.0, 0.2, 0.1, 0.6), true)
