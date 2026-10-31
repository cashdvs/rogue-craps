## Scene test for the Bonfire sandbox (scenes/bonfire.tscn): real 5-die
## physics throws with rigged faces, lit dice, potting groups, rethrow of the
## cold dice, Hot Hand, bust, bank, end screen + restart; plus timing/spread
## over seeded random throws.
##   godot --headless --path . --script res://tests/test_bonfire_scene.gd
extends SceneTree

## Settle samples (section 7): soft/medium flicks and hard flicks. 40 hard
## throws make the nearest-rank p95 the 38th of 40, not just the max.
const N_SOFT: int = 16
const N_HARD: int = 40

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	# The sandbox table_1 is a real F1 target table now; this suite tests bounties.
	var sandbox_tuning := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	sandbox_tuning.table_goal = preload("res://tests/bounty_fixture.gd").goal(self)
	if sandbox_tuning.table_goal == null:
		return  # fixture missing: goal() printed why and quits
	set_meta(&"sandbox_tuning", sandbox_tuning)  # keep it cached so every load sees the fixture
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


## Median of a sorted list.
func _median(v: Array[float]) -> float:
	if v.is_empty():
		return INF
	var m := v.size() / 2
	return v[m] if v.size() % 2 == 1 else (v[m - 1] + v[m]) * 0.5


