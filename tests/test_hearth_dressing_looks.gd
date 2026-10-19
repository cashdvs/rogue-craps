## Headless test: the Hearth set dressing's looks at image / resource level (detail pass, Oct 19;
## art/concept/bonfire_table/hearth_detail_pass.md). Split from test_hearth_dressing.gd (QA on #111), which keeps
## the in-scene checks (budget, clearance, toggle, motion). Checks:
##   felt       the worn felt overlay: low-contrast (<= 15 % value shift), off the landing centre and off both
##              combo-table strips (landscape / portrait felt decal), never bone-coloured.
##   materials  prop outlines ~60 % of the dice ink (0.0025); no Soul cyan / Danger red; dark, dim backdrop.
##   ceiling    the dressing's unlit light (self-glow + warm rim) stays <= 60 % of the dice value and no more
##              saturated than Ember; light pools at ~25-35 % value; the tail's top-edge rim is Ember, clear of
##              Danger red's hue and brightness; the near-rail carving brass stays under the brass total plate.
##
## Run:
##   godot --headless --path . --script res://tests/test_hearth_dressing_looks.gd
extends SceneTree

const H := "res://art/models/boards/hearth/"
const DICE_INK := 0.0042
const PROP_INK := 0.0025
const BONE := Color("E8DCC0")
const SOUL := Color("4FE6E0")
const DANGER := Color("FF2E3E")
## Combo-table strips: the felt combo decal (art/ui/readability/felt/, outside the repo) alpha bounds in board
## metres (landscape: along the near edge, z 0.366..0.513; portrait: the left edge, x -0.994..-0.713), + 2 cm.
const COMBO_LANDSCAPE := Rect2(-1.02, 0.346, 2.04, 0.187)      # x, z, w, h
const COMBO_PORTRAIT := Rect2(-1.02, -0.522, 0.327, 1.044)
const EMBER := Color("E8622A")
const UNLIT_CEIL := 0.6       # dressing unlit light <= 60 % of the dice (bone) value

var _passed := 0
var _failed := 0


func _initialize() -> void:
	print("=== Dice of the Damned: Hearth set dressing looks tests ===")
	_run.call_deferred()


func _run() -> void:
	_check_felt_wear()
	_check_materials()  # also runs _check_ceiling()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# --- felt wear + materials (image / resource level) -----------------------------------------------------

func _check_felt_wear() -> void:
	var plain := Image.load_from_file(ProjectSettings.globalize_path(H + "textures/felt_ember_corners.png"))
	var worn := Image.load_from_file(ProjectSettings.globalize_path(H + "textures/felt_ember_corners_worn.png"))
	_check(plain != null and worn != null and plain.get_size() == worn.get_size(), "felt: plain + worn overlays load at the same size")
	if plain == null or worn == null:
		return
	var felt := Color8(18, 58, 54)  # Underfelt #123A36 under the overlay
	var w := plain.get_width()
	var h := plain.get_height()
	var changed := 0
	var centre_ok := true
	var band_ok := true
	var band_at := ""
	var shift := 0.0
	var hue_ok := true
	var bad := ""
	for y in range(0, h, 2):
		for x in range(0, w, 2):
			var a := plain.get_pixel(x, y)
			var b := worn.get_pixel(x, y)
			if a.is_equal_approx(b):
				continue
			changed += 1
			# board metres (row 0 = near edge): u = (x + 1.02) / 2.04, v = (0.52 - z) / 1.04
			var bx := (x + 0.5) / w * 2.04 - 1.02
			var bz := 0.52 - (y + 0.5) / h * 1.04
			if absf(bx) < 0.4 and absf(bz) < 0.2:
				centre_ok = false  # the dice landing centre stays clean
			for r: Rect2 in [COMBO_LANDSCAPE, COMBO_PORTRAIT]:
				if r.has_point(Vector2(bx, bz)) and absf(b.a - a.a) + Vector3(b.r - a.r, b.g - a.g, b.b - a.b).length() > 0.004:
					band_ok = false  # the combo-table strip stays clean
					band_at = "(%.3f, %.3f)" % [bx, bz]
			var ca := felt.lerp(Color(a.r, a.g, a.b), a.a)
			var cb := felt.lerp(Color(b.r, b.g, b.b), b.a)
			shift = maxf(shift, absf(cb.v - ca.v) / maxf(ca.v, 0.05))
			# the wear may only dull / darken the felt: never warmer (bone / pip-like) than the board under it
			if (cb.r - cb.g > ca.r - ca.g + 0.03 and cb.v > 0.3) or (_near(cb, BONE, 0.35) and not _near(ca, BONE, 0.35)):
				hue_ok = false
				bad = "(%d,%d) %s" % [x, y, cb.to_html(false)]
	_check(changed > 200, "felt: the worn overlay adds wear marks (%d px changed, sampled)" % changed)
	_check(shift <= 0.15 + 0.01, "felt: wear is very low contrast (max value shift %.3f <= 0.15)" % shift)
	_check(centre_ok, "felt: no wear on the dice landing centre (|x| < 0.4, |z| < 0.2)")
	_check(band_ok, "felt: no wear on the combo-table strips (landscape near edge, portrait left edge) " + band_at)
	_check(hue_ok, "felt: wear stays felt-toned, never bone / pip coloured " + bad)


