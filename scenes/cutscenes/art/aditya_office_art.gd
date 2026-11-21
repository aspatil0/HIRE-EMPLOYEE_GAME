extends Node2D
## Aditya's executive office, drawn in depth layers so the scene can stack:
##   WALLS -> NightWindow -> BACK (credenza, chair) -> Aditya -> DESK -> Alice.
## One node per layer, all using this script.

enum Layer { WALLS, BACK, DESK }

const WOOD := Color(0.3, 0.16, 0.1)
const WOOD_DARK := Color(0.13, 0.065, 0.04)

@export var layer: Layer = Layer.WALLS

var folder_offset: Vector2 = Vector2.ZERO:
	set(v):
		folder_offset = v
		queue_redraw()

var _lamp: Node2D


func _ready() -> void:
	if layer == Layer.DESK:
		_lamp = Node2D.new()
		_lamp.name = "LampGlow"
		_lamp.z_index = 60
		add_child(_lamp)
		_lamp.draw.connect(_draw_lamp_emissive)


func _draw() -> void:
	match layer:
		Layer.WALLS:
			_draw_walls()
		Layer.BACK:
			_draw_back()
		Layer.DESK:
			_draw_desk()


func _draw_walls() -> void:
	# Walls: dark walnut panelling.
	Paint.vgrad(self, Rect2(0, 0, 1920, 760), Color(0.22, 0.13, 0.09), Color(0.16, 0.09, 0.06))
	var x := 0.0
	while x < 1920.0:
		draw_line(Vector2(x, 0), Vector2(x, 760), Color(0, 0, 0, 0.35), 3.0)
		draw_line(Vector2(x + 3, 0), Vector2(x + 3, 760), Color(0.5, 0.3, 0.2, 0.12), 1.0)
		x += 120.0
	Paint.vgrad(self, Rect2(0, 0, 1920, 46), Color(0.06, 0.03, 0.02), WOOD_DARK)
	# Company plaque, left of the window.
	var plaque := Rect2(90, 250, 200, 120)
	Paint.soft(self, plaque.get_center() + Vector2(6, 8), plaque.size * 0.7, Color(0, 0, 0, 0.5))
	Paint.vgrad(self, plaque, Color(0.62, 0.48, 0.24), Color(0.38, 0.27, 0.12))
	draw_rect(plaque.grow(-6), Color(0.2, 0.13, 0.06, 0.5), false, 1.5)
	draw_string(UITheme.serif_spaced(), Vector2(plaque.position.x, plaque.position.y + 56), "ASHGROVE", HORIZONTAL_ALIGNMENT_CENTER, plaque.size.x, 24, Color(0.18, 0.11, 0.05))
	draw_string(UITheme.sans_spaced(), Vector2(plaque.position.x, plaque.position.y + 84), "HOLDINGS · EST. 1987", HORIZONTAL_ALIGNMENT_CENTER, plaque.size.x, 11, Color(0.18, 0.11, 0.05))
	# A dark oil painting to the right.
	var art := Rect2(1640, 190, 200, 260)
	Paint.soft(self, art.get_center() + Vector2(8, 10), art.size * 0.68, Color(0, 0, 0, 0.55))
	Paint.vgrad(self, art, Color(0.45, 0.33, 0.15), Color(0.25, 0.17, 0.07))
	var canvas := art.grow(-14)
	Paint.vgrad(self, canvas, Color(0.08, 0.08, 0.1), Color(0.14, 0.1, 0.08))
	Paint.soft(self, canvas.get_center() + Vector2(0, 20), Vector2(40, 70), Color(0.3, 0.25, 0.2, 0.6))
	Paint.ellipse(self, canvas.get_center() + Vector2(0, -30), Vector2(20, 24), Color(0.05, 0.05, 0.06))
	Paint.poly_vgrad(self, PackedVector2Array([canvas.get_center() + Vector2(-46, 100), canvas.get_center() + Vector2(-30, 0), canvas.get_center() + Vector2(30, 0), canvas.get_center() + Vector2(46, 100)]), Color(0.06, 0.06, 0.07), Color(0.03, 0.03, 0.04))


func _draw_back() -> void:
	# Credenza silhouette under the window.
	Paint.vgrad(self, Rect2(330, 600, 1260, 120), Color(0.1, 0.05, 0.03), Color(0.06, 0.03, 0.02))
	# Leather chair back behind Aditya.
	var chair := Paint.rounded_rect_points(Rect2(770, 270, 380, 470), 70.0)
	Paint.poly_hgrad(self, chair, Color(0.09, 0.05, 0.04), Color(0.04, 0.02, 0.02))
	for i in 4:
		draw_line(Vector2(800, 330 + i * 90), Vector2(1120, 330 + i * 90), Color(0, 0, 0, 0.35), 2.0)
		for j in 5:
			draw_circle(Vector2(810 + j * 75, 330 + i * 90), 3.0, Color(0.2, 0.12, 0.08, 0.6))


