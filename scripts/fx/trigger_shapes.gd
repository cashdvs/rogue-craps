## Procedural stand-ins for the Art Director's shapes atlas
## (fx_trigger_shapes_atlas.png, not delivered yet): each glow shape is a
## small hard-banded texture with the oxblood outline baked in (spec 0 and
## 1.7), drawn once from a distance function and cached. Flat shapes only:
## rings, frames, a shine bar, radial needles, diamond sparks. Nothing here
## is a flame tongue or teardrop.
class_name TriggerShapes
extends RefCounted

const SIZE: int = 96
## Outline width in texture px (about 2 px at 1080p on a 1.6x die card).
const OUTLINE: float = 0.07
const SHAPES: Array[StringName] = [&"ring", &"frame", &"shine", &"needles", &"diamond", &"flash"]

static var _cache: Dictionary = {}


## Signed distance (negative inside) of shape `id` at p in [-1, 1]^2.
static func sdf(id: StringName, p: Vector2) -> float:
	match id:
		&"ring":
			return absf(p.length() - 0.78) - 0.08
		&"frame":
			return absf(maxf(absf(p.x), absf(p.y)) - 0.72) - 0.07
		&"shine":
			return maxf(absf(p.x - p.y) * 0.7071 - 0.1, maxf(absf(p.x), absf(p.y)) - 0.66)
		&"needles":
			var d := 1e9
			for i in 8:
				var q := p.rotated(-TAU * i / 8.0 - PI / 8.0)
				var t := 0.075 * clampf(1.0 - (q.x - 0.42) / 0.56, 0.0, 1.0)
				d = minf(d, maxf(absf(q.y) - t, maxf(0.42 - q.x, q.x - 0.98)))
			return d
		&"diamond":
			return absf(p.x) + absf(p.y) - 0.78
		&"flash":
			return p.length() - 0.7
	return 1.0


## The texture for `id` filled with `fill` (the flash has a soft edge and
## no outline: it's the one bloom cell).
static func texture(id: StringName, fill: Color) -> ImageTexture:
	var key := "%s_%s" % [id, fill.to_html()]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			var p := Vector2((x + 0.5) / SIZE * 2.0 - 1.0, (y + 0.5) / SIZE * 2.0 - 1.0)
			var d := sdf(id, p)
			var c := Color(0, 0, 0, 0)
			if id == &"flash":
				c = Color(fill, clampf(-d / 0.3, 0.0, 1.0))
			elif d < 0.0:
				c = fill
			elif d < OUTLINE:
				c = TriggerFxDefs.OXBLOOD
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
