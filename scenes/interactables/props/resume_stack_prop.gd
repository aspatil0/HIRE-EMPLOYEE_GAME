class_name ResumeStackProp
extends Node2D
## Stack of printed candidate resumes on a manila folder, right under the lamp.
## The number of visible sheets follows GameState.candidates_pending.

const PAPER := Color(0.9, 0.88, 0.82)

var sheet_count: int = 6:
	set(v):
		sheet_count = clampi(v, 0, 8)
		queue_redraw()


func _draw() -> void:
	Paint.soft(self, Vector2(10, 16), Vector2(190, 120), Color(0, 0, 0, 0.6))
	# Folder.
	draw_set_transform(Vector2.ZERO, -0.06, Vector2.ONE)
	Paint.vgrad(self, Rect2(-150, -94, 300, 184), Color(0.74, 0.6, 0.37), Color(0.6, 0.47, 0.27))
	draw_rect(Rect2(-150, -114, 96, 22), Color(0.72, 0.58, 0.35))
	draw_string(UITheme.sans_spaced(), Vector2(-144, -98), "APPLICANTS", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.3, 0.2, 0.1))
	draw_line(Vector2(-150, 90), Vector2(150, 90), Color(0.35, 0.25, 0.12, 0.8), 2.0)
	Paint.reset_transform(self)
	# Sheets, each a little askew; the stack gains height as it grows.
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var n := maxi(sheet_count, 1)
	for i in n:
		var rot := rng.randf_range(-0.07, 0.05)
		var off := Vector2(rng.randf_range(-8, 8), -i * 2.2)
		var top := i == n - 1
		_sheet(off, rot, top and sheet_count > 0)


func _sheet(offset: Vector2, rot: float, detailed: bool) -> void:
	draw_set_transform(offset, rot, Vector2.ONE)
	var r := Rect2(-118, -82, 236, 162)
	draw_rect(Rect2(r.position + Vector2(0, 2), r.size), Color(0.45, 0.43, 0.4))
	Paint.vgrad(self, r, PAPER, PAPER.darkened(0.08))
	if detailed:
		# Letterhead + photo + text.
		draw_rect(Rect2(r.position, Vector2(r.size.x, 8)), Color(0.18, 0.2, 0.24))
		draw_string(UITheme.serif(), r.position + Vector2(14, 34), "CURRICULUM VITAE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.15, 0.14, 0.13))
		var photo := Rect2(r.end.x - 62, r.position.y + 18, 46, 56)
		draw_rect(photo, Color(0.58, 0.58, 0.6))
		draw_circle(photo.get_center() + Vector2(0, -6), 11.0, Color(0.38, 0.36, 0.35))
		Paint.ellipse(self, photo.get_center() + Vector2(0, 22), Vector2(18, 12), Color(0.25, 0.25, 0.28))
		draw_rect(photo, Color(0, 0, 0, 0.4), false, 1.0)
		Paint.text_lines(self, r.position + Vector2(14, 52), 140.0, 9.0, 3, Color(0.25, 0.25, 0.28, 0.7), 3, 1.6)
		Paint.text_lines(self, r.position + Vector2(14, 92), 200.0, 9.0, 6, Color(0.3, 0.3, 0.32, 0.55), 9, 1.4)
		# Paperclip.
		var clip := PackedVector2Array([Vector2(-96, -92), Vector2(-96, -58), Vector2(-86, -52), Vector2(-78, -58), Vector2(-78, -96), Vector2(-87, -102), Vector2(-92, -96), Vector2(-92, -66)])
		draw_polyline(clip, Color(0.75, 0.77, 0.8), 2.0, true)
		draw_polyline(clip, Color(0.3, 0.3, 0.32, 0.6), 0.8, true)
	Paint.reset_transform(self)
