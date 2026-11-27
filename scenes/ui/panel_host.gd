class_name PanelHost
extends Control
## Opens one ModalPanel at a time over the location and switches GameManager
## into INSPECT mode while it is open, so hotspots stay inert underneath.

signal panel_opened(panel: ModalPanel)
signal panel_closed(panel_name: StringName)

var current_panel: ModalPanel


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func is_open() -> bool:
	return current_panel != null


func open(scene: PackedScene, ctx: Dictionary = {}) -> ModalPanel:
	if current_panel != null or scene == null:
		return null
	var panel := scene.instantiate() as ModalPanel
	if panel == null:
		push_error("PanelHost: scene is not a ModalPanel: %s" % scene.resource_path)
		return null
	if not ctx.has("host"):
		ctx["host"] = self
	panel.context = ctx
	panel.closed.connect(_on_panel_closed.bind(panel))
	current_panel = panel
	if GameManager.mode == GameManager.Mode.EXPLORE:
		GameManager.set_mode(GameManager.Mode.INSPECT)
	add_child(panel)
	panel_opened.emit(panel)
	return panel


## Closes the current panel (if any) and opens another once it has gone,
## e.g. resume viewer -> decision screen.
func switch_to(scene: PackedScene, ctx: Dictionary = {}) -> void:
	if current_panel == null:
		open(scene, ctx)
		return
	var closing := current_panel
	await closing.close()
	if current_panel == null or current_panel == closing:
		open(scene, ctx)


func close_current() -> void:
	if current_panel:
		current_panel.close()


func _on_panel_closed(panel: ModalPanel) -> void:
	var panel_name := StringName(panel.name)
	if panel == current_panel:
		current_panel = null
	panel.queue_free()
	if GameManager.mode == GameManager.Mode.INSPECT:
		GameManager.set_mode(GameManager.Mode.EXPLORE)
	panel_closed.emit(panel_name)
