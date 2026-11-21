extends Node2D
## Alice's office: back wall, bookshelf, framed certificate and the corridor door.
## Placeholder painted art in 1920x1080 screen space; replace with a single
## illustrated background texture when final art exists.

const WALL_TOP := Color(0.19, 0.22, 0.22)
const WALL_BOTTOM := Color(0.27, 0.29, 0.28)
const WOOD := Color(0.3, 0.2, 0.13)
const WOOD_DARK := Color(0.16, 0.105, 0.07)


func _draw() -> void:
	_draw_wall()
	_draw_bookshelf(Rect2(36, 104, 390, 520))
	_draw_certificate(Rect2(446, 190, 96, 128))
	_draw_door(1694.0)


func _draw_wall() -> void:
	Paint.vgrad(self, Rect2(0, 0, 1920, 620), WALL_TOP, WALL_BOTTOM)
	# Damask-ish wallpaper stripes.
	var x := 0.0
	while x < 1920.0:
		draw_rect(Rect2(x, 34, 30, 430), Color(1, 1, 1, 0.022))
		draw_line(Vector2(x + 44, 34), Vector2(x + 44, 464), Color(0, 0, 0, 0.05), 1.0)
		x += 60.0
	# Crown molding.
	Paint.vgrad(self, Rect2(0, 0, 1920, 34), WOOD_DARK.darkened(0.3), WOOD_DARK)
	draw_line(Vector2(0, 34), Vector2(1920, 34), Color(0.5, 0.38, 0.27, 0.5), 2.0)
	Paint.vgrad(self, Rect2(0, 36, 1920, 40), Color(0, 0, 0, 0.35), Color(0, 0, 0, 0))
	# Chair rail and wainscot panels.
	Paint.vgrad(self, Rect2(0, 462, 1920, 16), WOOD.lightened(0.1), WOOD_DARK)
	draw_line(Vector2(0, 462), Vector2(1920, 462), Color(0.6, 0.45, 0.3, 0.5), 1.5)
	Paint.vgrad(self, Rect2(0, 478, 1920, 150), WOOD.darkened(0.15), WOOD_DARK)
	var px := 20.0
	while px < 1920.0:
		var panel := Rect2(px, 500, 200, 120)
		draw_rect(panel, Color(0, 0, 0, 0.18), false, 3.0)
		draw_line(panel.position + Vector2(2, 2), Vector2(panel.end.x - 2, panel.position.y + 2), Color(0.6, 0.45, 0.3, 0.18), 1.0)
		px += 230.0
	# Corners fall into shadow.
	Paint.hgrad(self, Rect2(0, 0, 260, 620), Color(0, 0, 0, 0.45), Color(0, 0, 0, 0))
	Paint.hgrad(self, Rect2(1660, 0, 260, 620), Color(0, 0, 0, 0), Color(0, 0, 0, 0.4))