func _check_materials() -> void:
	var ink := load(H + "materials/ink_prop.tres") as ShaderMaterial
	var wd: Variant = ink.get_shader_parameter("width") if ink != null else null
	_check(wd != null and absf(float(wd) - PROP_INK) < 1e-5 and absf(float(wd) / DICE_INK - 0.6) < 0.02,
		"materials: prop ink width %.4f = ~60 %% of the dice ink (0.0042)" % (float(wd) if wd != null else -1.0))
	var bd := load(H + "materials/backdrop.tres") as ShaderMaterial
	var mv := _param(bd, "max_value")
	_check(bd != null and mv > 0.0 and mv <= 0.02, "materials: backdrop is dark (max_value %.3f linear <= 0.02, ~<= 10 %% value)" % mv)
	var dust := load(H + "materials/lamp_dust.tres") as ShaderMaterial
	_check(dust != null and dust.shader.resource_path.ends_with("hearth_dust.gdshader"), "materials: lamp dust uses hearth_dust")
	var drip := load(H + "materials/dressing_wax_drip.tres") as ShaderMaterial
	_check(drip != null and drip.get_shader_parameter("drip_mode") == true, "materials: wax drips creep (hearth_toon_detail drip_mode)")
	var carved := load(H + "materials/hearth_leather_carved.tres") as ShaderMaterial
	var plain := load(H + "materials/hearth_leather.tres") as ShaderMaterial
	_check(carved != null and carved.get_shader_parameter("use_carve") == true and carved.get_shader_parameter("carve_tex") != null,
		"materials: carved rail leather (imp faces + flame scroll normal map)")
	_check(carved != null and plain != null and carved.next_pass == plain.next_pass, "materials: carved leather keeps the ember seam pass + ink hull")
	var worn := load(H + "materials/hearth_felt_worn.tres") as ShaderMaterial
	_check(worn != null and str(worn.get_shader_parameter("overlay_tex").resource_path).ends_with("felt_ember_corners_worn.png"), "materials: worn felt = the worn overlay")
	# palette: no Soul cyan / Danger red, no dice bone on dressing props (aged bone #C9B48A is darker)
	var pal_ok := true
	var bad := ""
	var d := DirAccess.open(H + "materials")
	for f in d.get_files():
		if not f.begins_with("dressing_") or not f.ends_with(".tres"):
			continue
		var m := load(H + "materials/" + f) as ShaderMaterial
		var c: Variant = m.get_shader_parameter("albedo")
		if c == null:
			continue
		var col := c as Color
		if _near(col, SOUL, 0.3) or _near(col, DANGER, 0.3) or (f != "dressing_wax.tres" and f != "dressing_wax_drip.tres" and _near(col, BONE, 0.12)):
			pal_ok = false
			bad += " " + f
	_check(pal_ok, "materials: dressing palette avoids Soul cyan, Danger red and the dice bone" + bad)
	_check_ceiling()


