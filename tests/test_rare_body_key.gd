## feat/rare-body-key: a rare die spawns its own art body (DiceIds.body_key
## -> art/models/dice/<key>.glb) at the Bonfire table, through the real
## shop -> bag -> table path. d6 bodies only; shaped rares (Gallows d4,
## Beacon d8) and every non-rare die keep the cube collider and face read.
extends SceneTree

var _passed: int = 0
var _failed: int = 0
var _t: BonfireTuning
var _data: RunData


func _initialize() -> void:
	_t = load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	_data = load("res://resources/map/bonfire_run.tres") as RunData
	_test_paths()
	for id: StringName in [&"barrel", &"fortune", &"usurer", &"gallows", &"beacon"]:
		await _test_table(id)
	print("=== rare body key: %d passed, %d failed ===" % [_passed, _failed])
	_t = null
	_data = null
	quit(1 if _failed > 0 else 0)


func _check(c: bool, what: String) -> void:
	_passed += int(c)
	_failed += int(not c)
	if not c: print("FAIL: ", what)


func _test_paths() -> void:
	var want := {
		&"pyre": "hellfire_d6", &"gilt": "gilded_d6", &"lodestone": "mirror_d6", &"ossuary": "bone_d6",
		&"barrel": "bone_d6", &"fortune": "bone_d6", &"usurer": "bone_d6",
	}
	for id: StringName in want:
		var key := String(DiceIds.body_key(id))
		var p := PolyDie.art_body_path(id)
		_check(p == "res://art/models/dice/%s.glb" % key and key.ends_with("_d6"), "%s: art body %s (body_key %s)" % [id, p, key])
		_check(PolyDie.art_body_mesh(id) != null, "%s: its .glb has a mesh" % id)
	for id: StringName in [&"gallows", &"beacon", &"bone", &"bellows", &"lantern", &"caltrop", &"nope"]:
		_check(PolyDie.art_body_path(id) == "", "%s: keeps the cube (no art body here)" % id)


func _shape(id: StringName) -> DieShape:
	for s in _data.shapes:
		if s.id == id: return s
	return null


func _test_table(id: StringName) -> void:
	var sh := _shape(id)
	var run := MapRun.new(_data, 7)
	run.screen = MapRun.Screen.SHOP
	run.progress.embers = 999
	run.shop_dice = [sh, sh] as Array[SpecialDieData]
	run.buy_die(1)
	run.screen = MapRun.Screen.MAP
	for n in run.map.reachable():
		if run.screen == MapRun.Screen.MAP and run.map.node(n).type == MapGenData.NodeType.TABLE:
			run.choose_node(n)
	var b := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	b.setup = run.table_setup().to_table_setup(_t)
	b.tutorial_override = 0
	b.test_speed = 10.0
	root.add_child(b)
	await process_frame
	await process_frame
	var at := -1
	for i in b.dice.size():
		if b._td(i).id == id: at = i
	_check(at >= 0, "%s: at the table" % id)
	if at < 0:
		b.queue_free()
		await process_frame
		return
	var d := b.dice[at]
	var body := d.faces.get_node("Body") as MeshInstance3D
	var other := b.dice[0 if at != 0 else 1]
	var cube := d.get_meta(&"cube_mesh", body.mesh) as Mesh
	var art := PolyDie.art_body_path(id) != ""
	if art:
		_check(d.get_meta(&"art_body", &"") == DiceIds.body_key(id) and body.mesh != cube, "%s: spawns its %s body" % [id, DiceIds.body_key(id)])
		var ext := body.mesh.get_aabb().size.x * body.scale.x
		_check(absf(ext - d.edge) < d.edge * 0.02, "%s: art body is scaled to the die edge (%.4f vs %.4f)" % [id, ext, d.edge])
		# A die of another edge: the body is scaled by edge / mesh size (Godot Dev #197).
		var small := DieVisual.new(0.05)
		b.add_child(small)
		b.apply_art_body(small, id)
		var sb := small.faces.get_node("Body") as MeshInstance3D
		_check(absf(sb.mesh.get_aabb().size.x * sb.scale.x - 0.05) < 0.001, "%s: a 0.05 m die gets a 0.05 m art body" % id)
		small.free()
		_check(body.material_override == d.body_material, "%s: keeps its toon material (lit / cold still work)" % id)
	else:
		# Gallows / Beacon: no body key; PolyBody dresses them as d4 / d8 (#198).
		_check(d.get_meta(&"art_body", &"") == &"" and d.shape != &"d6" and body.mesh == PolyBody.mesh_for(d.shape), "%s: shaped rare gets its own shaped body" % id)
	_check(other.get_meta(&"art_body", &"") == &"" and not (other.faces.get_node("Body") as MeshInstance3D).mesh.resource_path.contains(".glb"), "%s: the Bone die beside it keeps the cube" % id)
	# Reapplying a plain die gives the cube back (a cube-shaped die only).
	if not art:
		b.queue_free()
		await process_frame
		return
	b.apply_art_body(d, &"bone")
	_check(body.mesh == cube and body.scale == Vector3.ONE, "%s: a Bone look restores the cube" % id)
	b.queue_free()
	await process_frame
