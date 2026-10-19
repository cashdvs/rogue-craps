## Ferryman's Coin physics (Cash's bug: the coin slid and kept landing the
## same face). Checks the coin math (CoinPhysics), then throws the coin
## through the REAL throw path (Bonfire3D.launch_for -> random flip phase ->
## DiceSim with the barrelled convex-hull collider) many times at mixed flick speeds:
##   - heads lands 45-55% (physically, read by the face normal: +Y = heads),
##   - no throw ends with the coin on its edge,
##   - the longest same-face streak is one chance would allow,
##   - it really flips (several half-turns in the air at every speed),
## and finally plays a few throws end to end: the seeded slot shows.
## COIN_TOSSES (env) sets the toss count (default 1000; the CI-sized run).
##   godot --headless --path . --script res://tests/test_coin_flip.gd
extends SceneTree

const SPEEDS: Array[float] = [720.0, 1500.0, 2300.0, 3200.0, 4200.0, 5500.0]

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


func coin_die() -> TableDie:
	var td := TableDie.new(&"ferryman", "Ferryman's Coin", &"coin")
	td.special = &"ferryman"
	td.weights = [1.0, 1.0] as Array[float]
	return td


func _math() -> void:
	check(CoinPhysics.face_slot(Basis.IDENTITY) == 1, "+Y up = heads (slot 1)")
	check(CoinPhysics.face_slot(Basis(Vector3.RIGHT, PI)) == 2, "-Y up = tails (slot 2)")
	check(is_equal_approx(CoinPhysics.tilt_deg(Basis(Vector3.RIGHT, PI * 0.5)), 90.0), "on edge = 90 deg tilt")
	# The hull: 72 points, barrelled profile, mirror-symmetric across Y.
	var pts := CoinPhysics.hull_points()
	var max_r := 0.0
	var max_y := 0.0
	var mirrored := true
	for p in pts:
		max_r = maxf(max_r, Vector2(p.x, p.z).length())
		max_y = maxf(max_y, absf(p.y))
		var found := false
		for q in pts:
			found = found or q.is_equal_approx(Vector3(p.x, -p.y, p.z))
		mirrored = mirrored and found
	check(pts.size() == 72 and mirrored, "hull: 72 points, mirror-symmetric across Y")
	check(is_equal_approx(max_r, 0.05) and is_equal_approx(max_y, 0.012), "hull: 0.100 m across at the middle, 0.024 m thick")
	check(absf(CoinPhysics.rim_radius(0.012) - 0.046) < 0.0002 and absf(CoinPhysics.rim_radius(0.0104) - 0.0471) < 0.0002, "rim arc (r 0.020) matches the art's ring radii (0.0466 face edge / 0.0471)")
	check(CoinPhysics.make_shape() is ConvexPolygonShape3D, "make_shape -> ConvexPolygonShape3D")
	check(CoinPhysics.is_on_edge(Basis(Vector3.RIGHT, deg_to_rad(80))) and not CoinPhysics.is_on_edge(Basis(Vector3.RIGHT, deg_to_rad(60))), "edge band = within 15 deg of vertical")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var h := 0
	for i in 200:
		var b := Basis(Vector3.RIGHT.rotated(Vector3.UP, rng.randf() * TAU), rng.randf_range(0.0, PI))
		var f := CoinPhysics.flat_basis(b, rng)
		if CoinPhysics.tilt_deg(f) > 0.01:
			check(false, "flat_basis lies flat")
			break
		if absf(rad_to_deg(b.orthonormalized().y.angle_to(Vector3.UP)) - 90.0) > 1.0:
			check(CoinPhysics.face_slot(f) == CoinPhysics.face_slot(b), "flat_basis keeps the nearer face")
	# Exactly on edge: flat_basis picks a side at random (the edge reroll).
	for i in 200:
		h += 1 if CoinPhysics.face_slot(CoinPhysics.flat_basis(Basis(Vector3.RIGHT, PI * 0.5), rng)) == 1 else 0
	check(h > 70 and h < 130, "edge reroll is a fair pick (%d/200 heads)" % h)
	var ax := CoinPhysics.flip_axis(Vector3.UP, Vector3(0, 0.5, -3), rng, 0.3)
	check(absf(ax.dot(Vector3.UP)) < 0.001 and ax.is_normalized(), "flip axis is a diameter (in the coin's plane)")
	var tilted := Vector3(0.3, 1, 0).normalized()
	check(absf(CoinPhysics.flip_axis(tilted, Vector3(1, 0, 0), rng, 0.0).dot(tilted)) < 0.001, "flip axis stays in a tilted coin's plane")
	check(CoinPhysics.axis_id(1) == 1 and CoinPhysics.axis_id(2) == 6 and CoinPhysics.slot_for_axis_id(6) == 2, "slot <-> cube axis id")


