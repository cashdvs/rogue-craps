## Onboarding hints v1 (design/onboarding_hints_v1.md) on the 3D Bonfire
## table: the Table 1 seeds (BonfireTuning.tutorial_first_throw /
## tutorial_seeds) and when they stop, and each hint's trigger firing once.
##   godot --headless --path . --script res://tests/test_onboarding_hints.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0
var t: BonfireTuning


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


func make_table(tutorial: int = 1, setup: TableSetup = null) -> Bonfire3D:
	var st := setup if setup != null else TableSetup.sandbox(t, 5)
	st.table_seed = 7
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = st
	s.tutorial_override = tutorial
	s.test_speed = 10.0
	root.add_child(s)
	await process_frame
	await process_frame
	return s


func ready_to_throw(s: Bonfire3D) -> void:
	for k in 600:
		if s.phase == Table3D.Phase.BET and not s.bhud.countup.is_playing() and not s.hand_moving() and s.run.state == BonfireRun.State.AIM:
			return
		await process_frame


## Throws (rigged if faces is given, else whatever the seeds say).
func throw(s: Bonfire3D, faces: Array[int] = []) -> Array[int]:
	await ready_to_throw(s)
	if not faces.is_empty():
		s.rig_faces(faces)
	if not s.quick_throw():
		check(false, "throw starts")
		return []
	await s.throw_resolved
	await s.sequence_finished
	return s.run.throw_faces.duplicate()


func wait_bet(s: Bonfire3D) -> void:
	for k in 600:
		if s.phase == Table3D.Phase.BET and not s.bhud.countup.is_playing():
			return
		await process_frame


func pick_faces(s: Bonfire3D, want: Array) -> void:
	var left := want.duplicate()
	for i in s.run.throw_faces.size():
		var v := int(s.run.throw_faces[i])
		if left.has(v):
			left.erase(v)
			s.pick_die(i)


func close_all(s: Bonfire3D) -> void:
	for k in 20:
		if s.bhud.tutorial.current == &"":
			return
		s.bhud.tutorial.dismiss()


func _run() -> void:
	t = load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	_seed_data()
	await _seeded_run_run3()
	await _seeded_run_pair44()
	await _stop_hand2_end()
	await _stop_skip()
	await _stop_other_table()
	await _hints_once()
	await _jit_hints()
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


## Seeded hand 1, potting the obvious run: 2-3-4, then 1-1 -> Hot Hand, then
## the first unclaimed, not-pending bounty (Triple), then seeding stops.
func _seeded_run_run3() -> void:
	var s := await make_table()
	check(s.bhud.tutorial.active, "Table 1 + tutorial: the tutorial runs")
	var f := await throw(s)
	check(f == [2, 3, 4, 4, 6] and s.seeded_throws == [true], "H1 T1 seeded 2 3 4 4 6 (%s)" % str(f))
	pick_faces(s, [2, 3, 4])
	check(s.throw_again(), "pot the run")
	await wait_bet(s)
	f = await throw(s)
	check(f == [1, 1], "H1 T2 (2 dice) seeded 1 1 (%s)" % str(f))
	pick_faces(s, [1, 1])
	check(s.throw_again() and s.run.hot_hands == 1, "pot the Pair: every die scored, Hot Hand")
	await wait_bet(s)
	f = await throw(s)
	check(f == [3, 3, 3, 2, 6], "H1 T3: Run of 3 is pending, so the Triple seed (%s)" % str(f))
	pick_faces(s, [3, 3, 3])
	check(s.throw_again(), "pot the Trips")
	await wait_bet(s)
	await throw(s)
	check(s.seeded_throws == [true, true, true, false] and not s._seeding, "H1 T4 has no seed: unseeded, seeding stops (%s)" % str(s.seeded_throws))
	s.queue_free()
	await process_frame


## The other branch: pot 4-4, then 1-1-1 -> Hot Hand; hand 2 is not seeded.
func _seeded_run_pair44() -> void:
	var s := await make_table()
	await throw(s)
	pick_faces(s, [4, 4])
	s.throw_again()
	await wait_bet(s)
	var f := await throw(s)
	check(f == [1, 1, 1], "H1 T2 (3 dice) seeded 1 1 1 (%s)" % str(f))
	pick_faces(s, [1, 1, 1])
	check(s.throw_again() and s.run.hot_hands == 1, "pot the Trips: Hot Hand")
	await wait_bet(s)
	f = await throw(s)
	check(f == [2, 2, 5, 5, 6], "H1 T3: Triple pending, so the Two Pair seed (%s)" % str(f))
	pick_faces(s, [2, 2, 5, 5])
	await s.bank()
	await wait_bet(s)
	await throw(s)
	check(s.seeded_throws.size() == 4 and not s.seeded_throws[3], "hand 1 had a Hot Hand: hand 2 is not seeded (%s)" % str(s.seeded_throws))
	s.queue_free()
	await process_frame


