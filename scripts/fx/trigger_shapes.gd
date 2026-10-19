## Trigger glow shapes: the Art Director's sheet (art/vfx/trigger_fx/, copied
## to assets/vfx/trigger_fx/shapes/) with procedural stand-ins for any file
## that's missing (tests, or a row whose art isn't in yet).
##
## texture(id, fill) returns ONE ready card per (shape, tint), cached:
## - white soft shapes (ring_pulse_soft, radial_glow_soft, glint_streak) are
##   multiplied by the tint;
## - hard shapes (<id>_fill + <id>_outline: needles_radial, spark_diamond,
##   shine_bar, frame_square, frame_hex) get the tinted fill composited over
##   the fixed Oxblood outline (the README's "outline card behind the fill",
##   baked into one texture so each effect stays one quad);
## - fixed(name) loads fixed-colour sprites (coin_brass_*, chip_x*) as is.
## The material colour stays white (tint() is kept for callers).
class_name TriggerShapes
extends RefCounted

const DIR := "res://assets/vfx/trigger_fx/shapes/"
const SIZE: int = 96
## Outline width of the procedural stand-ins, in texture px fractions.
const OUTLINE: float = 0.07
const SHAPES: Array[StringName] = [&"ring_pulse_soft", &"radial_glow_soft", &"glint_streak", &"needles_radial",
		&"spark_diamond", &"shine_bar", &"frame_square", &"frame_hex"]
const SOFT: Array[StringName] = [&"ring_pulse_soft", &"radial_glow_soft", &"glint_streak"]

static var _cache: Dictionary = {}


## True if the authored PNG(s) for `id` are in the repo.
static func is_art(id: StringName) -> bool:
	if id in SOFT:
		return ResourceLoader.exists(DIR + "%s.png" % id)
	return ResourceLoader.exists(DIR + "%s_fill.png" % id) and ResourceLoader.exists(DIR + "%s_outline.png" % id)


static func art_path(id: StringName) -> String:
	return DIR + ("%s.png" if id in SOFT else "%s_fill.png") % id


## The material colour to draw texture(id, fill) with (tint is baked in).
static func tint(_id: StringName, _fill: Color) -> Color:
	return Color.WHITE


## A fixed-colour sprite (coin_brass_face / _tilt / _edge, chip_x1_5 ...).
static func fixed(name: String) -> Texture2D:
	var p := DIR + "%s.png" % name
	return load(p) as Texture2D if ResourceLoader.exists(p) else null


## The card for shape `id` tinted `fill` (cached, with mipmaps).
static func texture(id: StringName, fill: Color) -> Texture2D:
	var key := "%s_%s" % [id, fill.to_html()]
	if _cache.has(key):
		return _cache[key]
	var img: Image
	if is_art(id):
		img = _art(id, fill)
	else:
		img = _procedural(id, fill)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func _load_image(path: String) -> Image:
	var img := (load(path) as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	img.clear_mipmaps()
	img.convert(Image.FORMAT_RGBA8)
	return img


static func _art(id: StringName, fill: Color) -> Image:
	if id in SOFT:
		var s := _load_image(DIR + "%s.png" % id)
		for y in s.get_height():
			for x in s.get_width():
				var c := s.get_pixel(x, y)
				s.set_pixel(x, y, Color(c.r * fill.r, c.g * fill.g, c.b * fill.b, c.a))
		return s
	var out := _load_image(DIR + "%s_outline.png" % id)
	var f := _load_image(DIR + "%s_fill.png" % id)
	for y in out.get_height():
		for x in out.get_width():
			var c := f.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			var t := Color(c.r * fill.r, c.g * fill.g, c.b * fill.b, c.a)
			out.set_pixel(x, y, out.get_pixel(x, y).blend(t))
	return out


## Signed distance (negative inside) of the stand-in for `id`, p in [-1, 1]^2.
static func sdf(id: StringName, p: Vector2) -> float:
	match id:
		&"ring_pulse_soft":
			return absf(p.length() - 0.76) - 0.08
		&"radial_glow_soft":
			return p.length() - 0.7
		&"glint_streak":
			return absf(p.y) * 6.0 + absf(p.x) - 0.9
		&"needles_radial":
			var d := 1e9
			for i in 8:
				var q := p.rotated(-TAU * i / 8.0 - PI / 8.0)
				var t := 0.085 * clampf(1.0 - (q.x - 0.5) / 0.48, 0.0, 1.0)
				d = minf(d, maxf(absf(q.y) - t, maxf(0.5 - q.x, q.x - 0.98)))
			return d
		&"spark_diamond":
			return absf(p.x) * 1.4 + absf(p.y) - 0.8
		&"shine_bar":
			return maxf(absf(p.x - p.y) * 0.7071 - 0.1, maxf(absf(p.x), absf(p.y)) - 0.66)
		&"frame_square":
			return absf(maxf(absf(p.x), absf(p.y)) - 0.72) - 0.07
		&"frame_hex":
			var q := p.abs()
			return absf(maxf(q.x * 0.866 + q.y * 0.5, q.y) - 0.72) - 0.07
	return 1.0


static func _procedural(id: StringName, fill: Color) -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			var p := Vector2((x + 0.5) / SIZE * 2.0 - 1.0, (y + 0.5) / SIZE * 2.0 - 1.0)
			var d := sdf(id, p)
			var c := Color(0, 0, 0, 0)
			if id in SOFT:
				c = Color(fill, clampf(-d / 0.3, 0.0, 1.0) * 0.9)
			elif d < 0.0:
				c = fill
			elif d < OUTLINE:
				c = TriggerFxDefs.OXBLOOD
			img.set_pixel(x, y, c)
	return img
