class_name MainComputerProp
extends Node2D
## Main workstation: monitor running the recruitment management system,
## keyboard and mouse. The screen is an emissive child drawn above the
## LightingRig so it glows in the dark office.

const SCREEN := Rect2(-238, -153, 476, 282)
const BEZEL := Rect2(-256, -172, 512, 334)

var _screen: Node2D
var _blink: float = 0.0
var _cursor_on: bool = true


func _ready() -> void:
	_screen = Node2D.new()
	_screen.name = "Screen"
	_screen.z_index = 60
	add_child(_screen)
	_screen.draw.connect(_draw_screen)


func _process(delta: float) -> void:
	_blink += delta
	if _blink >= 0.55:
		_blink = 0.0
		_cursor_on = not _cursor_on
		_screen.queue_redraw()


func _draw() -> void:
	# Shadow cast on the wall/window behind.
	Paint.soft(self, Vector2(10, 10), Vector2(340, 240), Color(0, 0, 0, 0.5))
	_draw_stand()
	# Bezel.
	var bezel := Paint.rounded_rect_points(BEZEL, 10.0)
	Paint.poly_vgrad(self, bezel, Color(0.17, 0.18, 0.19), Color(0.08, 0.085, 0.09))
	bezel.append(bezel[0])
	draw_polyline(bezel, Color(0, 0, 0, 0.8), 2.0, true)
	draw_line(BEZEL.position + Vector2(10, 1), Vector2(BEZEL.end.x - 10, BEZEL.position.y + 1), Color(0.5, 0.52, 0.55, 0.45), 1.5)
	draw_rect(SCREEN.grow(3), Color(0.02, 0.02, 0.025))
	# Chin logo.
	draw_string(UITheme.sans_spaced(), Vector2(-60, BEZEL.end.y - 12), "ASHGROVE", HORIZONTAL_ALIGNMENT_CENTER, 120, 11, Color(0.5, 0.52, 0.55, 0.6))
	_draw_keyboard()
	_draw_mouse(Vector2(276, 394))


func _draw_stand() -> void:
	var neck := PackedVector2Array([Vector2(-26, 150), Vector2(26, 150), Vector2(32, 232), Vector2(-32, 232)])
	Paint.poly_hgrad(self, neck, Color(0.26, 0.27, 0.29), Color(0.1, 0.1, 0.11))
	Paint.soft(self, Vector2(6, 246), Vector2(180, 30), Color(0, 0, 0, 0.6))
	Paint.ellipse(self, Vector2(0, 238), Vector2(122, 20), Color(0.08, 0.08, 0.09))
	Paint.ellipse(self, Vector2(0, 234), Vector2(118, 17), Color(0.2, 0.21, 0.22))
	draw_arc(Vector2(0, 234), 118.0, PI * 1.08, PI * 1.92, 24, Color(0.55, 0.57, 0.6, 0.35), 1.5, true)


func _draw_keyboard() -> void:
	var back_y := 336.0
	var front_y := 418.0
	var a := Vector2(-226, back_y)
	var b := Vector2(226, back_y)
	var c := Vector2(246, front_y)
	var d := Vector2(-246, front_y)
	Paint.soft(self, Vector2(8, front_y - 20), Vector2(300, 60), Color(0, 0, 0, 0.55))
	# Front lip.
	Paint.quad_v(self, d, c, c + Vector2(0, 12), d + Vector2(0, 12), Color(0.1, 0.1, 0.11), Color(0.04, 0.04, 0.045))
	var body := PackedVector2Array([a, b, c, d])
	Paint.poly_vgrad(self, body, Color(0.15, 0.15, 0.16), Color(0.1, 0.1, 0.11))
	draw_line(a, b, Color(0.4, 0.4, 0.42, 0.5), 1.0)
	var q := PackedVector2Array([a + Vector2(12, 8), b + Vector2(-12, 8), c + Vector2(-14, -8), d + Vector2(14, -8)])
	var rows := 5
	var cols := 15
	for row in rows:
		var v0 := float(row) / rows
		var v1 := float(row + 1) / rows - 0.03
		if row == rows - 1:
			# Space bar row.
			_key(q, Rect2(0.0, v0, 0.12, v1 - v0))
			_key(q, Rect2(0.13, v0, 0.1, v1 - v0))
			_key(q, Rect2(0.24, v0, 0.5, v1 - v0))
			_key(q, Rect2(0.75, v0, 0.12, v1 - v0))
			_key(q, Rect2(0.88, v0, 0.12, v1 - v0))
			continue
		for col in cols:
			var u0 := float(col) / cols
			_key(q, Rect2(u0, v0, 1.0 / cols - 0.008, v1 - v0))


func _key(q: PackedVector2Array, r: Rect2) -> void:
	var pts := Paint.quad_rect(q, r)
	Paint.poly_vgrad(self, pts, Color(0.27, 0.27, 0.29), Color(0.17, 0.17, 0.18))
	draw_line(pts[0], pts[1], Color(0.55, 0.55, 0.58, 0.35), 1.0)


