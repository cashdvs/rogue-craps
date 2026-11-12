## Headless test: every special die wears its own authored material, not
## plain Bone (Cash beta-0.1.3: a bought Mirror die looked like Bone).
## Through the real Bonfire3D scene, one die at a time:
##   - EACH die with a materials/<die>_body.tres gets a body colour that is
##     not Bone (#E8DCC0): the albedo and shader of its own .tres;
##   - a d6 special with a built <die>_d6.glb wears that body;
##   - the Mirror uses the toon_mirror chrome (#B8C2CC body, #1A2226 pips,
##     reflect 0.3, a 1.2x cream #E8DCC0 keyline, AD Nov 1);
##   - Knucklebone / Midnight get a brass #C9A24A rim (0.25, power 3);
##   - rares get a brass rim (0.3, power 2.5) on their tint;
##   - Blood Pact's Wild gets cream #E8DCC0 keylines and 1.5x ticks, Bone's
##     Wild does not.
##   godot --headless --path . --script res://tests/test_special_dice_materials.gd
extends SceneTree

const BONE := Color("#E8DCC0")
const BRASS := Color("#C9A24A")

var _passed: int = 0
var _failed: int = 0


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


func _initialize() -> void:
	_run.call_deferred()


## Puts one die (optionally Wild on every face) on a Bonfire table.
func _table(id: StringName, wild := false) -> Bonfire3D:
	var td := TableDie.new(id, String(id), DiceIds.shape_of(id))
	if wild:
		var m := FaceModData.new()
		m.id = &"test_wild"
		m.effect = FaceModData.Effect.WILD
		td.mods = [m, null, null, null, null, null]
	var st := TableSetup.new()
	st.dice.append(td)
	st.run_mode = false
	st.table_seed = 3
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = st
	root.add_child(s)
	return s


func _run() -> void:
	var specials := 0
	for id: StringName in DiceIds.ALL:
		if DieArtMaterial.body_path(id) == "" or DiceIds.shape_of(id) == &"coin":
			continue
		specials += 1
		var s := _table(id)
		await process_frame
		var d: DieVisual = s.all_dice[0]
		var col: Color = d.body_material.get_shader_parameter("albedo")
		check(not col.is_equal_approx(BONE), "%s: body is not Bone (%s)" % [id, col.to_html(false)])
		# ... and it is its OWN material: the albedo authored in its .tres.
		var art := load(DieArtMaterial.body_path(id)) as ShaderMaterial
		check(col.is_equal_approx(art.get_shader_parameter("albedo")), "%s: body is its own .tres colour" % id)
		if id == DiceIds.DIE_POWDER_KEG:
			# No Twin carve on this die: the live body stays the plain toon shader.
			check(d.body_material.shader.resource_path.ends_with("toon_noir.gdshader"), "powder_keg without Twin stays on toon_noir")
		else:
			check(d.body_material.shader == art.shader, "%s: its own shader" % id)
		var body := d.faces.get_node("Body") as MeshInstance3D
		check(body.material_override == d.body_material, "%s: the body shows that material" % id)
		# A d6 special with a built .glb wears that body, not the plain cube.
		var glb := "res://art/models/dice/%s_d6.glb" % id
		## Bellows dropped its slatted body (AD, Nov 1): it is the plain cube.
		if id == DiceIds.DIE_BELLOWS:
			check(body.mesh == d.get_meta(&"cube_mesh"), "bellows: plain cube, no slats")
		elif DiceIds.shape_of(id) == &"d6" and ResourceLoader.exists(glb):
			check(body.mesh != null and body.mesh.resource_path.begins_with(glb), "%s: wears %s" % [id, glb])
		if id == DiceIds.DIE_MIRROR:
			_check_mirror(d)
		if id in [DiceIds.DIE_KNUCKLEBONE, DiceIds.DIE_MIDNIGHT]:
			_check_rim(d, 0.25, 3.0, String(id))
		s.queue_free()
		await process_frame
	check(specials >= 12, "found the special dice (%d)" % specials)
	# A rare on the Bone stand-in: tint plus a brass rim.
	## Ossuary has its own ash body since AD Nov 1; Gallows is still a stand-in.
	var r := _table(DiceIds.DIE_GALLOWS)
	await process_frame
	_check_rim(r.all_dice[0], 0.3, 2.5, "gallows")
	r.queue_free()
	await process_frame
	# Wild: keylines + wide ticks only on the red body.
	var e_red := await _wild_kids(DiceIds.DIE_BLOOD_PACT)
	var e_bone := await _wild_kids(DiceIds.DIE_BONE)
	check(e_bone.size() == 8, "Bone Wild: unchanged 8 pieces (%d)" % e_bone.size())
	check(e_red.size() == 10, "Blood Pact Wild: 8 pieces + 2 keylines (%d)" % e_red.size())
	if e_red.size() == 10 and e_bone.size() == 8:
		check(is_equal_approx(e_red[4][0].x, e_bone[4][0].x * 1.5), "Blood Pact ticks 1.5x wide")
		for i in [8, 9]:
			check((e_red[i][1] as Color).is_equal_approx(BONE), "keyline %d is cream" % i)
			var long_side := maxf(e_red[i][0].x, e_red[i][0].y)
			check(absf(long_side - (0.88 + 0.024) * _edge) < 0.0001, "keyline %d is 0.012 e each side" % i)
	print("test_special_dice_materials: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


var _edge := 0.0


func _wild_kids(id: StringName) -> Array:
	var s := _table(id, true)
	await process_frame
	var d: DieVisual = s.all_dice[0]
	_edge = d.edge
	# [quad size, colour] per piece, read before the table is freed.
	var kids := []
	for mi: MeshInstance3D in d.faces.get_node("FaceMods").get_children():
		kids.append([(mi.mesh as QuadMesh).size, _col(mi)])
	s.queue_free()
	await process_frame
	return kids


func _check_mirror(d: DieVisual) -> void:
	var m := d.body_material
	check(m.shader.resource_path.ends_with("toon_mirror.gdshader"), "mirror: chrome shader")
	check((m.get_shader_parameter("albedo") as Color).is_equal_approx(Color("#B8C2CC")), "mirror: #B8C2CC body")
	check(is_equal_approx(m.get_shader_parameter("reflect_energy"), 0.3), "mirror: reflect 0.3")
	check(d.pip_material != null and (d.pip_material.get_shader_parameter("albedo") as Color).is_equal_approx(Color("#1A2226")), "mirror: #1A2226 pips")
	var o := m.next_pass as ShaderMaterial
	check(o != null and (o.get_shader_parameter("color") as Color).is_equal_approx(Color("#E8DCC0")), "mirror: cream keyline")
	check(o != null and is_equal_approx(o.get_shader_parameter("width"), 0.0042 * 1.2), "mirror: keyline 1.2x")


func _check_rim(d: DieVisual, strength: float, power: float, what: String) -> void:
	var m := d.body_material
	check((m.get_shader_parameter("rim_color") as Color).is_equal_approx(BRASS), "%s: brass rim" % what)
	check(is_equal_approx(m.get_shader_parameter("rim_strength"), strength), "%s: rim %.2f" % [what, strength])
	check(is_equal_approx(m.get_shader_parameter("rim_power"), power), "%s: rim power %.1f" % [what, power])


func _col(mi: MeshInstance3D) -> Color:
	return (mi.material_override as StandardMaterial3D).albedo_color
