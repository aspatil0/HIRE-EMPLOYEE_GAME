class_name CharacterFigure
extends Node2D
## Placeholder character art drawn as backlit silhouettes, which suits the
## noir framing and keeps faces unseen until final portraits exist.
##   ADITYA: seated CEO behind his desk, rim-lit by the city window. His
##           glasses can catch the light (set `glint` 0..1).
##   ALICE:  over-the-shoulder foreground figure (back of head, hair bun,
##           blazer), warm rim light from the desk lamp.

enum Who { ADITYA, ALICE }

@export var who: Who = Who.ADITYA

var glint: float = 0.0:
	set(v):
		glint = v
		if _emissive:
			_emissive.queue_redraw()

var _emissive: Node2D


func _ready() -> void:
	_emissive = Node2D.new()
	_emissive.name = "Glint"
	_emissive.z_index = 60
	add_child(_emissive)
	_emissive.draw.connect(_draw_glint)


func _draw() -> void:
	if who == Who.ADITYA:
		_draw_aditya()
	else:
		_draw_alice()


func _draw_aditya() -> void:
	# Origin = centre of the head.
	var suit := Color(0.045, 0.045, 0.055)
	var rim := Color(0.55, 0.65, 0.85, 0.55)
	# Shoulders & torso.
	var torso := PackedVector2Array([
		Vector2(-46, 52), Vector2(46, 52), Vector2(150, 110), Vector2(196, 170),
		Vector2(214, 330), Vector2(-214, 330), Vector2(-196, 170), Vector2(-150, 110)])
	Paint.poly_vgrad(self, torso, Color(0.07, 0.07, 0.085), suit)
	# Shirt V, tie, lapels.
	draw_colored_polygon(PackedVector2Array([Vector2(-30, 60), Vector2(30, 60), Vector2(0, 160)]), Color(0.5, 0.5, 0.52))
	draw_colored_polygon(PackedVector2Array([Vector2(-9, 70), Vector2(9, 70), Vector2(14, 160), Vector2(0, 178), Vector2(-14, 160)]), Color(0.32, 0.05, 0.05))
	draw_line(Vector2(-30, 60), Vector2(-70, 200), Color(0, 0, 0, 0.7), 3.0, true)
	draw_line(Vector2(30, 60), Vector2(70, 200), Color(0, 0, 0, 0.7), 3.0, true)
	# Neck and head.
	Paint.quad(self, Vector2(-26, 30), Vector2(26, 30), Vector2(30, 66), Vector2(-30, 66), Color(0.1, 0.08, 0.075))
	var head := Paint.ellipse_points(Vector2.ZERO, Vector2(46, 58), 40)
	Paint.poly_hgrad(self, head, Color(0.16, 0.12, 0.1), Color(0.05, 0.045, 0.045))
	# Hair.
	draw_colored_polygon(Paint.ellipse_points(Vector2(0, -26), Vector2(48, 36), 30, PI, TAU), Color(0.03, 0.03, 0.035))
	# Rim light from the window behind him (right side).
	draw_arc(Vector2.ZERO, 57.0, -PI * 0.45, PI * 0.25, 24, rim, 2.5, true)
	draw_polyline(PackedVector2Array([Vector2(46, 52), Vector2(150, 110), Vector2(196, 170)]), rim, 2.5, true)
	draw_polyline(PackedVector2Array([Vector2(-46, 52), Vector2(-150, 110), Vector2(-196, 170)]), Color(rim, 0.25), 2.0, true)
	# Glasses frames, barely visible.
	draw_line(Vector2(-34, -4), Vector2(34, -4), Color(0.0, 0.0, 0.0, 0.8), 2.0, true)
	draw_rect(Rect2(-32, -10, 24, 14), Color(0.25, 0.25, 0.3, 0.35), false, 1.5)
	draw_rect(Rect2(8, -10, 24, 14), Color(0.25, 0.25, 0.3, 0.35), false, 1.5)
	# Folded hands resting on the desk (drawn low; the desk covers the arms).
	Paint.ellipse(self, Vector2(-26, 318), Vector2(40, 18), Color(0.14, 0.1, 0.09))
	Paint.ellipse(self, Vector2(24, 322), Vector2(40, 18), Color(0.12, 0.09, 0.08))


func _draw_alice() -> void:
	# Origin = centre of the back of her head.
	var hair := Color(0.07, 0.05, 0.045)
	var blazer := Color(0.1, 0.11, 0.13)
	var rim := Color(1.0, 0.75, 0.45, 0.5)
	var body := PackedVector2Array([
		Vector2(-60, 120), Vector2(70, 120), Vector2(230, 210), Vector2(300, 330),
		Vector2(320, 520), Vector2(-330, 520), Vector2(-300, 300), Vector2(-200, 190)])
	Paint.poly_vgrad(self, body, blazer, Color(0.04, 0.045, 0.055))
	draw_line(Vector2(70, 120), Vector2(230, 210), rim, 3.0, true)
	draw_line(Vector2(230, 210), Vector2(300, 330), Color(rim, 0.3), 3.0, true)
	# Collar.
	draw_colored_polygon(PackedVector2Array([Vector2(-60, 112), Vector2(70, 112), Vector2(40, 150), Vector2(-30, 150)]), Color(0.75, 0.73, 0.7))
	# Neck, head and bun.
	Paint.quad(self, Vector2(-40, 60), Vector2(44, 60), Vector2(54, 126), Vector2(-50, 126), Color(0.2, 0.14, 0.12))
	var head := Paint.ellipse_points(Vector2.ZERO, Vector2(104, 126), 48)
	Paint.poly_hgrad(self, head, Color(0.04, 0.03, 0.03), hair)
	Paint.ellipse(self, Vector2(10, -118), Vector2(56, 46), hair)
	draw_arc(Vector2(10, -118), 54.0, -PI * 0.6, PI * 0.1, 18, rim, 2.5, true)
	draw_arc(Vector2.ZERO, 124.0, -PI * 0.35, PI * 0.3, 30, rim, 3.0, true)
	# A few loose strands catching the lamp light.
	for i in 5:
		var a := Vector2(70 + i * 6, -60 + i * 22)
		draw_line(a, a + Vector2(18, 26), Color(1.0, 0.7, 0.45, 0.25), 1.2, true)
	# Ear.
	Paint.ellipse(self, Vector2(100, 6), Vector2(12, 22), Color(0.22, 0.15, 0.13))


func _draw_glint() -> void:
	if who != Who.ADITYA or glint <= 0.01:
		return
	for x in [-20.0, 20.0]:
		Paint.soft(_emissive, Vector2(x, -3), Vector2(22, 12), Color(0.85, 0.92, 1.0, 0.8 * glint), true)
		_emissive.draw_rect(Rect2(x - 10, -8, 20, 3), Color(1, 1, 1, 0.9 * glint))
