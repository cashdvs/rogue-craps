## Smiles behind the shop counter (HANDOFF_SPEC §3, AD review of #178/#182).
## A still picture, not the live 3D scene: art/ui/shop/dealer_smiles.png is
## the Smiles render with the boss_toon lift already baked in (warm #3A3732
## ambient at 0.40, greys raised by 0.08, no glow) by
## art/ui/shop/src/make_dealer_still.py.
## - A full-width brass rail (a lip plus a dark shadow line) runs along the
##   bottom, at the top of the counter.
## - Smiles is shown chest-up and whole (raised arm included), scaled to fit
##   the band above the rail and centred on the screen. His cut-off chest
##   hides behind the rail.
class_name DealerBackdrop
extends Control

const STILL := "res://art/ui/shop/dealer_smiles.png"
## The part of the still Smiles fills (no empty margins), in image px.
const FIGURE := Rect2(37, 77, 420, 364)
const BRASS := Color("#C9A24A")
const SHADOW := Color("#1A120C")
## Rail lip and shadow heights in spec px.
const RAIL_PX := 14.0
const SHADOW_PX := 4.0

var still: TextureRect
var rail: ColorRect
var shadow: ColorRect


## Fill the band `box` (design px) across the whole screen width; `k` is
## design px per spec px. Call after adding to the tree.
func setup(box: Rect2, k: float) -> void:
	var w := get_viewport_rect().size.x
	position = Vector2(0, box.position.y)
	size = Vector2(w, box.size.y)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rail_h := RAIL_PX * k
	var shadow_h := SHADOW_PX * k
	still = TextureRect.new()
	var tex := AtlasTexture.new()
	tex.atlas = load(STILL)
	tex.region = FIGURE
	still.texture = tex
	still.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	still.stretch_mode = TextureRect.STRETCH_SCALE
	still.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Fit his whole figure above the rail (his bottom tucks under the lip).
	var fit := minf((size.y - shadow_h - 2.0 * k) / FIGURE.size.y, maxf(box.size.x, w * 0.6) / FIGURE.size.x)
	still.size = FIGURE.size * fit
	still.position = Vector2((w - still.size.x) / 2.0, size.y - shadow_h - still.size.y)
	add_child(still)
	rail = _bar(size.y - shadow_h - rail_h, rail_h, BRASS)
	shadow = _bar(size.y - shadow_h, shadow_h, SHADOW)


func _bar(y: float, h: float, c: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = c
	r.position = Vector2(0, y)
	r.size = Vector2(size.x, h)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r
