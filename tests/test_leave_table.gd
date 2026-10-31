## Leave table (how_bonfire_plays.md §2.8; PM Oct 19, Game Designer ruling
## via Systems Dev). Once every required bounty is banked the table is
## CLEARED: the clear Embers are locked in, but the table stays open. The
## player can chase the bonus bounty / more points with the hands left, or
## Leave table between hands. When hands run out a cleared table leaves by
## itself. A bust while chasing costs Soul as usual but never undoes the
## clear. TableOutcome fields are checked in every case.
##
## Table 1: required Triple, Run of 3, Two Pairs; bonus Full House (+5);
## 5 hands; clear +10 Embers; 1 Ember per 100 points.
##   godot --headless --path . --script res://tests/test_leave_table.gd
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


# --- Pure BonfireRun helpers ---------------------------------------------------

## Lands `faces`, pots the dice at `idx` and banks. Returns the bank result.
func bank_hand(r: BonfireRun, faces: Array[int], idx: Array[int]) -> Dictionary:
	r.set_throw(faces)
	for i in idx:
		r.toggle(i)
	return r.bank()


## Hands 1-3 clear Table 1 without the bonus: Run of 3, Triple, Two Pairs.
## Returns the points banked.
func clear_table(r: BonfireRun) -> int:
	bank_hand(r, [1, 2, 3, 6, 6] as Array[int], [0, 1, 2] as Array[int])   # Run of 3
	bank_hand(r, [4, 4, 4, 2, 6] as Array[int], [0, 1, 2] as Array[int])   # Triple
	var b := bank_hand(r, [2, 2, 6, 6, 3] as Array[int], [0, 1, 2, 3] as Array[int])  # Two Pairs: clear
	check(b.get("cleared_now", false), "the Two Pairs bank is the clearing bank")
	return r.points


## A hand that pots all five 3s (Hot Hand), then throws 2-4-6 (nothing lights): bust.
func bust_hand(r: BonfireRun) -> void:
	r.set_throw([3, 3, 3, 3, 3] as Array[int])
	for i in 5:
		r.toggle(i)
	r.rethrow()
	check(not r.set_throw([2, 4, 6] as Array[int]) and r.last_result.get("kind") == &"bust", "2-4-6 lights nothing: bust")


func new_run() -> BonfireRun:
	return BonfireRun.new(t, t.table_goal, 35, 5)


