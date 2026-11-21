class_name ShiftClock
extends Node
## Advances GameState's in-game clock while the player is in control.
## Time stands still during dialogue, open interfaces and pause.

@export var real_seconds_per_minute: float = 8.0
@export var running: bool = true

var _accum: float = 0.0


func _process(delta: float) -> void:
	if not running or GameManager.mode != GameManager.Mode.EXPLORE:
		return
	_accum += delta
	while _accum >= real_seconds_per_minute:
		_accum -= real_seconds_per_minute
		GameState.advance_time(1)
