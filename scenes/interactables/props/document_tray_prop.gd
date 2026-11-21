extends Node2D
## Two-tier metal document tray holding candidates' identity papers
## (ID cards, a passport, photocopies) waiting for verification.

const METAL := Color(0.26, 0.27, 0.28)
const METAL_DARK := Color(0.1, 0.105, 0.11)


func _draw() -> void:
	Paint.soft(self, Vector2(8, 40), Vector2(260, 70), Color(0, 0, 0, 0.65))
	_draw_upper_tier()
	_draw_lower_tier()


func _draw_lower_tier() -> void:
	# Floor of the tray.
	var floor_pts := PackedVector2Array([Vector2(-182, -30), Vector2(182, -30), Vector2(206, 46), Vector2(-206, 46)])
	Paint.poly_vgrad(self, floor_pts, Color(0.12, 0.125, 0.13), Color(0.18, 0.185, 0.19))
	# Papers inside, fanned.
	_paper(Vector2(-20, 6), 0.03, Vector2(300, 66), Color(0.86, 0.84, 0.78))
	_paper(Vector2(-6, 0), -0.05, Vector2(290, 62), Color(0.8, 0.79, 0.74))
	# ID card (orange/white/green header band: generic national ID placeholder).
	_card(Vector2(-110, -4), -0.12, Color(0.93, 0.92, 0.88), [Color(0.95, 0.55, 0.2), Color(0.95, 0.95, 0.95), Color(0.2, 0.55, 0.3)])
	# Tax card (blue-grey placeholder).
	_card(Vector2(46, -10), 0.08, Color(0.62, 0.74, 0.82), [Color(0.2, 0.35, 0.55)])
	# Passport booklet.
	draw_set_transform(Vector2(140, 2), 0.22, Vector2.ONE)
	Paint.soft(self, Vector2(4, 6), Vector2(48, 60), Color(0, 0, 0, 0.5))
	Paint.rounded_rect(self, Rect2(-34, -46, 68, 92), 4.0, Color(0.32, 0.1, 0.12))
	draw_rect(Rect2(-34, -46, 6, 92), Color(0, 0, 0, 0.25))
	draw_arc(Vector2(0, -6), 13.0, 0, TAU, 24, Color(0.85, 0.7, 0.35, 0.8), 1.5, true)
	draw_string(UITheme.serif(), Vector2(-30, 28), "PASSPORT", HORIZONTAL_ALIGNMENT_CENTER, 60, 9, Color(0.85, 0.7, 0.35, 0.8))
	Paint.reset_transform(self)
	# Front lip (perforated metal).
	var lip := PackedVector2Array([Vector2(-208, 30), Vector2(208, 30), Vector2(212, 70), Vector2(-212, 70)])
	Paint.poly_vgrad(self, lip, METAL.lightened(0.08), METAL_DARK)
	for row in 2:
		for i in 34:
			var x := -196.0 + i * 12.0
			draw_circle(Vector2(x, 42 + row * 13), 3.0, Color(0.03, 0.03, 0.035, 0.85))
	draw_line(Vector2(-208, 30), Vector2(208, 30), Color(0.7, 0.72, 0.75, 0.6), 2.0)
	# Side walls.
	Paint.quad(self, Vector2(-182, -30), Vector2(-176, -30), Vector2(-202, 32), Vector2(-208, 32), METAL)
	Paint.quad(self, Vector2(176, -30), Vector2(182, -30), Vector2(208, 32), Vector2(202, 32), METAL_DARK)
	# Label clip.
	var label := Rect2(-46, 44, 92, 20)
	draw_rect(label, Color(0.88, 0.86, 0.8))
	draw_string(UITheme.sans_spaced(), Vector2(label.position.x, label.position.y + 15), "VERIFY", HORIZONTAL_ALIGNMENT_CENTER, label.size.x, 12, Color(0.6, 0.12, 0.1))


func _draw_upper_tier() -> void:
	# Posts.
	for x in [-170.0, 170.0]:
		draw_line(Vector2(x, -26), Vector2(x * 0.95, -92), METAL.lightened(0.1), 4.0)
	var floor_pts := PackedVector2Array([Vector2(-168, -104), Vector2(168, -104), Vector2(184, -62), Vector2(-184, -62)])
	Paint.poly_vgrad(self, floor_pts, Color(0.1, 0.1, 0.11), Color(0.16, 0.16, 0.17))
	# Manila folder with a tab.
	var folder := PackedVector2Array([Vector2(-140, -112), Vector2(120, -116), Vector2(130, -70), Vector2(-150, -68)])
	Paint.poly_vgrad(self, folder, Color(0.76, 0.62, 0.38), Color(0.6, 0.47, 0.27))
	draw_rect(Rect2(-130, -128, 70, 16), Color(0.72, 0.58, 0.35))
	draw_string(UITheme.sans_spaced(), Vector2(-126, -116), "ID DOCS", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.25, 0.18, 0.1))
	var lip := PackedVector2Array([Vector2(-186, -74), Vector2(186, -74), Vector2(188, -50), Vector2(-188, -50)])
	Paint.poly_vgrad(self, lip, METAL.lightened(0.05), METAL_DARK)
	draw_line(Vector2(-186, -74), Vector2(186, -74), Color(0.7, 0.72, 0.75, 0.55), 1.5)
	for i in 30:
		draw_circle(Vector2(-174.0 + i * 12.0, -62), 2.6, Color(0.03, 0.03, 0.035, 0.85))


func _paper(c: Vector2, rot: float, size: Vector2, col: Color) -> void:
	draw_set_transform(c, rot, Vector2.ONE)
	var r := Rect2(-size * 0.5, size)
	draw_rect(r, col)
	Paint.text_lines(self, r.position + Vector2(14, 12), size.x * 0.6, 9.0, 4, Color(0.2, 0.2, 0.22, 0.45), int(c.x * 10), 1.5)
	draw_line(r.position, Vector2(r.end.x, r.position.y), Color(1, 1, 1, 0.4), 1.0)
	Paint.reset_transform(self)


func _card(c: Vector2, rot: float, base: Color, bands: Array) -> void:
	draw_set_transform(c, rot, Vector2.ONE)
	Paint.soft(self, Vector2(3, 5), Vector2(64, 42), Color(0, 0, 0, 0.45))
	var r := Rect2(-54, -34, 108, 68)
	Paint.rounded_rect(self, r, 5.0, base)
	var band_h := 14.0 / bands.size()
	for i in bands.size():
		draw_rect(Rect2(r.position.x + 4, r.position.y + 4 + i * band_h, r.size.x - 8, band_h), bands[i])
	draw_rect(Rect2(r.position.x + 8, r.position.y + 24, 26, 32), Color(0.45, 0.45, 0.47))
	draw_circle(Vector2(r.position.x + 21, r.position.y + 36), 6.0, Color(0.25, 0.25, 0.27))
	Paint.text_lines(self, Vector2(r.position.x + 42, r.position.y + 30), 56.0, 7.0, 4, Color(0.15, 0.15, 0.18, 0.6), int(c.y * 7 + 13), 1.5)
	Paint.reset_transform(self)
