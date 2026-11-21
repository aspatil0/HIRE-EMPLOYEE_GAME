extends Node2D
## Secondary terminal used for online investigation. Turned towards Alice,
## so it is drawn as a perspective quad; its pale browser screen is emissive.

# Outer bezel corners (top-left, top-right, bottom-right, bottom-left).
const OUTER := [Vector2(-168, -112), Vector2(150, -138), Vector2(150, 118), Vector2(-168, 100)]

var _screen: Node2D
var _time: float = 0.0
var _scroll: float = 0.0


func _ready() -> void:
	_screen = Node2D.new()
	_screen.name = "Screen"
	_screen.z_index = 60
	add_child(_screen)
	_screen.draw.connect(_draw_screen)


func _process(delta: float) -> void:
	_time += delta
	# The page occasionally "reloads", a subtle sign the machine is alive.
	var new_scroll := floorf(_time / 7.0)
	if new_scroll != _scroll:
		_scroll = new_scroll
		_screen.queue_redraw()


func _outer() -> PackedVector2Array:
	return PackedVector2Array(OUTER)


func _screen_quad() -> PackedVector2Array:
	var o := _outer()
	return Paint.quad_rect(o, Rect2(0.045, 0.06, 0.91, 0.86))


func _draw() -> void:
	var o := _outer()
	Paint.soft(self, Vector2(-4, 10), Vector2(230, 180), Color(0, 0, 0, 0.5))
	# Stand.
	var neck := PackedVector2Array([Vector2(-14, 100), Vector2(18, 100), Vector2(22, 168), Vector2(-16, 168)])
	Paint.poly_hgrad(self, neck, Color(0.24, 0.25, 0.26), Color(0.09, 0.09, 0.1))
	Paint.soft(self, Vector2(4, 182), Vector2(120, 22), Color(0, 0, 0, 0.6))
	Paint.ellipse(self, Vector2(2, 174), Vector2(84, 14), Color(0.17, 0.17, 0.18))
	draw_arc(Vector2(2, 174), 84.0, PI * 1.1, PI * 1.9, 20, Color(0.5, 0.52, 0.55, 0.3), 1.5, true)
	# Side thickness (far edge).
	Paint.quad(self, o[0] + Vector2(-12, 6), o[0], o[3], o[3] + Vector2(-12, -4), Color(0.06, 0.06, 0.065))
	Paint.poly_vgrad(self, o, Color(0.16, 0.165, 0.17), Color(0.08, 0.08, 0.085))
	var outline := o.duplicate()
	outline.append(o[0])
	draw_polyline(outline, Color(0, 0, 0, 0.8), 2.0, true)
	draw_line(o[0], o[1], Color(0.5, 0.52, 0.55, 0.4), 1.5)
	var sq := _screen_quad()
	draw_colored_polygon(Paint.quad_rect(o, Rect2(0.035, 0.045, 0.93, 0.89)), Color(0.02, 0.02, 0.025))
	# Sticky note on the bezel.
	var note := Paint.quad_rect(o, Rect2(0.82, 0.86, 0.14, 0.14))
	draw_colored_polygon(note, Color(0.9, 0.82, 0.4))
	draw_line(note[0].lerp(note[3], 0.4), note[1].lerp(note[2], 0.4), Color(0.2, 0.2, 0.3, 0.6), 1.0)
	draw_line(sq[3] + Vector2(10, 14), sq[3] + Vector2(40, 12), Color(0.4, 0.42, 0.45, 0.5), 1.0)


func _draw_screen() -> void:
	var s := _screen
	var q := _screen_quad()
	# Page background.
	s.draw_polygon(q, PackedColorArray([Color(0.84, 0.87, 0.89), Color(0.8, 0.84, 0.87), Color(0.7, 0.74, 0.77), Color(0.74, 0.78, 0.8)]))
	# Browser chrome.
	s.draw_colored_polygon(Paint.quad_rect(q, Rect2(0, 0, 1, 0.1)), Color(0.32, 0.35, 0.38))
	s.draw_colored_polygon(Paint.quad_rect(q, Rect2(0.02, 0.015, 0.22, 0.07)), Color(0.78, 0.81, 0.84))
	s.draw_colored_polygon(Paint.quad_rect(q, Rect2(0, 0.1, 1, 0.08)), Color(0.9, 0.92, 0.93))
	s.draw_colored_polygon(Paint.quad_rect(q, Rect2(0.12, 0.115, 0.75, 0.05)), Color(1, 1, 1))
	_line(q, 0.14, 0.14, 0.4, Color(0.3, 0.4, 0.55, 0.8), 1.5)
	# Search box and results.
	s.draw_colored_polygon(Paint.quad_rect(q, Rect2(0.08, 0.24, 0.62, 0.08)), Color(1, 1, 1))
	_line(q, 0.1, 0.28, 0.3, Color(0.2, 0.2, 0.25, 0.7), 1.5)
	s.draw_colored_polygon(Paint.quad_rect(q, Rect2(0.72, 0.24, 0.14, 0.08)), Color(0.55, 0.15, 0.13))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 + int(_scroll)
	for i in 4:
		var v := 0.4 + i * 0.13
		_line(q, 0.08, v, rng.randf_range(0.35, 0.55), Color(0.15, 0.3, 0.62, 0.9), 2.0)
		_line(q, 0.08, v + 0.04, rng.randf_range(0.5, 0.7), Color(0.35, 0.37, 0.4, 0.6), 1.2)
		_line(q, 0.08, v + 0.07, rng.randf_range(0.3, 0.6), Color(0.35, 0.37, 0.4, 0.6), 1.2)
	# A profile photo square that is just... dark.
	s.draw_colored_polygon(Paint.quad_rect(q, Rect2(0.76, 0.4, 0.17, 0.24)), Color(0.18, 0.19, 0.2))
	var head := Paint.quad_point(q[0], q[1], q[2], q[3], 0.845, 0.49)
	s.draw_circle(head, 7.0, Color(0.08, 0.08, 0.09))
	# Screen glare and vignette.
	s.draw_colored_polygon(Paint.quad_rect(q, Rect2(0.0, 0.0, 0.25, 1.0)), Color(1, 1, 1, 0.04))
	var bottom := Paint.quad_rect(q, Rect2(0, 0.8, 1, 0.2))
	s.draw_polygon(bottom, PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.18), Color(0, 0, 0, 0.18)]))


func _line(q: PackedVector2Array, u: float, v: float, length: float, col: Color, width: float) -> void:
	var a := Paint.quad_point(q[0], q[1], q[2], q[3], u, v)
	var b := Paint.quad_point(q[0], q[1], q[2], q[3], u + length, v)
	_screen.draw_line(a, b, col, width, true)
