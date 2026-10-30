## The combo table printed on the felt (how_bonfire_plays.md section 4: a
## Seal "upgrades a combo; shown on the felt's combo table, e.g. 'Trips Lv3
## 60x5'"). It replaces the old side combo panel.
##
## Two parts, from the Art Director's pack (assets/ui/readability/felt/):
##   - the print: a 2048 x 1044 texture over the whole felt bed (2.04 x
##     1.04 m), with the combo names, tier pips and empty slot boxes. It goes
##     on the felt material's overlay layer (UV = the felt plane's UV:
##     u = (x + 1.02) / 2.04, v = (z + 0.52) / 1.04; texture top = far rail),
##     with a little emission so it reads in the lamp's falloff;
##   - the live numbers: one Label3D per slot, "Lv2 30x3" (Seal level,
##     base x mult; just "30x3" with no Seal), lying flat on the felt.
## Phones show none of it (set_off). PC uses a thin band along the near rail;
## phone portrait swaps to a block at the screen-bottom end of the felt,
## with the text turned to read upright there.
class_name FeltComboTable
extends Node3D

const DIR := "res://assets/ui/readability/felt/"
const SLOTS_JSON := DIR + "felt_slots.json"
## Print emission: ~0.35 x its albedo (the Art Director's import note).
const PRINT_EMISSION := 0.35
## Label3D look (shared by every slot).
const FONT_PATH := "res://fonts/BarlowCondensed-Bold.ttf"
const PIXEL_SIZE := 0.0005
const TEXT_COLOR := Color("#E8DCC0")
const OUTLINE_COLOR := Color("#0E1414")
const OUTLINE_PX := 12
const LIFT := 0.003
## Landscape: font 94, flat, stretched x1.40 along the felt's depth to
## cancel the camera's foreshortening. Portrait: font 88, turned 90 deg, x1.10.
const LAND_FONT := 94
const LAND_ROT := Vector3(-90, 0, 0)
const LAND_STRETCH := 1.40
const PORT_FONT := 88
const PORT_ROT := Vector3(-90, -90, 0)
const PORT_STRETCH := 1.10
## Overflow: squeeze scale.x down to 0.80 first, then "Lv" -> "L". The font
## size never shrinks.
const MIN_SQUEEZE := 0.80
## Landscape: the band is drawn at the near rail (z 0.38-0.49 m), right
## under the bottom HUD (POT, count-up, prompts) in the throw view. It is
## printed this far toward the middle of the felt instead (metres, -z =
## away from the player), so no HUD text sits on it (QA #63 overlaps).
const LAND_SHIFT_Z := -0.56

var felt_material: ShaderMaterial
var portrait: bool = false
## Portrait only: true turns the block 180 deg (x -> -x, z -> -z) for a
## camera that puts +X at the bottom of the screen. Bonfire3D works it out.
var portrait_flipped: bool = false
## Combo id -> its Label3D.
var labels: Dictionary = {}
## Portrait only: the block's fit to the phone camera (fit_portrait_view):
## a uniform scale about its outer-rail edge, then a slide across the felt
## (z, metres). 1 / 0 = as drawn.
var port_scale: float = 1.0
var port_shift_z: float = 0.0
## Landscape only: the band's fit to the camera (fit_landscape_view): a
## uniform scale about the felt's centre line, then a slide along x
## (metres). 1 / 0 = as drawn.
var land_scale: float = 1.0
var land_shift_x: float = 0.0
## The landscape band as drawn (felt metres): its x span, its z span and
## the point it scales about (x 0, the middle of its depth).
const LAND_X := Vector2(-0.955, 0.980)
const LAND_Z := Vector2(0.382, 0.4925)
var _tuning: BonfireTuning
var _levels: Dictionary = {}
var _slots: Dictionary = {}
var _tex_land: Texture2D
var _tex_port: Texture2D
var _tex_port_flipped: Texture2D
var _font: Font


## True on phone: no felt print or slot numbers (set_off).
var off := false