func _run() -> void:
	_math()
	var st := TableSetup.new()
	st.dice.append(coin_die())
	for i in 4:
		st.dice.append(TableDie.new())
	st.run_mode = false
	st.table_seed = int(OS.get_environment("COIN_SEED")) if OS.get_environment("COIN_SEED") != "" else 21
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = st
	s.test_speed = 10.0
	root.add_child(s)
	await process_frame
	await process_frame
	s.run.hands_left = 100000
	var coin: DieVisual = s.all_dice[0]
	check(coin.shape == &"coin", "the Ferryman die is shown as a coin")
	var sim_body_ok := true
	# Collider and mass after a throw: the coin's body is a thin cylinder.
	var n := int(OS.get_environment("COIN_TOSSES")) if OS.get_environment("COIN_TOSSES") != "" else 1000
	var heads := 0
	var edge_rests := 0
	var edge_nudges := 0
	# Still rolling / rocking on its rim when the settle assist began: the
	# assist lays it on the nearer face (not a rest on its edge).
	var edge_eased := 0
	var streak := 0
	var longest := 0
	var last := 0
	var min_turns := INF
	var sum_turns := 0.0
	var per_speed := {}
	var t0 := Time.get_ticks_msec()
	var release := s.camera.cam.unproject_position(Table3D.HAND)
	for k in n:
		# Alternate: the coin alone (a 1-die rethrow) and in a 5-die handful.
		var alone := k % 2 == 0
		var hand: Array[DieVisual] = []
		if alone:
			hand.append(coin)
		else:
			hand.assign(s.all_dice)
		s._set_active(hand)
		for i in hand.size():
			hand[i].global_transform = Transform3D(Basis.IDENTITY.rotated(Vector3.UP, 0.7 * k), s.hand_spot(i))
		var sp: float = SPEEDS[k % SPEEDS.size()]
		var dir := Vector2(0.15 * sin(k * 1.7), -1.0).normalized()
		var rec: ThrowRecording = await s.simulate_throw(dir * sp, release)
		if k == 0:
			var body := s.sim.bodies[0]
			var cs := body.get_node("Shape") as CollisionShape3D
			sim_body_ok = cs.shape is ConvexPolygonShape3D and (cs.shape as ConvexPolygonShape3D).points.size() == 72 \
				and is_equal_approx(body.mass, s.tuning.die_mass * 0.5)
		var slot := CoinPhysics.slot_for_axis_id(rec.up_values[0])
		var fin := rec.final_transform(0)
		if CoinPhysics.tilt_deg(fin.basis) > 0.5 or CoinPhysics.face_slot(fin.basis) != slot:
			check(false, "toss %d: coin ends flat and up_values matches its face normal" % k)
		if rec.rest_tilt_deg[0] >= 90.0 - CoinPhysics.EDGE_DEG:
			if rec.end_moving[0]:
				edge_eased += 1
			else:
				edge_rests += 1
		if OS.get_environment("COIN_DEBUG") != "":
			print("toss %d alone=%s sp=%.0f slot=%d tilt=%.1f assisted=%s settled=%s nudges=%d edge=%d dur=%.2f" % [k, alone, sp, slot, rec.rest_tilt_deg[0], rec.assisted, rec.settled, rec.nudges, rec.edge_nudges, rec.duration()])
		edge_nudges += rec.edge_nudges
		heads += 1 if slot == 1 else 0
		streak = streak + 1 if slot == last else 1
		last = slot
		longest = maxi(longest, streak)
		# Half-turns in the air: total rotation of the face normal.
		var turns := 0.0
		var fr := rec.frames[0] as Array
		for f in range(1, fr.size()):
			turns += ((fr[f - 1] as Transform3D).basis.y.normalized()).angle_to((fr[f] as Transform3D).basis.y.normalized())
		min_turns = minf(min_turns, turns / PI)
		sum_turns += turns / PI
		if OS.get_environment("COIN_DEBUG") != "":
			var first_hit := -1.0
			for c in rec.contacts:
				if int(c["die"]) == 0 and c["kind"] == &"felt":
					first_hit = float(c["t"])
					break
			print("toss %d sp=%.0f slot=%d half-turns=%.1f first_felt=%.2f spin=%s lin=%s" % [k, sp, slot, turns / PI, first_hit, s.last_launch["spin"][0], s.last_launch["lin"][0]])
		var ps: Array = per_speed.get(sp, [0, 0])
		ps[0] += 1 if slot == 1 else 0
		ps[1] += 1
		per_speed[sp] = ps
	var ms := Time.get_ticks_msec() - t0
	var frac := float(heads) / float(n)
	# Longest run of one face in n fair tosses is about log2(n) (~10 for
	# 1000); allow log2(n) + 6 (chance of a longer one is under 2%).
	var allowed := int(ceil(log(float(n)) / log(2.0))) + 6
	print("COIN STATS: %d tosses, heads %d (%.1f%%), longest streak %d (allowed %d), edge rests %d, edge tips (nudges) %d, eased flat from its rim by the assist %d, min half-turns %.1f, mean %.1f, %d ms" % [n, heads, frac * 100.0, longest, allowed, edge_rests, edge_nudges, edge_eased, min_turns, sum_turns / float(n), ms])
	for sp in per_speed:
		print("  %.0f px/s: heads %d / %d" % [sp, per_speed[sp][0], per_speed[sp][1]])
	check(sim_body_ok, "coin collider = 72-point ConvexPolygonShape3D, mass 0.5x d6")
	check(frac >= 0.45 and frac <= 0.55, "heads %.1f%% within 45-55%%" % (frac * 100.0))
	check(edge_rests == 0, "no edge rests (%d)" % edge_rests)
	check(edge_eased <= n / 20, "rarely still on its rim at the settle assist (%d of %d)" % [edge_eased, n])
	check(longest <= allowed, "longest same-face streak %d <= %d" % [longest, allowed])
	check(min_turns >= 1.0, "every toss turns over at least once (min %.1f half-turns of the face normal)" % min_turns)
	check(float(sum_turns) / float(n) >= 2.5, "it really tumbles: %.1f half-turns on average" % (float(sum_turns) / float(n)))
	# Fairness by symmetry: the same throw started half a flip later lands
	# the other face (the coin is the same shape either way up), so a
	# uniform random phase gives heads and tails exactly equal odds.
	var one: Array[DieVisual] = [coin]
	s._set_active(one)
	coin.global_transform = Transform3D(Basis.IDENTITY, s.hand_spot(0))
	var L := s.launch_for(Vector2(0, -1500), release)
	var lin: Array[Vector3] = [L["lin"][0]]
	var spin: Array[Vector3] = [L["spin"][0]]
	s.sim.set_body_shapes([&"coin"])
	var prng := RandomNumberGenerator.new()
	prng.seed = 9
	# Line a hull vertex up with the flip axis (a turn about local Y), so a
	# half flip maps the 24-sided hull exactly onto itself.
	var ax := spin[0].normalized()
	var align := Basis(Vector3.UP, atan2(-ax.z, ax.x))
	var swapped := 0
	for p in 12:
		var phi := prng.randf_range(0.0, PI)
		var got: Array[int] = []
		for add in [0.0, PI]:
			var starts: Array[Transform3D] = [Transform3D(Basis(ax, phi + add) * align, s.hand_spot(0) + Vector3(0, 0.02, 0))]
			var r: ThrowRecording = await s.sim.simulate(starts, lin, spin, 77)
			got.append(CoinPhysics.slot_for_axis_id(r.up_values[0]))
		swapped += 1 if got[0] != got[1] else 0
	check(swapped >= 10, "phase + half a flip lands the other face (%d of 12 pairs)" % swapped)
	# End to end: the seeded slot is the face that shows (heads and tails).
	var all: Array[DieVisual] = []
	all.assign(s.all_dice)
	s._set_active(all)
	s._to_hand()
	for want in [1, 2, 2, 1]:
		await _settle_hand(s)
		s.rig_slots([want, 1, 1, 1, 1] as Array[int])
		if not s.quick_throw():
			check(false, "quick throw %d" % want)
			break
		await s.throw_resolved
		var shown := coin.shown_value()
		check(shown == want and coin.up_slot() == want, "seeded coin slot %d shows (got %d)" % [want, shown])
		check(CoinPhysics.tilt_deg(coin.global_transform.basis) < 1.0 and absf(coin.global_position.y - CoinPhysics.THICKNESS * 0.5) < 0.004,
			"coin lies flat on the felt after the reveal")
		check(s.run.throw_table_dice[0] != null and s.run.last_throw.slots[0] == want, "the run sees slot %d" % want)
		await s.sequence_finished
		s.new_run(21)
		await process_frame
		s.run.hands_left = 100
	print("test_coin_flip: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _settle_hand(s: Bonfire3D) -> void:
	for i in 30:
		await process_frame
		if s.phase == Table3D.Phase.BET and s.can_throw() == "":
			return
