## Placeholder chip icon for the Target HUD (icon_placeholders_2x.png):
## a flat brass shape drawn in code, picked by the bounty's icon_id. Swap
## for the painted icons later; only SHAPES changes then.
## lit = false (e.g. Clean Hands after a bust) dims it and strikes it out.
class_name GoalIcon
extends Control

## Run Bounty icon_id -> placeholder shape (icon_placeholders_2x.png, right).
const SHAPES: Dictionary[StringName, StringName] = {
	&"three_of_a_kind": &"triangle", &"straight_shooter": &"chevrons", &"pair_up": &"half",
	&"high_roller": &"bars", &"powder_pact": &"circle", &"usurers_ledger": &"page",
	&"clean_hands": &"diamond", &"crooked_wheel": &"hexagon", &"house_seal": &"square",
}

var icon_id: StringName = &""
var lit: bool = true
var color: Color = Palette.BRASS_HI


## The shape for an icon_id (a shape name works too; unknown = circle).
static func shape_for(id: StringName) -> StringName:
	if SHAPES.has(id):
		return SHAPES[id]
	return id if id in SHAPES.values() else &"circle"


func _draw() -> void:
	var c := color if lit else Color(color, 0.35)
	var r := minf(size.x, size.y) * 0.5
	var m := size * 0.5
	match shape_for(icon_id):
		&"triangle":
			draw_colored_polygon(PackedVector2Array([m + Vector2(0, -r), m + Vector2(r, r * 0.8), m + Vector2(-r, r * 0.8)]), c)
		&"chevrons":
			for dx in [-0.5, 0.25]:
				var o := m + Vector2(dx * r, 0)
				draw_polyline(PackedVector2Array([o + Vector2(-r * 0.3, -r * 0.7), o + Vector2(r * 0.3, 0), o + Vector2(-r * 0.3, r * 0.7)]), c, r * 0.22)
		&"half":
			draw_arc(m, r * 0.85, 0, TAU, 32, c, r * 0.18)
			draw_colored_polygon(_arc_points(m, r * 0.85, PI * 0.5, PI * 1.5), c)
		&"bars":
			for i in 3:
				var h := r * (0.8 + 0.6 * i)
				draw_rect(Rect2(m.x - r + i * r * 0.72, m.y + r - h, r * 0.55, h), c)
		&"page":
			draw_rect(Rect2(m - Vector2(r * 0.75, r), Vector2(r * 1.5, r * 2)), c)
			for i in 3:
				draw_line(m + Vector2(-r * 0.45, -r * 0.4 + i * r * 0.45), m + Vector2(r * 0.45, -r * 0.4 + i * r * 0.45), Palette.PIT_BLACK, r * 0.14)
		&"diamond":
			draw_colored_polygon(PackedVector2Array([m + Vector2(0, -r), m + Vector2(r, 0), m + Vector2(0, r), m + Vector2(-r, 0)]), c)
		&"hexagon":
			var pts := PackedVector2Array()
			for i in 6:
				pts.append(m + Vector2.from_angle(TAU * i / 6.0) * r)
			draw_colored_polygon(pts, c)
		&"square":
			draw_rect(Rect2(m - Vector2.ONE * r * 0.8, Vector2.ONE * r * 1.6), c)
		&"ring":
			draw_arc(m, r * 0.75, 0, TAU, 32, c, r * 0.3)
		&"plus":
			draw_rect(Rect2(m - Vector2(r, r * 0.3), Vector2(r * 2, r * 0.6)), c)
			draw_rect(Rect2(m - Vector2(r * 0.3, r), Vector2(r * 0.6, r * 2)), c)
		_:
			draw_circle(m, r * 0.9, c)
	if not lit:  # struck through
		draw_line(Vector2(0, size.y), Vector2(size.x, 0), Palette.BONE, maxf(2.0, r * 0.15))


func _arc_points(center: Vector2, r: float, from: float, to: float) -> PackedVector2Array:
	var pts := PackedVector2Array([center])
	for i in 17:
		pts.append(center + Vector2.from_angle(lerpf(from, to, i / 16.0)) * r)
	return pts