func _init() -> void:
	name = "FeltComboTable"


## felt: the felt's toon material (its overlay layer gets the print).
func setup(felt: ShaderMaterial, t: BonfireTuning, seal_levels: Dictionary = {}) -> void:
	felt_material = felt
	_font = load(FONT_PATH) as Font if ResourceLoader.exists(FONT_PATH) else null
	_tex_land = _load_tex("felt_combo_decal_landscape.png")
	_tex_port = _load_tex("felt_combo_decal_portrait.png")
	if FileAccess.file_exists(SLOTS_JSON):
		var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(SLOTS_JSON))
		if j is Dictionary:
			_slots = j
	set_combos(t, seal_levels)
	_apply()


static func _load_tex(file: String) -> Texture2D:
	return load(DIR + file) as Texture2D if ResourceLoader.exists(DIR + file) else null


## Fills the slots from the tuning: "Lv<level> <base>x<mult>". seal_levels:
## combo id -> level (1 = no Seal yet).
func set_combos(t: BonfireTuning, seal_levels: Dictionary = {}) -> void:
	_tuning = t
	_levels = seal_levels.duplicate()
	_apply()


## Phone (#204): the felt combo print and its numbers are off; Seals live in
## the bottom bar's SEALS list instead.
func set_off(on: bool) -> void:
	if on != off:
		off = on
		_apply()


## Switches the felt print between the landscape band and the portrait
## block (flipped: turned to face a portrait camera from the far side).
func set_portrait(on: bool, flipped: bool = portrait_flipped) -> void:
	if on == portrait and flipped == portrait_flipped and not labels.is_empty():
		return
	if on != portrait or flipped != portrait_flipped:
		port_scale = 1.0
		port_shift_z = 0.0
	portrait = on
	portrait_flipped = flipped
	_apply()


## The portrait block as drawn (unflipped felt metres): outer rail edge,
## inner edge, and its z span (felt_slots.json's portrait items and boxes).
const PORT_OUTER_X := -0.99
const PORT_INNER_X := -0.72
const PORT_Z := Vector2(-0.47, 0.50)
## Phone portrait: the block is drawn along the near rail, where the hand of
## dice and GRAB & FLICK sit. It is printed this far toward the middle of
## the felt instead (metres), so the hand doesn't cover its text.
const PORT_SHIFT_X := 0.30


## The portrait block's slide toward the middle (felt metres along x; the
## sign follows the flip).
func _port_shift_x() -> float:
	return (-1.0 if portrait_flipped else 1.0) * PORT_SHIFT_X if portrait else 0.0


## Phone portrait: the Art Director's block spans nearly the felt's full
## depth, wider than a portrait phone sees at the near rail, so the right
## column clipped. This shrinks the block (print and slots together, about
## its outer rail edge) and slides it so it sits inside the camera's view
## with margin_px to spare each side. Call with the camera at home.
func fit_portrait_view(cam: Camera3D, view: Vector2, margin_px: float) -> void:
	port_scale = 1.0
	port_shift_z = 0.0
	if cam != null and portrait:
		var sgn := -1.0 if portrait_flipped else 1.0
		var lo := -INF
		var hi := INF
		for xu: float in [PORT_OUTER_X + PORT_SHIFT_X, PORT_INNER_X + PORT_SHIFT_X]:
			var span := visible_z(cam, view, sgn * xu, margin_px)
			lo = maxf(lo, span.x)
			hi = minf(hi, span.y)
		if hi > lo:
			var z0 := minf(sgn * PORT_Z.x, sgn * PORT_Z.y)
			var z1 := maxf(sgn * PORT_Z.x, sgn * PORT_Z.y)
			var zc := (z0 + z1) * 0.5
			port_scale = clampf((hi - lo) / (z1 - z0), 0.6, 1.0)
			var hw := (z1 - z0) * 0.5 * port_scale
			port_shift_z = clampf(zc, lo + hw, maxf(lo + hw, hi - hw)) - zc
	_apply()


