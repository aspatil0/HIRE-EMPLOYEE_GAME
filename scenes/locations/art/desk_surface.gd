extends Node2D
## Alice's desk top seen from her chair, plus non-interactive clutter
## (blotter, mug with steam, pen cup, notepad, sticky notes).

const TOP_BACK := Color(0.46, 0.31, 0.2)
const TOP_FRONT := Color(0.33, 0.21, 0.13)

var _steam_time: float = 0.0
var _steam: Node2D


func _ready() -> void:
	_steam = Node2D.new()
	_steam.name = "Steam"
	add_child(_steam)
	_steam.draw.connect(_draw_steam)


func _process(delta: float) -> void:
	_steam_time += delta
	_steam.queue_redraw()


func _draw() -> void:
	# Contact shadow where the desk meets the wall.
	Paint.vgrad(self, Rect2(0, 570, 1920, 34), Color(0, 0, 0, 0), Color(0, 0, 0, 0.6))
	# Desk top.
	Paint.vgrad(self, Rect2(0, 602, 1920, 440), TOP_BACK, TOP_FRONT)
	Paint.wood_grain(self, Rect2(0, 606, 1920, 430), Color(0.12, 0.06, 0.03, 0.32), 38, 1234)
	Paint.wood_grain(self, Rect2(0, 606, 1920, 430), Color(0.7, 0.5, 0.32, 0.06), 14, 99)
	draw_line(Vector2(0, 603), Vector2(1920, 603), Color(0.7, 0.52, 0.36, 0.55), 2.0)
	# Front edge (bullnose).
	Paint.vgrad(self, Rect2(0, 1036, 1920, 44), Color(0.38, 0.25, 0.16), Color(0.12, 0.07, 0.04))
	draw_line(Vector2(0, 1036), Vector2(1920, 1036), Color(0.75, 0.55, 0.38, 0.45), 2.0)

	_draw_blotter()
	_draw_pen_cup(Vector2(590, 660))
	_draw_notepad(Vector2(625, 965))
	_draw_mug(Vector2(606, 800))
	_draw_sticky(Vector2(1255, 640), -0.12, Color(0.92, 0.82, 0.38))
	_draw_sticky(Vector2(1290, 662), 0.18, Color(0.88, 0.6, 0.62))
	_draw_crumpled(Vector2(1470, 992))


func _draw_blotter() -> void:
	var pts := PackedVector2Array([Vector2(660, 748), Vector2(1262, 748), Vector2(1296, 1000), Vector2(626, 1000)])
	Paint.soft(self, Vector2(961, 880), Vector2(380, 150), Color(0, 0, 0, 0.35))
	Paint.poly_vgrad(self, pts, Color(0.12, 0.14, 0.13), Color(0.07, 0.085, 0.08))
	var inner := PackedVector2Array([Vector2(672, 758), Vector2(1250, 758), Vector2(1282, 990), Vector2(640, 990), Vector2(672, 758)])
	draw_polyline(inner, Color(0.45, 0.42, 0.33, 0.25), 1.0, true)
	draw_line(pts[0], pts[1], Color(0.4, 0.42, 0.38, 0.35), 1.5)


func _draw_pen_cup(p: Vector2) -> void:
	Paint.soft(self, p + Vector2(8, 52), Vector2(46, 14), Color(0, 0, 0, 0.6))
	var pens := [[Vector2(-10, 0), Vector2(-26, -72), Color(0.1, 0.12, 0.3)], [Vector2(0, 0), Vector2(6, -84), Color(0.75, 0.12, 0.1)],
		[Vector2(10, 0), Vector2(30, -66), Color(0.85, 0.75, 0.2)], [Vector2(4, 0), Vector2(-6, -60), Color(0.15, 0.15, 0.15)]]
	for pen in pens:
		draw_line(p + pen[0], p + pen[1], pen[2], 5.0, true)
		draw_line(p + pen[0] + Vector2(-1, 0), p + pen[1] + Vector2(-1, 0), Color(1, 1, 1, 0.15), 1.0, true)
	var body := PackedVector2Array([p + Vector2(-28, 0), p + Vector2(28, 0), p + Vector2(25, 52), p + Vector2(-25, 52)])
	Paint.poly_hgrad(self, body, Color(0.22, 0.23, 0.25), Color(0.08, 0.085, 0.09))
	Paint.ellipse(self, p, Vector2(28, 7), Color(0.05, 0.05, 0.06))
	draw_arc(p, 28.0, 0.0, PI, 16, Color(0.45, 0.47, 0.5, 0.6), 1.5, true)


