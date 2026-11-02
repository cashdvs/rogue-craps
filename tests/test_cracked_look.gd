## Headless test: the Cracked Die's Art Director look (it washed out white
## and its cracks were lost under the body material). Through a Bonfire table:
##   - body #858A90, shadow #33363A, less light wrap than before (<= 0.2);
##   - a "CrackInk" child on its Body: #16130F, unshaded (no glow / light
##     lift), seams on all 6 faces, with a branch (2+ seam steps) on each;
##   - seam width 2x the modelled groove (SEAM 0.075 of the half edge);
##   - Bone gets no crack ink, and the ink goes when the die turns plain.
##   godot --headless --path . --script res://tests/test_cracked_look.gd
extends SceneTree

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


func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < 0.01


func _run() -> void:
	var st := TableSetup.new()
	st.dice.append(TableDie.new(&"cracked", "Cracked", DiceIds.shape_of(&"cracked")))
	st.run_mode = false
	st.table_seed = 3
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = st
	root.add_child(s)
	await process_frame
	await process_frame
	var d: DieVisual = s.dice[0]
	s.apply_die_look(d, TableDie.new(&"cracked", "Cracked", DiceIds.shape_of(&"cracked")))
	var m := d.body_material
	check(_near(m.get_shader_parameter("albedo"), Color("#858A90")), "body #858A90")
	check(_near(m.get_shader_parameter("shadow_color"), Color("#33363A")), "shadow #33363A")
	check(float(m.get_shader_parameter("wrap")) <= 0.2, "light wrap cut (<= 0.2)")
	var body := d.faces.get_node("Body") as MeshInstance3D
	var ink := body.get_node_or_null(NodePath(DieCrackInk.NODE)) as MeshInstance3D
	check(ink != null, "Cracked has CrackInk")
	if ink != null:
		var im := ink.material_override as StandardMaterial3D
		check(im != null and _near(im.albedo_color, Color("#16130F")), "ink #16130F")
		check(im != null and im.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, "ink unshaded")
		check(ink.layers == body.layers, "ink on the body's render layers")
		var faces := DieCrackInk.per_face(ink.mesh as ArrayMesh)
		for k in ["+x", "-x", "+y", "-y", "+z", "-z"]:
			## 2 triangles per seam step; a branch needs 2+ steps.
			check(int(faces.get(k, 0)) >= 4, "cracks with a branch on face %s (%d tris)" % [k, faces.get(k, 0)])
	check(is_equal_approx(DieCrackInk.SEAM, 0.075), "seam 2x the modelled groove")
	s.apply_die_look(d, TableDie.new(&"bone", "Bone", &"d6"))
	check(body.get_node_or_null(NodePath(DieCrackInk.NODE)) == null, "Bone: no crack ink")
	print("test_cracked_look: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
