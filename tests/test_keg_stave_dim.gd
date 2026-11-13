## Powder Keg: after settle, only the scored stave's numeral stays full.
## The other numeral cells (atlas cells 0, 1, 2 = values 1, 2, 3) fade.
## Checked here:
##   - set the read value directly on each stave slot (1, 1, 2, 2, 3, 3)
##   - the instance uniform lit_stave is that face value, not the slot and
##     not the cell. cell_is_full then marks only cell (value - 1) full.
##     Writing the cell index, or the slot, fails this.
##   - a real throw settles the same way; throw_started clears it
##   - reduced motion snaps the fade; a normal fade takes about 0.15 s
##   - a second keg keeps its own value; a d6 is never touched
##   - the include lights cell (lit_stave - 1) and adds no emission
##   godot --headless --path . --script res://tests/test_keg_stave_dim.gd
extends SceneTree

const FACES: Array[int] = [1, 1, 2, 2, 3, 3]
const INCLUDE := "res://shaders/3d/keg_stave_dim.gdshaderinc"
const TOON := "res://shaders/3d/toon_noir.gdshader"
const TWIN := "res://shaders/3d/toon_noir_twin.gdshader"

var _passed := 0
var _failed := 0


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_shader()
	_check_mesh_cells()
	var a := _make_keg()
	var b := _make_keg()
	var bone := DieVisual.new()
	root.add_child(bone)
	_check_pair(a, b)
	await _check_slots(a)
	await _check_fade(a)
	_check_other(bone)
	await _check_throw()
	print("test_keg_stave_dim: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


## The include, and both toon shaders that have to read it.
func _check_shader() -> void:
	var inc := FileAccess.get_file_as_string(INCLUDE)
	check(inc != "", "keg stave dim include exists")
	check("lit_stave - 1.0" in inc, "shader lights cell lit_stave - 1 (the value's atlas cell)")
	check("KEG_DIM_KEEP = 0.30" in inc, "dimmed numerals keep about 30% contrast")
	check("EMISSION" not in inc, "the dim include adds no emission")
	check("keg_spec_keep" in inc and "keg_body" in inc, "numeral ink can drop the lamp specular")
	check(is_equal_approx(KegStaveDim.spec_keep(true, 0, 1.0), 0.0), "keg numeral cell keeps no specular")
	check(is_equal_approx(KegStaveDim.spec_keep(true, 2, 0.0), 0.0), "wood in a numeral cell skips specular too")
	check(is_equal_approx(KegStaveDim.spec_keep(true, 3, 1.0), 0.0), "gutter cell beside the numerals skips specular")
	check(is_equal_approx(KegStaveDim.spec_keep(true, 22, 1.0), 0.0), "a seam cell on the stave body skips specular")
	check(is_equal_approx(KegStaveDim.spec_keep(true, 23, 1.0), 1.0), "lid cell keeps specular")
	check(is_equal_approx(KegStaveDim.spec_keep(true, 24, 1.0), 1.0), "hoop cell keeps specular")
	check(is_equal_approx(KegStaveDim.spec_keep(false, 0, 1.0), 1.0), "a non-keg keeps specular on every cell")
	check(KegStaveDim.SPEC_STRENGTH <= 0.15, "keg spec strength stays at most 0.15")
	check("smoothstep(0.40, 0.82" in inc, "keg spec lobe is softer and broader than the bone step")
	for path in [TOON, TWIN]:
		var src := FileAccess.get_file_as_string(path)
		check("keg_stave_dim.gdshaderinc" in src, "%s includes the dim" % path.get_file())
		check("keg_ink_keep" in src, "%s fades overlay ink through keg_ink_keep" % path.get_file())
		check("keg_spec_keep" in src, "%s clamps specular on keg numeral ink" % path.get_file())


## Each stave's mesh UV really is that value's cell. A flipped V, or cell = value, fails.
func _check_mesh_cells() -> void:
	check(KegStaveDim.cell_of_uv(Vector2(0.1, 0.1)) == 0, "UV (0.1, 0.1) is cell 0")
	check(KegStaveDim.cell_of_uv(Vector2(0.3, 0.1)) == 1, "UV (0.3, 0.1) is cell 1")
	check(KegStaveDim.cell_of_uv(Vector2(0.5, 0.1)) == 2, "UV (0.5, 0.1) is cell 2")
	var scene := load("res://art/models/dice/powder_keg_d6.glb") as PackedScene
	var inst := scene.instantiate()
	var mesh: Mesh = null
	for n in inst.find_children("*", "MeshInstance3D", true, false):
		mesh = (n as MeshInstance3D).mesh
		break
	var arr: Array = mesh.surface_get_arrays(0)
	var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var dirs: Array = DieHullData.SHAPES[&"keg"]["dirs"]
	var values: Array = DieHullData.SHAPES[&"keg"]["values"]
	for k in dirs.size():
		var n: Vector3 = dirs[k]
		var sum := Vector2.ZERO
		var count := 0
		for i in norms.size():
			if norms[i].normalized().dot(n) < 0.95:
				continue
			sum += uvs[i]
			count += 1
		var cell := KegStaveDim.cell_of_uv(sum / float(count)) if count > 0 else -1
		var want: int = int(values[k]) - 1
		check(count > 0 and cell == want, "stave %d value %s UV cell %d (want %d)" % [k + 1, values[k], cell, want])
	inst.free()


## Two kegs at once: each mesh keeps the value it was given.
func _check_pair(a: DieVisual, b: DieVisual) -> void:
	var da: KegStaveDim = a.get_node("KegStaveDim")
	var db: KegStaveDim = b.get_node("KegStaveDim")
	check(a.get_node_or_null("KegValueTag") != null, "keg still has its value tag")
	var before := _energy(a)
	da.set_read(1, true)
	db.set_read(3, true)
	check(is_equal_approx(_uniform(a, KegStaveDim.PARAM_BODY), 1.0), "keg A is marked so the stave skips specular")
	check(is_equal_approx(float(a.body_material.get_shader_parameter(&"spec_strength")), KegStaveDim.SPEC_STRENGTH),
		"keg spec strength is %.2f" % KegStaveDim.SPEC_STRENGTH)
	check(is_equal_approx(_uniform(a, KegStaveDim.PARAM_LIT), 1.0), "keg A lit_stave is 1")
	check(is_equal_approx(_uniform(b, KegStaveDim.PARAM_LIT), 3.0), "keg B lit_stave is 3")
	check(is_equal_approx(_uniform(a, KegStaveDim.PARAM_DIM), 1.0), "keg A is faded")
	check(_energy(a) == before and _energy(a) <= 0.3, "dimming does not change emission (%.3f)" % _energy(a))
	_check_cells(a, 1, "pair A")
	_check_cells(b, 3, "pair B")


## Every stave slot. The uniform must be the printed value.
func _check_slots(d: DieVisual) -> void:
	var dim: KegStaveDim = d.get_node("KegStaveDim")
	for slot in range(1, 7):
		d.set_face(slot, false)
		var want: int = FACES[slot - 1]
		check(d.up_slot() == slot and d.shown_value() == want, "slot %d shows %d" % [slot, d.shown_value()])
		d.settled.emit(d.die_id, slot)
		check(dim.lit_value() == want, "slot %d: state lit value is %d (got %d)" % [slot, want, dim.lit_value()])
		check(is_equal_approx(_uniform(d, KegStaveDim.PARAM_LIT), float(want)),
			"slot %d: uniform lit_stave is the value %d, not the slot" % [slot, want])
		check(is_equal_approx(_uniform(d, KegStaveDim.PARAM_DIM), 1.0), "slot %d: stave_dim is 1" % slot)
		_check_cells(d, want, "slot %d" % slot)
	# A Nerve turn after settle follows the new up stave without a new signal.
	d.set_face(5, false)
	for i in 3:
		await process_frame
	check(d.shown_value() == 3 and dim.lit_value() == 3 and is_equal_approx(_uniform(d, KegStaveDim.PARAM_LIT), 3.0),
		"after the up stave changes, lit_stave follows it")


## Full ink while the fade is running, then only the scored cell once it ends.
func _check_fade(d: DieVisual) -> void:
	var dim: KegStaveDim = d.get_node("KegStaveDim")
	dim.set_read(0, true)
	check(dim.lit_value() == 0 and is_zero_approx(_uniform(d, KegStaveDim.PARAM_DIM)), "clear puts every numeral back")
	for cell in 3:
		check(KegStaveDim.cell_is_full(0.0, 0.0, cell), "cleared cell %d is full" % cell)
	dim.set_read(2, false)
	check(dim.dim_amount() < 0.25, "fade starts near full ink (dim %.2f)" % dim.dim_amount())
	await create_timer(0.25).timeout
	check(is_equal_approx(dim.dim_amount(), 1.0) and is_equal_approx(_uniform(d, KegStaveDim.PARAM_LIT), 2.0),
		"fade ends with value 2 lit")
	_check_cells(d, 2, "after fade")


func _check_other(bone: DieVisual) -> void:
	check(bone.get_node_or_null("KegStaveDim") == null, "a d6 has no keg dimmer")
	check(bone.get_node_or_null("KegValueTag") == null, "a d6 has no keg tag")
	var body := bone.faces.get_node("Body") as MeshInstance3D
	var raw: Variant = body.get_instance_shader_parameter(KegStaveDim.PARAM_LIT)
	check(raw == null, "a d6 lit_stave uniform is left unset")
	raw = body.get_instance_shader_parameter(KegStaveDim.PARAM_BODY)
	check(raw == null, "a d6 is not marked as a keg body")
	check(bone.body_material.get_shader_parameter(&"spec_strength") == null, "a d6 keeps its own specular strength")
	raw = body.get_instance_shader_parameter(KegStaveDim.PARAM_DIM)
	check(raw == null, "a d6 stave_dim uniform is left unset")


## One real settle, then the throw signal clears the fade before the next roll.
func _check_throw() -> void:
	var built: Array = await _scene()
	var s: Bonfire3D = built[0]
	await _until_aim(s)
	s.set_reduced_motion(true)
	var keg := _find_keg(s)
	var other := _find_other(s, keg)
	check(keg != null and keg.get_node_or_null("KegStaveDim") != null, "table keg has a dimmer")
	check(other != null and other.get_node_or_null("KegStaveDim") == null, "the other die has no dimmer")
	if keg == null or other == null:
		s.queue_free()
		await process_frame
		return
	var dim: KegStaveDim = keg.get_node("KegStaveDim")
	check(s.throw_started.is_connected(dim._on_throw), "dimmer listens for the next throw")
	s.test_speed = 10.0
	check(s.quick_throw(), "throw started")
	await s.sequence_finished
	for i in 5:
		await process_frame
	var want := keg.shown_value()
	check(want >= 1 and want <= 3, "settled keg shows 1, 2 or 3 (got %d)" % want)
	check(dim.lit_value() == want and is_equal_approx(dim.dim_amount(), 1.0),
		"reduced motion: settle lights %d at once" % want)
	check(is_equal_approx(_uniform(keg, KegStaveDim.PARAM_LIT), float(want)),
		"settled uniform lit_stave is %d" % want)
	_check_cells(keg, want, "settled")
	var tag := keg.get_node_or_null("KegValueTag") as KegValueTag
	check(tag != null and tag.text == str(want), "value tag still shows %d" % want)
	# A drawn die may report the shader default 0. A copied keg value would not be 0.
	var bone_body := other.faces.get_node("Body") as MeshInstance3D
	var bone_raw: Variant = bone_body.get_instance_shader_parameter(KegStaveDim.PARAM_LIT)
	var bone_dim: Variant = bone_body.get_instance_shader_parameter(KegStaveDim.PARAM_DIM)
	check((bone_raw == null or is_zero_approx(float(bone_raw))) and (bone_dim == null or is_zero_approx(float(bone_dim))),
		"the other die stays undimmed (lit %s, dim %s)" % [str(bone_raw), str(bone_dim)])
	# Same frame: reduced motion must not leave the fade at 0.
	dim.set_read(0, true)
	keg.settled.emit(keg.die_id, keg.up_slot())
	check(is_equal_approx(dim.dim_amount(), 1.0), "reduced motion snaps the fade on the settle frame")
	s.throw_started.emit()
	check(dim.lit_value() == 0 and is_zero_approx(dim.dim_amount()) and is_zero_approx(_uniform(keg, KegStaveDim.PARAM_DIM)),
		"throw_started restores every numeral")
	for cell in 3:
		check(KegStaveDim.cell_is_full(_uniform(keg, KegStaveDim.PARAM_LIT), _uniform(keg, KegStaveDim.PARAM_DIM), cell),
			"after a new throw, cell %d is full again" % cell)
	s.queue_free()
	await process_frame


func _check_cells(d: DieVisual, want: int, label: String) -> void:
	var lit := _uniform(d, KegStaveDim.PARAM_LIT)
	var dim := _uniform(d, KegStaveDim.PARAM_DIM)
	for cell in 3:
		var full := KegStaveDim.cell_is_full(lit, dim, cell)
		var expect := cell == want - 1
		check(full == expect, "%s: cell %d full=%s, only cell %d should be" % [label, cell, full, want - 1])
	check(KegStaveDim.cell_is_full(lit, dim, 24), "%s: hoop cell stays full" % label)


func _uniform(d: DieVisual, param: StringName) -> float:
	var body := d.faces.get_node("Body") as MeshInstance3D
	var v: Variant = body.get_instance_shader_parameter(param)
	return 0.0 if v == null else float(v)


func _energy(d: DieVisual) -> float:
	var v: Variant = d.body_material.get_shader_parameter(&"emission_energy")
	return 0.0 if v == null else float(v)


func _make_keg() -> DieVisual:
	var d := DieVisual.new()
	root.add_child(d)
	var td := TableDie.new(DiceIds.DIE_POWDER_KEG, "Powder Keg")
	var printed: Array[int] = []
	printed.assign(FACES)
	td.faces = printed
	DieArtMaterial.apply(d, td)
	PolyBody.dress(d, td)
	return d


func _scene() -> Array:
	var t := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var st := TableSetup.sandbox(t, 2)
	st.nerve_uses = 0
	var keg := TableDie.new(DiceIds.DIE_POWDER_KEG, "Powder Keg")
	var printed: Array[int] = []
	printed.assign(FACES)
	keg.faces = printed
	st.dice[st.dice.size() - 1] = keg
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = st
	s.tutorial_override = 0
	s.bonfire_seed = 5
	s.test_speed = 10.0
	root.add_child(s)
	for i in 4:
		await process_frame
	return [s]


func _find_keg(s: Bonfire3D) -> DieVisual:
	for d: DieVisual in s.all_dice:
		if d.shape == &"keg":
			return d
	return null


func _find_other(s: Bonfire3D, keg: DieVisual) -> DieVisual:
	for d: DieVisual in s.all_dice:
		if d != keg:
			return d
	return null


func _until_aim(s: Bonfire3D) -> void:
	for i in 600:
		if s.phase == Table3D.Phase.BET and s.run != null and s.run.state == BonfireRun.State.AIM and not s.hand_moving():
			return
		await process_frame
