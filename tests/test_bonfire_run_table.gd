## The Bonfire table opened by the run: TableSetup (any number of dice with
## per-face values / weights / mods, goal, starting + max Soul, seed), mod
## decals, Hot Hand with 7 dice, run mode (no Restart / Quit to title,
## Forfeit table with confirm, finished(TableOutcome), no scene change), and
## the sandbox fallback.
##   godot --headless --path . --script res://tests/test_bonfire_run_table.gd
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


func throw_slots(s: Bonfire3D, slots: Array[int]) -> Array:
	s.rig_slots(slots)
	if not s.quick_throw():
		check(false, "throw %s starts" % str(slots))
		return []
	var res: Array = await s.throw_resolved
	await s.sequence_finished
	return res


func make_table(st: TableSetup) -> Bonfire3D:
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = st
	s.test_speed = 10.0
	root.add_child(s)
	await process_frame
	await process_frame
	return s


func _run() -> void:
	var H := load("res://resources/mods/hellfire.tres") as FaceModData
	var W := load("res://resources/mods/wild.tres") as FaceModData
	var T := load("res://resources/mods/twin.tres") as FaceModData
	var B := load("res://resources/mods/blank.tres") as FaceModData
	var lib: Array = [H, W, T, B]
	var tuning := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning

	# TableDie basics.
	var td := TableDie.from_mod_ids([&"hellfire", &"", &"wild", &"", &"twin", &"blank"], lib)
	check(td.mod_at(1) == H and td.mod_at(2) == null and td.mod_at(3) == W and td.mod_at(5) == T and td.mod_at(6) == B, "TableDie.from_mod_ids (RunDie.faces order)")
	var heavy := TableDie.new(&"loaded", "Loaded")
	heavy.weights = [0.0, 0.0, 0.0, 0.0, 0.0, 1.0]
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var all6 := true
	for k in 50:
		all6 = all6 and heavy.roll_slot(rng) == 6
	check(all6, "face weights drive the roll")

	# --- A 7-die run table ---
	var st := TableSetup.new()
	st.dice.append(TableDie.from_mod_ids([&"", &"", &"", &"hellfire", &"", &""], lib))  # 0: Hellfire 4
	st.dice.append(TableDie.from_mod_ids([&"", &"", &"", &"", &"", &"wild"], lib))      # 1: Wild on 6
	st.dice.append(TableDie.from_mod_ids([&"", &"twin", &"", &"", &"", &""], lib))      # 2: Twin 2
	st.dice.append(TableDie.from_mod_ids([&"blank", &"", &"", &"", &"", &""], lib))     # 3: Blank 1
	var odd := TableDie.new(&"odd", "Odd")
	odd.faces = [1, 1, 3, 3, 5, 5]
	st.dice.append(odd)                                                                  # 4: 1,1,3,3,5,5
	st.dice.append(TableDie.new())
	st.dice.append(TableDie.new())
	var goal := TableGoal.new()
	goal.display_name = "Test"
	goal.hands = 3
	goal.required = tuning.table_goal.required.duplicate()
	goal.clear_embers = 10
	goal.timeout_soul_per_bounty = 3
	st.goal = goal
	st.starting_soul = 20
	st.max_soul = 40
	st.table_seed = 11
	var s := await make_table(st)
	var r := s.run
	check(s.dice.size() == 7 and s.all_dice.size() == 7 and r.cold == 7 and r.dice_count == 7, "7 dice in the hand")
	check(r.soul == 20 and s.soul_meter.soul == 20 and s.soul_meter.soul_max == 40, "Soul 20 of max 40 on the meter")
	check(r.goal == goal and r.hands_left == 3, "the setup's goal")
	check(s.all_dice[4].labels == [1, 1, 3, 3, 5, 5], "custom face values show as pips")
	check(s.all_dice[0].faces.get_node_or_null("FaceMods") != null and s.all_dice[0].faces.get_node("FaceMods").get_child_count() == 4, "Hellfire rim on die 0")
	check(s.all_dice[2].faces.get_node("FaceMods").get_child_count() == 8, "Twin: double outline (8 strips)")
	check(s.all_dice[1].faces.get_node("FaceMods").get_child_count() == 4, "Wild: rainbow rim")
	check(s.all_dice[5].faces.get_node("FaceMods").get_child_count() == 0, "plain die: no decals")
	var felt := Table3DBuilder.FELT_HALF
	var ring_ok := true
	for i in 7:
		var p := s.hand_spot(i)
		ring_ok = ring_ok and absf(p.x) + s.tuning.die_size * 0.5 < felt.x and absf(p.z) + s.tuning.die_size * 0.5 < felt.y
	check(ring_ok, "7-die hand ring stays on the felt")
	check(s.bhud.continue_button.visible and not s.bhud.restart_button.visible, "run mode: CONTINUE, no RESTART")
	check(s.pause_menu.forfeit_button.visible and not s.pause_menu.quit_button.visible, "run mode: Forfeit table, no Quit to title")

	# Throw 1: slots -> Hellfire 4, Wild, Twin 2, Blank 1, odd slot 3 (=3), 4, 4.
	var res := await throw_slots(s, [4, 6, 2, 1, 3, 4, 4] as Array[int])
	check(res.size() == 2 and res[0] == [4, 6, 2, 1, 3, 4, 4], "values come from each die's face slots")
	check(r.throw_mods[0] == H and r.throw_mods[1] == W and r.throw_mods[2] == T and r.throw_mods[3] == B and r.throw_mods[4] == null, "mods ride with the throw")
	check(not (res[1] as Array).has(3), "the Blank 1 doesn't light")
	check((res[1] as Array).has(1) and (res[1] as Array).has(2), "the Wild and the Twin light")
	check(s.pick_die(0) and s.pick_die(5) and s.pick_die(6), "pot Hellfire 4 + 4 + 4")
	check(r.selection()["combo"] == &"trips" and r.throw_points() == 189, "Hellfire trips: 126 x1.5 = 189")
	check(not s.pick_die(3), "the Blank can't be potted")
	check(s.pick_die(1), "add the Wild (quads of 4s)")
	check(r.selection()["combo"] == &"quads", "Wild makes quads")
	check(s.throw_again(), "pot and gather the 3 cold dice")
	check(s.dice.size() == 3 and r.cold == 3, "3 cold dice left")
	res = await throw_slots(s, [2, 1, 5] as Array[int])  # Twin 2, Blank, odd slot 5 (=5)
	check(res[0] == [2, 1, 5] and res[1] == [0, 2], "Twin 2 and the 5 light, the Blank doesn't")
	check(s.pick_die(0), "pot the Twin 2")
	check(r.potted == [0] and r.selection()["combo"] == &"pair", "a Twin 2 alone pots as a pair")
	var bk: Dictionary = await s.bank()
	check(int(bk.get("gain", 0)) > 0 and r.hands_left == 2, "bank the hand")
	for k in 200:
		if s.phase == Table3D.Phase.BET and s.dice.size() == 7:
			break
		await process_frame

	# Hot Hand with 7 dice: five 4s, then the last two as a pair.
	res = await throw_slots(s, [4, 6, 4, 4, 1, 4, 4] as Array[int])
	for i in [0, 2, 3, 5, 6]:
		s.pick_die(i)
	check(r.selection()["combo"] == &"five_kind", "five 4s (one Hellfire) = five of a kind")
	check(not r.is_hot(), "5 of 7 potted isn't a Hot Hand")
	check(s.throw_again() and r.cold == 2, "2 cold dice")
	res = await throw_slots(s, [6, 5] as Array[int])  # Wild + odd 5
	s.pick_die(0)
	s.pick_die(1)
	check(r.selection()["combo"] == &"pair" and r.is_hot(), "Wild + 5 pair pots the last 2: Hot Hand with 7 dice")
	check(s.throw_again() and r.cold == 7 and s.dice.size() == 7 and r.hot_hands == 1, "Hot Hand scoops all 7 back")

	# Forfeit from the pause menu (confirm step), outcome, finished once.
	for k in 120:
		if s.phase == Table3D.Phase.BET and not r.is_over():
			break
		await process_frame
	var got: Array = []
	s.finished.connect(func(o: TableOutcome) -> void: got.append(o))
	var scene_before := current_scene
	s.pause_menu.open()
	check(paused, "pause menu pauses")
	s.pause_menu.ask_forfeit()
	check(s.pause_menu.confirm_panel.visible and not r.is_over(), "Forfeit asks to confirm first")
	s.pause_menu.cancel_forfeit()
	check(s.pause_menu.panel.visible and not r.is_over(), "Keep playing backs out")
	var unticked := r.unticked_required()
	var soul_now := r.soul
	s.pause_menu.ask_forfeit()
	s.pause_menu.confirm_forfeit()
	await process_frame
	check(not paused and r.is_over() and r.forfeited and r.state == BonfireRun.State.FAILED, "confirm forfeits the table")
	check(r.soul == soul_now - unticked * 3, "forfeit: -3 Soul per unticked required bounty")
	check(s.bhud.end_panel.visible and s.bhud.end_title.text == "TABLE FORFEITED", "end panel shows the forfeit")
	check(got.is_empty(), "finished waits for CONTINUE")
	s.bhud.continue_pressed.emit()
	check(got.size() == 1, "CONTINUE emits finished once")
	if got.size() == 1:
		var o: TableOutcome = got[0]
		check(not o.cleared and o.forfeited, "outcome: forfeited, not cleared")
		check(o.soul_after == r.soul and o.soul_delta == r.soul - 20, "outcome Soul delta from the starting Soul")
		check(o.points == r.points and o.embers == r.embers and o.embers == r.points / tuning.points_per_ember, "outcome points / Embers (no clear bonus)")
		check(o.hands_used == 3 - r.hands_left, "outcome hands used")
		check(o.bounties_claimed == r.claimed_bounties(), "outcome bounties")
	s.bhud.continue_pressed.emit()
	check(got.size() == 1 and s.finish() == null, "finished only fires once")
	check(current_scene == scene_before and s.is_inside_tree(), "the table never changes scenes")
	check(not s.forfeit(), "can't forfeit twice")
	s.queue_free()
	await process_frame

	# --- Cleared outcome (pure) ---
	var g0 := TableGoal.new()
	g0.hands = 2
	var r3 := BonfireRun.new(tuning, g0, 30, 5)
	r3.set_throw([5, 5, 5, 2, 3] as Array[int])
	r3.toggle(0)
	r3.toggle(1)
	r3.toggle(2)
	r3.bank()
	check(r3.cleared and not r3.is_over() and r3.leave(), "cleared: the table stays open until Leave")
	var o3 := TableOutcome.from_run(r3, 30)
	check(o3.cleared and not o3.forfeited and o3.soul_delta == 0 and o3.hands_used == 1, "cleared outcome")
	check(o3.points == r3.points and o3.embers == r3.points / tuning.points_per_ember + g0.clear_embers, "cleared outcome: Embers include the clear bonus")

	# --- Sandbox fallback (no setup) is unchanged ---
	var sb := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	sb.bonfire_seed = 5
	sb.test_speed = 10.0
	root.add_child(sb)
	await process_frame
	await process_frame
	check(sb.setup != null and not sb.is_run_mode() and sb.dice.size() == 5, "sandbox: 5 Bone dice")
	check(sb.run.goal == sb.bonfire_tuning.table_goal and sb.soul_meter.soul_max == sb.bonfire_tuning.starting_soul, "sandbox: Table 1, Soul 35")
	check(sb.bhud.restart_button.visible and not sb.bhud.continue_button.visible, "sandbox: RESTART")
	check(sb.pause_menu.quit_button.visible and not sb.pause_menu.forfeit_button.visible, "sandbox: Quit to title")
	sb.queue_free()
	await process_frame
	print("test_bonfire_run_table: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
