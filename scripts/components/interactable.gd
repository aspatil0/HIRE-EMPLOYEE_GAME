class_name Interactable
extends Area2D
## Reusable clickable hotspot for a physical object in a fixed-camera location.
##
## Add as a child of a prop (the prop is brightened on hover) with one or more
## CollisionPolygon2D children describing the clickable shape. An
## InteractionController in the location handles mouse picking, cursor,
## tooltip, opening panel_scene on left-click and inspection on right-click.
##
## Behaviour on left-click, in order:
##   1. emits `activated` (props can connect to it for custom actions)
##   2. opens panel_scene if set
##   3. otherwise, if activate_inspects, shows the inspect text

signal hovered(target: Interactable)
signal unhovered(target: Interactable)
signal activated(target: Interactable)
signal inspected(target: Interactable)

@export var interaction_id: StringName = &""
@export var display_name: String = "Object"
## Verb shown in the tooltip for left-click ("Open", "Use", "Answer"...).
@export var action_verb: String = "Use"
## Alice's thoughts on right-click.
@export_multiline var inspect_text: String = ""
@export var panel_scene: PackedScene
@export var activate_inspects: bool = false
@export var enabled: bool = true
## Higher wins when hotspots overlap.
@export var pick_priority: int = 0
## CanvasItem brightened on hover. Empty = parent node.
@export var highlight_target: NodePath
@export var highlight_color: Color = Color(1.28, 1.2, 1.08)
## Off for hotspots on large shared art (walls, doors) where only the rim should show.
@export var brighten: bool = true
@export var rim_color: Color = Color(1.0, 0.82, 0.55, 0.22)
@export var interact_sound: StringName = &"ui_click"

var is_hovered: bool = false

var _target: CanvasItem
var _hover_amount: float = 0.0
var _tween: Tween
var _polygons: Array[PackedVector2Array] = []
var _rims: Array[PackedVector2Array] = []


func _ready() -> void:
	input_pickable = false # picking is done by InteractionController
	monitoring = false
	monitorable = false
	if z_index == 0:
		z_index = 65 # draw the hover rim above the LightingRig (z 50)
	_collect_polygons()
	add_to_group(&"interactables")
	if highlight_target.is_empty():
		_target = get_parent() as CanvasItem
	else:
		_target = get_node_or_null(highlight_target) as CanvasItem


func _collect_polygons() -> void:
	_polygons.clear()
	_rims.clear()
	for child in get_children():
		if child is CollisionPolygon2D:
			var cp := child as CollisionPolygon2D
			var pts := PackedVector2Array()
			for p in cp.polygon:
				pts.append(cp.transform * p)
			_polygons.append(pts)
			var grown := Geometry2D.offset_polygon(pts, 6.0, Geometry2D.JOIN_ROUND)
			if not grown.is_empty():
				var rim: PackedVector2Array = grown[0]
				rim.append(rim[0])
				_rims.append(rim)


## True if a global point is inside any of this hotspot's polygons.
func contains_global_point(global_point: Vector2) -> bool:
	if not enabled or not is_visible_in_tree():
		return false
	var local := to_local(global_point)
	for poly in _polygons:
		if Geometry2D.is_point_in_polygon(local, poly):
			return true
	return false


func set_hovered(on: bool) -> void:
	if on == is_hovered:
		return
	is_hovered = on
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_hover_amount, _hover_amount, 1.0 if on else 0.0, 0.18 if on else 0.3)
	if on:
		hovered.emit(self)
	else:
		unhovered.emit(self)


func activate() -> void:
	activated.emit(self)


func inspect() -> void:
	inspected.emit(self)


func _set_hover_amount(v: float) -> void:
	_hover_amount = v
	if _target and brighten:
		_target.modulate = Color.WHITE.lerp(highlight_color, v)
	queue_redraw()


func _draw() -> void:
	if _hover_amount <= 0.01:
		return
	# Faint warm rim around the object; brightness of the prop does most of the work.
	var c := rim_color
	c.a *= _hover_amount
	for rim in _rims:
		draw_polyline(rim, c, 1.5, true)
		var soft := c
		soft.a *= 0.25
		draw_polyline(rim, soft, 8.0, true)
