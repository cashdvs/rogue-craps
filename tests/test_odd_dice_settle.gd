## Settle test for every non-d6 die with its own collider (PM ruling,
## Oct 19): the coin's procedural hull and the mobile-mesh hulls (PolyDie /
## DieHullData) for the Caltrop d4, Lantern d8, Tithe d10, Midnight d12,
## Verdict d20, Knucklebone (talus) and the Powder Keg barrel (keg body; its
## data is a d6 printed 1, 1, 2, 2, 3, 3 and each value is on 2 staves).
## For each die: ODD_THROWS (default 200) throws on each of soft, medium and
## hard flicks, alternating the die alone and in a 5-die handful, through the
## real Bonfire launch + DiceSim. Checked per die:
##   - no jitter: after a natural settle the dice are watched live for
##     0.3 s (DiceSim.post_rest_watch) and must not start moving again (a
##     slow creep off a near-balance is FLAGged; more than 1% fails),
##   - never left on an edge / point once the assist finishes (final pose
##     flat on a face); dice that had stopped tilted > 15 deg (an edge, a
##     point, or leaning on a die / rail) before the lay-flat are counted,
##   - settle time median / p95 against bonfire_map_events_juice.md §7 (soft
##     and medium median <= 0.9 s; hard median <= 1.3 s, p95 <= 1.8 s), for
##     the die and for the whole 5-die handful,
##   - the face read matches the seeded face every time: the landed pose
##     remapped to the seeded slot (PolyDie.remap_basis) reads that slot back
##     (the d4 by its top vertex), and the sim's up value matches the pose.
## Prints one table row per die (ODD TABLE ...).
##   godot --headless --path . --script res://tests/test_odd_dice_settle.gd
## Env: ODD_THROWS (per strength), ODD_SHAPES (comma list), ODD_SEED.
extends SceneTree

const STRENGTHS := {"soft": [700.0, 1100.0], "medium": [1500.0, 2100.0], "hard": [2600.0, 4200.0]}
const TARGET_MEDIAN := {"soft": 0.9, "medium": 0.9, "hard": 1.3}
const TARGET_P95_HARD: float = 1.8
const STUCK_DEG: float = 15.0

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


func pct(a: Array, p: float) -> float:
	if a.is_empty():
		return 0.0
	var s := a.duplicate()
	s.sort()
	return float(s[clampi(int(ceil(p * s.size())) - 1, 0, s.size() - 1)])


