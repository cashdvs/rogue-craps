## Onboarding hints v1 (design/onboarding_hints_v1.md): each hint's
## trigger on the 3D Bonfire table firing once (TH, JIT, bounty and Seal
## hints). Seeds and gating: test_onboarding_hints.gd.
##   godot --headless --path . --script res://tests/test_onboarding_triggers.gd
extends "res://tests/onboarding_test_base.gd"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	t = load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	await _hints_once()
	await _jit_hints()
	await _bounty_seal_hints()
	print("test_onboarding_triggers: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


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
	check(tut.current == &"hb3_bonus", "after TH1, the next throw that lights: HB3 for the bonus card (%s)" % tut.current)
	tut.dismiss()
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
	check(tut.current == &"th9_bust" and tut.label.text == "Nothing lit, so you bust: lose the hand's points and 1 Soul.", "first bust: TH9 (%s)" % tut.label.text)
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
	# (HB3 is waiting behind JIT5; tested in _bounty_seal_hints.)
	tut._queue.clear()
	tut.seen[&"hb3_bonus"] = 1
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


## HB3 bonus card, HB4 bigger combo, HB5 bust lost a pending bounty (in
## place of TH9), TH9's real Soul cost under the Bloodletter, HS2 Seal.
func _bounty_seal_hints() -> void:
	# HB3 at the start of a table with a bonus card (no tutorial running).
	var s := await hints_table(TableSetup.sandbox(t, 5))
	var tut := s.bhud.tutorial
	var bonus: BountyData = s.run.goal.bonus[0]
	check(tut.current == &"hb3_bonus" and tut.label.text == "The bonus card is optional: claim it for extra Embers.", "HB3: the bonus card (%s)" % tut.current)
	await throw(s, [4, 4, 4, 4, 2] as Array[int])
	check(tut.current != &"hb3_bonus", "the next throw closes HB3")
	# HB4: Quads claims the Triple card.
	pick_faces(s, [4, 4, 4, 4])
	var tri: BountyData = null
	for b: BountyData in s.run.goal.required:
		if b.kind == BountyData.Kind.N_OF_A_KIND and b.n == 3:
			tri = b
	var want := "Bigger combos count too: %s claims a %s card." % [str(s.run.selection()["name"]), tri.display_name if tri != null else "?"]
	check(tut.current == &"hb4_bigger" and tut.label.text == want, "HB4: '%s' (want '%s')" % [tut.label.text, want])
	check(tut.text_for(&"hb4_bigger", {"run": true, "combo": "Run of 4", "card_name": "Run of 3"}) == "Bigger combos count too: a Run of 4 claims Run of 3.", "HB4 run variant")
	# Rethrow the 2 and bust: the pending Triple is lost, HB5 (not TH9).
	s.throw_again()
	await wait_bet(s)
	tut.dismiss()
	await throw(s, [2] as Array[int])
	if s.run.state != BonfireRun.State.AIM or s.run.last_result.get("kind") != &"bust":
		check(false, "the lone 2 busts (%s)" % str(s.run.last_result))
	for k in 30:
		await process_frame
	check(tut.current == &"hb5_lost" and tut.label.text == "That bust lost your pending bounty; bank sooner to keep it.", "HB5 on a bust that loses a pending bounty (%s)" % tut.current)
	check(int(tut.seen.get(&"th9_bust", 0)) == 0, "HB5 replaces TH9 (TH9 still unseen)")
	tut.dismiss()
	var seen := tut.seen.duplicate()
	s.queue_free()
	await process_frame
	# TH9 under the Bloodletter: the real cost, 2.
	var st := TableSetup.sandbox(t, 2)
	st.rules = [{"id": &"bloodletter", "params": {}}]
	s = await hints_table(st)
	tut = s.bhud.tutorial
	tut.seen = seen
	close_all(s)
	await throw(s, [2, 3] as Array[int])
	for k in 30:
		await process_frame
	var cost := int(s.run.last_result.get("soul_lost", 0))
	check(cost == 2 and tut.current == &"th9_bust" and tut.label.text == "Nothing lit, so you bust: lose the hand's points and 2 Soul.", "TH9 with the Bloodletter's cost %d (%s)" % [cost, tut.label.text])
	check(not tut.label.text.contains("burn"), "TH9 has no 'burned'")
	s.queue_free()
	await process_frame
	# HS2: a run table whose Trips combo carries a Seal level.
	st = TableSetup.sandbox(t, 5)
	st.run_mode = true
	var lv := t.duplicate() as BonfireTuning
	var combos: Array[BonfireCombo] = []
	for c in t.combos:
		var cc := c.duplicate() as BonfireCombo
		if cc.id == &"trips":
			cc.base += 10
			cc.mult += 1
		combos.append(cc)
	lv.combos = combos
	st.tuning = lv
	s = await hints_table(st)
	tut = s.bhud.tutorial
	tut.seen = {&"hb3_bonus": 1}
	close_all(s)
	check(s.is_sealed(&"trips") and not s.is_sealed(&"pair"), "is_sealed: the leveled Trips only")
	await throw(s, [3, 3, 3, 2, 6] as Array[int])
	close_all(s)
	pick_faces(s, [3, 3, 3])
	close_all(s)
	s.throw_again()
	check(tut.current == &"hs2_sealed" and tut.label.text == "Your Seal boosts this combo: more base and more mult.", "HS2: first pot of a sealed combo (%s)" % tut.current)
	# The map / shop ones have their text for the run screens.
	for id: StringName in [&"hb1_bounties", &"hb2_cost", &"hb6_boss", &"hs3_stack", &"hs4_rare"]:
		check(BonfireTutorial.HINTS.has(id) and not tut.text_for(id, {"soul": 3}).contains("{"), "%s text defined: %s" % [id, tut.text_for(id, {"soul": 3})])
	check(tut.text_for(&"hb2_cost", {"soul": 6}) == "Each bounty still unclaimed at the end costs 6 Soul.", "HB2 uses the real cost")
	s.queue_free()
	await process_frame
