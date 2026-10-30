## Headless test: the Gallows (d4) and Beacon (d8) rare dice on the Bonfire
## table get their shaped bodies (PolyBody), hull colliders, and face reads.
## Checks, through the real Bonfire3D scene:
##   - each die gets the caltrop_d4 / lantern_d8 art mesh, shape d4 / d8,
##     no cube pips, and a ConvexPolygonShape3D collider in DiceSim;
##   - rotating the die so each slot's direction points up reads that value
##     (the d4 by its top point, so resting on a face reads the opposite tip);
##   - real throws (rig_slots + quick_throw, Instant speed) of every value
##     land showing it, including Beacon's 7 and 8;
##   - Bone dice in the same handful stay cubes.
##   godot --headless --path . --script res://tests/test_gallows_beacon_table.gd
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


## A TableDie for a shaped rare, as RunProgress builds it (die id + shape).
func rare(die_id: StringName) -> TableDie:
	var shape := DiceIds.shape_of(die_id)
	return TableDie.new(die_id, DiceIds.display_name(die_id), shape)


## The basis that turns local direction [param dir] straight up.
func up_basis(dir: Vector3, spin: float) -> Basis:
	var b := Basis(Quaternion(dir.normalized(), Vector3.UP))
	return (Basis(Vector3.UP, spin) * b).orthonormalized()


func _run() -> void:
	var st := TableSetup.new()
	st.dice.append(rare(DiceIds.DIE_GALLOWS))
	st.dice.append(rare(DiceIds.DIE_BEACON))
	for i in 3:
		st.dice.append(TableDie.new())
	st.run_mode = false
	st.table_seed = 5
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = st
	s.test_speed = 10.0
	root.add_child(s)
	await process_frame
	await process_frame
	var g: DieVisual = s.all_dice[0]
	var b: DieVisual = s.all_dice[1]
	_check_bodies(s, g, b)
	_check_rotations(g, &"d4", 4)
	_check_rotations(b, &"d8", 8)
	await _check_throws(s)
	s.queue_free()
	await process_frame
	print("test_gallows_beacon_table: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check_bodies(s: Bonfire3D, g: DieVisual, b: DieVisual) -> void:
	for pair in [[g, &"d4", "caltrop_d4"], [b, &"d8", "lantern_d8"]]:
		var d: DieVisual = pair[0]
		var body := d.faces.get_node("Body") as MeshInstance3D
		check(d.shape == pair[1], "%s: table shape %s (got %s)" % [pair[2], pair[1], d.shape])
		check(body.mesh == PolyBody.mesh_for(pair[1]) and body.mesh != null, "%s: art mesh on the body" % pair[2])
		check(body.mesh.resource_path.begins_with("res://art/models/dice/%s.glb" % pair[2]), "%s: the full-detail mesh, not the mobile LOD (%s)" % [pair[2], body.mesh.resource_path])
		check(body.material_override == null and body.mesh.surface_get_material(0) != null, "%s: the art's own numbered material" % pair[2])
		check(d.faces.get_node_or_null("Pips") == null, "%s: no cube pips" % pair[2])
		var ext := body.mesh.get_aabb().size * body.scale
		check(maxf(ext.x, maxf(ext.y, ext.z)) <= PolyDie.MAX_HALF_EXTENT * 2.0 + 0.002, "%s: within the 0.050 m cap" % pair[2])
	var bone: DieVisual = s.all_dice[2]
	check(bone.shape == &"d6" and bone.faces.get_node_or_null("Pips") != null, "Bone die stays a pipped cube")
	check(PolyBody.table_shape(TableDie.new()) == &"", "a d6 TableDie gets no shaped body")


## Every slot pointed up (at a few spins) reads its value; the d4 resting
## flat on the face opposite a tip reads that tip.
func _check_rotations(d: DieVisual, shape: StringName, n: int) -> void:
	var dirs := PolyDie.dirs(shape)
	var bad := 0
	for k in n:
		for spin in [0.0, 1.1, 2.7]:
			d.faces.quaternion = Quaternion.IDENTITY
			d.global_transform = Transform3D(up_basis(dirs[k], spin), d.global_position)
			if d.up_slot() != k + 1 or d.shown_value() != k + 1:
				bad += 1
	check(bad == 0, "%s: each of %d slots pointed up reads its value (%d bad)" % [shape, n, bad])
	if shape == &"d4":
		# Resting on the face opposite tip 1 (its outward normal is -dir1) = tip 1 up.
		d.global_transform = Transform3D(up_basis(-(dirs[0] as Vector3), 0.0).rotated(Vector3.RIGHT, PI), d.global_position)
		check(d.shown_value() == 1, "d4: flat on the bottom face reads the top point (1), got %d" % d.shown_value())


## Real throws (rig_slots + quick_throw, the player's Space path): each
## seeded value shows once the throw resolves, including Beacon's 7 and 8,
## and the run sees the same slots.
func _check_throws(s: Bonfire3D) -> void:
	s.set_speed_mode(2)
	var bad := {0: 0, 1: 0}
	var seen_beacon: Array[int] = []
	var all: Array[DieVisual] = []
	all.assign(s.all_dice)
	for k in 8:
		s.new_run(30 + k)
		await process_frame
		s.run.hands_left = 100
		s._set_active(all)
		s._to_hand()
		await _settle_hand(s)
		var want: Array[int] = [k % 4 + 1, k + 1, 1, 2, 3]
		s.rig_slots(want)
		if not s.quick_throw():
			check(false, "quick throw %d" % k)
			break
		await s.throw_resolved
		for i in 2:
			var d: DieVisual = s.all_dice[i]
			if d.shown_value() != want[i] or s.run.last_throw.slots[i] != want[i] or PolyDie.tilt_deg(d.shape, d.global_transform.basis * d.faces.basis) > 1.0:
				bad[i] += 1
				print("  throw %d die %d want %d shown %d" % [k, i, want[i], d.shown_value()])
		seen_beacon.append(s.all_dice[1].shown_value())
		check(s.sim.bodies[0].get_node("Shape").shape is ConvexPolygonShape3D and s.sim.bodies[1].get_node("Shape").shape is ConvexPolygonShape3D, "throw %d: Gallows and Beacon roll on hull colliders" % k)
		await s.sequence_finished
	check(bad[0] == 0, "Gallows: 8 real throws show the seeded 1-4 (%d bad)" % bad[0])
	check(bad[1] == 0, "Beacon: 8 real throws show the seeded 1-8 (%d bad)" % bad[1])
	check(seen_beacon.has(7) and seen_beacon.has(8), "Beacon shows 7 and 8 (%s)" % str(seen_beacon))


func _settle_hand(s: Bonfire3D) -> void:
	for i in 30:
		await process_frame
		if s.phase == Table3D.Phase.BET and s.can_throw() == "":
			return