func _draw_bookshelf(r: Rect2) -> void:
	Paint.soft(self, r.get_center() + Vector2(14, 10), r.size * 0.62, Color(0, 0, 0, 0.55))
	# Carcass.
	Paint.vgrad(self, r, WOOD.lightened(0.05), WOOD_DARK)
	var inner := r.grow(-16)
	Paint.vgrad(self, inner, Color(0.08, 0.06, 0.05), Color(0.12, 0.09, 0.07))
	draw_line(r.position, Vector2(r.end.x, r.position.y), Color(0.62, 0.47, 0.33, 0.6), 2.0)
	draw_line(Vector2(r.end.x - 1, r.position.y), Vector2(r.end.x - 1, r.end.y), Color(0, 0, 0, 0.5), 2.0)
	var shelf_ys := [inner.position.y + 120.0, inner.position.y + 240.0, inner.position.y + 360.0]
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	var palette := [
		Color(0.42, 0.13, 0.11), Color(0.14, 0.2, 0.3), Color(0.17, 0.17, 0.18),
		Color(0.55, 0.49, 0.38), Color(0.22, 0.28, 0.22), Color(0.3, 0.12, 0.16),
	]
	var top := inner.position.y
	for sy: float in shelf_ys + [inner.end.y]:
		# Books / binders standing on this shelf.
		var bx := inner.position.x + 6.0
		var stop_x := inner.end.x - rng.randf_range(10.0, 70.0)
		while bx < stop_x:
			var w := rng.randf_range(16.0, 34.0)
			var h := rng.randf_range(70.0, sy - top - 12.0)
			var col: Color = palette[rng.randi() % palette.size()]
			var book := Rect2(bx, sy - h, w, h)
			Paint.hgrad(self, book, col.lightened(0.12), col.darkened(0.35))
			draw_line(Vector2(bx + w - 1, sy - h), Vector2(bx + w - 1, sy), Color(0, 0, 0, 0.4), 1.0)
			if w > 24.0:
				draw_rect(Rect2(bx + 5, sy - h * 0.45, w - 10, h * 0.18), Color(0.85, 0.82, 0.72, 0.55))
				draw_circle(Vector2(bx + w * 0.5, sy - h * 0.16), 3.0, Color(0, 0, 0, 0.5))
			bx += w + rng.randf_range(0.0, 2.0)
		# One leaning book at the end of the row.
		var lean := PackedVector2Array([Vector2(bx + 4, sy), Vector2(bx + 26, sy), Vector2(bx + 52, sy - 86), Vector2(bx + 30, sy - 90)])
		Paint.poly_hgrad(self, lean, Color(0.3, 0.26, 0.2), Color(0.16, 0.13, 0.1))
		# Shelf board.
		Paint.vgrad(self, Rect2(inner.position.x - 4, sy, inner.size.x + 8, 14), WOOD.lightened(0.15), WOOD_DARK)
		Paint.vgrad(self, Rect2(inner.position.x, sy + 14, inner.size.x, 18), Color(0, 0, 0, 0.5), Color(0, 0, 0, 0))
		top = sy + 14.0
	# On top: archive boxes and a plant nobody waters.
	for i in 2:
		var box := Rect2(r.position.x + 20 + i * 10, r.position.y - 50 * (i + 1), 118 - i * 18, 50)
		Paint.vgrad(self, box, Color(0.52, 0.45, 0.34), Color(0.38, 0.31, 0.22))
		draw_rect(Rect2(box.position.x + 12, box.position.y + 14, 46, 18), Color(0.85, 0.83, 0.76, 0.7))
		draw_line(box.position, Vector2(box.end.x, box.position.y), Color(0.7, 0.6, 0.45, 0.6), 1.5)
	var pot := Vector2(r.end.x - 70, r.position.y)
	Paint.poly_hgrad(self, PackedVector2Array([pot + Vector2(-30, -52), pot + Vector2(30, -52), pot + Vector2(22, 0), pot + Vector2(-22, 0)]), Color(0.42, 0.22, 0.15), Color(0.22, 0.11, 0.08))
	Paint.ellipse(self, pot + Vector2(0, -52), Vector2(30, 6), Color(0.12, 0.08, 0.06))
	var leaf_rng := RandomNumberGenerator.new()
	leaf_rng.seed = 9
	for i in 7:
		var base := pot + Vector2(leaf_rng.randf_range(-12, 12), -54)
		var tip := base + Vector2(leaf_rng.randf_range(-70, 70), leaf_rng.randf_range(-90, -40))
		var droop := tip + Vector2(signf(tip.x - base.x) * 26.0, 46)
		var stem := PackedVector2Array()
		for t in 9:
			var u := t / 8.0
			stem.append(base.lerp(tip, u).lerp(tip.lerp(droop, u), u))
		draw_polyline(stem, Color(0.28, 0.27, 0.13), 3.0, true)
		Paint.ellipse(self, droop, Vector2(7, 4), Color(0.33, 0.26, 0.12))


