extends Node2D
## Main-menu foreground: the dark edge of a desk, an empty office chair and a
## lamp left on, silhouetted against the window.

var _bulb: Node2D


func _ready() -> void:
	_bulb = Node2D.new()
	_bulb.z_index = 60
	add_child(_bulb)
	_bulb.draw.connect(_draw_bulb)


func _draw() -> void:
	# Wall below the window and the floor in shadow.
	Paint.vgrad(self, Rect2(0, 930, 1920, 150), Color(0.08, 0.08, 0.09), Color(0.03, 0.03, 0.035))
	# Desk silhouette across the bottom right.
	var desk := PackedVector2Array([Vector2(1080, 900), Vector2(1960, 880), Vector2(1960, 1080), Vector2(1040, 1080)])
	Paint.poly_vgrad(self, desk, Color(0.16, 0.1, 0.07), Color(0.05, 0.03, 0.02))
	draw_line(Vector2(1080, 900), Vector2(1960, 880), Color(0.6, 0.42, 0.28, 0.5), 2.0, true)
	# Empty chair, turned away.
	var back := Paint.rounded_rect_points(Rect2(1180, 650, 260, 330), 46.0)
	Paint.poly_hgrad(self, back, Color(0.07, 0.07, 0.08), Color(0.02, 0.02, 0.025))
	draw_arc(Vector2(1310, 700), 128.0, PI * 1.15, PI * 1.85, 20, Color(0.45, 0.55, 0.75, 0.35), 2.0, true)
	Paint.quad(self, Vector2(1295, 980), Vector2(1325, 980), Vector2(1330, 1080), Vector2(1290, 1080), Color(0.03, 0.03, 0.035))
	# Lamp on the desk.
	var base := Vector2(1640, 900)
	Paint.ellipse(self, base, Vector2(60, 14), Color(0.07, 0.07, 0.08))
	draw_line(base, base + Vector2(30, -160), Color(0.12, 0.12, 0.13), 6.0, true)
	draw_line(base + Vector2(30, -160), base + Vector2(-40, -210), Color(0.12, 0.12, 0.13), 6.0, true)
	var shade := PackedVector2Array([base + Vector2(-52, -230), base + Vector2(-20, -200), base + Vector2(-60, -130), base + Vector2(-130, -170)])
	Paint.poly_hgrad(self, shade, Color(0.06, 0.12, 0.09), Color(0.12, 0.22, 0.17))
	# Papers on the desk, catching the lamp.
	draw_set_transform(base + Vector2(-190, 6), -0.1, Vector2.ONE)
	draw_rect(Rect2(-90, -22, 180, 44), Color(0.75, 0.72, 0.66))
	Paint.text_lines(self, Vector2(-76, -10), 140.0, 8.0, 3, Color(0.2, 0.2, 0.22, 0.6), 4, 1.5)
	Paint.reset_transform(self)


func _draw_bulb() -> void:
	var base := Vector2(1640, 900)
	Paint.soft(_bulb, base + Vector2(-95, -150), Vector2(90, 70), Color(1.0, 0.8, 0.5, 0.5), true)
	_bulb.draw_line(base + Vector2(-62, -133), base + Vector2(-127, -168), Color(1.0, 0.9, 0.7), 7.0, true)
