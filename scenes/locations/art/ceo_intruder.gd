class_name CEOIntruder
extends Node2D
## Aditya bursting into Alice's office during a CEO intervention: the door
## swings open onto a cold corridor, his silhouette fills the frame and his
## eyes burn red. Drawn in office screen space over the door (x 1694-1920).
## Call enter() / leave(); `presence` (0..1) drives the whole effect.

const DOOR := Rect2(1718, 52, 210, 560)
const HEAD := Vector2(1822, 196)

var presence: float = 0.0:
	set(v):
		presence = v
		visible = v > 0.01
		queue_redraw()
		if _eyes:
			_eyes.queue_redraw()

var _eyes: Node2D
var _time: float = 0.0
var _tween: Tween


func _ready() -> void:
	visible = false
	_eyes = Node2D.new()
	_eyes.name = "Eyes"
	_eyes.z_index = 60 # above the LightingRig: the eyes glow in the dark
	add_child(_eyes)
	_eyes.draw.connect(_draw_eyes)


func _process(delta: float) -> void:
	if presence > 0.01:
		_time += delta
		_eyes.queue_redraw()


func enter(duration: float = 1.6) -> void:
	_animate(1.0, duration)


func leave(duration: float = 1.2) -> void:
	_animate(0.0, duration)


func _animate(target: float, duration: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "presence", target, duration).set_trans(Tween.TRANS_SINE)


func _draw() -> void:
	var p := presence
	# The door swung open: a harsh corridor light behind him.
	Paint.vgrad(self, DOOR, Color(0.7, 0.78, 0.82, p), Color(0.38, 0.44, 0.48, p))
	Paint.soft(self, Vector2(DOOR.get_center().x, DOOR.position.y + 30), Vector2(150, 90), Color(0.9, 0.95, 1.0, 0.5 * p), true)
	# The door slab, opened inward, seen edge-on.
	Paint.quad(self, DOOR.position, DOOR.position + Vector2(46, 26), Vector2(DOOR.position.x + 46, DOOR.end.y - 10), Vector2(DOOR.position.x, DOOR.end.y), Color(0.16, 0.11, 0.07, p))
	# Long shadow thrown into the room.
	Paint.soft(self, Vector2(1790, 610), Vector2(170, 30), Color(0, 0, 0, 0.7 * p))
	# Silhouette: shoulders and suit fill the doorway.
	var s := Color(0.025, 0.02, 0.025, p)
	var body := PackedVector2Array([
		HEAD + Vector2(-26, 44), HEAD + Vector2(26, 44), HEAD + Vector2(96, 86), HEAD + Vector2(112, 140),
		HEAD + Vector2(104, 430), HEAD + Vector2(-104, 430), HEAD + Vector2(-112, 140), HEAD + Vector2(-96, 86)])
	draw_colored_polygon(body, s)
	Paint.quad(self, HEAD + Vector2(-17, 26), HEAD + Vector2(17, 26), HEAD + Vector2(20, 50), HEAD + Vector2(-20, 50), s)
	Paint.ellipse(self, HEAD, Vector2(34, 43), s)
	# Cold rim light from the corridor.
	var rim := Color(0.7, 0.8, 0.95, 0.55 * p)
	draw_arc(HEAD, 44.0, PI * 1.05, PI * 1.95, 20, rim, 2.0, true)
	draw_polyline(PackedVector2Array([HEAD + Vector2(-96, 86), HEAD + Vector2(-26, 46)]), rim, 2.0, true)
	draw_polyline(PackedVector2Array([HEAD + Vector2(26, 46), HEAD + Vector2(96, 86)]), rim, 2.0, true)


func _draw_eyes() -> void:
	if presence <= 0.01:
		return
	# Eyes ignite a little after he appears, and pulse with anger.
	var burn := clampf((presence - 0.35) / 0.65, 0.0, 1.0)
	var pulse := 0.78 + 0.22 * sin(_time * 7.0) + 0.08 * sin(_time * 23.0)
	var a := burn * pulse
	for x in [-13.0, 13.0]:
		var e: Vector2 = HEAD + Vector2(x, -4)
		Paint.soft(_eyes, e, Vector2(34, 22), Color(1.0, 0.08, 0.04, 0.55 * a), true)
		Paint.ellipse(_eyes, e, Vector2(7, 3.2), Color(1.0, 0.18, 0.1, a))
		Paint.ellipse(_eyes, e, Vector2(3, 1.4), Color(1.0, 0.85, 0.7, a))
	Paint.soft(_eyes, HEAD + Vector2(0, -4), Vector2(70, 40), Color(0.9, 0.05, 0.02, 0.18 * a), true)