## No Hot Hand in hand 1: hand 2 is seeded (1 1 3 3 5, then 5 -> Hot Hand);
## hand 3 never is (seeding ends with hand 2).
func _stop_hand2_end() -> void:
	var s := await make_table()
	await throw(s)
	pick_faces(s, [2, 3, 4])
	await s.bank()
	await wait_bet(s)
	var f := await throw(s)
	check(f == [1, 1, 3, 3, 5], "H2 T1 seeded 1 1 3 3 5 (%s)" % str(f))
	pick_faces(s, [1, 1, 3, 3])
	s.throw_again()
	await wait_bet(s)
	f = await throw(s)
	check(f == [5], "H2 T2 seeded 5 (%s)" % str(f))
	pick_faces(s, [5])
	check(s.run.can_continue(), "the 5 pots")
	await s.bank()
	await wait_bet(s)
	await throw(s)
	check(s.seeded_throws == [true, true, true, false] and not s._seeding, "hand 3: unseeded, seeding over (%s)" % str(s.seeded_throws))
	s.queue_free()
	await process_frame


func _stop_skip() -> void:
	var s := await make_table()
	s.bhud.tutorial.skip()
	check(not s._seeding and not s.bhud.tutorial.active, "Skip tutorial stops seeding")
	await throw(s)
	check(s.seeded_throws == [false], "after Skip the first throw is not seeded")
	s.queue_free()
	await process_frame


func _stop_other_table() -> void:
	var st := TableSetup.sandbox(t, 5)
	st.first_table = false
	var s := await make_table(1, st)
	check(not s.bhud.tutorial.active and not s._seeding, "not the run's first table: no tutorial, no seeds")
	await throw(s)
	check(s.seeded_throws == [false], "not the run's first table: unseeded")
	s.queue_free()
	await process_frame
	var rs := RunTableSetup.new()
	check(not rs.first_table and not rs.to_table_setup(t).first_table, "a run table is not the first unless MapRun says so")
	rs.first_table = true
	check(rs.to_table_setup(t).first_table, "MapRun's first table carries first_table")