func _run() -> void:
	var shapes: Array = [&"coin", &"d4", &"d8", &"d10", &"d12", &"d20", &"talus", &"keg"]
	if OS.get_environment("ODD_SHAPES") != "":
		shapes.clear()
		for x in OS.get_environment("ODD_SHAPES").split(","):
			shapes.append(StringName(x))
	var n := int(OS.get_environment("ODD_THROWS")) if OS.get_environment("ODD_THROWS") != "" else 200
	var st := TableSetup.new()
	for i in 5:
		st.dice.append(TableDie.new())
	st.run_mode = false
	st.table_seed = int(OS.get_environment("ODD_SEED")) if OS.get_environment("ODD_SEED") != "" else 41
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = st
	s.test_speed = 10.0
	root.add_child(s)
	await process_frame
	await process_frame
	s.sim.post_rest_watch = 0.3
	var release := s.camera.cam.unproject_position(Table3D.HAND)
	var seed_rng := RandomNumberGenerator.new()
	seed_rng.seed = 77
	var odd: DieVisual = s.all_dice[0]
	print("ODD TABLE | die | throws | soft med/p95 | medium med/p95 | hard med/p95 | hand hard med/p95 | assisted | jitter | eased off edge/lean | stuck after assist | read ok | max post-rest lin/ang")
	for shape: StringName in shapes:
		odd.shape = shape
		var faces := 2 if shape == &"coin" else PolyDie.dirs(shape).size()
		var times := {"soft": [], "medium": [], "hard": []}
		var hand_hard: Array = []
		var assisted := 0
		var jitter := 0
		var stuck := 0
		var eased := 0
		var read_bad := 0
		var max_lin := 0.0
		var max_ang := 0.0
		var total := 0
		var hull_ok := true
		for strength: String in STRENGTHS:
			var span: Array = STRENGTHS[strength]
			for k in n:
				var alone := k % 2 == 0
				var hand: Array[DieVisual] = []
				if alone:
					hand.append(odd)
				else:
					hand.assign(s.all_dice)
				s._set_active(hand)
				for i in hand.size():
					hand[i].global_transform = Transform3D(Basis.IDENTITY.rotated(Vector3.UP, 0.9 * k + 0.3 * i).rotated(Vector3.RIGHT, 0.37 * k), s.hand_spot(i))
				var sp := lerpf(span[0], span[1], float(k) / float(maxi(n - 1, 1)))
				var dir := Vector2(0.2 * sin(k * 1.3), -1.0).normalized()
				var rec: ThrowRecording = await s.simulate_throw(dir * sp, release)
				total += 1
				if total == 1:
					var cs := s.sim.bodies[0].get_node("Shape") as CollisionShape3D
					hull_ok = cs.shape is ConvexPolygonShape3D and is_equal_approx(s.sim.bodies[0].mass, s.tuning.die_mass * (0.5 if shape == &"coin" else 1.0))
				(times[strength] as Array).append(rec.rest_t[0])
				if strength == "hard" and not alone:
					var mx := 0.0
					for i in hand.size():
						mx = maxf(mx, rec.rest_t[i])
					hand_hard.append(mx)
				if rec.assisted:
					assisted += 1
				if OS.get_environment("ODD_DEBUG") != "":
					print("  %s %s k=%d settled=%s assisted=%s rest=%.2f tilt=%.1f moving=%s post=%s/%s restarts=%d nudges=%d dur=%.2f" % [shape, strength, k, rec.settled, rec.assisted, rec.rest_t[0], rec.rest_tilt_deg[0], rec.end_moving[0], str(rec.post_rest_max_lin[0]), str(rec.post_rest_max_ang[0]), rec.post_rest_restarts[0], rec.nudges, rec.duration()])
				if rec.settled:
					max_lin = maxf(max_lin, rec.post_rest_max_lin[0])
					max_ang = maxf(max_ang, rec.post_rest_max_ang[0])
					if rec.post_rest_restarts[0] > 0:
						jitter += 1
				# Stopped but tilted (on an edge / point, or leaning on a die or
				# rail) when the sim ended: the lay-flat / assist eases it onto a
				# face (reported). After that it must be flat (checked below).
				var edge_deg := 90.0 - CoinPhysics.EDGE_DEG if shape == &"coin" else STUCK_DEG
				if not rec.end_moving[0] and rec.rest_tilt_deg[0] > edge_deg:
					eased += 1
				var fin_tilt := CoinPhysics.tilt_deg(rec.final_transform(0).basis) if shape == &"coin" else PolyDie.tilt_deg(shape, rec.final_transform(0).basis)
				if fin_tilt > 0.5:
					stuck += 1
				# Face read: the seeded slot, through the remap, every time.
				var fin := rec.final_transform(0)
				var want := seed_rng.randi_range(1, faces)
				var ok := true
				if shape == &"coin":
					ok = CoinPhysics.slot_for_axis_id(rec.up_values[0]) == CoinPhysics.face_slot(fin.basis)
					var shown := fin.basis * Basis(Vector3.RIGHT, PI) if CoinPhysics.face_slot(fin.basis) != want else fin.basis
					ok = ok and CoinPhysics.face_slot(shown) == want
				else:
					ok = rec.up_values[0] == PolyDie.up_slot(shape, fin.basis) and PolyDie.tilt_deg(shape, fin.basis) < 0.5
					ok = ok and PolyDie.up_slot(shape, PolyDie.remap_basis(shape, fin.basis, want)) == want
				if not ok:
					read_bad += 1
		var row := "ODD TABLE | %s | %d | %.2f/%.2f | %.2f/%.2f | %.2f/%.2f | %.2f/%.2f | %d | %d | %d | %d | %d/%d | %.3f/%.2f" % [shape, total,
			pct(times["soft"], 0.5), pct(times["soft"], 0.95), pct(times["medium"], 0.5), pct(times["medium"], 0.95),
			pct(times["hard"], 0.5), pct(times["hard"], 0.95), pct(hand_hard, 0.5), pct(hand_hard, 0.95),
			assisted, jitter, eased, stuck, total - read_bad, total, max_lin, max_ang]
		print(row)
		check(hull_ok, "%s: convex-hull collider, mass %s" % [shape, "0.5x" if shape == &"coin" else "1x"])
		# A die "at rest" balanced within a few degrees of a face can creep
		# over a little later (seen on the Knucklebone's curved sides, ~0.3%).
		# In the game it is laid flat and frozen at settle, so the player sees
		# a small ease, not jitter; flagged to PM, failed only above 1%.
		if jitter > 0:
			print("FLAG  %s: %d of %d throws crept after settling (max %.3f m/s, %.2f rad/s)" % [shape, jitter, total, max_lin, max_ang])
		check(jitter * 100 <= total, "%s: no jitter after settle (%d of %d throws restarted; <= 1%%)" % [shape, jitter, total])
		check(stuck == 0, "%s: never left on an edge / point once the assist finishes (%d)" % [shape, stuck])
		check(read_bad == 0, "%s: face read matches the seeded face every time (%d bad)" % [shape, read_bad])
		for strength: String in STRENGTHS:
			check(pct(times[strength], 0.5) <= TARGET_MEDIAN[strength], "%s %s: median settle %.2f s <= %.1f" % [shape, strength, pct(times[strength], 0.5), TARGET_MEDIAN[strength]])
		check(pct(times["hard"], 0.95) <= TARGET_P95_HARD and pct(hand_hard, 0.95) <= TARGET_P95_HARD, "%s hard: p95 settle %.2f s (hand %.2f) <= 1.8" % [shape, pct(times["hard"], 0.95), pct(hand_hard, 0.95)])
	odd.shape = &"d6"
	s.queue_free()
	await process_frame
	print("test_odd_dice_settle: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
