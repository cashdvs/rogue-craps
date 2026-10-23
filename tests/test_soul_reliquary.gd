## Headless test: the Soul Reliquary prop (art/models/props/soul_reliquary, world_props_v1 §2.2). PC + mobile:
##   nodes    named rig nodes + hooks (DeltaAnchor, LiquidTop, TooltipAnchor, PlateCenter)
##   numeral  Label3D text "cur/max", light-on-dark (cream modulate over the near-black plate), fits the window
##   fill     fill = cur/max, liquid top maps inside the rings (fill_lo/fill_hi), LiquidTop follows
##   grow     the cage grows in steps of GROW_SOUL max Soul, capped; growth first, then fill
##   frost    shader frost on at soul <= SOUL_FROST_AT only
##   crack    visible only when lethal, never inside the digit window
##   cyan     Soul cyan lives only in the vessel shader (no other reliquary material is cyan)
##   board    Anchors/SoulReliquary, SoulReliquaryPhone, SoulReliquaryPortrait in both hearth boards
##   budget   drawn tris <= 300
## Run:
##   godot --headless --path . --script res://tests/test_soul_reliquary.gd
extends SceneTree

const SCN := "res://art/models/props/soul_reliquary/scenes/soul_reliquary%s.tscn"
const M := "res://art/models/props/soul_reliquary/materials/"
const CYAN := Color("#4FE6E0")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	print("=== Dice of the Damned: soul reliquary tests ===")
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("  FAIL ", what)


