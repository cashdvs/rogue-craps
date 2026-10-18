## Scene test for the Bonfire sandbox (scenes/bonfire.tscn): real 5-die
## physics throws with rigged faces, lit dice, potting groups, rethrow of the
## cold dice, Hot Hand, bust, bank, end screen + restart; plus timing/spread
## over seeded random throws.
##   godot --headless --path . --script res://tests/test_bonfire_scene.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


func throw_faces(s: Bonfire3D, faces: Array[int]) -> Array:
	if not faces.is_empty():
		s.rig_faces(faces)
	if not s.quick_throw():
		check(false, "throw %s starts" % str(faces))
		return []
	var res: Array = await s.throw_resolved
	await s.sequence_finished
	return res


func _run() -> void:
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.bonfire_seed = 5
	s.test_speed = 10.0
	root.add_child(s)
	await process_frame
	await process_frame
	var r := s.run
	var t := s.bonfire_tuning
	check(s.dice.size() == 5 and r.state == BonfireRun.State.AIM, "5 dice in the hand")
	check(s.can_throw() == "", "can throw at the start")

	# Timing and spread over random seeded 5-die throws.
	r.hands_left = 1000
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var slow := 0
	var bad := 0
	var overlap := 0
	var spread_sum := 0.0
	var durations: Array[float] = []
	var n := 12
	for k in n:
		var v := Vector2.from_angle(rng.randf_range(-PI * 0.9, -PI * 0.3)) * rng.randf_range(s.tuning.min_throw_speed * 1.1, s.tuning.max_throw_speed)
		check(s.throw(v), "random throw %d starts" % k)
		var rr: Array = await s.throw_resolved
		var rec := s.last_recording
		var dur := rec.duration() + s.tuning.windup_time + s.tuning.settle_wobble_time
		durations.append(rec.duration() + s.tuning.windup_time)
		if dur > s.tuning.reveal_cap + 0.001:
			slow += 1
		var lim := Table3DBuilder.FELT_HALF
		var c := Vector3.ZERO
		for i in s.throw_dice.size():
			var d := s.throw_dice[i]
			var p := d.global_position
			c += p
			if d.up_dot() < 0.999 or absf(p.x) > lim.x - 0.039 or absf(p.z) > lim.y - 0.039 or d.shown_value() != int(rr[0][i]):
				bad += 1
			for j in range(i + 1, s.throw_dice.size()):
				if Vector2(p.x, p.z).distance_to(Vector2(s.throw_dice[j].global_position.x, s.throw_dice[j].global_position.z)) < s.tuning.die_size * 0.95:
					overlap += 1
		c /= float(s.throw_dice.size())
		for d in s.throw_dice:
			spread_sum += d.global_position.distance_to(c) / float(s.throw_dice.size())
		await s.sequence_finished
		if r.state == BonfireRun.State.PICK:
			var subs := BonfireScoring.matching_subsets(r.throw_faces, t)
			for i in subs[0]:
				s.pick_die(i)
			await s.bank()
		if r.is_over():
			s.new_run(5)
			r = s.run
			r.hands_left = 1000
	durations.sort()
	print("  bonfire 5-die settle (release -> rest): median %.3f s, max %.3f s, mean spread %.3f m" % [durations[n / 2], durations[-1], spread_sum / n])
	check(durations[n / 2] <= s.tuning.settle_target, "median 5-die settle <= settle_target")
	check(slow == 0, "every 5-die reveal within reveal_cap (%d slow)" % slow)
	check(bad == 0, "5-die throws rest flat, on the felt, faces as seeded (%d bad)" % bad)
	check(overlap == 0, "dice never interpenetrate (%d)" % overlap)
	check(spread_sum / n > 0.06, "dice spread out (%.3f m)" % (spread_sum / n))

	# A scripted table: trips, a bust, a Hot Hand, then the clearing bank.
	s.new_run(5)
	r = s.run
	await create_timer(0.3).timeout
	var res := await throw_faces(s, [4, 4, 4, 5, 2] as Array[int])
	var shown: Array[int] = []
	for d in s.throw_dice:
		shown.append(d.shown_value())
	check(shown == [4, 4, 4, 5, 2], "up-faces show the seeded values (%s)" % str(shown))
	check(res[1] == [0, 1, 2, 3] and s.is_lit(s.throw_dice[3]) and not s.is_lit(s.throw_dice[4]), "4-4-4 and the 5 catch fire, the 2 stays cold")
	check(s.bhud.bank_button.disabled and s.bhud.throw_button.disabled, "must pot a combo before bank/rethrow")
	check(not s.pick_die(4), "clicking the cold 2 is refused")
	check(s.pick_die(0) and s.pick_die(1) and s.pick_die(2) and r.throw_points() == 126, "pot 4-4-4 = 126")
	check(not s.pick_die(3), "the 5 can't join the trips")
	check(s.bhud.throw_label.text == "Trips  (30 + 12) x 3 = 126", "live formula (%s)" % s.bhud.throw_label.text)
	await create_timer(0.3).timeout
	check(s.throw_dice[2].global_position.distance_to(s.pot_slot(2)) < 0.01, "potted dice sit on the rail pot")
	check(s.throw_again() and s.dice.size() == 2 and r.pot == 126, "throw again: 2 cold dice back in the hand")
	check(s.bhud.bounty_rows[&"triple"].text.begins_with("[?]"), "Triple pending in the checklist")
	await create_timer(0.3).timeout
	var soul := r.soul
	res = await throw_faces(s, [2, 6] as Array[int])
	check((res[1] as Array).is_empty() and r.soul == soul - t.bust_soul_loss and not r.is_ticked(t.table_goal.required[0]), "2-6 = bust: -Soul, the pending Triple is lost")
	check(r.hands_left == 4 and s.dice.size() == 5 and s.bhud.bounty_rows[&"triple"].text.begins_with("[ ]"), "fresh hand of 5 after the bust")
	res = await throw_faces(s, [3, 3, 3, 5, 5] as Array[int])
	for i in 5:
		s.pick_die(i)
	check(r.selection()["combo"] == &"full_house" and r.is_hot(), "Full House of all 5 = Hot Hand")
	check(s.throw_again() and s.dice.size() == 5 and r.mult_bonus() == 1 and s.pot_dice.is_empty(), "Hot Hand scoops all 5 back, +1 mult")
	await create_timer(0.3).timeout
	res = await throw_faces(s, [1, 2, 3, 6, 6] as Array[int])
	s.pick_die(0); s.pick_die(1); s.pick_die(2)
	check(r.throw_points() == (20 + 6) * 3, "run of 3 at mult 2+1")
	var b: Dictionary = await s.bank()
	check(b["kind"] == &"bank" and r.state == BonfireRun.State.CLEARED, "banking the last required bounty clears the table")
	check(s.bhud.end_panel.visible and s.can_throw() != "" and s.bhud.bounty_rows[&"two_pairs"].text.begins_with("[x]"), "cleared screen; checklist ticked")
	check(r.embers == 5 + 10 + r.points / 100, "Embers: bonus + clear + points/100 (%d)" % r.embers)
	s.bhud.restart_pressed.emit()
	await process_frame
	check(s.run != r and s.run.hands_left == t.table_goal.hands and s.run.embers == 0 and not s.bhud.end_panel.visible and s.can_throw() == "", "Restart starts a fresh run")
	s.queue_free()
	await process_frame
	print("test_bonfire_scene: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
