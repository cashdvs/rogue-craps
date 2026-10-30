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
		check(body.material_override == d.body_material and d.body_material.get_shader_parameter("use_overlay") == true, "%s: own toon material with the art's numbers" % pair[2])
		check(d.faces.get_node_or_null("Pips") == null, "%s: no cube pips" % pair[2])
		# The d4 is grown to exactly 0.065 m; the d8 stays at the 0.050 m cap.
		var want_half := 0.065 if pair[1] == &"d4" else 0.050
		var hull_half := PolyDie.half_extent(pair[1])
		var ab := body.mesh.get_aabb()
		var mesh_half := maxf(maxf(maxf(-ab.position.x, ab.end.x), maxf(-ab.position.y, ab.end.y)), maxf(-ab.position.z, ab.end.z)) * body.scale.x
		check(absf(hull_half - want_half) < 0.0002 and absf(mesh_half - want_half) < 0.0002 and d.hull_outline.scale.is_equal_approx(body.scale),
			"%s: hull %.5f and drawn mesh %.5f reach %.3f m" % [pair[2], hull_half, mesh_half, want_half])
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
		if k == 0:
			_check_hand_gaps(s)
		var want: Array[int] = [k % 4 + 1, k + 1, 1, 2, 3]
		s.rig_slots(want)
		var got := {}
		for i in 2:
			s.all_dice[i].settled.connect(_on_settled.bind(s.all_dice[i], got), CONNECT_ONE_SHOT)
		if not s.quick_throw():
			check(false, "quick throw %d" % k)
			break
		await s.throw_resolved
		for i in 2:
			var d: DieVisual = s.all_dice[i]
			# Read when the die's own settled signal fired (value, tilt, scale).
			var at: Array = got.get(i, [0, 99.0, false])
			if at[0] != want[i] or at[1] > 1.0 or not at[2]:
				bad[i] += 1
				print("  throw %d die %d settled %s" % [k, i, str(at)])
			if d.shown_value() != want[i] or s.run.last_throw.slots[i] != want[i] or PolyDie.tilt_deg(d.shape, d.global_transform.basis * d.faces.basis) > 1.0:
				bad[i] += 1
				print("  throw %d die %d want %d shown %d slot %d tilt %.2f" % [k, i, want[i], d.shown_value(), s.run.last_throw.slots[i], PolyDie.tilt_deg(d.shape, d.global_transform.basis * d.faces.basis)])
		seen_beacon.append(s.all_dice[1].shown_value())
		check(s.sim.bodies[0].get_node("Shape").shape is ConvexPolygonShape3D and s.sim.bodies[1].get_node("Shape").shape is ConvexPolygonShape3D, "throw %d: Gallows and Beacon roll on hull colliders" % k)
		await s.sequence_finished
	check(bad[0] == 0, "Gallows: 8 real throws show the seeded 1-4 (%d bad)" % bad[0])
	check(bad[1] == 0, "Beacon: 8 real throws show the seeded 1-8 (%d bad)" % bad[1])
	check(seen_beacon.has(7) and seen_beacon.has(8), "Beacon shows 7 and 8 (%s)" % str(seen_beacon))


## The grown d4 (0.065 m) still fits the hand ring: no two dice's top-down
## footprints (their hull points as posed, on the felt plane) overlap.
func _check_hand_gaps(s: Bonfire3D) -> void:
	var feet: Array[PackedVector2Array] = []
	for d: DieVisual in s.dice:
		var pts := PolyDie.hull(d.shape) if PolyDie.has_shape(d.shape) else _cube_pts()
		var flat := PackedVector2Array()
		for p in pts:
			var w := d.faces.global_transform * p
			flat.append(Vector2(w.x, w.z))
		feet.append(Geometry2D.convex_hull(flat))
	var hits: Array[String] = []
	for a in feet.size():
		for b in range(a + 1, feet.size()):
			if not Geometry2D.intersect_polygons(feet[a], feet[b]).is_empty():
				hits.append("%d-%d" % [a, b])
	check(feet.size() == 5 and hits.is_empty(), "hand of %d with the 0.065 m d4: no footprints overlap %s" % [feet.size(), str(hits)])


func _cube_pts() -> PackedVector3Array:
	var out := PackedVector3Array()
	for x in [-1, 1]:
		for y in [-1, 1]:
			for z in [-1, 1]:
				out.append(Vector3(x, y, z) * 0.04)
	return out


## A die's settled signal: what it reads right then (slot, tilt, unsquashed).
func _on_settled(i: int, value: int, d: DieVisual, got: Dictionary) -> void:
	var tilt := PolyDie.tilt_deg(d.shape, d.global_transform.basis * d.faces.basis)
	got[i] = [value, tilt, d.scale.is_equal_approx(Vector3.ONE)]


func _settle_hand(s: Bonfire3D) -> void:
	# Wait on the real gather tweens (their finished signal), not a frame count.
	for tw in s._hand_tweens:
		if tw.is_valid() and tw.is_running():
			await tw.finished
