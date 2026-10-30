## Gallows (d4) and Beacon (d8) on the real map-run path (QA #198): bought
## in the shop -> RunProgress bag -> MapRun.table_setup -> Bonfire3D. They
## must be shaped bodies (not cubes) on the PC-mesh hull, keep the rare
## tint and marks, and stay visible on the felt after the throw.
extends SceneTree

var _passed: int = 0
var _failed: int = 0
var _t: BonfireTuning
var _data: RunData


func _initialize() -> void:
	_t = load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	_data = load("res://resources/map/bonfire_run.tres") as RunData
	await _test(&"gallows", &"d4", "caltrop_d4")
	await _test(&"beacon", &"d8", "lantern_d8")
	_check_dress_keeps_other_nodes()
	print("test_gallows_beacon_run: %d passed, %d failed" % [_passed, _failed])
	_t = null
	_data = null
	quit(1 if _failed > 0 else 0)


func _check(c: bool, what: String) -> void:
	_passed += int(c)
	_failed += int(not c)
	if not c: print("FAIL: ", what)


func _shape(id: StringName) -> DieShape:
	for s in _data.shapes:
		if s.id == id: return s
	return null


## Buys die [param id] and plays it at the next table, as a player would.
func _test(id: StringName, shape: StringName, glb: String) -> void:
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
	var rs := run.table_setup()
	var b := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	b.setup = rs.to_table_setup(_t)
	b.tutorial_override = 0
	b.test_speed = 10.0
	root.add_child(b)
	for k in 900:
		await process_frame
		if b.phase == Table3D.Phase.BET and b.run.state == BonfireRun.State.AIM and not b.hand_moving(): break
	var at := -1
	for i in b.dice.size():
		if b._td(i).id == id: at = i
	_check(at >= 0, "%s: in hand at the table" % id)
	if at < 0:
		b.queue_free()
		return
	var d: DieVisual = b.dice[at]
	var body := d.faces.get_node("Body") as MeshInstance3D
	_check(d.shape == shape and body.mesh.resource_path.begins_with("res://art/models/dice/%s.glb" % glb), "%s: a %s body on the run path, not a cube (%s %s)" % [id, shape, d.shape, body.mesh.resource_path])
	_check(body.material_override == d.body_material and (d.body_material.get_shader_parameter("albedo") as Color).is_equal_approx(RareDieLook.body_color()), "%s: keeps the rare tint" % id)
	var art := body.mesh.surface_get_material(0) as ShaderMaterial
	_check(d.body_material.get_shader_parameter("use_overlay") == true and d.body_material.get_shader_parameter("overlay_tex") == art.get_shader_parameter("overlay_tex"), "%s: shows the art's printed numbers" % id)
	_check(d.faces.get_node_or_null("FaceMods") != null, "%s: keeps its FaceMods marks node" % id)
	var top: int = sh.faces.max()
	var rig: Array[int] = []
	for i in b.dice.size():
		rig.append(top if i == at else 2)
	b.rig_faces(rig)
	b.quick_throw()
	await b.throw_resolved
	var col := b.sim.bodies[at].get_node("Shape").shape as ConvexPolygonShape3D
	_check(col != null and col.points == PolyBody.pc_hull(shape) and col.points != (DieHullData.SHAPES[shape]["hull"] as PackedVector3Array), "%s: rolls on the PC-mesh hull, not the mobile LOD" % id)
	_check(d.shown_value() == top and b.run.last_throw.values[at] == top, "%s: shows its %d" % [id, top])
	_check_visible(d, body, id, "after the throw")
	await b.sequence_finished
	_check_visible(d, body, id, "after the sequence")
	b.queue_free()
	await process_frame


func _check_visible(d: DieVisual, body: MeshInstance3D, id: StringName, when: String) -> void:
	var low := INF
	var xf := body.global_transform
	for p in PolyBody.pc_hull(d.shape):
		low = minf(low, (xf * p).y)
	_check(body.is_visible_in_tree() and d.shape != &"d6" and body.mesh == PolyBody.mesh_for(d.shape) and low > -0.005, "%s: shaped and visible on the felt %s (low point %.3f)" % [id, when, low])


## dress() leaves other systems' nodes and the look alone (FaceMods from
## #196, RareTrim from Systems Dev), even when called twice.
func _check_dress_keeps_other_nodes() -> void:
	var d := DieVisual.new()
	var td := TableDie.new(DiceIds.DIE_GALLOWS, "Gallows", DiceIds.shape_of(DiceIds.DIE_GALLOWS))
	d.set_look(RareDieLook.body_color(), Color.WHITE, [1, 2, 3, 4] as Array[int])
	var fm := Node3D.new()
	fm.name = "FaceMods"
	fm.add_child(Node3D.new())
	d.faces.add_child(fm)
	var trim := Node3D.new()
	trim.name = "RareTrim"
	d.faces.add_child(trim)
	PolyBody.dress(d, td)
	PolyBody.dress(d, td)
	_check(is_instance_valid(fm) and fm.get_child_count() == 1 and is_instance_valid(trim), "dress keeps FaceMods marks and RareTrim")
	_check((d.body_material.get_shader_parameter("albedo") as Color).is_equal_approx(RareDieLook.body_color()), "dress keeps the rare tint")
	d.free()
