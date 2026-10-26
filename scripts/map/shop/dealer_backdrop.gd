## Smiles behind the shop counter (HANDOFF_SPEC §3, AD review of #178).
## A still picture, not the live 3D scene: art/ui/shop/dealer_smiles.png is
## the Smiles render with the boss_toon lift already baked in (warm #3A3732
## ambient at 0.40, greys raised by 0.08, no glow) by
## art/ui/shop/src/make_dealer_still.py. A brass rail runs along his bottom
## edge, so he stands behind the counter as in the mock.
class_name DealerBackdrop
extends Control

const STILL := "res://art/ui/shop/dealer_smiles.png"
const BRASS := Color("#C9A24A")
## Rail height in spec px (the mock's rail is about 2% of the height).
const RAIL_PX := 20.0

var still: TextureRect
var rail: ColorRect


## Fill `box` (design px) with Smiles; `k` is design px per spec px.
func setup(box: Rect2, k: float) -> void:
	position = box.position
	size = box.size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	still = TextureRect.new()
	still.texture = load(STILL)
	still.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# Cover the box, keeping his shape; the head stays in view at the top.
	still.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	still.clip_contents = true
	still.size = box.size
	still.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(still)
	rail = ColorRect.new()
	rail.color = BRASS
	rail.size = Vector2(box.size.x, RAIL_PX * k)
	rail.position = Vector2(0, box.size.y - RAIL_PX * k)
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rail)
