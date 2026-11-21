extends Node2D
## Corkboard of pinned notes, polaroids and a calendar, with a red string
## somebody started and never finished.

const SIZE := Vector2(340, 236)


func _draw() -> void:
	var r := Rect2(-SIZE * 0.5, SIZE)
	Paint.soft(self, Vector2(10, 12), SIZE * 0.62, Color(0, 0, 0, 0.55))
	Paint.vgrad(self, r.grow(10), Color(0.32, 0.22, 0.14), Color(0.2, 0.13, 0.08))
	Paint.vgrad(self, r, Color(0.56, 0.42, 0.27), Color(0.47, 0.34, 0.2))
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	for i in 260:
		draw_circle(r.position + Vector2(rng.randf() * r.size.x, rng.randf() * r.size.y), rng.randf_range(0.6, 1.6), Color(0.3, 0.2, 0.1, 0.35))
	draw_line(r.position - Vector2(10, 10), Vector2(r.end.x + 10, r.position.y - 10), Color(0.6, 0.45, 0.3, 0.5), 1.5)

	_note(Vector2(-118, -60), -0.06, Color(0.9, 0.88, 0.82), 4)
	_calendar(Vector2(-10, -38), 0.02)
	_polaroid(Vector2(104, -52), 0.08)
	_polaroid(Vector2(118, 54), -0.1)
	_note(Vector2(-124, 58), 0.05, Color(0.92, 0.82, 0.38), 3)
	_note(Vector2(-24, 74), -0.03, Color(0.86, 0.86, 0.84), 3)
	# Red string between the two photos, and one loose end.
	var pins := [Vector2(104, -96), Vector2(118, 12), Vector2(-24, 44)]
	draw_line(pins[0], pins[1], Color(0.7, 0.08, 0.06), 1.5, true)
	draw_line(pins[1], pins[2], Color(0.7, 0.08, 0.06), 1.5, true)
	draw_line(pins[2], pins[2] + Vector2(-20, 46), Color(0.7, 0.08, 0.06), 1.5, true)
	for p: Vector2 in pins:
		_pin(p, Color(0.8, 0.12, 0.1))


func _note(c: Vector2, rot: float, col: Color, lines: int) -> void:
	draw_set_transform(c, rot, Vector2.ONE)
	Paint.soft(self, Vector2(3, 5), Vector2(52, 44), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(-44, -34, 88, 68), col)
	Paint.text_lines(self, Vector2(-34, -16), 68.0, 10.0, lines, Color(0.18, 0.18, 0.25, 0.65), int(c.x + c.y), 1.3)
	Paint.reset_transform(self)
	_pin(c + Vector2(0, -30).rotated(rot), Color(0.2, 0.35, 0.7))


func _calendar(c: Vector2, rot: float) -> void:
	draw_set_transform(c, rot, Vector2.ONE)
	Paint.soft(self, Vector2(3, 5), Vector2(72, 66), Color(0, 0, 0, 0.35))
	var r := Rect2(-62, -54, 124, 112)
	draw_rect(r, Color(0.92, 0.9, 0.86))
	draw_rect(Rect2(r.position, Vector2(r.size.x, 20)), Color(0.55, 0.13, 0.11))
	draw_string(UITheme.sans_spaced(), Vector2(r.position.x, r.position.y + 15), "NOVEMBER", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 11, Color(1, 0.95, 0.9))
	for i in 30:
		var cell := Vector2(r.position.x + 8 + (i % 7) * 16, r.position.y + 32 + int(i / 7.0) * 15)
		draw_rect(Rect2(cell, Vector2(11, 9)), Color(0.75, 0.74, 0.7))
		if i < 20:
			draw_line(cell, cell + Vector2(11, 9), Color(0.7, 0.1, 0.08, 0.85), 1.4)
			draw_line(cell + Vector2(11, 0), cell + Vector2(0, 9), Color(0.7, 0.1, 0.08, 0.85), 1.4)
		elif i == 20:
			draw_arc(cell + Vector2(5.5, 4.5), 8.0, 0, TAU, 16, Color(0.7, 0.1, 0.08), 1.6, true)
	Paint.reset_transform(self)
	_pin(c + Vector2(0, -50), Color(0.85, 0.75, 0.2))


func _polaroid(c: Vector2, rot: float) -> void:
	draw_set_transform(c, rot, Vector2.ONE)
	Paint.soft(self, Vector2(3, 5), Vector2(46, 54), Color(0, 0, 0, 0.4))
	draw_rect(Rect2(-38, -44, 76, 90), Color(0.92, 0.91, 0.88))
	var photo := Rect2(-31, -37, 62, 60)
	Paint.vgrad(self, photo, Color(0.22, 0.24, 0.26), Color(0.12, 0.12, 0.13))
	draw_circle(photo.get_center() + Vector2(0, -6), 11.0, Color(0.05, 0.05, 0.06))
	Paint.ellipse(self, photo.get_center() + Vector2(0, 24), Vector2(22, 16), Color(0.05, 0.05, 0.06))
	Paint.reset_transform(self)


func _pin(p: Vector2, col: Color) -> void:
	draw_circle(p + Vector2(2, 3), 4.5, Color(0, 0, 0, 0.4))
	draw_circle(p, 4.5, col)
	draw_circle(p + Vector2(-1.5, -1.5), 1.5, Color(1, 1, 1, 0.6))
