## The rare treatment (HANDOFF_SPEC §5): a brass RARE chip and a
## bone-and-brass plinth. Both are driven only by `offer.rare` (set from the
## die's rarity data or the Rare Seal), so no die needs its own layout code.
## No glow: flat brass and bone only.
class_name RareMarks
extends RefCounted

const BRASS := Color("#C9A24A")
const BONE := Color("#E8DCC0")
const DARK := Color("#1E1712")
## Spec chip size is 52x20 spec px; the label inside is 16 spec px.
const CHIP_W := 52.0
const CHIP_H := 20.0


## A brass "RARE" chip. `font_px` is the label size, `k` design px per spec px.
## Used by the shelf item (above its icon) and the side card (by the title).
static func chip(font_px: int, k: float) -> Label:
	var c := RunTheme.label("RARE", font_px, DARK)
	c.name = "RareChip"
	var b := StyleBoxFlat.new()
	b.bg_color = BRASS
	b.set_corner_radius_all(int(4 * k))
	b.set_content_margin_all(maxf(1.0, 2.0 * k))
	b.content_margin_left = 6 * k
	b.content_margin_right = 6 * k
	c.add_theme_stylebox_override("normal", b)
	c.autowrap_mode = TextServer.AUTOWRAP_OFF
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.custom_minimum_size = Vector2(CHIP_W, CHIP_H) * k
	c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## A plinth drawn behind the bottom of `icon` (a rare die sits on it).
## It is a child of the icon, so it moves with it when the item lifts.
static func plinth(icon: Control, px: float) -> Control:
	var p := Control.new()
	p.name = "Plinth"
	p.show_behind_parent = true  # Behind the 3D die, in front of the shelf.
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.position = Vector2(-px * 0.05, px * 0.86)
	p.size = Vector2(px * 1.1, px * 0.2)
	p.draw.connect(_draw_plinth.bind(p))
	icon.add_child(p)
	return p


## Bone trapezoid (wide at the base) with a brass cap and brass foot.
static func _draw_plinth(p: Control) -> void:
	var w := p.size.x
	var h := p.size.y
	var inset := w * 0.08
	var body := PackedVector2Array([Vector2(inset, 0), Vector2(w - inset, 0), Vector2(w, h), Vector2(0, h)])
	p.draw_colored_polygon(body, BONE)
	p.draw_rect(Rect2(inset, 0, w - inset * 2, h * 0.22), BRASS)  # Cap.
	p.draw_rect(Rect2(0, h * 0.8, w, h * 0.2), BRASS)  # Foot.
