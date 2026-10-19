## The trigger icon pop (spec 1.5): a Leather disc with a brass rim (rim
## studs by tier, a Danger rim + down-tab for costs), an Oxblood outline and
## a flat 2-tone Bone pictogram. 28 / 30 / 32 px at 720p by tier (Art
## Director, v1 review). Uses the Art Director's baked icons
## (assets/vfx/trigger_fx/icons/icon_<row>.png: disc, rim, studs, glyph,
## README option A) when the file exists and the trigger isn't a cost the
## art doesn't carry; otherwise the code-drawn stand-in below. The art's
## disc is 112 px of its 128 px cell, so the cell is drawn 128/112 x the
## disc diameter. icon &"brass_coin" is the Gilded flight coin: the brass
## sprite's flip frames (coin_frame 0 face / 1 tilt / 2 edge).
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
var diameter: float = 28.0
## Flight coin frame: 0 face, 1 tilt, 2 edge.
var coin_frame: int = 0:
	set(v):
		if v != coin_frame:
			coin_frame = v
			queue_redraw()
var _art: Texture2D
## The coin's flip frames, loaded in setup() (never inside _draw: a texture
## first loaded mid-draw records as a blank white rect).
var _coin_tex: Array[Texture2D] = []
const COIN_FRAMES: Array[String] = ["coin_brass_face", "coin_brass_tilt", "coin_brass_edge"]
## Art disc radius / cell (README: centre (64, 62), radius 56 in 128).
const ART_DISC: float = 112.0 / 128.0
const ART_CENTRE := Vector2(64.0, 62.0) / 128.0


## px_scale: viewport height / 720.
func setup(icon_id: StringName, tier: int, px_scale: float, is_cost: bool = false) -> void:
	icon = icon_id
	studs = TriggerFxDefs.STUDS[tier]
	cost = is_cost
	diameter = TriggerFxDefs.ICON_PX_720[tier] * px_scale
	var path := TriggerFxDefs.ART_DIR + "icons/icon_%s.png" % icon_id
	_art = load(path) as Texture2D if ResourceLoader.exists(path) and not is_cost else null
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_coin_tex.clear()
	if icon_id == &"brass_coin":
		for n in COIN_FRAMES:
			var t := TriggerShapes.fixed(n)
			if t != null:
				_coin_tex.append(t)
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
	if _art != null:
		var cell := diameter / ART_DISC
		draw_texture_rect(_art, Rect2(c - ART_CENTRE * cell, Vector2.ONE * cell), false)
		return
	if icon == &"brass_coin":
		if _coin_tex.size() == COIN_FRAMES.size():
			draw_texture_rect(_coin_tex[clampi(coin_frame, 0, 2)], Rect2(c - size * 0.5, size), false)
			return
		draw_circle(c, r, ink)
		draw_circle(c, r - maxf(1.5, r * 0.12), TriggerFxDefs.BRASS)
		draw_circle(c, r * 0.6, TriggerFxDefs.BRASS_HI, false, maxf(1.5, r * 0.12))
		_diamond(c + Vector2(-r * 0.3, -r * 0.3), r * 0.22, TriggerFxDefs.EMBER_CORE)
		return
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
		&"mirror_copy":  # two facing half-squares and a centre line (symmetry)
			draw_rect(Rect2(c + Vector2(-s, -s * 0.8), Vector2(s * 0.75, s * 1.6)), bone)
			draw_rect(Rect2(c + Vector2(s * 0.25, -s * 0.8), Vector2(s * 0.75, s * 1.6)), bone, false, w)
			draw_line(c + Vector2(0, -s), c + Vector2(0, s), TriggerFxDefs.PIT_BLACK, maxf(1.0, w * 0.5))
		&"gilded_payout":  # a coin with one diamond glint
			draw_circle(c + Vector2(-s * 0.1, s * 0.1), s * 0.8, bone)
			draw_circle(c + Vector2(-s * 0.1, s * 0.1), s * 0.5, TriggerFxDefs.PIT_BLACK, false, maxf(1.0, w * 0.4))
			_diamond(c + Vector2(s * 0.75, -s * 0.75), s * 0.3, bone)
		&"coin_heads_copy":  # coin with a skull, plus the up-chevron (heads)
			draw_circle(c + Vector2(0, s * 0.15), s * 0.8, bone)
			draw_circle(c + Vector2(-s * 0.25, s * 0.05), s * 0.15, TriggerFxDefs.PIT_BLACK)
			draw_circle(c + Vector2(s * 0.25, s * 0.05), s * 0.15, TriggerFxDefs.PIT_BLACK)
			draw_rect(Rect2(c + Vector2(-s * 0.2, s * 0.35), Vector2(s * 0.4, s * 0.15)), TriggerFxDefs.PIT_BLACK)
			draw_polyline(PackedVector2Array([c + Vector2(-s * 0.4, -s * 0.85), c + Vector2(0, -s * 1.15), c + Vector2(s * 0.4, -s * 0.85)]), bone, w)
		&"hellfire_face":  # three bone needles fanned upward
			for a: float in [-0.45, 0.0, 0.45]:
				var dir := Vector2.UP.rotated(a)
				var base := c + Vector2(0, s * 0.8)
				var n := dir.orthogonal() * s * 0.16
				draw_colored_polygon(PackedVector2Array([base - n, base + n, base + dir * s * 1.7]), bone)
		_:  # generic: one diamond spark
			_diamond(c, s * 0.8, bone)


func _diamond(at: Vector2, r: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([at + Vector2(0, -r), at + Vector2(r * 0.7, 0), at + Vector2(0, r), at + Vector2(-r * 0.7, 0)]), col)
