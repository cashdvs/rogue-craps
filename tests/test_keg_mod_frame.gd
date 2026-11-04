extends SceneTree
## The Powder Keg barrel is smaller than a d6 cube. Its face-mod frame must
## sit on the barrel (within its box), not float at the cube's face height.

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
	var run := load("res://resources/map/bonfire_run.tres") as RunData
	run.max_dice = 6  # bag5: these checks add a die past the fixed 5
	var p := RunProgress.new(run)
	check(p.add_die(&"powder_keg"), "keg: added")
	var td: TableDie = p.shaped_table_die(p.dice.size() - 1)
	var m := FaceModData.new()
	m.id = &"t_wild"
	m.effect = FaceModData.Effect.WILD
	td.mods = [m, m, m, m, m, m]
	var st := TableSetup.new()
	st.dice.append(td)
	st.run_mode = false
	st.table_seed = 5
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = st
	root.add_child(s)
	for i in 6:
		await process_frame
	var d: DieVisual = s.all_dice[0]
	check(d.shape == &"keg", "keg: barrel body (%s)" % d.shape)
	var body := d.faces.get_node("Body") as MeshInstance3D
	var box := body.transform * body.mesh.get_aabb()
	box = box.grow(0.01 * d.edge)
	var mods := d.faces.get_node("FaceMods")
	var n := 0
	for q in mods.find_children("*", "MeshInstance3D", true, false):
		var mi := q as MeshInstance3D
		var at: AABB = mods.transform * mi.transform * mi.mesh.get_aabb()
		n += 1
		check(box.encloses(at), "keg: mark %s inside the barrel box (%s vs %s)" % [mi.name, at, box])
	check(n > 0, "keg: has its Wild frame marks (%d)" % n)
	print("test_keg_mod_frame: %d passed, %d failed" % [_passed, _failed])
	s.queue_free()
	await process_frame
	quit(1 if _failed > 0 else 0)
