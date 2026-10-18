## One casino chip, top-down (poc_feel.md 3): ink rim, 8 notches, value.
class_name ChipView
extends Node2D

const RADIUS: float = 32.0
## Stack offset per chip (spec: -6 px).
const STACK_STEP: float = -6.0
## Denominations, biggest first.
const DENOMS: Array[int] = [100, 25, 5, 1]

var value: int = 5:
	set(v):
		value = v
		queue_redraw()


static func color_for(v: int) -> Color:
	if v >= 100:
		return Palette.BRASS
	if v >= 25:
		return Color("#2E7D5B")
	if v >= 5:
		return Color("#A3242E")
	return Palette.BONE


## Greedy split of an amount into chip values (100/25/5/1).
static func break_into_chips(amount: int) -> Array[int]:
	var out: Array[int] = []
	var left := amount
	for d in DENOMS:
		while left >= d:
			out.append(d)
			left -= d
	return out


func _draw() -> void:
	var c := color_for(value)
	var light := Color.WHITE if value != 1 else Palette.PIT_BLACK
	# Edge/side (gives a little thickness under the face).
	draw_circle(Vector2(0, 3), RADIUS + 2, Palette.PIT_BLACK)
	draw_circle(Vector2.ZERO, RADIUS + 2, Palette.PIT_BLACK)
	draw_circle(Vector2.ZERO, RADIUS - 1, c)
	# 8 rim notches.
	for i in 8:
		var a := TAU * float(i) / 8.0
		var pts := PackedVector2Array()
		for k in 4:
			var aa := a + deg_to_rad(-9.0 + 18.0 * float(k / 2))
			var rr := RADIUS - 1.0 if k == 0 or k == 3 else RADIUS - 9.0
			pts.append(Vector2.from_angle(aa) * rr)
		draw_colored_polygon(pts, Color(Palette.BONE if value != 1 else Palette.BURGUNDY, 0.95))
	draw_arc(Vector2.ZERO, RADIUS - 12.0, 0.0, TAU, 32, Color(light, 0.55), 2.0)
	draw_circle(Vector2.ZERO, RADIUS - 13.0, c.darkened(0.12))
	Palette.draw_ink_text(self, Vector2(0, -1), str(value), 22, light if value != 1 else Palette.PIT_BLACK, 4 if value != 1 else 0)