func _draw_notepad(c: Vector2) -> void:
	draw_set_transform(c, -0.09, Vector2.ONE)
	Paint.soft(self, Vector2(6, 10), Vector2(110, 80), Color(0, 0, 0, 0.5))
	var r := Rect2(-80, -62, 160, 124)
	draw_rect(r, Color(0.86, 0.8, 0.55))
	for i in 9:
		draw_line(Vector2(r.position.x + 6, r.position.y + 22 + i * 11), Vector2(r.end.x - 6, r.position.y + 22 + i * 11), Color(0.4, 0.5, 0.65, 0.35), 1.0)
	draw_line(Vector2(r.position.x + 22, r.position.y), Vector2(r.position.x + 22, r.end.y), Color(0.8, 0.3, 0.3, 0.4), 1.0)
	Paint.vgrad(self, Rect2(r.position.x, r.position.y, r.size.x, 10), Color(0.45, 0.15, 0.12), Color(0.3, 0.1, 0.08))
	# Scribbles: names crossed out.
	var font := UITheme.serif()
	draw_string(font, Vector2(-50, -20), "ask Aditya re: last qtr?", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.15, 0.15, 0.3, 0.85))
	draw_string(font, Vector2(-50, 2), "3 seats. 6 names.", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.15, 0.15, 0.3, 0.85))
	draw_string(font, Vector2(-50, 24), "who signed the old files", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.15, 0.15, 0.3, 0.85))
	draw_line(Vector2(-52, 20), Vector2(68, 22), Color(0.15, 0.15, 0.3, 0.7), 1.2)
	# Pen lying across it.
	draw_line(Vector2(-60, 54), Vector2(96, 18), Color(0.08, 0.08, 0.09), 6.0, true)
	draw_line(Vector2(76, 23), Vector2(96, 18), Color(0.7, 0.62, 0.35), 6.0, true)
	Paint.reset_transform(self)


func _draw_mug(p: Vector2) -> void:
	Paint.soft(self, p + Vector2(14, 62), Vector2(64, 18), Color(0, 0, 0, 0.6))
	# Handle.
	draw_arc(p + Vector2(34, 30), 18.0, -PI * 0.5, PI * 0.5, 16, Color(0.6, 0.57, 0.52), 7.0, true)
	var body := PackedVector2Array([p + Vector2(-34, 0), p + Vector2(34, 0), p + Vector2(31, 64), p + Vector2(-31, 64)])
	Paint.poly_hgrad(self, body, Color(0.82, 0.79, 0.73), Color(0.42, 0.4, 0.37))
	Paint.ellipse(self, p + Vector2(0, 64), Vector2(31, 7), Color(0.4, 0.38, 0.35))
	draw_rect(Rect2(p + Vector2(-34, 18), Vector2(68, 9)), Color(0.55, 0.14, 0.12, 0.85))
	Paint.ellipse(self, p, Vector2(34, 9), Color(0.85, 0.83, 0.78))
	Paint.ellipse(self, p + Vector2(0, 1), Vector2(29, 7), Color(0.13, 0.07, 0.04))
	Paint.ellipse(self, p + Vector2(-6, 0), Vector2(10, 2), Color(0.4, 0.28, 0.2, 0.5))


func _draw_steam() -> void:
	var base := Vector2(606, 788)
	for i in 3:
		var pts := PackedVector2Array()
		var phase := _steam_time * 0.9 + i * 2.1
		for k in 14:
			var y := -k * 9.0
			var x := sin(phase + k * 0.45) * (4.0 + k * 1.2) + (i - 1) * 9.0
			pts.append(base + Vector2(x, y))
		var a := 0.05 + 0.03 * sin(_steam_time * 0.7 + i)
		_steam.draw_polyline(pts, Color(0.9, 0.9, 0.95, a), 5.0, true)


func _draw_sticky(c: Vector2, rot: float, col: Color) -> void:
	draw_set_transform(c, rot, Vector2.ONE)
	Paint.soft(self, Vector2(3, 5), Vector2(34, 34), Color(0, 0, 0, 0.4))
	Paint.vgrad(self, Rect2(-24, -24, 48, 48), col.darkened(0.05), col)
	Paint.text_lines(self, Vector2(-17, -12), 34.0, 8.0, 3, Color(0.2, 0.2, 0.3, 0.6), int(c.x), 1.2)
	Paint.reset_transform(self)


func _draw_crumpled(c: Vector2) -> void:
	Paint.soft(self, c + Vector2(6, 14), Vector2(34, 12), Color(0, 0, 0, 0.5))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var pts := PackedVector2Array()
	for i in 14:
		var a := TAU * i / 14.0
		pts.append(c + Vector2(cos(a), sin(a) * 0.85) * rng.randf_range(18.0, 26.0))
	Paint.poly_vgrad(self, pts, Color(0.88, 0.86, 0.8), Color(0.55, 0.53, 0.49))
	for i in 5:
		var a := c + Vector2(rng.randf_range(-14, 14), rng.randf_range(-12, 12))
		draw_line(a, a + Vector2(rng.randf_range(-10, 10), rng.randf_range(-8, 8)), Color(0.4, 0.38, 0.35, 0.6), 1.0)
