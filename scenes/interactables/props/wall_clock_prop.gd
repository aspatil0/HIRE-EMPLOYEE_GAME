extends Node2D
## Analog wall clock. Hour/minute hands follow the in-game time
## (GameState.time_minutes); the second hand ticks with real seconds to stay
## in sync with the ticking sound.

const R := 74.0

var _seconds: float = 0.0
var _last_tick: int = -1


func _ready() -> void:
	GameState.time_changed.connect(func(_m: int) -> void: queue_redraw())


func _process(delta: float) -> void:
	_seconds = fmod(_seconds + delta, 60.0)
	if int(_seconds) != _last_tick:
		_last_tick = int(_seconds)
		queue_redraw()


func _draw() -> void:
	Paint.soft(self, Vector2(8, 12), Vector2(R + 26, R + 26), Color(0, 0, 0, 0.55))
	draw_circle(Vector2.ZERO, R, Color(0.17, 0.11, 0.07))
	draw_arc(Vector2.ZERO, R - 2.0, PI * 1.1, PI * 1.6, 24, Color(0.6, 0.45, 0.3, 0.5), 2.0, true)
	draw_circle(Vector2.ZERO, R - 7.0, Color(0.5, 0.42, 0.3))
	draw_circle(Vector2.ZERO, R - 11.0, Color(0.86, 0.83, 0.75))
	draw_arc(Vector2.ZERO, R - 14.0, 0, TAU, 64, Color(0, 0, 0, 0.12), 6.0, true)
	for i in 60:
		var a := TAU * i / 60.0 - PI * 0.5
		var d := Vector2(cos(a), sin(a))
		var hour := i % 5 == 0
		var inner := R - (26.0 if hour else 19.0)
		draw_line(d * inner, d * (R - 15.0), Color(0.12, 0.11, 0.1), 3.0 if hour else 1.0, true)
	var font := UITheme.serif()
	var numerals := {12: Vector2(0, -38), 3: Vector2(40, 2), 6: Vector2(0, 42), 9: Vector2(-40, 2)}
	for n: int in numerals:
		var p: Vector2 = numerals[n]
		draw_string(font, p + Vector2(-15, 6), str(n), HORIZONTAL_ALIGNMENT_CENTER, 30, 15, Color(0.12, 0.11, 0.1))
	draw_string(UITheme.sans_spaced(), Vector2(-30, 24), "ASHGROVE", HORIZONTAL_ALIGNMENT_CENTER, 60, 7, Color(0.3, 0.27, 0.24))
	# Hands.
	var minutes := float(GameState.time_minutes % 60) + _seconds / 60.0
	var hours := fmod(float(GameState.time_minutes) / 60.0, 12.0)
	_hand(hours / 12.0, 30.0, 5.0, Color(0.1, 0.09, 0.08))
	_hand(minutes / 60.0, 48.0, 3.5, Color(0.1, 0.09, 0.08))
	_hand(float(int(_seconds)) / 60.0, 54.0, 1.3, Color(0.65, 0.1, 0.08), 14.0)
	draw_circle(Vector2.ZERO, 4.5, Color(0.2, 0.15, 0.1))
	draw_circle(Vector2.ZERO, 1.8, Color(0.75, 0.6, 0.35))
	# Glass glare.
	draw_arc(Vector2.ZERO, R - 22.0, PI * 1.15, PI * 1.45, 16, Color(1, 1, 1, 0.16), 7.0, true)


func _hand(turn: float, length: float, width: float, col: Color, tail: float = 8.0) -> void:
	var a := TAU * turn - PI * 0.5
	var d := Vector2(cos(a), sin(a))
	draw_line(-d * tail, d * length, col, width, true)
