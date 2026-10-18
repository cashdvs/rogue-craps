## The felt's printed markings (point boxes 4-10 and the Pass Line arc),
## drawn in 2D into a 2048x1024 SubViewport whose texture the 3D felt shows
## (poc_3d.md section 2: "one decal texture ... or baked into the felt
## albedo"). Redraw it (refresh()) when a highlight changes.
class_name FeltPrint
extends Node2D

const TEX := Vector2(2048, 1024)

var highlighted_point: int = 0
var pass_bettable: bool = false
var pass_hover: bool = false
var pass_has_bet: bool = false
var pass_locked: bool = false
var viewport: SubViewport


static func make() -> FeltPrint:
	var p := FeltPrint.new()
	var vp := SubViewport.new()
	vp.size = Vector2i(TEX)
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.add_child(p)
	p.viewport = vp
	return p


## Felt meters (x, z) -> texture pixels. The felt bed is 2.04 x 1.04 m.
static func to_px(x: float, z: float) -> Vector2:
	return Vector2((x / (Table3DBuilder.FELT_HALF.x * 2.0) + 0.5) * TEX.x, (z / (Table3DBuilder.FELT_HALF.y * 2.0) + 0.5) * TEX.y)


static func m_to_px(m: float) -> float:
	return m / (Table3DBuilder.FELT_HALF.x * 2.0) * TEX.x


func refresh() -> void:
	queue_redraw()
	if viewport != null:
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _draw() -> void:
	var ink := Color(Palette.BONE, 0.85)
	# Point boxes.
	for n in Table3DBuilder.POINT_NUMBERS:
		var c := Table3DBuilder.point_box_center(n)
		var half := Table3DBuilder.BOX_SIZE * 0.5
		var r := Rect2(to_px(c.x - half.x, c.z - half.y), Vector2(m_to_px(Table3DBuilder.BOX_SIZE.x), m_to_px(Table3DBuilder.BOX_SIZE.y)))
		var lit := n == highlighted_point
		if lit:
			draw_rect(r, Color(Palette.BRASS_HI, 0.22))
		draw_rect(r, Palette.BRASS_HI if lit else ink, false, 10.0 if lit else 6.0)
		var label := {6: "SIX", 9: "NINE"}.get(n, str(n)) as String
		var font := Palette.display_font()
		var size := int(m_to_px(0.11) * (0.62 if label.length() > 2 else 1.0))
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		draw_string(font, r.get_center() + Vector2(-w * 0.5, size * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Palette.BRASS_HI if lit else ink)
	# Pass Line band (an elliptical arc near the player).
	var outer := _arc(Table3DBuilder.PASS_OUTER)
	var inner := _arc(Table3DBuilder.PASS_INNER)
	var band := outer.duplicate()
	inner.reverse()
	band.append_array(inner)
	var fill := Color(0, 0, 0, 0)
	if pass_hover and pass_bettable:
		fill = Color(Palette.EMBER, 0.28)
	elif pass_bettable and not pass_has_bet:
		fill = Color(Palette.EMBER, 0.12)
	elif pass_locked:
		fill = Color(Palette.PIT_BLACK, 0.25)
	if fill.a > 0.0:
		draw_colored_polygon(band, fill)
	var closed := band.duplicate()
	closed.append(band[0])
	draw_polyline(closed, ink, 6.0, true)
	# "PASS LINE" along the band center.
	var text := "PASS LINE" if not pass_locked else "LOCKED"
	var font2 := Palette.display_font()
	var fsize := int(m_to_px(0.07) * 1.3)
	var mid := (Table3DBuilder.PASS_INNER + Table3DBuilder.PASS_OUTER) * 0.5
	var span := 34.0
	for i in text.length():
		var a := deg_to_rad(270.0 - span * 0.5 + span * (float(i) + 0.5) / text.length())
		var p := to_px(Table3DBuilder.PASS_CENTER.x + mid.x * cos(a), Table3DBuilder.PASS_CENTER.y - mid.y * sin(a))
		var tangent := Vector2(-sin(a) * mid.x, -cos(a) * mid.y).normalized()
		draw_set_transform(p, tangent.angle(), Vector2.ONE)
		var cw := font2.get_char_size(text.unicode_at(i), fsize).x
		draw_char(font2, Vector2(-cw * 0.5, fsize * 0.35), text[i], fsize, ink)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Bet spot.
	var spot := to_px(Table3DBuilder.BET_SPOT.x, Table3DBuilder.BET_SPOT.z)
	draw_arc(spot, m_to_px(0.05), 0.0, TAU, 48, ink, 5.0, true)


func _arc(radii: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var c := Table3DBuilder.PASS_CENTER
	for i in 41:
		var a := deg_to_rad(lerpf(200.0, 340.0, float(i) / 40.0))
		var x := clampf(c.x + radii.x * cos(a), -Table3DBuilder.FELT_HALF.x + 0.02, Table3DBuilder.FELT_HALF.x - 0.02)
		var z := clampf(c.y - radii.y * sin(a), -Table3DBuilder.FELT_HALF.y + 0.02, Table3DBuilder.FELT_HALF.y - 0.02)
		pts.append(to_px(x, z))
	return pts