## v2 (AD Oct 19): nothing in the dressing outshines the lit dice / brazier / candles. Unlit light only (the
## lamp-lit part is shared with every board prop): self-glow + the warm rim, as a value, <= 60 % of the dice
## bone; emission no more saturated than Ember (the brazier / candle fire); the light pools 25-35 %.
func _check_ceiling() -> void:
	var ceil_v := UNLIT_CEIL * BONE.v
	var worst := 0.0
	var worst_f := ""
	var sat_ok := true
	var sat_bad := ""
	var rims := 0
	var d := DirAccess.open(H + "materials")
	for f in d.get_files():
		if not f.begins_with("dressing_") or not f.ends_with(".tres") or f == "dressing_pool.tres":
			continue
		var m := load(H + "materials/" + f) as ShaderMaterial
		var v := 0.0
		for pair in [["emission_color", "emission_energy"], ["rim_emit_color", "rim_emit"]]:
			var c: Variant = m.get_shader_parameter(pair[0])
			var k := _param(m, pair[1])
			if c == null or k <= 0.0:
				continue
			v += (c as Color).v * k
			if (c as Color).s > EMBER.s + 0.02:
				sat_ok = false
				sat_bad += " " + f
		if _param(m, "rim_emit") > 0.0:
			rims += 1
		if v > worst:
			worst = v
			worst_f = f
	_check(worst <= ceil_v, "materials: dressing unlit light <= %d %% of the dice value (worst %.3f <= %.3f, %s)" % [int(UNLIT_CEIL * 100), worst, ceil_v, worst_f])
	_check(sat_ok, "materials: dressing glow / rim no more saturated than Ember" + sat_bad)
	_check(rims >= 9, "materials: the dressing props carry the warm rim (%d materials)" % rims)
	var pool := load(H + "materials/dressing_pool.tres") as ShaderMaterial
	_check(pool != null and pool.shader.resource_path.ends_with("hearth_pool.gdshader"), "materials: corner light pools use hearth_pool")
	if pool != null:
		var pc: Color = pool.get_shader_parameter("pool_color") if pool.get_shader_parameter("pool_color") != null else Color("D9783B")
		var cc: Color = pool.get_shader_parameter("core_color") if pool.get_shader_parameter("core_color") != null else Color("E2B46B")
		var pe := _param(pool, "energy")
		var ce := _param(pool, "core_energy")
		# additive in linear light on the dark leather: the pool core as an sRGB value
		var lin := pc.srgb_to_linear() * pe + cc.srgb_to_linear() * ce
		var val := Color(lin.r, lin.g, lin.b).linear_to_srgb().v
		_check(val >= 0.2 and val <= 0.4, "materials: light-pool core adds ~25-35 %% value (%.2f sRGB)" % val)
	var tail := load(H + "materials/dressing_tail.tres") as ShaderMaterial
	var rc: Variant = tail.get_shader_parameter("rim_emit_color")
	var rk := _param(tail, "rim_emit")
	var hue_d := 1.0
	if rc != null:
		hue_d = absf((rc as Color).h - DANGER.h)
		hue_d = minf(hue_d, 1.0 - hue_d) * 360.0
	_check(rc != null and rk > 0.0 and _param(tail, "rim_emit_up") >= 0.9 and _near(rc as Color, EMBER, 0.02),
		"materials: the tail carries an Ember rim along its top edge")
	_check(hue_d >= 15.0 and rk * (rc as Color).v <= 0.6 * DANGER.v, "materials: the tail rim stays clear of Danger red (hue %.0f deg off, value %.2f)" % [hue_d, rk * ((rc as Color).v if rc != null else 0.0)])
	var carved := load(H + "materials/hearth_leather_carved.tres") as ShaderMaterial
	var skip: Variant = carved.get_shader_parameter("carve_skip_u")
	_check(_param(carved, "carve_brass") > 0.0 and skip != null and (skip as Vector2).y > 4.0,
		"materials: carving has a brass edge highlight and is off the far rail (U %s)" % str(skip))
	# AD sign-off (Oct 19): the brass total plate stays the brightest brass on the near rail. The near-rail carving
	# brass is a partial mix (carve_brass x carve_dim of the edge mask) of a darker brass + a little emission; its
	# strongest possible value must stay under the plate ring's brass albedo (renders: plate p99 0.96 vs carving max 0.85).
	var plate_v := 0.0
	var dial := (load("res://art/models/boards/infernal_pit/scenes/total_dial.tscn") as PackedScene).instantiate()
	var dial_meshes: Array[MeshInstance3D] = []
	_collect(dial, dial_meshes)
	for mi in dial_meshes:
		for si in mi.mesh.get_surface_count():
			var dm := mi.get_active_material(si) as ShaderMaterial
			if dm != null and _param(dm, "spec_size") > 0.0 and dm.get_shader_parameter("albedo") != null:
				var ac := dm.get_shader_parameter("albedo") as Color
				if ac.g > ac.b + 0.1 and ac.r > ac.g:   # brass-coloured
					plate_v = maxf(plate_v, ac.v)
	dial.free()
	var cb: Variant = carved.get_shader_parameter("carve_brass_color")
	var dim := _param(carved, "carve_dim")
	var cbv := (cb as Color).v if cb != null else 0.0
	var near_brass := cbv * (_param(carved, "carve_brass") + _param(carved, "carve_brass_emit")) * dim
	_check(plate_v > 0.0 and cbv < plate_v and near_brass < plate_v and dim <= 0.86 and _param(carved, "carve_rim_dim") > 0.0,
		"materials: the total plate (brass %.2f) stays the brightest brass on the near rail (carving brass %.2f, x %.2f near-rail dim, at most %.2f)" % [plate_v, cbv, dim, near_brass])


func _near(a: Color, b: Color, dist: float) -> bool:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length() < dist


# --- the board -----------------------------------------------------------------------------------------


func _mat(mi: MeshInstance3D) -> String:
	var m := mi.get_active_material(0)
	return m.resource_path if m != null else ""


func _param(m: ShaderMaterial, n: String) -> float:
	if m == null:
		return 0.0
	var v: Variant = m.get_shader_parameter(n)
	if v == null:
		var re := RegEx.create_from_string("uniform float " + n + "[^=;]*=\\s*([0-9.]+)")
		var r := re.search(m.shader.code)
		return 0.0 if r == null else float(r.get_string(1))
	return float(v)


func _collect(n: Node, out: Array[MeshInstance3D]) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out.append(n)
	for c in n.get_children():
		_collect(c, out)


func _check(cond: bool, name: String) -> void:
	if cond:
		_passed += 1
		print("  ok   ", name)
	else:
		_failed += 1
		print("  FAIL ", name)