func _draw_certificate(r: Rect2) -> void:
	Paint.soft(self, r.get_center() + Vector2(6, 8), r.size * 0.7, Color(0, 0, 0, 0.5))
	Paint.vgrad(self, r, Color(0.38, 0.3, 0.16), Color(0.22, 0.16, 0.08))
	var mat := r.grow(-8)
	draw_rect(mat, Color(0.8, 0.77, 0.69))
	var font := UITheme.serif()
	draw_string(font, Vector2(mat.position.x, mat.position.y + 18), "EMPLOYEE", HORIZONTAL_ALIGNMENT_CENTER, mat.size.x, 11, Color(0.25, 0.2, 0.15))
	draw_string(font, Vector2(mat.position.x, mat.position.y + 30), "OF THE MONTH", HORIZONTAL_ALIGNMENT_CENTER, mat.size.x, 9, Color(0.25, 0.2, 0.15))
	# Photo with the face scratched out.
	var photo := Rect2(mat.position.x + 16, mat.position.y + 38, mat.size.x - 32, 52)
	draw_rect(photo, Color(0.3, 0.32, 0.33))
	Paint.ellipse(self, photo.get_center() + Vector2(0, 2), Vector2(11, 13), Color(0.55, 0.5, 0.45))
	Paint.ellipse(self, photo.get_center() + Vector2(0, 30), Vector2(22, 14), Color(0.2, 0.2, 0.22))
	for i in 6:
		var a := photo.get_center() + Vector2(-12 + i * 3, -12)
		draw_line(a, a + Vector2(8, 24), Color(0.12, 0.1, 0.1, 0.9), 1.5)
	draw_line(Vector2(mat.position.x + 14, mat.end.y - 12), Vector2(mat.end.x - 14, mat.end.y - 12), Color(0.3, 0.25, 0.2, 0.6), 1.0)
	draw_line(r.position, Vector2(r.end.x, r.position.y), Color(0.75, 0.6, 0.35, 0.5), 1.5)


func _draw_door(x: float) -> void:
	var jamb := Rect2(x, 40, 24, 600)
	Paint.hgrad(self, jamb, WOOD.lightened(0.1), WOOD_DARK)
	var slab := Rect2(x + 24, 52, 260, 600)
	Paint.hgrad(self, slab, Color(0.27, 0.19, 0.13), Color(0.2, 0.14, 0.095))
	Paint.wood_grain(self, Rect2(slab.position.x, slab.position.y, slab.size.x, slab.size.y), Color(0.08, 0.05, 0.03, 0.12), 6, 77)
	Paint.vgrad(self, Rect2(x, 40, 300, 14), WOOD.lightened(0.1), WOOD_DARK)
	# Frosted glass with corridor light behind it.
	var glass := Rect2(x + 58, 96, 168, 250)
	draw_rect(glass.grow(6), Color(0.13, 0.09, 0.06))
	Paint.vgrad(self, glass, Color(0.42, 0.49, 0.54), Color(0.3, 0.36, 0.41))
	Paint.soft(self, glass.get_center() + Vector2(0, -50), Vector2(120, 110), Color(0.75, 0.85, 0.9, 0.18))
	# Lettering painted on the corridor side, so we read it mirrored.
	var font := UITheme.serif_spaced()
	draw_set_transform(Vector2(glass.end.x, 0), 0.0, Vector2(-1, 1))
	draw_string(font, Vector2(0, glass.position.y + 120), "RECRUITMENT", HORIZONTAL_ALIGNMENT_CENTER, glass.size.x, 17, Color(0.12, 0.12, 0.14, 0.75))
	draw_string(font, Vector2(0, glass.position.y + 150), "13", HORIZONTAL_ALIGNMENT_CENTER, glass.size.x, 22, Color(0.12, 0.12, 0.14, 0.75))
	Paint.reset_transform(self)
	draw_rect(glass, Color(0, 0, 0, 0.4), false, 2.0)
	# Lower panel and handle.
	draw_rect(Rect2(x + 58, 390, 168, 220), Color(0, 0, 0, 0.18), false, 3.0)
	var handle := Vector2(x + 46, 410)
	Paint.ellipse(self, handle, Vector2(8, 16), Color(0.42, 0.34, 0.18))
	draw_line(handle, handle + Vector2(30, 0), Color(0.6, 0.5, 0.28), 6.0, true)
	draw_line(handle + Vector2(0, -3), handle + Vector2(30, -3), Color(0.9, 0.8, 0.55, 0.6), 1.5, true)
	# Thin cold light leaking through the gap at the hinge side.
	draw_line(Vector2(x + 24, 60), Vector2(x + 24, 640), Color(0.6, 0.7, 0.8, 0.25), 2.0)
	# Light switch.
	var sw := Rect2(x - 64, 300, 30, 46)
	draw_rect(sw, Color(0.72, 0.7, 0.64))
	draw_rect(Rect2(sw.position + Vector2(11, 12), Vector2(8, 20)), Color(0.55, 0.53, 0.48))
