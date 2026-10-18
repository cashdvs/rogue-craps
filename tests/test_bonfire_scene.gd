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

	var res := await throw_faces(s, [4, 1, 4, 2, 4] as Array[int])
	var shown: Array[int] = []
	for d in s.throw_dice:
		shown.append(d.shown_value())
	check(shown == [4, 1, 4, 2, 4], "up-faces show the seeded values (%s)" % str(shown))
	check(res[1] == [0, 1, 2, 4] and s.is_lit(s.throw_dice[0]) and not s.is_lit(s.throw_dice[3]), "4-4-4 and 1 catch fire, the 2 stays cold")
	check(s.can_throw() != "" and s.bhud.bank_button.disabled and s.bhud.throw_button.disabled, "must pot before bank/rethrow")
	check(not s.pick_die(3), "clicking the cold 2 is refused")
	check(s.pick_die(0) and r.potted.size() == 3, "clicking one 4 pots the whole set")
	await create_timer(0.3).timeout
	check(s.throw_dice[2].global_position.distance_to(s.pot_slot(1)) < 0.01, "potted dice sit on the rail pot")
	check(s.pick_die(1) and r.throw_points() == 50 and not s.bhud.bank_button.disabled, "4-4-4 + 1 = 50, bank enabled")
	check(s.bhud.pot_label.text == "POT 50", "HUD pot")
	check(s.throw_again() and s.dice.size() == 1 and r.cold == 1 and r.pot == 50, "throw again: 1 cold die back in the hand")
	await create_timer(0.3).timeout
	res = await throw_faces(s, [5] as Array[int])
	check(s.pick_die(0) and r.is_hot(), "last die potted = Hot Hand available")
	check(s.throw_again() and s.dice.size() == 5 and r.multiplier == t.hot_hand_multiplier and s.pot_dice.is_empty(), "Hot Hand scoops all 5 back at x2")
	await create_timer(0.3).timeout
	var soul := r.soul
	res = await throw_faces(s, [2, 3, 4, 6, 6] as Array[int])
	check((res[1] as Array).is_empty() and r.soul == soul - t.bust_soul_loss, "nothing lit = bust, -Soul")
	check(r.hands_left == t.hands - 1 and r.pot == 0 and r.state == BonfireRun.State.AIM and s.dice.size() == 5, "bust ends the hand, fresh 5 dice")
	res = await throw_faces(s, [1, 1, 1, 3, 2] as Array[int])
	check(s.pick_die(1) and r.throw_points() == 10, "1 of 1-1-1 = 10")
	check(s.pick_die(0) and s.pick_die(2) and r.throw_points() == t.triple_ones, "all three 1s = triple")
	var b: Dictionary = await s.bank()
	check(b.get("gain") == t.triple_ones and r.coin == t.triple_ones, "bank moves the pot to coin")

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
		durations.append(rec.duration())
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
		c /= 5.0
		for d in s.throw_dice:
			spread_sum += d.global_position.distance_to(c) / 5.0
		await s.sequence_finished
		if r.state == BonfireRun.State.PICK:
			s.pick_die((rr[1] as Array)[0])
			await s.bank()
		r.coin = 0
	durations.sort()
	print("  bonfire 5-die settle: median %.3f s, max %.3f s, mean spread %.3f m" % [durations[n / 2], durations[-1], spread_sum / n])
	check(slow == 0, "every 5-die reveal within reveal_cap (%d slow)" % slow)
	check(bad == 0, "5-die throws rest flat, on the felt, faces as seeded (%d bad)" % bad)
	check(overlap == 0, "dice never interpenetrate (%d)" % overlap)
	check(spread_sum / n > 0.06, "dice spread out (%.3f m)" % (spread_sum / n))

	# End screen and restart.
	r.hands_left = 8
	r.coin = t.coin_target - 5
	await throw_faces(s, [1, 2, 3, 3, 6] as Array[int])
	s.pick_die(0)
	await s.bank()
	check(r.state == BonfireRun.State.CLEARED and s.bhud.end_panel.visible and s.can_throw() != "", "table cleared screen")
	s.bhud.restart_pressed.emit()
	await process_frame
	check(s.run != r and s.run.coin == t.start_coin and s.run.hands_left == t.hands and not s.bhud.end_panel.visible and s.can_throw() == "", "Restart starts a fresh run")
	s.queue_free()
	await process_frame
	print("test_bonfire_scene: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
