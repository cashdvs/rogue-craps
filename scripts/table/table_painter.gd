## Draws the table (poc_feel.md 1). Two instances are used:
##   Mode.RIM      - wooden rim with bevel, brass trim, chipped notches
##                   (drawn under the felt ColorRect)
##   Mode.MARKINGS - point row boxes and the Pass Line arc band
##                   (drawn on top of the felt)
class_name TablePainter
extends Node2D

enum Mode { RIM, MARKINGS }

const RIM_RECT := Rect2(240, 120, 1440, 840)
const FELT_RECT := Rect2(280, 160, 1360, 760)
const POINT_NUMBERS: Array[int] = [4, 5, 6, 8, 9, 10]
const BOX_SIZE := Vector2(150, 110)
const BOX_GAP: float = 20.0
const BOX_Y: float = 170.0
const BOX_X0: float = 460.0
## Pass Line arc band (spec angles 200-340 deg in y-up = 20-160 deg y-down).
const PASS_CENTER := Vector2(960, 420)
const PASS_OUTER := Vector2(620, 480)
const PASS_INNER := Vector2(620, 370)
const PASS_LABEL_POS := Vector2(960, 860)

var mode: Mode = Mode.MARKINGS
var highlighted_point: int = 0
## Pass Line state for drawing.
var pass_bettable: bool = true
var pass_has_bet: bool = false
var pass_locked: bool = false
var pass_hover: bool = false
var _t: float = 0.0


static func point_box(n: int) -> Rect2:
	var i := POINT_NUMBERS.find(n)
	return Rect2(BOX_X0 + i * (BOX_SIZE.x + BOX_GAP), BOX_Y, BOX_SIZE.x, BOX_SIZE.y)


static func point_box_center(n: int) -> Vector2:
	return point_box(n).get_center()


## The Pass Line band as a polygon (for drawing and hit tests).
static func pass_polygon() -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps := 48
	for i in steps + 1:
		var a := deg_to_rad(lerpf(20.0, 160.0, float(i) / steps))
		pts.append(PASS_CENTER + Vector2(cos(a) * PASS_OUTER.x, sin(a) * PASS_OUTER.y))
	for i in steps + 1:
		var a := deg_to_rad(lerpf(160.0, 20.0, float(i) / steps))
		pts.append(PASS_CENTER + Vector2(cos(a) * PASS_INNER.x, sin(a) * PASS_INNER.y))
	return pts


static func pass_contains(p: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(p, pass_polygon())


func _process(delta: float) -> void:
	if mode == Mode.MARKINGS:
		_t += delta
		queue_redraw()


func _draw() -> void:
	if mode == Mode.RIM:
		_draw_rim()
	else:
		_draw_point_boxes()
		_draw_pass_line()


func _draw_rim() -> void:
	var ci := get_canvas_item()
	# Drop shadow onto the floor.
	Palette.ink_box(Color(0, 0, 0, 0.55), 150, 0).draw(ci, Rect2(RIM_RECT.position + Vector2(0, 18), RIM_RECT.size))
	# Wood body with ink outline.
	Palette.ink_box(Palette.RIM_WOOD, 140, 6).draw(ci, RIM_RECT)
	# Bevel: lighter top-inner band, darker bottom.
	var hi := Palette.ink_box(Color(0, 0, 0, 0), 132, 3, Color(Palette.RIM_WOOD_HI, 0.9))
	hi.draw(ci, RIM_RECT.grow(-8))
	var lo := Palette.ink_box(Color(0, 0, 0, 0), 128, 4, Color(0, 0, 0, 0.35))
	lo.draw(ci, Rect2(RIM_RECT.position + Vector2(12, 16), RIM_RECT.size - Vector2(24, 24)))
	# Wood grain streaks.
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for i in 40:
		var y := rng.randf_range(RIM_RECT.position.y + 10, RIM_RECT.end.y - 10)
		var x := rng.randf_range(RIM_RECT.position.x + 120, RIM_RECT.end.x - 300)
		if y > FELT_RECT.position.y - 6 and y < FELT_RECT.end.y + 6:
			continue
		draw_line(Vector2(x, y), Vector2(x + rng.randf_range(60, 200), y + rng.randf_range(-2, 2)), Color(Palette.RIM_WOOD_HI, 0.35), 2.0)
	# Brass trim around the felt.
	Palette.ink_box(Color(0, 0, 0, 0), 118, 4, Palette.BRASS).draw(ci, FELT_RECT.grow(8))
	Palette.ink_box(Color(0, 0, 0, 0), 120, 2, Palette.PIT_BLACK).draw(ci, FELT_RECT.grow(12))
	# Chipped notches along the outer edge.
	for i in 14:
		var t := rng.randf()
		var edge := rng.randi_range(0, 1)
		var p := Vector2(lerpf(RIM_RECT.position.x + 160, RIM_RECT.end.x - 160, t), RIM_RECT.position.y + 3 if edge == 0 else RIM_RECT.end.y - 3)
		var w := rng.randf_range(8, 18)
		var dy := 7.0 if edge == 0 else -7.0
		draw_colored_polygon(PackedVector2Array([p + Vector2(-w, 0), p + Vector2(w, 0), p + Vector2(w * 0.2, dy)]), Palette.PIT_BLACK)


func _draw_point_boxes() -> void:
	var names := {4: "4", 5: "5", 6: "SIX", 8: "8", 9: "NINE", 10: "10"}
	for n in POINT_NUMBERS:
		var r := point_box(n)
		if n == highlighted_point:
			draw_rect(r, Color(Palette.BRASS, 0.18 + 0.06 * sin(_t * 4.0)))
		draw_rect(r.grow(2), Color(Palette.PIT_BLACK, 0.6), false, 6.0)
		draw_rect(r, Color(Palette.BONE, 0.8), false, 3.0)
		var big := n != 6 and n != 9
		Palette.draw_ink_text(self, r.get_center(), names[n], 56 if big else 40, Palette.BONE, 8, true)


func _draw_pass_line() -> void:
	var poly := pass_polygon()
	draw_colored_polygon(poly, Palette.FELT_DARK)
	if pass_hover and pass_bettable:
		draw_colored_polygon(poly, Color(Palette.BONE, 0.06))
	var border := Color(Palette.BONE, 0.7)
	if pass_has_bet:
		border = Palette.BRASS
	elif pass_bettable:
		border = Color(Palette.BONE, 0.55 + 0.25 * (0.5 + 0.5 * sin(_t * TAU / 1.4)))
	if pass_locked:
		border = Color(Palette.BRASS, 0.6)
	var closed := poly.duplicate()
	closed.append(poly[0])
	draw_polyline(closed, Color(Palette.PIT_BLACK, 0.7), 10.0, true)
	draw_polyline(closed, border, 4.0, true)
	Palette.draw_ink_text(self, PASS_LABEL_POS, "PASS LINE", 72, Palette.BONE, 10, true)
	if pass_locked:
		Palette.draw_ink_text(self, Vector2(660, 880), "LOCKED", 26, Palette.BRASS, 6)
