## The Croupier of Cinders (doc v0.3 Floor 1 Dealer), built from simple
## shapes: burgundy coat, porcelain-bone mask with ember eyes and a wide
## grin, brass visor, long pale fingers on the rail. He bobs and sways
## idly, and react() plays a pose:
##   &"gloat"  - player lost: leans in, grin opens, bounces (laughing)
##   &"sulk"   - player won: recoils, eyes narrow, shakes
class_name DealerView
extends Node2D

enum Part { ALL, BODY, HANDS }
## Draw only the body (behind the rim) or only the hands (on the rail).
var part: Part = Part.ALL
var _t: float = 0.0
var _pose: StringName = &""
var _pose_time: float = 0.0
var _shake: float = 0.0
## 0..1 extra eye glow (pulses when he taunts).
var eye_glow: float = 0.0


func react(pose: StringName) -> void:
	_pose = pose
	_pose_time = 1.2
	_shake = 1.0 if pose == &"sulk" else 0.5


func _process(delta: float) -> void:
	_t += delta
	_pose_time = maxf(_pose_time - delta, 0.0)
	_shake = maxf(_shake - delta * 1.8, 0.0)
	eye_glow = maxf(eye_glow - delta * 1.5, 0.0)
	if _pose_time <= 0.0:
		_pose = &""
	queue_redraw()


func _draw() -> void:
	var bob := sin(_t * 1.7) * 4.0
	var sway := sin(_t * 0.8) * 0.03
	var lean := 0.0
	var bounce := 0.0
	var grin_open := 0.25
	var eye_squint := 0.0
	var k := _pose_time / 1.2
	if _pose == &"gloat":
		lean = 10.0 * k
		bounce = absf(sin(_t * 22.0)) * 8.0 * k
		grin_open = 0.25 + 0.75 * k
	elif _pose == &"sulk":
		lean = -12.0 * k
		eye_squint = 0.8 * k
		grin_open = 0.05
	var shake := Vector2(sin(_t * 70.0), cos(_t * 55.0)) * 5.0 * _shake * _shake
	var root := Vector2(0, bob - bounce + lean) + shake

	if part != Part.HANDS:
		_draw_body(root, sway, grin_open, eye_squint)
	if part != Part.BODY:
		_draw_hands(bob)


func _draw_body(root: Vector2, sway: float, grin_open: float, eye_squint: float) -> void:
	# --- Shoulders / coat (behind everything) ---
	draw_set_transform(root, sway, Vector2.ONE)
	var coat := PackedVector2Array([Vector2(-150, 140), Vector2(-120, 40), Vector2(-40, 10), Vector2(40, 10), Vector2(120, 40), Vector2(150, 140)])
	_ink_poly(coat, Palette.BURGUNDY)
	# Lapels and a brass pin.
	_ink_poly(PackedVector2Array([Vector2(-40, 10), Vector2(0, 90), Vector2(-28, 140), Vector2(-70, 40)]), Palette.OXBLOOD)
	_ink_poly(PackedVector2Array([Vector2(40, 10), Vector2(0, 90), Vector2(28, 140), Vector2(70, 40)]), Palette.OXBLOOD)
	_ink_poly(PackedVector2Array([Vector2(-14, 18), Vector2(14, 18), Vector2(0, 70)]), Palette.BONE.darkened(0.15))
	draw_circle(Vector2(-60, 70), 9, Palette.PIT_BLACK)
	draw_circle(Vector2(-60, 70), 6, Palette.BRASS)

	# --- Head: porcelain mask ---
	var head := Vector2(0, -26)
	draw_circle(head, 52 + Palette.INK, Palette.PIT_BLACK)
	draw_circle(head, 52, Palette.BONE)
	draw_circle(head + Vector2(-16, -18), 20, Color(1, 1, 1, 0.3))  # painted shine
	# Cracks in the porcelain.
	draw_polyline(PackedVector2Array([head + Vector2(22, -48), head + Vector2(14, -30), head + Vector2(24, -20), head + Vector2(16, -6)]), Palette.PIT_BLACK, 2.5)
	# Brass visor.
	_ink_poly(PackedVector2Array([head + Vector2(-64, -30), head + Vector2(64, -30), head + Vector2(48, -54), head + Vector2(-48, -54)]), Palette.BRASS)
	draw_line(head + Vector2(-56, -36), head + Vector2(56, -36), Palette.BRASS.lightened(0.35), 3.0)
	# Eyes: ember slits that narrow when he sulks and flare when he taunts.
	var eye_h := lerpf(11.0, 3.0, eye_squint)
	for sx in [-1.0, 1.0]:
		var e := head + Vector2(20 * sx, -8)
		_ink_poly(PackedVector2Array([e + Vector2(-14, 0), e + Vector2(0, -eye_h), e + Vector2(14, 0), e + Vector2(0, eye_h * 0.6)]), Palette.PIT_BLACK)
		var glow := Palette.EMBER.lerp(Color(1.0, 0.9, 0.6), eye_glow)
		draw_circle(e, 4.0 + eye_glow * 2.0, glow)
		if eye_glow > 0.0:
			draw_circle(e, 12.0 * eye_glow, Color(glow, 0.25 * eye_glow))
	# Grin: a wide crescent with teeth.
	var mouth_y := head.y + 22
	var open_h := 6.0 + 22.0 * grin_open
	var mouth := PackedVector2Array()
	for i in 13:
		var a := lerpf(-1.0, 1.0, i / 12.0)
		mouth.append(Vector2(a * 34, mouth_y - 4 + absf(a) * -6))
	for i in 13:
		var a := lerpf(1.0, -1.0, i / 12.0)
		mouth.append(Vector2(a * 30, mouth_y + open_h * (1.0 - a * a * 0.6)))
	_ink_poly(mouth, Palette.OXBLOOD.darkened(0.4))
	for i in 7:
		var x := -24 + i * 8
		draw_rect(Rect2(x - 3, mouth_y - 6 + absf(x / 34.0) * -6, 6, 7), Palette.BONE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_hands(bob: float) -> void:
	# --- Hands on the rail (don't sway with the body) ---
	for sx in [-1.0, 1.0]:
		var h := Vector2(170 * sx, 120 + bob * 0.3)
		for f in 4:
			var tip := h + Vector2((f - 1.5) * 13 * sx, 26 + (f % 2) * 4)
			draw_line(h, tip, Palette.PIT_BLACK, 11.0)
			draw_line(h, tip, Palette.BONE.darkened(0.25), 6.0)
		draw_circle(h, 15, Palette.PIT_BLACK)
		draw_circle(h, 11, Palette.BONE.darkened(0.25))


func _ink_poly(points: PackedVector2Array, fill: Color) -> void:
	draw_colored_polygon(points, fill)
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, Palette.PIT_BLACK, Palette.INK, true)
