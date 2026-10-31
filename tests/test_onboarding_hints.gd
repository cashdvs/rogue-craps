## Onboarding hints v1 (design/onboarding_hints_v1.md) on the 3D Bonfire
## table: the Table 1 seeds (BonfireTuning.tutorial_first_throw /
## tutorial_seeds), when they stop, and who gets hints (M2: a table inside
## the current scene). Hint triggers: test_onboarding_triggers.gd.
##   godot --headless --path . --script res://tests/test_onboarding_hints.gd
extends "res://tests/onboarding_test_base.gd"


func _initialize() -> void:
	# The sandbox table_1 is a real F1 target table now; this suite tests bounties.
	var sandbox_tuning := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	sandbox_tuning.table_goal = preload("res://tests/bounty_fixture.gd").goal(self)
	if sandbox_tuning.table_goal == null:
		return  # fixture missing: goal() printed why and quits
	set_meta(&"sandbox_tuning", sandbox_tuning)  # keep it cached so every load sees the fixture
	_run.call_deferred()


func _run() -> void:
	t = load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	_seed_data()
	await _seeded_run_run3()
	await _seeded_run_pair44()
	await _stop_hand2_end()
	await _stop_skip()
	await _stop_other_table()
	await _m2_inside_scene()
	await _end_screen_stops()
	print("test_onboarding_hints: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


## The data: Table 1's first throw has a cold die; no seed busts.
func _seed_data() -> void:
	check(t.tutorial_first_throw == [2, 3, 4, 4, 6], "first-throw seed is 2 3 4 4 6 (%s)" % str(t.tutorial_first_throw))
	var lit := BonfireScoring.lit_indices(t.tutorial_first_throw, t)
	check(lit == [0, 1, 2, 3], "2-3-4 and 4-4 light, the 6 stays cold (%s)" % str(lit))
	check(not BonfireScoring.lit_indices(t.tutorial_first_throw, t).is_empty(), "the first throw can't bust")
	for e: Dictionary in t.tutorial_seeds:
		var f: Array = e["faces"]
		check(f.size() == int(e["dice"]) and not BonfireScoring.lit_indices(f, t).is_empty(), "seed H%d T%d %s lights something (never a bust)" % [e["hand"], e["throw"], str(f)])


## Seeded hand 1: 2-3-4 4 6. No cold rethrow now, so potting the run and
## pressing THROW banks it; the hand-1 throw-2/3 seeds (cold-dice throws)
## never come up, and hand 2 is seeded.
func _seeded_run_run3() -> void:
	var s := await make_table()
	check(s.bhud.tutorial.active, "Table 1 + tutorial: the tutorial runs")
	var f := await throw(s)
	check(f == [2, 3, 4, 4, 6] and s.seeded_throws == [true], "H1 T1 seeded 2 3 4 4 6 (%s)" % str(f))
	pick_faces(s, [2, 3, 4])
	var hands := s.run.hands_left
	check(s.throw_again(), "THROW with cold dice left: banks the run")
	f = await throw(s)
	check(s.run.hands_left == hands - 1 and s.run.throws_this_hand == 1, "the run banked: hand 2's first throw (hands %d)" % s.run.hands_left)
	check(f == [1, 1, 3, 3, 5] and s.seeded_throws == [true, true], "H2 T1 seeded 1 1 3 3 5 (%s)" % str(f))
	s.queue_free()
	await process_frame


## A Hot Hand in hand 1 (a rigged 1-1-1-1-1, every die potted): hand 2 is
## not seeded.
func _seeded_run_pair44() -> void:
	var s := await make_table()
	await throw(s, [1, 1, 1, 1, 1] as Array[int])
	pick_faces(s, [1, 1, 1, 1, 1])
	check(s.run.is_hot(), "every die potted: Hot Hand")
	check(s.throw_again() and s.run.hot_hands == 1, "THROW: the Hot Hand throws again")
	await wait_bet(s)
	await throw(s, [2, 2, 3, 3, 6] as Array[int])
	pick_faces(s, [2, 2, 3, 3])
	await s.bank()
	await wait_bet(s)
	await throw(s)
	check(s.seeded_throws.size() == 3 and not s.seeded_throws[2], "hand 1 had a Hot Hand: hand 2 is not seeded (%s)" % str(s.seeded_throws))
	s.queue_free()
	await process_frame


## No Hot Hand in hand 1: hand 2 is seeded (1 1 3 3 5); its throw-2 seed
## (the lone 5) needs a cold rethrow, so it never comes up: THROW banks,
## and hand 3 is unseeded (seeding ends with hand 2).
func _stop_hand2_end() -> void:
	var s := await make_table()
	await throw(s)
	pick_faces(s, [2, 3, 4])
	await s.bank()
	await wait_bet(s)
	var f := await throw(s)
	check(f == [1, 1, 3, 3, 5], "H2 T1 seeded 1 1 3 3 5 (%s)" % str(f))
	pick_faces(s, [1, 1, 3, 3])
	check(s.throw_again(), "THROW with the 5 left: banks the Two Pair")
	await throw(s)
	check(s.seeded_throws == [true, true, false] and not s.onboarding.seeding, "hand 3: unseeded, seeding over (%s)" % str(s.seeded_throws))
	s.queue_free()
	await process_frame


func _stop_skip() -> void:
	var s := await make_table()
	s.bhud.tutorial.skip()
	check(not s.onboarding.seeding and not s.bhud.tutorial.active, "Skip tutorial stops seeding")
	await throw(s)
	check(s.seeded_throws == [false], "after Skip the first throw is not seeded")
	s.queue_free()
	await process_frame


func _stop_other_table() -> void:
	var st := TableSetup.sandbox(t, 5)
	st.first_table = false
	var s := await make_table(1, st)
	check(not s.bhud.tutorial.active and not s.onboarding.seeding, "not the run's first table: no tutorial, no seeds")
	await throw(s)
	check(s.seeded_throws == [false], "not the run's first table: unseeded")
	s.queue_free()
	await process_frame
	var rs := RunTableSetup.new()
	check(not rs.first_table and not rs.to_table_setup(t).first_table, "a run table is not the first unless MapRun says so")
	rs.first_table = true
	check(rs.to_table_setup(t).first_table, "MapRun's first table carries first_table")


## M2: with no override, hints run only when the table is the current scene
## or inside it (a run's RunScreen), never for a stray table.
func _m2_inside_scene() -> void:
	var s := await make_table(-1)
	var prev := current_scene
	check(not s.hints_wanted(), "M2: a table outside the current scene gets no hints")
	var holder := Node.new()
	root.add_child(holder)
	current_scene = holder
	s.reparent(holder)
	var gs := root.get_node_or_null("GameSettings")
	var want := gs != null and bool(gs.get("tutorial_enabled"))
	check(s.hints_wanted() == want, "M2: a table inside the current scene follows Settings (%s)" % want)
	current_scene = s
	check(s.hints_wanted() == want, "M2: the table as the current scene follows Settings")
	current_scene = prev
	holder.queue_free()
	await process_frame


## #103 N6: the end screen stops the tutorial: the hint hides, the queue
## empties, and no hint can show over the end panel.
func _end_screen_stops() -> void:
	var s := await make_table(1)
	var tut := s.bhud.tutorial
	tut.request(&"th8_points")
	tut.request(&"th7_claimed", {"card": &"triple"})
	s.bhud.show_end(s.run)
	check(not tut.visible and tut.current == &"" and tut._queue.is_empty() and tut.stopped, "end screen: hint hidden, queue cleared")
	tut.dismiss()
	check(tut.current == &"" and not tut.visible, "dismiss after the end screen pops nothing")
	check(not tut.request(&"jit1_last", {"soul": 3}), "no new hint once the table is over")
	s.new_run(3)
	check(not tut.stopped, "the next table resets it")
	s.queue_free()
	await process_frame