func _draw_mouse(p: Vector2) -> void:
	# Cable back to the monitor.
	var cable := PackedVector2Array()
	for i in 16:
		var t := i / 15.0
		var a := p + Vector2(0, -30)
		var ctrl := Vector2(200, 250)
		var end := Vector2(60, 238)
		cable.append(a.lerp(ctrl, t).lerp(ctrl.lerp(end, t), t))
	draw_polyline(cable, Color(0.06, 0.06, 0.07), 3.0, true)
	Paint.soft(self, p + Vector2(8, 10), Vector2(42, 46), Color(0, 0, 0, 0.6))
	var body := Paint.ellipse_points(p, Vector2(24, 34), 32)
	Paint.poly_hgrad(self, body, Color(0.22, 0.22, 0.24), Color(0.07, 0.07, 0.08))
	draw_line(p + Vector2(0, -33), p + Vector2(0, -8), Color(0, 0, 0, 0.6), 1.5)
	Paint.ellipse(self, p + Vector2(0, -18), Vector2(3, 6), Color(0.35, 0.35, 0.38))
	draw_arc(p, 24.0, PI * 1.1, PI * 1.6, 12, Color(0.6, 0.6, 0.65, 0.35), 1.5, true)


func _draw_screen() -> void:
	var s := _screen
	var r := SCREEN
	Paint.vgrad(s, r, Color(0.06, 0.13, 0.21), Color(0.025, 0.06, 0.11))
	var mono := UITheme.mono()
	# Title bar.
	s.draw_rect(Rect2(r.position, Vector2(r.size.x, 24)), Color(0.09, 0.22, 0.35))
	s.draw_string(mono, r.position + Vector2(10, 17), "ASHGROVE RMS  //  RECRUITMENT MANAGEMENT", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.75, 0.88, 1.0))
	s.draw_string(mono, Vector2(r.end.x - 60, r.position.y + 17), GameState.get_time_string(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.75, 0.88, 1.0))
	# Sidebar.
	var side := Rect2(r.position + Vector2(0, 24), Vector2(112, r.size.y - 24))
	s.draw_rect(side, Color(0.03, 0.08, 0.14))
	var items := ["INBOX  (3)", "CANDIDATES", "DOCUMENTS", "COMPANY", "LOG OUT"]
	for i in items.size():
		var y := side.position.y + 26 + i * 24
		if i == 0:
			s.draw_rect(Rect2(side.position.x, y - 15, side.size.x, 21), Color(0.55, 0.15, 0.13, 0.55))
		s.draw_string(mono, Vector2(side.position.x + 10, y), items[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.62, 0.78, 0.92))
	# Main pane: pending applications table.
	var x0 := side.end.x + 16
	s.draw_string(mono, Vector2(x0, r.position.y + 50), "APPLICATIONS PENDING VERIFICATION", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.55, 0.72, 0.88))
	s.draw_string(UITheme.sans(), Vector2(r.end.x - 70, r.position.y + 56), str(GameState.candidates_pending), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0.95, 0.55, 0.45))
	var rows := DataLoader.candidates(GameState.day)
	for i in mini(rows.size(), 6):
		var y := r.position.y + 82 + i * 26
		s.draw_rect(Rect2(x0 - 6, y - 16, r.end.x - x0 - 10, 22), Color(1, 1, 1, 0.03 if i % 2 == 0 else 0.0))
		s.draw_string(mono, Vector2(x0, y), str(rows[i].get("name", "")).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.8, 0.9, 1.0))
		s.draw_string(mono, Vector2(x0 + 126, y), str(rows[i].get("position", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.5, 0.65, 0.8))
		s.draw_rect(Rect2(r.end.x - 86, y - 12, 66, 15), Color(0.6, 0.42, 0.12, 0.6))
		s.draw_string(mono, Vector2(r.end.x - 82, y), "PENDING", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 0.9, 0.7))
	if _cursor_on:
		s.draw_rect(Rect2(x0, r.end.y - 26, 9, 15), Color(0.75, 0.88, 1.0, 0.9))
	# CRT-ish finish: scanlines, glare, darkened corners.
	var y2 := r.position.y
	while y2 < r.end.y:
		s.draw_line(Vector2(r.position.x, y2), Vector2(r.end.x, y2), Color(0, 0, 0, 0.12), 1.0)
		y2 += 3.0
	s.draw_colored_polygon(PackedVector2Array([r.position, r.position + Vector2(200, 0), r.position + Vector2(60, r.size.y), Vector2(r.position.x, r.end.y)]), Color(0.8, 0.9, 1.0, 0.03))
	Paint.hgrad(s, Rect2(r.position, Vector2(40, r.size.y)), Color(0, 0, 0, 0.35), Color(0, 0, 0, 0))
	Paint.hgrad(s, Rect2(Vector2(r.end.x - 40, r.position.y), Vector2(40, r.size.y)), Color(0, 0, 0, 0), Color(0, 0, 0, 0.35))
	# Power LED.
	s.draw_circle(Vector2(BEZEL.end.x - 24, BEZEL.end.y - 14), 2.5, Color(0.4, 1.0, 0.6, 0.9))


## Called when stats change so the on-screen counter stays correct.
func refresh() -> void:
	_screen.queue_redraw()