## Landscape: on a window wider than 16:9 (e.g. 1688x780) the band's left
## end ("Pair") slid under the Soul meter once the camera glided in for a
## throw. Bonfire3D works out a size and slide that fits every camera pose
## (land_fits) and sets it here: the print and the slots move together.
func set_land_fit(k: float, sx: float) -> void:
	land_scale = k
	land_shift_x = sx
	_apply()


## True if the band, scaled by k and slid by sx, is inside [left_px, right_px].
func land_fits(cam: Camera3D, k: float, sx: float, left_px: float, right_px: float) -> bool:
	# The print can't leave the felt (2.04 m wide): past its edge it's cut.
	if LAND_X.x * k + sx < -1.01 or LAND_X.y * k + sx > 1.01:
		return false
	var zc := (LAND_Z.x + LAND_Z.y) * 0.5
	for x: float in [LAND_X.x, LAND_X.y]:
		for z: float in [LAND_Z.x, LAND_Z.y]:
			var p := Vector3(x * k + sx, 0.0, zc + (z - zc) * k + LAND_SHIFT_Z)
			if cam.is_position_behind(p):
				return false
			var px := cam.unproject_position(p).x
			if px < left_px or px > right_px:
				return false
	return true


## The felt's z range at x that the camera shows margin_px inside the
## viewport's left / right edges (x: min, y: max).
static func visible_z(cam: Camera3D, view: Vector2, x: float, margin_px: float) -> Vector2:
	var lo := INF
	var hi := -INF
	for k in 601:
		var z := -0.6 + k * 0.002
		var p := Vector3(x, 0, z)
		if cam.is_position_behind(p):
			continue
		var sp := cam.unproject_position(p)
		if sp.x >= margin_px and sp.x <= view.x - margin_px and sp.y >= 0.0 and sp.y <= view.y:
			lo = minf(lo, z)
			hi = maxf(hi, z)
	return Vector2(lo, hi)


## The portrait block's pivot (final felt metres: x, z).
func _port_pivot() -> Vector2:
	var sgn := -1.0 if portrait_flipped else 1.0
	return Vector2(sgn * PORT_OUTER_X, sgn * (PORT_Z.x + PORT_Z.y) * 0.5)


## The text a slot shows for combo c.
## No Seal yet (level 1): just "30x3", no "Lv1" (#204).
func slot_text(c: BonfireCombo, short: bool = false) -> String:
	var lv := int(_levels.get(c.id, 1))
	if lv <= 1:
		return "%dx%d" % [c.base, c.mult]
	return "%s%d %dx%d" % ["L" if short else "Lv", lv, c.base, c.mult]


