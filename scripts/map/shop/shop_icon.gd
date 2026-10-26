## The picture of one counter item (HANDOFF_SPEC §5).
## - Dice: the real 3D model, from the shared rig in ShopDieRender.
## - Everything else is a token: a bone disc with a brass ring and a carved
##   glyph, chosen by art key from the GLYPHS table below.
class_name ShopIcon
extends Control

const BONE := Color("#E8DCC0")
const BRASS := Color("#C9A24A")
const INK := Color("#1E1712")
## Which glyph each art key carves. Keys not listed get their first letter.
## Seals ("seal_<combo>") draw an inner ring plus the combo's pips instead.
const GLYPHS := {
	&"mod_wild": "spark", &"mod_twin": "twin", &"mod_gilded": "coin",
	&"mod_ember_pip": "ring_dot", &"soul": "bottle",
}
## Pips shown inside a Seal token, by combo. Unlisted combos show a bar.
const SEAL_PIPS := {&"pair": 2, &"trips": 3, &"two_pair": 4, &"quads": 4, &"full_house": 5}

var offer: ShopOffer
## The 3D view for dice (null for tokens). Tests read it.
var die_view: SubViewport


## Size the icon and build its contents for `o`.
func setup(o: ShopOffer, px: float) -> void:
	offer = o
	custom_minimum_size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if o.kind == ShopOffer.Kind.DIE:
		_build_die(px)
	queue_redraw()


## Path of the model for art key `key` ("" if the file doesn't exist).
static func model_path(key: StringName) -> String:
	return ShopDieRender.model_path(key)


## Dice use the shared 3D rig in ShopDieRender.
func _build_die(px: float) -> void:
	var r := ShopDieRender.make(offer, px)
	if r == null:
		return  # No model yet: _draw shows a plain bone die instead.
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(r)
	die_view = r.view


func _draw() -> void:
	if offer == null:
		return
	var px := size.x
	var c := size / 2.0
	if offer.kind == ShopOffer.Kind.DIE:
		if die_view == null:  # Fallback die: a bone tile with one pip.
			draw_rect(Rect2(Vector2.ONE * px * 0.1, Vector2.ONE * px * 0.8), BONE)
			draw_circle(c, px * 0.08, INK)
		return
	var r := px * 0.48
	draw_circle(c, r, BRASS)
	draw_circle(c, r * (0.78 if offer.kind == ShopOffer.Kind.RARE_SEAL else 0.88), BONE)
	if offer.kind == ShopOffer.Kind.SEAL or offer.kind == ShopOffer.Kind.RARE_SEAL:
		_draw_seal(c, r)
	else:
		_draw_glyph(String(GLYPHS.get(offer.art_key, "")), c, r)


func _draw_seal(c: Vector2, r: float) -> void:
	var rare := offer.kind == ShopOffer.Kind.RARE_SEAL
	draw_arc(c, r * 0.62, 0, TAU, 40, BRASS if rare else INK, r * (0.16 if rare else 0.07), true)
	var n: int = SEAL_PIPS.get(offer.id, 0)
	if rare or n == 0:
		draw_rect(Rect2(c - Vector2(r * 0.32, r * 0.08), Vector2(r * 0.64, r * 0.16)), INK)
		return
	for p: Vector2 in DiceIcons.PIPS[n]:
		draw_circle(c + p * r * 0.22, r * 0.12, INK)


func _draw_glyph(g: String, c: Vector2, r: float) -> void:
	match g:
		"spark":  # Wild: a 4-point star.
			var pts := PackedVector2Array()
			for k in 8:
				var a := k * TAU / 8.0 - PI / 2.0
				pts.append(c + Vector2.from_angle(a) * r * (0.55 if k % 2 == 0 else 0.14))
			draw_colored_polygon(pts, INK)
		"twin":  # Twin: two overlapping dice.
			draw_rect(Rect2(c + Vector2(-0.45, -0.45) * r, Vector2.ONE * r * 0.5), INK)
			draw_rect(Rect2(c + Vector2(-0.08, -0.08) * r, Vector2.ONE * r * 0.55), INK, false, r * 0.08)
			draw_circle(c + Vector2(0.2, 0.2) * r, r * 0.08, INK)
		"coin":  # Gilded: a coin with a slot.
			draw_arc(c, r * 0.45, 0, TAU, 40, INK, r * 0.1, true)
			draw_rect(Rect2(c - Vector2(r * 0.07, r * 0.25), Vector2(r * 0.14, r * 0.5)), INK)
		"ring_dot":  # Ember Pip: a dot inside a ring.
			draw_arc(c, r * 0.42, 0, TAU, 40, INK, r * 0.08, true)
			draw_circle(c, r * 0.18, INK)
		"bottle":  # Soul Draught: a bottle.
			draw_rect(Rect2(c + Vector2(-0.12, -0.55) * r, Vector2(0.24, 0.25) * r), INK)
			draw_rect(Rect2(c + Vector2(-0.35, -0.3) * r, Vector2(0.7, 0.8) * r), INK)
		_:  # Any other mod: its first letter, carved.
			var f := RunTheme.title_font
			var t := offer.display_name.left(1).to_upper()
			var fs := int(r)
			var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			draw_string(f, c + Vector2(-w.x / 2.0, fs * 0.35), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, INK)
