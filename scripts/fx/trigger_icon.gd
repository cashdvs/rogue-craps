## The trigger icon pop (spec 1.5): a Leather disc with a brass rim (rim
## studs by tier, a Danger rim + down-tab for costs), an Oxblood outline and
## a flat 2-tone Bone pictogram. Drawn in code until the icon atlas
## (fx_trigger_icons_atlas.png) exists. Sized in points at 1080p.
class_name TriggerIcon
extends Control

const DANGER := Color("#FF2E3E")

## Pictogram id (TriggerFxDefs row "icon").
var icon: StringName = &"generic"
## Rim studs (0 / 4 / 8 = minor / major / signature: tier is read by shape).
var studs: int = 0
## A cost trigger: Danger rim + a small down tab (the colour-blind cue).
var cost: bool = false
## Disc diameter in px.
var diameter: float = 24.0


func setup(icon_id: StringName, tier: int, px_per_pt: float, is_cost: bool = false) -> void:
	icon = icon_id
	studs = TriggerFxDefs.STUDS[tier]
	cost = is_cost
	diameter = TriggerFxDefs.ICON_PT[tier] * px_per_pt
	size = Vector2.ONE * diameter
	pivot_offset = size * 0.5
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := diameter * 0.5
	var rim := DANGER if cost else TriggerFxDefs.BRASS
	var ink := TriggerFxDefs.OXBLOOD
	var bone := TriggerFxDefs.BONE
	if cost:
		draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.3, r * 0.8), c + Vector2(r * 0.3, r * 0.8), c + Vector2(0, r * 1.25)]), rim)
	draw_circle(c, r, ink)
	draw_circle(c, r - 1.5, rim)
	draw_circle(c, r * 0.78, TriggerFxDefs.LEATHER)
	for i in studs:
		draw_circle(c + Vector2.from_angle(TAU * i / studs - PI / 2.0) * r * 0.89, maxf(1.2, r * 0.07), TriggerFxDefs.BRASS_HI)
	var s := r * 0.5  # pictogram half-size
	var w := maxf(1.5, r * 0.11)
	match icon:
		&"mirror":  # two facing half-squares and a centre line (symmetry)
			draw_rect(Rect2(c + Vector2(-s, -s * 0.8), Vector2(s * 0.75, s * 1.6)), bone)
			draw_rect(Rect2(c + Vector2(s * 0.25, -s * 0.8), Vector2(s * 0.75, s * 1.6)), bone, false, w)
			draw_line(c + Vector2(0, -s), c + Vector2(0, s), TriggerFxDefs.PIT_BLACK, maxf(1.0, w * 0.5))
		&"coin":  # a coin with one diamond glint
			draw_circle(c + Vector2(-s * 0.1, s * 0.1), s * 0.8, bone)
			draw_circle(c + Vector2(-s * 0.1, s * 0.1), s * 0.5, TriggerFxDefs.PIT_BLACK, false, maxf(1.0, w * 0.4))
			_diamond(c + Vector2(s * 0.75, -s * 0.75), s * 0.3, bone)
		&"coin_skull":  # coin with a skull, plus the up-chevron (heads)
			draw_circle(c + Vector2(0, s * 0.15), s * 0.8, bone)
			draw_circle(c + Vector2(-s * 0.25, s * 0.05), s * 0.15, TriggerFxDefs.PIT_BLACK)
			draw_circle(c + Vector2(s * 0.25, s * 0.05), s * 0.15, TriggerFxDefs.PIT_BLACK)
			draw_rect(Rect2(c + Vector2(-s * 0.2, s * 0.35), Vector2(s * 0.4, s * 0.15)), TriggerFxDefs.PIT_BLACK)
			draw_polyline(PackedVector2Array([c + Vector2(-s * 0.4, -s * 0.85), c + Vector2(0, -s * 1.15), c + Vector2(s * 0.4, -s * 0.85)]), bone, w)
		&"needles":  # three bone needles fanned upward
			for a: float in [-0.45, 0.0, 0.45]:
				var dir := Vector2.UP.rotated(a)
				var base := c + Vector2(0, s * 0.8)
				var n := dir.orthogonal() * s * 0.16
				draw_colored_polygon(PackedVector2Array([base - n, base + n, base + dir * s * 1.7]), bone)
		_:  # generic: one diamond spark
			_diamond(c, s * 0.8, bone)


func _diamond(at: Vector2, r: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([at + Vector2(0, -r), at + Vector2(r * 0.7, 0), at + Vector2(0, r), at + Vector2(-r * 0.7, 0)]), col)