func _run() -> void:
	_check_static()
	_check_cyan()
	_check_fill()
	_check_board()
	for lod in ["", "_mobile"]:
		await _check(lod)
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _tris(n: Node) -> int:
	var c := 0
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mesh := (m as MeshInstance3D).mesh
		for si in mesh.get_surface_count():
			var a := mesh.surface_get_arrays(si)
			c += (a[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3 if a[Mesh.ARRAY_INDEX] != null else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return c


func _check_static() -> void:
	_ok(SoulReliquary.steps_for(35) == 0 and SoulReliquary.steps_for(36) == 1 and SoulReliquary.steps_for(40) == 1 and SoulReliquary.steps_for(41) == 2, "grow steps per 5 max Soul")
	_ok(SoulReliquary.steps_for(999) == SoulReliquary.MAX_STEPS and SoulReliquary.steps_for(10) == 0, "grow steps clamped")
	_ok(SoulReliquary.height_for(39) > SoulReliquary.height_for(35), "taller cage for more max Soul")
	_ok(is_equal_approx(SoulReliquary.fill_for(18, 35), 18.0 / 35.0) and SoulReliquary.fill_for(50, 35) == 1.0 and SoulReliquary.fill_for(-3, 35) == 0.0, "fill = cur/max, clamped")


func _check_cyan() -> void:
	var d := DirAccess.open(M)
	for f in d.get_files():
		if not f.ends_with(".tres"):
			continue
		var m := load(M + f) as ShaderMaterial
		if m == null:
			continue
		var is_vessel := m.shader != null and m.shader.resource_path.ends_with("soul_vessel.gdshader")
		for p in ["albedo", "emission_color"]:
			var c: Variant = m.get_shader_parameter(p)
			if c is Color and not is_vessel:
				var cc := c as Color
				_ok(absf(cc.h - CYAN.h) > 0.08 or cc.s < 0.25, "%s %s is not Soul cyan" % [f, p])
		if not is_vessel:
			var e: Variant = m.get_shader_parameter("emission_energy")
			_ok(e == null or float(e) <= 0.15, f + ": no glow")
			_ok(m.next_pass != null, f + ": ink outline pass")


func _check_fill() -> void:
	for p in ["res://art/models/props/soul_reliquary/scenes/soul_reliquary.tscn", "res://art/models/props/soul_reliquary/scenes/soul_reliquary_mobile.tscn"]:
		var r := (load(p) as PackedScene).instantiate()
		var l := r.find_child("BrassFill", true, false) as OmniLight3D
		_ok(l != null, p.get_file() + ": BrassFill omni (v2)")
		if l != null:
			_ok(l.light_color.is_equal_approx(Color("#FFB070")) and l.light_energy <= 1.0 and not l.shadow_enabled, "BrassFill warm, low, no shadow")
			var plate := r.find_child("Plate", true, false) as VisualInstance3D
			_ok(plate != null and (plate.layers & l.light_cull_mask) == 0, "BrassFill does not light the digit plate")
		r.free()


func _check_board() -> void:
	for p in ["res://art/models/boards/hearth/scenes/hearth_board.tscn", "res://art/models/boards/hearth/scenes/hearth_board_mobile.tscn"]:
		var b := (load(p) as PackedScene).instantiate()
		for n in ["SoulReliquary", "SoulReliquaryPhone", "SoulReliquaryPortrait"]:
			var mk := b.get_node_or_null("Anchors/" + n) as Marker3D
			_ok(mk != null, "%s has Anchors/%s" % [p.get_file(), n])
		var pt := b.get_node_or_null("Anchors/SoulReliquaryPortrait") as Node3D
		_ok(pt != null and absf(rad_to_deg(pt.rotation.y) - 90.0) < 0.5, "portrait marker yaw 90")
		_ok(pt != null and pt.position.z >= 0.54 and pt.position.y > 0.08, "portrait marker on the near-rail lip, not the felt (v2)")
		_ok(pt != null and pt.position.z - 0.054 * 1.5 * pt.scale.x > 0.50, "portrait plinth clears the throw zone (z > 0.50)")
		var cn := 0
		for c in b.get_node("Hearth/Candles/RailLeft").get_children():
			cn += 1
		_ok(b.get_node_or_null("Hearth/Candles/RailLeft/Candle3") == null and b.get_node_or_null("Hearth/Candles/RailLeft/Candle5") == null, "rail candles 3/5 cut beside the reliquary (v2)")
		b.free()


func _crack_clear(r: SoulReliquary) -> bool:
	var lbl := r.get_node("Rig/Digits") as Label3D
	var cr := r.get_node("Rig/Crack") as MeshInstance3D
	var inv := lbl.global_transform.affine_inverse()
	var w := SoulReliquary.DIGIT_W * 0.5
	var h := SoulReliquary.DIGIT_CAP * 0.5 + 0.001   # ink cap half-height + 1 mm
	for si in cr.mesh.get_surface_count():
		for v in cr.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
			var l := inv * (cr.global_transform * v)
			if absf(l.x) < w and absf(l.y) < h:
				print("  crack vertex in window ", l)
				return false
	return true


func _check(lod: String) -> void:
	print("-- soul_reliquary%s" % lod)
	var r := (load(SCN % lod) as PackedScene).instantiate() as SoulReliquary
	root.add_child(r)
	await process_frame
	for n in ["Rig/Plinth", "Rig/Plate", "Rig/Frame", "Rig/Crack", "Rig/Digits", "Rig/Cage/Vessel", "Rig/Cage/Bars", "Rig/Cage/Top/DeltaAnchor", "Rig/Cage/LiquidTop", "Rig/TooltipAnchor", "Rig/PlateCenter"]:
		_ok(r.get_node_or_null(n) != null, "node " + n)
	var n := _tris(r)
	_ok(n <= 300, "drawn tris %d <= 300" % n)
	print("  tris ", n)
	var lbl := r.get_node("Rig/Digits") as Label3D
	var mat := (r.get_node("Rig/Cage/Vessel") as MeshInstance3D).get_active_material(0) as ShaderMaterial
	r.reduced_motion = true
	r.set_soul(18, 35)
	await process_frame
	_ok(lbl.text == "18/35", "label 18/35 (%s)" % lbl.text)
	_ok(lbl.modulate.get_luminance() > 0.6, "digits are light (on the dark plate)")
	_ok(is_equal_approx(float(mat.get_shader_parameter("fill")), 18.0 / 35.0), "shader fill 18/35")
	var lo := float(mat.get_shader_parameter("fill_lo"))
	var hi := float(mat.get_shader_parameter("fill_hi"))
	_ok(lo > 0.0 and hi < 1.0 and lo < hi, "fill maps inside the rings (%.3f..%.3f)" % [lo, hi])
	var lt := (r.get_node("Rig/Cage/LiquidTop") as Node3D).position.y
	_ok(is_equal_approx(lt, r.height * (lo + (hi - lo) * 18.0 / 35.0)), "LiquidTop follows the fill")
	_ok(float(mat.get_shader_parameter("frost")) == 0.0 and not r.frosted(), "no frost at 18")
	r.set_soul(5, 35)
	await process_frame
	_ok(float(mat.get_shader_parameter("frost")) == 1.0 and r.frosted(), "frost at 5")
	r.set_soul(6, 35)
	await process_frame
	_ok(float(mat.get_shader_parameter("frost")) == 0.0, "no frost at 6")
	var cr := r.get_node("Rig/Crack") as Node3D
	_ok(not cr.visible, "no crack when not lethal")
	r.lethal = true
	_ok(cr.visible, "crack when lethal")
	_ok(_crack_clear(r), "crack outside the digit window")
	r.lethal = false
	_ok(not cr.visible, "crack clears")
	r.set_soul(120, 120)
	await process_frame
	_ok(lbl.text == "120/120", "long label")
	var f := lbl.font
	var w := f.get_string_size(lbl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, lbl.font_size).x * lbl.pixel_size
	_ok(w <= SoulReliquary.DIGIT_W + 1e-4, "long label fits the window (%.4f)" % w)
	# grow first, then fill (animated)
	r.reduced_motion = false
	r.set_soul(35, 35, false)
	await process_frame
	var h0 := r.height
	r.set_soul(39, 39)
	var grew_before_fill := true
	var saw_grow := false
	for i in 120:
		await process_frame
		if r.height > h0 + 1e-5:
			saw_grow = true
		if not saw_grow and r.fill < 1.0 - 1e-4 and r.fill > 0.0:
			pass
		if r.fill > 0.99 and r.height < SoulReliquary.height_for(39) - 1e-5 and r.fill != 1.0:
			grew_before_fill = false
		if not r.is_moving():
			break
	_ok(saw_grow and is_equal_approx(r.height, SoulReliquary.height_for(39)), "cage grew to the 39 step")
	_ok(grew_before_fill and lbl.text == "39/39", "grow first, then fill; label 39/39")
	r.free()
