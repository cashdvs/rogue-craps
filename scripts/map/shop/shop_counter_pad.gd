## Quiet matte oval under one shop good (Nov 7 counter-pad handoff).
## One shared texture sits behind the existing icon, dice and Chips alike.
## It does not move the good, change its scale, or take a click.
## A slot that cannot hold 48 logical px plus 4 px of side clearance gets no pad.
class_name ShopCounterPad
extends RefCounted

## Full pad width in logical px (the shop's spec px, before `k`).
const LOGICAL_W := 64.0
## Full pad height in logical px. Width and height stay in this ratio.
const LOGICAL_H := 20.0
## Narrower than this, the pad is omitted rather than squeezed.
const MIN_W := 48.0
## Clearance on each side of a pad, in logical px. Also the gap between pads.
const SIDE := 4.0
## How far the bottom of the ellipse sits below the good's foot, logical px.
const FOOT_DROP := 2.0
## Sold ghost only: the shop removes a bought good, so this is unused there.
## A view that keeps a ghost draws the pad at this fraction of its normal alpha.
const SOLD_ALPHA := 0.35
## Native RGBA ellipse, 128x40. Drawn with no tint.
const TEXTURE := preload("res://art/ui/shop/counter_pad.png")


## Logical width for a slot of `slot_logical` px, or 0 when the pad is omitted.
static func logical_width(slot_logical: float) -> float:
	var room := slot_logical - SIDE * 2.0
	if room < MIN_W:
		return 0.0
	return minf(LOGICAL_W, room)


## Icon-local rect. Empty when `logical_width` omits the pad.
## `foot` is the contact point in the same space; `k` is design px per logical px.
static func rect_at(foot: Vector2, slot_logical: float, k: float) -> Rect2:
	var lw := logical_width(slot_logical)
	if lw <= 0.0 or k <= 0.0:
		return Rect2()
	var w := lw * k
	var h := w * LOGICAL_H / LOGICAL_W
	var bottom := foot.y + FOOT_DROP * k
	return Rect2(Vector2(foot.x - w * 0.5, bottom - h), Vector2(w, h))


## White modulate. A sold ghost keeps the same colour at `SOLD_ALPHA`.
static func modulate_for(ghost: bool) -> Color:
	return Color(1, 1, 1, SOLD_ALPHA if ghost else 1.0)


## True when `a` and `b` stay at least `gap` px apart horizontally.
## Pads on different shelves (no vertical overlap) are not neighbours.
static func separated(a: Rect2, b: Rect2, gap: float) -> bool:
	if a.size.x <= 0.0 or b.size.x <= 0.0:
		return true
	if a.position.y >= b.end.y or b.position.y >= a.end.y:
		return true
	var dx := 0.0
	if a.end.x <= b.position.x:
		dx = b.position.x - a.end.x
	elif b.end.x <= a.position.x:
		dx = a.position.x - b.end.x
	return dx + 0.01 >= gap


## Contact point in `icon`'s own pixels: centre x, lowest y of the 3D bounds.
## Falls back to the flat drawing's foot when the rig has no mesh.
static func foot_in_icon(icon: ShopIcon) -> Vector2:
	var sz := icon.size
	if sz.x < 1.0 or sz.y < 1.0:
		sz = icon.custom_minimum_size
	if icon.rig != null:
		var raw := icon.rig.contact_local()
		var vp := Vector2(icon.rig.view.size)
		if raw.y >= 0.0 and vp.x > 0.0 and vp.y > 0.0:
			return Vector2(raw.x / vp.x * sz.x, raw.y / vp.y * sz.y)
	if sz.y < 1.0:
		return Vector2(-1, -1)
	var y := sz.y * (0.90 if icon.offer != null and icon.offer.kind == ShopOffer.Kind.DIE else 0.98)
	return Vector2(sz.x * 0.5, y)


## Puts one pad behind `icon` when it fits `slot_px` (design px) and misses
## `blockers` and pads already in `placed` (both in global px).
## `ghost` uses the sold-ghost alpha. Returns null when the pad is omitted.
static func attach(icon: ShopIcon, slot_px: float, k: float, blockers: Array[Rect2], placed: Array[Rect2], ghost: bool = false) -> TextureRect:
	var foot := foot_in_icon(icon)
	if foot.y < 0.0:
		return null
	var local := rect_at(foot, slot_px / k, k)
	if local.size.x <= 0.0:
		return null
	var global := Rect2(icon.global_position + local.position, local.size)
	for b in blockers:
		if global.intersects(b):
			return null
	for p in placed:
		if not separated(global, p, SIDE * k):
			return null
	var pad := TextureRect.new()
	pad.name = "CounterPad"
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	pad.texture = TEXTURE
	pad.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pad.stretch_mode = TextureRect.STRETCH_SCALE
	pad.position = local.position
	pad.size = local.size
	pad.show_behind_parent = true
	pad.modulate = modulate_for(ghost)
	icon.add_child(pad)
	icon.move_child(pad, 0)
	return pad