func _draw_desk() -> void:
	var f := self
	# Desk top in perspective.
	var top := PackedVector2Array([Vector2(240, 700), Vector2(1680, 700), Vector2(1790, 790), Vector2(130, 790)])
	Paint.poly_vgrad(f, top, Color(0.36, 0.17, 0.1), Color(0.27, 0.12, 0.07))
	Paint.wood_grain(f, Rect2(150, 702, 1620, 86), Color(0.1, 0.04, 0.02, 0.3), 9, 66)
	# Window reflected in the polish.
	Paint.soft(f, Vector2(960, 730), Vector2(560, 26), Color(0.55, 0.65, 0.85, 0.12))
	draw_line_safe(f, Vector2(240, 700), Vector2(1680, 700), Color(0.7, 0.45, 0.3, 0.5), 2.0)
	# Front panel.
	Paint.vgrad(f, Rect2(130, 790, 1660, 300), Color(0.24, 0.11, 0.065), Color(0.1, 0.045, 0.025))
	draw_line_safe(f, Vector2(130, 790), Vector2(1790, 790), Color(0.65, 0.4, 0.25, 0.6), 2.0)
	for px in [180.0, 720.0, 1260.0]:
		var panel := Rect2(px, 830, 480, 220)
		f.draw_rect(panel, Color(0, 0, 0, 0.25), false, 4.0)
		f.draw_line(panel.position + Vector2(3, 3), Vector2(panel.end.x - 3, panel.position.y + 3), Color(0.6, 0.35, 0.2, 0.18), 1.5)
	# Desk props: banker's lamp, folder, nameplate, glass, pen set.
	_draw_bankers_lamp(f, Vector2(470, 712))
	_draw_folder(f, Vector2(960, 745) + folder_offset)
	_draw_nameplate(f, Vector2(1260, 772))
	_draw_glass(f, Vector2(1470, 728))
	f.draw_line(Vector2(700, 760), Vector2(800, 748), Color(0.05, 0.05, 0.05), 5.0, true)
	f.draw_line(Vector2(780, 750), Vector2(800, 748), Color(0.8, 0.65, 0.3), 5.0, true)


static func draw_line_safe(ci: CanvasItem, a: Vector2, b: Vector2, c: Color, w: float) -> void:
	ci.draw_line(a, b, c, w, true)


func _draw_bankers_lamp(f: Node2D, p: Vector2) -> void:
	Paint.soft(f, p + Vector2(10, 40), Vector2(120, 22), Color(0, 0, 0, 0.6))
	Paint.ellipse(f, p + Vector2(0, 30), Vector2(56, 13), Color(0.42, 0.32, 0.15))
	draw_line_safe(f, p + Vector2(0, 28), p + Vector2(0, -50), Color(0.55, 0.43, 0.2), 6.0)
	var shade := PackedVector2Array([p + Vector2(-96, -40), p + Vector2(96, -40), p + Vector2(70, -96), p + Vector2(-70, -96)])
	Paint.poly_vgrad(f, shade, Color(0.08, 0.3, 0.18), Color(0.12, 0.42, 0.25))
	f.draw_line(p + Vector2(-70, -96), p + Vector2(70, -96), Color(0.5, 0.8, 0.6, 0.4), 1.5, true)


func _draw_lamp_emissive() -> void:
	var p := Vector2(470, 712)
	Paint.ellipse(_lamp, p + Vector2(0, -40), Vector2(94, 8), Color(1.0, 0.88, 0.62))


func _draw_folder(f: Node2D, c: Vector2) -> void:
	Paint.soft(f, c + Vector2(8, 10), Vector2(150, 30), Color(0, 0, 0, 0.5))
	var pts := PackedVector2Array([c + Vector2(-120, -26), c + Vector2(110, -28), c + Vector2(130, 24), c + Vector2(-130, 26)])
	Paint.poly_vgrad(f, pts, Color(0.75, 0.6, 0.36), Color(0.58, 0.45, 0.25))
	f.draw_rect(Rect2(c + Vector2(-70, -12), Vector2(140, 22)), Color(0.6, 0.12, 0.1, 0.85), false, 2.0)
	f.draw_string(UITheme.sans_spaced(), c + Vector2(-70, 4), "CONFIDENTIAL", HORIZONTAL_ALIGNMENT_CENTER, 140, 12, Color(0.6, 0.12, 0.1, 0.9))


func _draw_nameplate(f: Node2D, c: Vector2) -> void:
	Paint.soft(f, c + Vector2(6, 16), Vector2(150, 18), Color(0, 0, 0, 0.6))
	var face := PackedVector2Array([c + Vector2(-130, -24), c + Vector2(130, -24), c + Vector2(136, 12), c + Vector2(-136, 12)])
	Paint.poly_vgrad(f, face, Color(0.75, 0.6, 0.3), Color(0.45, 0.33, 0.14))
	f.draw_line(c + Vector2(-130, -24), c + Vector2(130, -24), Color(1, 0.9, 0.6, 0.6), 1.5, true)
	f.draw_string(UITheme.serif_spaced(), c + Vector2(-130, -4), "ADITYA", HORIZONTAL_ALIGNMENT_CENTER, 260, 18, Color(0.15, 0.09, 0.03))
	f.draw_string(UITheme.sans_spaced(), c + Vector2(-130, 9), "CHIEF EXECUTIVE OFFICER", HORIZONTAL_ALIGNMENT_CENTER, 260, 9, Color(0.15, 0.09, 0.03))


func _draw_glass(f: Node2D, c: Vector2) -> void:
	Paint.soft(f, c + Vector2(6, 46), Vector2(44, 12), Color(0, 0, 0, 0.5))
	var body := PackedVector2Array([c + Vector2(-28, 0), c + Vector2(28, 0), c + Vector2(24, 48), c + Vector2(-24, 48)])
	f.draw_colored_polygon(body, Color(0.6, 0.65, 0.7, 0.22))
	var drink := PackedVector2Array([c + Vector2(-26, 22), c + Vector2(26, 22), c + Vector2(24, 48), c + Vector2(-24, 48)])
	Paint.poly_vgrad(f, drink, Color(0.7, 0.4, 0.12, 0.8), Color(0.45, 0.22, 0.06, 0.9))
	f.draw_line(c + Vector2(-20, 4), c + Vector2(-18, 44), Color(1, 1, 1, 0.35), 2.0, true)
	Paint.ellipse(f, c, Vector2(28, 5), Color(0.8, 0.85, 0.9, 0.25))
