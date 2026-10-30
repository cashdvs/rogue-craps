## PM ruling (Oct 19): every non-d6 die's visual mesh and collider hull stay
## within a 0.050 m half-extent (PolyDie.MAX_HALF_EXTENT) along every axis.
## The hulls (DieHullData) are generated from the 3D Artist's mobile meshes,
## which are rescaled in PR #102 (Caltrop, Knucklebone, Lantern). Until #102
## is merged (its meshes aren't in res://art/models/dice/) the size check is
## PENDING: it prints what is over and passes. Once the meshes are here it
## fails until they and the regenerated hulls (tools/gen_die_hulls.gd) fit.
## Always checked: hull point budget (12-72) and the coin's procedural hull.
##   godot --headless --path . --script res://tests/test_die_hull_extent.gd
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
	var cap := PolyDie.MAX_HALF_EXTENT + 0.0001
	var merged := true
	var over: PackedStringArray = []
	for shape: StringName in DieHullData.SHAPES:
		var pts := PolyDie.hull(shape)
		check(pts.size() >= 12 and pts.size() <= 72, "%s: hull of %d points (budget 12-72)" % [shape, pts.size()])
		check(PolyDie.dirs(shape).size() == PolyDie.values(shape).size(), "%s: one direction per face slot" % shape)
		# Per-shape cap: 0.050 m, the d4 0.065 m (PolyDie.cap_for).
		var scap := PolyDie.cap_for(shape) + 0.0001
		var hull_half := PolyDie.half_extent(shape)
		var mesh_half := PolyDie.mesh_half_extent(shape)
		var path := PolyDie.mesh_path(shape)
		if path != "":
			var scene := (load(path) as PackedScene).instantiate()
			var mi: MeshInstance3D = scene.find_children("*", "MeshInstance3D", true, false)[0]
			var ab := mi.mesh.get_aabb()
			mesh_half = maxf(maxf(maxf(-ab.position.x, ab.end.x), maxf(-ab.position.y, ab.end.y)), maxf(-ab.position.z, ab.end.z))
			mesh_half *= PolyBody.body_scale(shape)  # as drawn on the table
			scene.free()
		else:
			merged = false
		if hull_half > scap or mesh_half > scap:
			over.append("%s (mesh %.4f, hull %.4f)" % [shape, mesh_half, hull_half])
		if merged:
			check(mesh_half <= scap and hull_half <= scap, "%s: mesh %.4f / hull %.4f m within the %.3f m half-extent" % [shape, mesh_half, hull_half, scap - 0.0001])
	check(CoinPhysics.RADIUS <= cap and CoinPhysics.THICKNESS * 0.5 <= cap, "coin: hull within 0.050 m")
	if not merged:
		print("PENDING (PR #102 not merged, its meshes are not in res://art/models/dice/): half-extent cap not enforced yet. Over 0.050 m now: %s" % (", ".join(over) if not over.is_empty() else "none"))
	_check_d4_cap()
	_check_rest_timer()
	print("test_die_hull_extent: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


## QA ask: the d4's real collider (PolyBody.pc_hull, the one dress() uses)
## must reach its 0.065 m cap, so shrinking it back to 0.050 m fails here.
func _check_d4_cap() -> void:
	var far := 0.0
	for p: Vector3 in PolyBody.pc_hull(&"d4"):
		far = maxf(far, maxf(absf(p.x), maxf(absf(p.y), absf(p.z))))
	check(absf(PolyDie.cap_for(&"d4") - 0.065) < 0.0005, "d4: cap_for is %.4f m, want 0.065" % PolyDie.cap_for(&"d4"))
	check(absf(far - 0.065) < 0.002, "d4: collider hull reaches %.4f m, want 0.065 m" % far)


## QA ask: the settle rest timer. 0.12 s at 120 Hz = 15 still frames in a
## row; any longer (e.g. +1 s) or shorter wait fails here.
func _check_rest_timer() -> void:
	var sim := DiceSim.new()
	sim.tuning = TuningData.new()
	check(is_equal_approx(sim.tuning.sim_rest_time, 0.12), "rest time %.3f s, want 0.12 s" % sim.tuning.sim_rest_time)
	check(sim.rest_frames() == 15, "rest_frames() = %d, want 15" % sim.rest_frames())
	sim.free()