func _apply() -> void:
	if _tuning == null:
		return
	if off:
		if felt_material != null:
			felt_material.set_shader_parameter("use_overlay", false)
		for id in labels:
			(labels[id] as Node).queue_free()
		labels.clear()
		return
	if felt_material != null:
		var tex := _tex_land
		if portrait:
			tex = _flipped_portrait() if portrait_flipped else _tex_port
		felt_material.set_shader_parameter("use_overlay", tex != null)
		felt_material.set_shader_parameter("overlay_tex", tex)
		felt_material.set_shader_parameter("overlay_tint", Color(1, 1, 1, 1))
		felt_material.set_shader_parameter("overlay_emission", PRINT_EMISSION)
		var fit := portrait and not is_equal_approx(port_scale, 1.0) or portrait and not is_zero_approx(port_shift_z)
		var pv := _port_pivot()
		felt_material.set_shader_parameter("overlay_pivot", Vector2((pv.x + 1.02) / 2.04, (pv.y + 0.52) / 1.04) if fit else Vector2(0.5, 0.5))
		felt_material.set_shader_parameter("overlay_scale", port_scale if fit else 1.0)
		# The felt is 1.04 m deep, so metres / 1.04 = UV units.
		var shift := Vector2(0.0, port_shift_z / 1.04) if fit else Vector2.ZERO
		if not portrait:
			shift = Vector2(land_shift_x / 2.04, LAND_SHIFT_Z / 1.04)
			var land_fit := not is_equal_approx(land_scale, 1.0)
			var zc := (LAND_Z.x + LAND_Z.y) * 0.5
			felt_material.set_shader_parameter("overlay_pivot", Vector2(0.5, (zc + 0.52) / 1.04) if land_fit else Vector2(0.5, 0.5))
			felt_material.set_shader_parameter("overlay_scale", land_scale if land_fit else 1.0)
		else:
			# The felt is 2.04 m wide: metres / 2.04 = UV units.
			shift.x = _port_shift_x() / 2.04
		felt_material.set_shader_parameter("overlay_shift", shift)
	for id in labels:
		(labels[id] as Node).queue_free()
	labels.clear()
	var layout: Dictionary = _slots.get("portrait" if portrait else "landscape", {})
	for slot: Dictionary in layout.get("slots", []):
		var c := _combo_named(String(slot.get("combo", "")))
		if c == null:
			continue
		var l := Label3D.new()
		l.name = "Slot_%s" % c.id
		if _font != null:
			l.font = _font
		l.font_size = PORT_FONT if portrait else LAND_FONT
		l.pixel_size = PIXEL_SIZE
		l.modulate = TEXT_COLOR
		l.outline_size = OUTLINE_PX
		l.outline_modulate = OUTLINE_COLOR
		l.shaded = false
		l.double_sided = false
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var x := float(slot.get("center_x", 0.0))
		var z := float(slot.get("center_z", 0.0))
		var rot := PORT_ROT if portrait else LAND_ROT
		if portrait and portrait_flipped:
			x = -x
			z = -z
			rot.y += 180.0
		var k := 1.0
		if portrait:
			var pv := _port_pivot()
			k = port_scale
			x = pv.x + (x - pv.x) * k
			z = pv.y + (z - pv.y) * k + port_shift_z
			x += _port_shift_x()
		else:
			# Landscape fit: scale about the band's middle, slide along x.
			k = land_scale
			var zc := (LAND_Z.x + LAND_Z.y) * 0.5
			x = x * k + land_shift_x
			z = zc + (z - zc) * k + LAND_SHIFT_Z
		l.position = Vector3(x, LIFT, z)
		l.rotation_degrees = rot
		var stretch := PORT_STRETCH if portrait else LAND_STRETCH
		_fit(l, c, float(slot.get("max_text_width_m", 0.167)), stretch)
		l.scale *= Vector3(k, k, 1.0)
		add_child(l)
		labels[c.id] = l


## Sets the text and squeezes it into max_w metres (the overflow rule).
func _fit(l: Label3D, c: BonfireCombo, max_w: float, stretch: float) -> void:
	l.text = slot_text(c)
	var sx := 1.0
	var w := text_width(l)
	if w > max_w:
		sx = maxf(max_w / w, MIN_SQUEEZE)
		if w * sx > max_w + 0.0001:
			l.text = slot_text(c, true)
			w = text_width(l)
			sx = clampf(max_w / w, MIN_SQUEEZE, 1.0)
	l.scale = Vector3(sx, stretch, 1.0)


## A label's text width in metres at scale 1.
func text_width(l: Label3D) -> float:
	var f := l.font if l.font != null else ThemeDB.fallback_font
	return f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.font_size).x * l.pixel_size


func _combo_named(n: String) -> BonfireCombo:
	for c: BonfireCombo in _tuning.combos:
		if c.display_name == n:
			return c
	return null


## The portrait print turned 180 deg (made once, only if a camera needs it).
func _flipped_portrait() -> Texture2D:
	if _tex_port_flipped == null and _tex_port != null:
		var img := _tex_port.get_image()
		if img != null:
			img = img.duplicate()
			if img.is_compressed():
				img.decompress()
			img.rotate_180()
			_tex_port_flipped = ImageTexture.create_from_image(img)
	return _tex_port_flipped if _tex_port_flipped != null else _tex_port