func _run() -> void:
	t = load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var per := t.points_per_ember
	var clear_e := t.table_goal.clear_embers

	# 1) Clear, then leave right away.
	var r := new_run()
	check(not r.can_leave() and not r.leave(), "1: can't leave before the table is cleared")
	var pts := clear_table(r)
	check(r.cleared and not r.is_over() and r.hands_left == 2, "1: cleared after 3 hands, table still open (2 hands left)")
	check(r.embers == clear_e, "1: the %d clear Embers are locked in at the clear (%d)" % [clear_e, r.embers])
	check(r.can_leave() and r.leave() and r.state == BonfireRun.State.CLEARED, "1: Leave right after the clearing bank")
	var o := TableOutcome.from_run(r, 35)
	check(o.cleared and not o.forfeited and o.soul_delta == 0 and o.hands_used == 3, "1: outcome cleared, Soul 0, 3 hands used")
	check(o.embers == clear_e + pts / per, "1: embers = clear %d + points %d/100 = %d" % [clear_e, pts, o.embers])
	check(o.bounties_claimed.size() == 3 and not o.bounties_claimed.has(&"full_house"), "1: 3 required bounties claimed (%s)" % str(o.bounties_claimed))
	check(o.banked_combos == ([&"run3", &"trips", &"two_pair"] as Array[StringName]), "1: banked combos in order (%s)" % str(o.banked_combos))
	check(int(r.table_summary.get("timeout_soul", -1)) == 0, "1: no timeout penalty")
	check(not r.leave(), "1: can't leave twice")

	# 2) Clear, chase, claim the bonus, leave.
	r = new_run()
	clear_table(r)
	var b := bank_hand(r, [3, 3, 3, 5, 5] as Array[int], [0, 1, 2, 3, 4] as Array[int])
	check((b["ticked"] as Array).has(&"full_house") and b["bonus_embers"] == 5, "2: chasing: the Full House bonus is claimed (+5)")
	check(r.cleared and not r.is_over() and r.embers == clear_e + 5, "2: still open, clear + bonus locked in (%d)" % r.embers)
	pts = r.points
	check(r.leave(), "2: leave after the bonus")
	o = TableOutcome.from_run(r, 35)
	check(o.cleared and o.soul_delta == 0 and o.hands_used == 4, "2: outcome cleared, Soul 0, 4 hands used")
	check(o.bounties_claimed.has(&"full_house") and o.bounties_claimed.size() == 4, "2: bonus bounty in bounties_claimed (%s)" % str(o.bounties_claimed))
	check(o.embers == clear_e + 5 + pts / per, "2: embers = clear + bonus 5 + points/100 = %d" % o.embers)
	check(o.banked_combos.size() == 4 and o.banked_combos[3] == &"full_house", "2: the chase pot is a banked combo (%s)" % str(o.banked_combos))

	# 3) Clear, bust while chasing, leave.
	r = new_run()
	pts = clear_table(r)
	bust_hand(r)
	check(r.cleared and not r.is_over() and r.soul == 34, "3: the bust costs 1 Soul and the table stays cleared and open")
	check(r.claimed_bounties().size() == 3 and r.embers == clear_e and r.points == pts, "3: banked bounties, clear Embers and banked points kept; only the hand's pot is lost")
	check(r.leave(), "3: leave after the bust")
	o = TableOutcome.from_run(r, 35)
	check(o.cleared and o.soul_delta == -1 and o.embers == clear_e + pts / per and o.hands_used == 4, "3: outcome cleared, Soul -1, embers %d kept, 4 hands" % o.embers)
	check(o.banked_combos.size() == 3, "3: the busted pair isn't a banked combo (%s)" % str(o.banked_combos))

	# 4) Clear, then the hands run out: the table leaves by itself.
	r = new_run()
	clear_table(r)
	bank_hand(r, [1, 1, 2, 4, 6] as Array[int], [0, 1] as Array[int])
	check(not r.is_over() and r.hands_left == 1, "4: hand 4 banked, 1 hand left")
	bank_hand(r, [6, 6, 2, 4, 3] as Array[int], [0, 1] as Array[int])
	check(r.is_over() and r.state == BonfireRun.State.CLEARED, "4: after the last hand the table auto-leaves as CLEARED")
	o = TableOutcome.from_run(r, 35)
	check(o.cleared and o.soul_delta == 0 and int(r.table_summary["timeout_soul"]) == 0 and o.hands_used == 5, "4: no timeout penalty, Soul 0, 5 hands used")
	check(o.embers == clear_e + r.points / per, "4: embers = clear + points/100 (%d)" % o.embers)

	# 5) Ruling: clear, bonus banked, then a bust on the FINAL hand.
	r = new_run()
	clear_table(r)
	bank_hand(r, [3, 3, 3, 5, 5] as Array[int], [0, 1, 2, 3, 4] as Array[int])  # hand 4: bonus
	pts = r.points
	bust_hand(r)  # hand 5 busts
	check(r.is_over() and r.state == BonfireRun.State.CLEARED and r.points == pts, "5: final-hand bust: auto-leave, only that hand's points lost")
	o = TableOutcome.from_run(r, 35)
	check(o.cleared and o.soul_delta == -1 and int(r.table_summary["timeout_soul"]) == 0, "5: cleared, Soul -1 (the bust only), no end-of-table penalty")
	check(o.embers == clear_e + 5 + pts / per, "5: embers = clear 10 + bonus 5 + points %d/100 = %d" % [pts, o.embers])
	check(o.bounties_claimed.size() == 4 and o.hands_used == 5, "5: 4 bounties claimed, 5 hands used")

	# 6) Not cleared: the timeout penalty is unchanged.
	r = new_run()
	bank_hand(r, [1, 2, 3, 6, 6] as Array[int], [0, 1, 2] as Array[int])  # Run of 3 only
	for h in 4:
		bank_hand(r, [6, 6, 2, 4, 3] as Array[int], [0, 1] as Array[int])
	check(r.is_over() and r.state == BonfireRun.State.FAILED and not r.cleared, "6: out of hands, not cleared: FAILED")
	o = TableOutcome.from_run(r, 35)
	var lost := 2 * t.table_goal.timeout_soul_per_bounty
	check(not o.cleared and o.soul_delta == -lost and o.embers == r.points / per, "6: timeout -%d Soul (2 unticked x %d), no clear Embers (%d)" % [lost, t.table_goal.timeout_soul_per_bounty, o.embers])

	# Leave is refused mid-hand (after a throw, or after a rethrow).
	r = new_run()
	clear_table(r)
	r.set_throw([3, 3, 3, 3, 3] as Array[int])
	check(not r.can_leave(), "mid-hand (dice landed): can't leave")
	for i in 5:
		r.toggle(i)
	r.rethrow()
	check(r.state == BonfireRun.State.AIM and not r.can_leave(), "mid-hand (Hot Hand to throw): can't leave")

	await _scene()
	print("test_leave_table: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# --- The 3D table: the button and finished ---------------------------------------

func throw_faces(s: Bonfire3D, faces: Array[int]) -> void:
	s.rig_faces(faces)
	if not s.quick_throw():
		check(false, "throw %s starts" % str(faces))
		return
	await s.throw_resolved
	await s.sequence_finished


func wait_bet(s: Bonfire3D) -> void:
	for k in 300:
		if s.phase == Table3D.Phase.BET:
			return
		await process_frame


func scene_bank(s: Bonfire3D, faces: Array[int], idx: Array[int]) -> Dictionary:
	await wait_bet(s)
	await throw_faces(s, faces)
	for i in idx:
		s.pick_die(i)
	return await s.bank()


func _scene() -> void:
	var st := TableSetup.sandbox(t, 5)
	st.run_mode = true
	st.table_seed = 5
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = st
	s.tutorial_override = 0
	s.test_speed = 10.0
	root.add_child(s)
	await process_frame
	await process_frame
	var got: Array = []
	s.finished.connect(func(o: TableOutcome) -> void: got.append(o))
	var r := s.run
	check(not s.bhud.leave_button.visible, "scene: no Leave table button before the clear")
	await scene_bank(s, [1, 2, 3, 6, 6] as Array[int], [0, 1, 2] as Array[int])
	await scene_bank(s, [4, 4, 4, 2, 6] as Array[int], [0, 1, 2] as Array[int])
	check(not s.bhud.leave_button.visible, "scene: no button between hands while not cleared")
	# The clearing bank: hidden during the count-up, shown right after.
	await wait_bet(s)
	await throw_faces(s, [2, 2, 6, 6, 3] as Array[int])
	for i in 4:
		s.pick_die(i)
	check(not s.bhud.leave_button.visible, "scene: hidden mid-hand (dice landed)")
	var during: Array = []
	s.bhud.countup.banner.connect(func(_a: int, _b: int) -> void: during.append(s.bhud.leave_button.visible), CONNECT_ONE_SHOT)
	await s.bank()
	check(during.size() == 1 and not during[0], "scene: hidden during the count-up (%s)" % str(during))
	await wait_bet(s)
	check(r.cleared and s.bhud.leave_button.visible, "scene: Leave table shows right after the clearing bank")
	check(s.bhud.cleared_banner.text.begins_with("TABLE CLEARED"), "scene: TABLE CLEARED banner (%s)" % s.bhud.cleared_banner.text)
	check(got.is_empty(), "scene: clearing doesn't emit finished (the table stays open)")
	# Chase: mid-hand hidden again, back between hands.
	await throw_faces(s, [3, 3, 2, 4, 6] as Array[int])
	check(not s.bhud.leave_button.visible and not s.leave(), "scene: hidden and refused mid-hand while chasing")
	s.pick_die(0)
	s.pick_die(1)
	await s.bank()
	await wait_bet(s)
	check(s.bhud.leave_button.visible, "scene: back between hands")
	# Leave: end panel, finished once on CONTINUE.
	s.bhud.leave_pressed.emit()
	await process_frame
	check(r.is_over() and r.state == BonfireRun.State.CLEARED and s.bhud.end_panel.visible and not s.bhud.leave_button.visible, "scene: Leave ends the table (end panel, button gone)")
	check(s.bhud.end_title.text == "Table cleared", "scene: end panel says Table cleared")
	s.bhud.continue_pressed.emit()
	s.bhud.continue_pressed.emit()
	await process_frame
	check(got.size() == 1 and s.finish() == null, "scene: finished emitted exactly once (%d)" % got.size())
	if got.size() == 1:
		var o: TableOutcome = got[0]
		check(o.cleared and o.soul_delta == 0 and o.hands_used == 4 and o.embers == t.table_goal.clear_embers + r.points / t.points_per_ember, "scene: outcome cleared, 4 hands, embers %d" % o.embers)
	s.queue_free()
	await process_frame

	# Hands run out after a clear: auto-leave, finished once.
	st = TableSetup.sandbox(t, 5)
	st.run_mode = true
	st.table_seed = 6
	s = (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = st
	s.tutorial_override = 0
	s.test_speed = 10.0
	root.add_child(s)
	await process_frame
	got = []
	s.finished.connect(func(o: TableOutcome) -> void: got.append(o))
	r = s.run
	await scene_bank(s, [1, 2, 3, 6, 6] as Array[int], [0, 1, 2] as Array[int])
	await scene_bank(s, [4, 4, 4, 2, 6] as Array[int], [0, 1, 2] as Array[int])
	await scene_bank(s, [2, 2, 6, 6, 3] as Array[int], [0, 1, 2, 3] as Array[int])
	await scene_bank(s, [6, 6, 2, 4, 3] as Array[int], [0, 1] as Array[int])
	await scene_bank(s, [6, 6, 2, 4, 3] as Array[int], [0, 1] as Array[int])
	check(r.is_over() and r.state == BonfireRun.State.CLEARED and s.bhud.end_panel.visible and not s.bhud.leave_button.visible, "scene: last hand -> the table leaves by itself")
	s.bhud.continue_pressed.emit()
	await process_frame
	check(got.size() == 1 and (got[0] as TableOutcome).cleared and (got[0] as TableOutcome).soul_delta == 0, "scene: auto-leave emits finished once, cleared, no penalty")
	s.queue_free()
	await process_frame
