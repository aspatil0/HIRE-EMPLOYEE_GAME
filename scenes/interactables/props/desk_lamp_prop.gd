class_name DeskLampProp
extends Node2D
## Articulated desk lamp aimed at the resumes. The bulb/opening is emissive,
## the beam and halo are additive. Toggling it is handled by the location,
## which also dims the matching LightingRig light.

signal toggled(is_on: bool)

const JOINT_BASE := Vector2(0, -12)
const ELBOW := Vector2(34, -205)
const HEAD := Vector2(-88, -262)
const AIM := Vector2(-268, 112) # where the beam lands (resume stack)
const SHADE_LEN := 112.0

var is_on: bool = true

var _emissive: Node2D
var _beam: Node2D
var _motes: CPUParticles2D


func _ready() -> void:
	_emissive = Node2D.new()
	_emissive.name = "Bulb"
	_emissive.z_index = 60
	add_child(_emissive)
	_emissive.draw.connect(_draw_bulb)
	_beam = Node2D.new()
	_beam.name = "Beam"
	_beam.z_index = 70
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_beam.material = add
	add_child(_beam)
	_beam.draw.connect(_draw_beam)
	_motes = _make_motes(add)
	_beam.add_child(_motes)
	var hotspot := get_node_or_null(^"Interactable") as Interactable
	if hotspot:
		hotspot.activated.connect(func(_t: Interactable) -> void: toggle())


func set_on(on: bool) -> void:
	if on == is_on:
		return
	is_on = on
	_emissive.queue_redraw()
	_beam.visible = on
	AudioManager.play_sfx(&"lamp_switch")
	toggled.emit(on)


func toggle() -> void:
	set_on(not is_on)


func _axis() -> Vector2:
	return (AIM - HEAD).normalized()


func _mouth_center() -> Vector2:
	return HEAD + _axis() * SHADE_LEN


func _draw() -> void:
	Paint.soft(self, Vector2(10, 8), Vector2(110, 26), Color(0, 0, 0, 0.65))
	# Base.
	Paint.ellipse(self, Vector2(0, 4), Vector2(74, 19), Color(0.05, 0.05, 0.055))
	Paint.ellipse(self, Vector2(0, -2), Vector2(70, 17), Color(0.14, 0.14, 0.15))
	draw_arc(Vector2(0, -2), 70.0, PI * 1.05, PI * 1.95, 24, Color(0.5, 0.5, 0.55, 0.35), 1.5, true)
	Paint.ellipse(self, Vector2(0, -10), Vector2(22, 8), Color(0.2, 0.2, 0.21))
	# Arms with springs.
	_arm(JOINT_BASE, ELBOW)
	_arm(ELBOW, HEAD)
	for j in [JOINT_BASE, ELBOW, HEAD]:
		draw_circle(j, 7.0, Color(0.45, 0.36, 0.2))
		draw_circle(j + Vector2(-2, -2), 2.5, Color(0.9, 0.78, 0.5, 0.7))
	# Shade: a truncated cone from HEAD along the aim axis.
	var ax := _axis()
	var perp := Vector2(-ax.y, ax.x)
	var mouth := _mouth_center()
	var shade := PackedVector2Array([HEAD + perp * 22.0, mouth + perp * 70.0, mouth - perp * 70.0, HEAD - perp * 22.0])
	Paint.poly_hgrad(self, shade, Color(0.08, 0.17, 0.13), Color(0.16, 0.3, 0.23))
	draw_line(HEAD - perp * 22.0, mouth - perp * 70.0, Color(0.5, 0.7, 0.6, 0.35), 2.0, true)
	draw_circle(HEAD - ax * 6.0, 14.0, Color(0.07, 0.14, 0.1))


func _arm(a: Vector2, b: Vector2) -> void:
	var dir := (b - a).normalized()
	var perp := Vector2(-dir.y, dir.x)
	draw_line(a + perp * 4.0, b + perp * 4.0, Color(0.1, 0.1, 0.11), 5.0, true)
	draw_line(a - perp * 4.0, b - perp * 4.0, Color(0.2, 0.2, 0.22), 5.0, true)
	draw_line(a - perp * 5.5, b - perp * 5.5, Color(0.6, 0.6, 0.65, 0.3), 1.0, true)
	# Spring alongside.
	var pts := PackedVector2Array()
	var length := a.distance_to(b)
	for i in 28:
		var t := 0.2 + 0.5 * i / 27.0
		pts.append(a + dir * length * t + perp * (12.0 + (3.0 if i % 2 == 0 else -3.0)))
	draw_polyline(pts, Color(0.55, 0.55, 0.58, 0.8), 1.2, true)


func _draw_bulb() -> void:
	var ax := _axis()
	var perp := Vector2(-ax.y, ax.x)
	var mouth := _mouth_center()
	var opening := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0
		opening.append(mouth + perp * cos(a) * 68.0 + ax * sin(a) * 18.0)
	if is_on:
		_emissive.draw_colored_polygon(opening, Color(1.0, 0.86, 0.62))
		_emissive.draw_circle(mouth - ax * 10.0, 20.0, Color(1.0, 0.97, 0.88))
	else:
		_emissive.draw_colored_polygon(opening, Color(0.12, 0.11, 0.1))
		_emissive.draw_circle(mouth - ax * 10.0, 18.0, Color(0.35, 0.33, 0.3))


func _draw_beam() -> void:
	var ax := _axis()
	var perp := Vector2(-ax.y, ax.x)
	var mouth := _mouth_center()
	var land := AIM + Vector2(0, 30)
	var beam := PackedVector2Array([mouth + perp * 66.0, land + Vector2(-240, 40), land + Vector2(260, -30), mouth - perp * 66.0])
	var warm := Color(1.0, 0.8, 0.5)
	_beam.draw_polygon(beam, PackedColorArray([Color(warm, 0.11), Color(warm, 0.0), Color(warm, 0.0), Color(warm, 0.11)]))
	Paint.soft(_beam, mouth + ax * 10.0, Vector2(170, 130), Color(1.0, 0.75, 0.45, 0.32))
	Paint.soft(_beam, mouth, Vector2(60, 40), Color(1.0, 0.9, 0.7, 0.4), true)


func _make_motes(mat: Material) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = "DustMotes"
	p.material = mat
	p.amount = 40
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.position = (_mouth_center() + AIM) * 0.5
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(110, 130)
	p.gravity = Vector2(0, 2)
	p.direction = Vector2(1, -0.3)
	p.spread = 180.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 8.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.6
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	ramp.colors = PackedColorArray([Color(1, 0.85, 0.6, 0), Color(1, 0.85, 0.6, 0.5), Color(1, 0.85, 0.6, 0.4), Color(1, 0.85, 0.6, 0)])
	p.color_ramp = ramp
	return p