## Each Table 1 hint fires at its moment, once.
func _hints_once() -> void:
	var s := await make_table()
	var tut := s.bhud.tutorial
	var log: Array[StringName] = []
	tut.shown_hint.connect(func(id: StringName) -> void: log.append(id))
	# start() ran before we connected: TH0 is up.
	check(tut.current == &"th0_throw" and tut.label.text == "Grab the dice and flick them onto the felt.", "TH0 at the start (%s)" % tut.label.text)
	check(tut.skip_button.visible and tut.close_button.visible, "TH bubble: ✕ and Skip tutorial")
	await throw(s)
	check(tut.current == &"th1_lit", "throwing closes TH0; TH1 when hand 1 throw 1 settles")
	tut.dismiss()
	check(tut.current == &"th2_pot" and tut.label.text == "Click glowing dice to pot one combo.", "✕ on TH1, nothing potted: TH2 (%s)" % tut.label.text)
	tut.touch = true
	check(tut.text_for(&"th2_pot") == "Tap glowing dice to pot one combo." and tut.text_for(&"th0_throw").contains("swipe"), "mobile: Tap / swipe")
	tut.touch = false
	check(not s.pick_die(4), "the cold 6 is refused")
	check(tut.current == &"th2_pot", "TH2b never stacks on another hint")
	pick_faces(s, [2, 3, 4])
	check(tut.current == &"th3_pending" and tut.label.text == "This combo claims that bounty. Bank to lock it.", "a valid pot closes TH2; it claims Run of 3: TH3 (%s)" % tut.current)
	tut.dismiss()
	check(tut.current == &"th4_choice", "then TH4 (Bank and Rethrow both on)")
	tut.dismiss()
	check(tut.current == &"th5_risk" and tut.label.text == "2 cold dice: 1 in 3 chance nothing lights.", "then TH5 with the exact odds (%s)" % tut.label.text)
	tut.dismiss()
	for k in 4:
		s.pick_die(4)
	check(log.count(&"th2b_nofit") == 3, "TH2b: up to 3 times (%d)" % log.count(&"th2b_nofit"))
	tut.dismiss()
	s.throw_again()
	await wait_bet(s)
	await throw(s)
	pick_faces(s, [1, 1])
	s.throw_again()
	check(tut.current == &"th6_hot" and tut.label.text == "Every die scored! All five come back, plus 1 mult.", "Hot Hand: TH6 (%s)" % tut.label.text)
	await wait_bet(s)
	await throw(s)
	check(tut.current != &"th6_hot", "the next throw closes TH6")
	pick_faces(s, [3, 3, 3])
	close_all(s)
	await s.bank()
	check(tut.current == &"th7_claimed", "a bank that locks a required bounty: TH7")
	tut.dismiss()
	check(tut.current == &"th8_points", "then TH8 (first bank, after TH7)")
	tut.dismiss()
	await wait_bet(s)
	# A real bust (rigged): TH9.
	await throw(s, [4, 4, 4, 2, 3] as Array[int])
	pick_faces(s, [4, 4, 4])
	close_all(s)
	s.throw_again()
	await wait_bet(s)
	await throw(s, [2, 3] as Array[int])
	for k in 30:
		await process_frame
	check(tut.current == &"th9_bust" and tut.label.text == "Nothing lit, so the hand burned: points and 1 Soul.", "first bust: TH9 (%s)" % tut.label.text)
	tut.dismiss()
	await wait_bet(s)
	# Clear the table (Two Pairs is the one left): TH10.
	await throw(s, [2, 2, 3, 3, 6] as Array[int])
	pick_faces(s, [2, 2, 3, 3])
	close_all(s)
	await s.bank()
	check(s.run.cleared and tut.current == &"th10_cleared", "first clear with hands left and the bonus open: TH10 (%s)" % tut.current)
	await wait_bet(s)
	s.leave()
	check(tut.current == &"", "Leave table closes TH10")
	var once := true
	for id: StringName in log:
		if id != &"th2b_nofit" and log.count(id) != 1:
			once = false
	check(once, "each hint shown once (%s)" % str(log))
	# Same moments again on a fresh table with these flags: nothing repeats.
	var seen := tut.seen.duplicate()
	s.queue_free()
	await process_frame
	s = await make_table()
	tut = s.bhud.tutorial
	tut.seen = seen
	tut.dismiss()
	var again: Array[StringName] = []
	tut.shown_hint.connect(func(id: StringName) -> void: again.append(id))
	await throw(s)
	pick_faces(s, [2, 3, 4])
	s.pick_die(4)
	s.throw_again()
	await wait_bet(s)
	await throw(s)
	pick_faces(s, [1, 1])
	s.throw_again()
	check(again.is_empty(), "seen flags: no hint fires a second time (%s)" % str(again))
	s.queue_free()
	await process_frame


## The just-in-time hints: JIT1 last hand, JIT4 Wild, JIT5 twist table.
func _jit_hints() -> void:
	var st := TableSetup.sandbox(t, 5)
	st.first_table = false
	st.rules = [{"id": &"cold_sixes", "params": {"face": 6}}]
	var s := await make_table(1, st)
	var tut := s.bhud.tutorial
	check(not tut.active and tut.current == &"jit5_twist" and tut.label.text == "This table has a twist. Check its rule card.", "a twist table: JIT5 (%s)" % tut.current)
	check(not tut.skip_button.visible, "JIT bubbles have no Skip tutorial link")
	await throw(s, [4, 4, 4, 2, 3] as Array[int])
	check(tut.current == &"", "the next throw closes JIT5")
	s.run.hands_left = 2
	pick_faces(s, [4, 4, 4])
	await s.bank()
	await wait_bet(s)
	check(tut.current == &"jit1_last" and tut.label.text == "Last hand! Each unclaimed bounty costs 3 Soul.", "the last hand with bounties open: JIT1 (%s)" % tut.label.text)
	s.queue_free()
	await process_frame
	# A Wild face in the pot.
	var st2 := TableSetup.sandbox(t, 5)
	st2.first_table = false
	var wd := TableDie.new()
	wd.mods = [null, null, null, null, null, load("res://resources/mods/wild.tres")]
	st2.dice[0] = wd
	s = await make_table(1, st2)
	tut = s.bhud.tutorial
	await throw(s, [6, 4, 4, 2, 3] as Array[int])
	pick_faces(s, [6, 4, 4])
	s.throw_again()
	check(tut.current == &"jit4_wild" and tut.label.text == "Wild faces pick their best value for you.", "first pot with a Wild: JIT4 (%s)" % tut.current)
	s.queue_free()
	await process_frame