## Nearest-rank 95th percentile of a sorted list.
func _p95(v: Array[float]) -> float:
	if v.is_empty():
		return INF
	return v[clampi(ceili(0.95 * v.size()) - 1, 0, v.size() - 1)]


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
	# These checks expect plain busts (no Nerve rescue pause): no Nerve.
	s.setup.nerve_uses = 0
	s.new_run(5)
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
	# Settle targets (design/bonfire_map_events_juice.md section 7): soft and
	# medium flicks (<= settle_split_px_s) median <= settle_target; hard flicks
	# (up to the top of the curve) median <= settle_target_hard and p95 <=
	# settle_p95_hard, over enough hard throws for a p95 to mean something.
	var split := s.tuning.settle_split_px_s
	var speeds: Array[float] = []
	for k in N_SOFT:
		speeds.append(rng.randf_range(s.tuning.min_throw_speed * 1.1, split))
	for k in N_HARD:
		speeds.append(rng.randf_range(split + 1.0, t.flick_speed_max))
	var durations: Array[float] = []
	var soft_d: Array[float] = []
	var hard_d: Array[float] = []
	var n := speeds.size()
	for k in n:
		var v := Vector2.from_angle(rng.randf_range(-PI * 0.9, -PI * 0.3)) * speeds[k]
		check(s.throw(v), "random throw %d starts" % k)
		var rr: Array = await s.throw_resolved
		var rec := s.last_recording
		var dur := rec.duration() + s.tuning.windup_time + s.tuning.settle_wobble_time
		durations.append(rec.duration() + s.tuning.windup_time)
		if speeds[k] <= split:
			soft_d.append(durations[-1])
		else:
			hard_d.append(durations[-1])
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
					print("OVERLAP throw %d speed %.0f: die %d %s up %.3f / die %d %s up %.3f" % [k, speeds[k], i, p, d.up_dot(), j, s.throw_dice[j].global_position, s.throw_dice[j].up_dot()])
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
	soft_d.sort()
	hard_d.sort()
	var soft_med := _median(soft_d)
	var hard_med := _median(hard_d)
	var hard_p95 := _p95(hard_d)
	print("  bonfire 5-die settle (release -> rest): soft/medium <= %.0f px/s (%d): median %.3f s, max %.3f s | hard (%d): median %.3f s, p95 %.3f s, max %.3f s | mean spread %.3f m" % [
		split, soft_d.size(), soft_med, soft_d[-1], hard_d.size(), hard_med, hard_p95, hard_d[-1], spread_sum / n])
	check(soft_d.size() == N_SOFT and hard_d.size() == N_HARD and hard_d.size() >= 40, "enough soft (%d) and hard (%d) samples" % [soft_d.size(), hard_d.size()])
	check(soft_med <= s.tuning.settle_target, "median 5-die settle, flicks <= %.0f px/s: %.3f <= settle_target %.2f" % [split, soft_med, s.tuning.settle_target])
	check(hard_med <= s.tuning.settle_target_hard, "median 5-die settle, hard flicks: %.3f <= settle_target_hard %.2f" % [hard_med, s.tuning.settle_target_hard])
	check(hard_p95 <= s.tuning.settle_p95_hard, "p95 5-die settle, hard flicks: %.3f <= settle_p95_hard %.2f" % [hard_p95, s.tuning.settle_p95_hard])
	check(slow == 0, "every 5-die reveal within reveal_cap (%d slow)" % slow)
	check(bad == 0, "5-die throws rest flat, on the felt, faces as seeded (%d bad)" % bad)
	check(overlap == 0, "dice never interpenetrate (%d)" % overlap)
	check(spread_sum / n > 0.06, "dice spread out (%.3f m)" % (spread_sum / n))

	await _count_up_after_settle(s)

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
	# The live pot preview (how_bonfire_plays.md section 4).
	check(s.bhud.throw_label.text == "TRIPS: (30+12) x3 = 126", "live pot preview (%s)" % s.bhud.throw_label.text)
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
	check(b["kind"] == &"bank" and r.cleared and not r.is_over(), "banking the last required bounty clears the table (it stays open)")
	check(s.can_leave_now() and s.bhud.leave_button.visible and s.leave(), "Leave table right after the clearing bank")
	check(r.state == BonfireRun.State.CLEARED and s.bhud.end_panel.visible and s.can_throw() != "" and s.bhud.bounty_rows[&"two_pairs"].text.begins_with("[x]"), "cleared screen; checklist ticked")
	check(r.embers == 5 + 10 + r.points / 100, "Embers: bonus + clear + points/100 (%d)" % r.embers)
	s.bhud.restart_pressed.emit()
	await process_frame
	check(s.run != r and s.run.hands_left == t.table_goal.hands and s.run.embers == 0 and not s.bhud.end_panel.visible and s.can_throw() == "", "Restart starts a fresh run")
	s.queue_free()
	await process_frame
	print("test_bonfire_scene: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


## Section 7: the scoring count-up's time budget (juice_cap / juice_cap_big)
## starts after the dice settle, not at release. A hard flick (the longest
## settle): no pot / bank / count-up while the dice still move; the count-up
## starts after the last die came to rest, and its budget is timed from its
## own start.
func _count_up_after_settle(s: Bonfire3D) -> void:
	s.new_run(5)
	s.run.hands_left = 1000
	while s.phase != Table3D.Phase.BET or s.hand_moving():
		await process_frame
	var last_rest := [0]
	var on_rest := func(_i: int) -> void: last_rest[0] = Time.get_ticks_msec()
	for d in s.all_dice:
		d.rest.connect(on_rest)
	s.rig_faces([4, 4, 4, 5, 2] as Array[int])
	var release_ms := Time.get_ticks_msec()
	check(s.throw(Vector2.from_angle(-PI * 0.6) * s.bonfire_tuning.flick_speed_max), "hard flick at the top of the curve starts")
	await process_frame
	var again := s.throw_again()
	var banked: Dictionary = await s.bank()
	check(not again and banked.is_empty() and not s.bhud.countup.is_playing(), "no pot, bank or count-up while the dice are still rolling (phase %d)" % s.phase)
	await s.throw_resolved
	await s.sequence_finished
	var rest_ms: int = last_rest[0]
	for d in s.all_dice:
		d.rest.disconnect(on_rest)
	check(s.pick_die(0) and s.pick_die(1) and s.pick_die(2), "pot the 4-4-4")
	check(s.throw_again() and s.bhud.countup.is_playing(), "committing the pot starts the count-up")
	var cu := s.bhud.countup
	var start_ms: int = cu._start_ms
	check(rest_ms > release_ms and start_ms >= rest_ms, "count-up starts after the dice rest (release +%d ms, rest +%d ms, count-up +%d ms)" % [0, rest_ms - release_ms, start_ms - release_ms])
	await cu.finished
	var cap := float(cu.plan["cap"]) / cu.speed
	check(cu.last_duration <= cap + 0.1, "count-up budget timed from its own start: %.3f s <= cap %.3f s (at clock x%.0f)" % [cu.last_duration, cap, cu.speed])
	check(absf(cu.last_duration - (Time.get_ticks_msec() - start_ms) / 1000.0) < 0.1, "count-up duration runs from the count-up start, not release")

