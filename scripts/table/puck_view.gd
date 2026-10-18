## The Point puck (poc_feel.md 4): OFF = black, ON = bone with the number.
class_name PuckView
extends Node2D

const DIAMETER: float = 96.0

var is_on: bool = false
var number: int = 0
## 0..1 DANGER flash (seven-out).
var danger: float = 0.0
var _glow_t: float = 0.0


func _process(delta: float) -> void:
	_glow_t += delta
	queue_redraw()


## Flip to ON with `n` and arc-move to `target` (30 px lift, TRANS_BACK).
func turn_on(n: int, target: Vector2, t: TuningData, reduced: bool) -> void:
	await _flip(true, n, t.puck_flip_time)
	await _arc_move(target, t.puck_move_time, reduced)


## Flip back to OFF and return to the OFF spot.
func turn_off(target: Vector2, t: TuningData, reduced: bool) -> void:
	await _flip(false, 0, t.puck_flip_time)
	await _arc_move(target, t.puck_return_time, reduced)


func flash_danger() -> void:
	danger = 1.0
	var tw := create_tween()
	tw.tween_property(self, "danger", 0.0, 0.6)


func _flip(on: bool, n: int, seconds: float) -> void:
	var tw := create_tween()
	tw.tween_property(self, "scale:x", 0.0, seconds * 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_set_face.bind(on, n))
	tw.tween_property(self, "scale:x", 1.0, seconds * 0.5).set_trans(Tween.TRANS_SINE)
	await tw.finished


func _arc_move(target: Vector2, seconds: float, reduced: bool) -> void:
	var start := position
	var tw := create_tween()
	if reduced:
		tw.tween_property(self, "position", target, seconds)
	else:
		tw.tween_method(_arc_step.bind(start, target), 0.0, 1.0, seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished
	position = target


func _set_face(on: bool, n: int) -> void:
	is_on = on
	number = n


func _arc_step(p: float, start: Vector2, target: Vector2) -> void:
	position = start.lerp(target, p) + Vector2(0, -30.0 * sin(PI * clampf(p, 0.0, 1.0)))


func _draw() -> void:
	var r := DIAMETER * 0.5
	if is_on:
		# Soft brass glow, pulsing 0.4..0.6 over 1.6 s.
		var a := 0.4 + 0.1 * (1.0 + sin(_glow_t * TAU / 1.6))
		for i in 5:
			draw_circle(Vector2.ZERO, r + 14.0 - float(i) * 3.0, Color(Palette.BRASS_HI, a * 0.12))
	draw_circle(Vector2(0, 4), r + 3, Palette.PIT_BLACK)
	draw_circle(Vector2.ZERO, r + 3, Palette.PIT_BLACK)
	var fill := Palette.BONE if is_on else Palette.PIT_BLACK
	draw_circle(Vector2.ZERO, r - 1, fill)
	draw_arc(Vector2.ZERO, r - 7, 0.0, TAU, 40, Palette.BRASS if is_on else Color(Palette.BONE, 0.6), 2.0)
	if danger > 0.0:
		draw_circle(Vector2.ZERO, r - 1, Color(Palette.DANGER, danger * 0.85))
	if is_on:
		Palette.draw_ink_text(self, Vector2(0, -22), "ON", 18, Palette.PIT_BLACK, 0, true)
		Palette.draw_ink_text(self, Vector2(0, 10), str(number), 40, Palette.BURGUNDY, 0, true)
	else:
		Palette.draw_ink_text(self, Vector2.ZERO, "OFF", 26, Palette.BONE, 0, true)
