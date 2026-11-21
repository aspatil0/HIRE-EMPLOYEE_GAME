class_name LightingRig
extends ColorRect
## Full-screen multiply lighting pass (see assets/shaders/lighting.gdshader).
##
## Place it above the environment art (z_index ~50) and below emissive details
## (screens, bulbs) which should stay at full brightness. Lights are registered
## by id so scene scripts can dim, toggle, flicker or flash them.

const SHADER := preload("res://assets/shaders/lighting.gdshader")
const MAX_LIGHTS := 10

@export var ambient: Color = Color(0.14, 0.16, 0.22)
@export var canvas_size: Vector2 = Vector2(1920, 1080)

var _lights: Dictionary[StringName, Dictionary] = {}
var _order: Array[StringName] = []
var _flash: float = 0.0
var _flash_color: Color = Color(0.6, 0.7, 0.95)
var _time: float = 0.0
var _mat: ShaderMaterial


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color.WHITE
	position = Vector2.ZERO
	size = canvas_size
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	material = _mat
	_push()


## flicker: 0..1, how much the light randomly wavers (old bulbs, CRT screens).
func add_light(id: StringName, pos: Vector2, radius: float, light_color: Color, intensity: float, squash: float = 1.0, flicker: float = 0.0) -> void:
	if not _lights.has(id):
		if _order.size() >= MAX_LIGHTS:
			push_warning("LightingRig: too many lights, ignoring '%s'" % id)
			return
		_order.append(id)
	_lights[id] = {
		"pos": pos, "radius": radius, "color": light_color, "intensity": intensity,
		"base": intensity, "squash": squash, "flicker": flicker, "seed": randf() * 100.0,
	}


func set_light_intensity(id: StringName, intensity: float, fade: float = 0.0) -> void:
	if not _lights.has(id):
		return
	if fade <= 0.0:
		_lights[id]["intensity"] = intensity
		return
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: _lights[id]["intensity"] = v, float(_lights[id]["intensity"]), intensity, fade)


func get_base_intensity(id: StringName) -> float:
	return float(_lights[id]["base"]) if _lights.has(id) else 0.0


## Brief cold flash over the whole room (lightning).
func flash(strength: float = 1.0, flash_color: Color = Color(0.6, 0.7, 0.95)) -> void:
	_flash = strength
	_flash_color = flash_color


func _process(delta: float) -> void:
	_time += delta
	_flash = maxf(0.0, _flash - delta * 2.2)
	_push()


func _push() -> void:
	if _mat == null:
		return
	var pos_arr := PackedVector4Array()
	var col_arr := PackedVector4Array()
	pos_arr.resize(MAX_LIGHTS)
	col_arr.resize(MAX_LIGHTS)
	var i := 0
	for id in _order:
		var L: Dictionary = _lights[id]
		var intensity: float = L["intensity"]
		var fl: float = L["flicker"]
		if fl > 0.0 and intensity > 0.0:
			var s: float = L["seed"]
			var n := sin(_time * 13.0 + s) * 0.5 + sin(_time * 31.7 + s * 2.0) * 0.3 + sin(_time * 2.3 + s) * 0.2
			intensity *= 1.0 - fl * (0.5 + 0.5 * n)
		var p: Vector2 = L["pos"]
		var c: Color = L["color"]
		pos_arr[i] = Vector4(p.x, p.y, L["radius"], intensity)
		col_arr[i] = Vector4(c.r, c.g, c.b, L["squash"])
		i += 1
	var amb := Vector3(ambient.r, ambient.g, ambient.b)
	if _flash > 0.0:
		var f := _flash * _flash
		amb += Vector3(_flash_color.r, _flash_color.g, _flash_color.b) * f
	_mat.set_shader_parameter(&"ambient", amb)
	_mat.set_shader_parameter(&"light_count", i)
	_mat.set_shader_parameter(&"lights", pos_arr)
	_mat.set_shader_parameter(&"light_colors", col_arr)
