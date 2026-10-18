## Headless scene test for the Burn Line sandbox (scenes/burn_line.tscn):
## real RigidBody3D throws of one die with rigged faces, Stop, a burn, the
## Knucklebone's Cramped greying, the Exact Hit lock, Change dice, and the
## table-clear screen into table 2.
##   godot --headless --path . --script res://tests/test_burn_line_scene.gd
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


func _throw_slot(s: BurnLine3D, slot: int) -> Array:
	s.rig_next_slot(slot)
	if not s.quick_throw():
		return []
	var landed: Array = await s.dice_landed
	check(s.dice[0].shown_value() == s.current_die().faces[slot - 1] or s.run.state != BurnLineRun.State.HAND, "die shows face slot %d" % slot)
	await s.sequence_finished
	return landed


func _run() -> void:
	var s := (load("res://scenes/burn_line.tscn") as PackedScene).instantiate() as BurnLine3D
	s.burn_seed = 7
	s.test_speed = 10.0
	root.add_child(s)
	await process_frame
	await process_frame
	var r := s.run
	check(r.table().line == 15 and r.coin + r.bet == 20 and r.bet == 5, "T1: Line 15, 20 coin, 5 auto-bet (%d/%d)" % [r.coin, r.bet])
	check(r.loadout.size() == 2 and r.loadout[0].id == &"bone" and r.loadout[1].id == &"knucklebone", "Standard loadout pre-selected")
	check(s.target_label3d.text == "15", "far-rail plate shows the Line")
	check(s.burn_hud.stop_button.disabled, "Stop disabled before the first throw")
	check((await s.stop_hand()).is_empty(), "can't Stop with nothing thrown")

	# Hand 1: 6 + 6 (Bone) + 3 (Knucklebone) = 15 exact.
	await _throw_slot(s, 6)
	check(r.total == 6 and s.burn_hud.total_label.text == "6", "first throw totals 6")
	check(not s.burn_hud.stop_button.disabled, "Stop enabled after a throw")
	check(s.burn_hud.side_button.disabled, "Exact Hit locked after the first throw")
	await _throw_slot(s, 6)
	s.select_die(1)
	check(s.current_die().id == &"knucklebone", "die button 2 selects the Knucklebone")
	await _throw_slot(s, 5)
	check(r.total == 15, "Knucklebone slot 5 adds 3 (total %d)" % r.total)
	check(r.can_throw(r.loadout[1]) != "" and s.burn_hud.die_buttons[1].disabled, "Cramped: Knucklebone greyed after one throw")
	check(s.current_die().id == &"bone", "used-up die swaps back to Bone")
	var res: Dictionary = await s.stop_hand()
	check(res.get("kind") == &"exact" and int(res["returned"]) == 10, "exact stop returns 2x (%s)" % str(res))
	check(r.coin + r.bet == 25 and r.hands_left == 7, "coin 25 after the exact (%d+%d)" % [r.coin, r.bet])
	check(not s.burn_hud.die_buttons[1].disabled, "Knucklebone available again next hand")

	# Hand 2: Exact Hit on, then 6+6+4 = 16 burns.
	s.set_side_bet(true)
	check(r.side_bet, "Exact Hit toggles on before the first throw")
	await _throw_slot(s, 6)
	s.set_side_bet(false)
	check(r.side_bet, "Exact Hit can't be turned off after a throw")
	await _throw_slot(s, 6)
	var soul_before := r.soul
	var results: Array = []
	s.hand_result_shown.connect(func(x: Dictionary) -> void: results.append(x))
	await _throw_slot(s, 4)
	check(results.size() == 1 and results[0]["kind"] == &"burn", "16 burns automatically")
	check(r.soul == soul_before - 2 and s.soul_meter.value == r.soul if "value" in s.soul_meter else r.soul == soul_before - 2, "burn costs 2 Soul (%d)" % r.soul)
	check(int(results[0]["side_returned"]) == 0, "Exact Hit lost on a burn")
	check(r.total == 0 and r.hands_left == 6 and s.phase == Table3D.Phase.BET, "next hand ready after the burn")

	# Change dice: Bone + Leadfoot.
	var ids: Array[StringName] = [&"bone", &"leadfoot"]
	s._on_loadout_chosen(ids)
	check(r.loadout[1].id == &"leadfoot", "Change dice swaps in the Leadfoot")
	s.select_die(1)
	check(s.dice[0].material == "iron", "Leadfoot looks/sounds heavy")
	# Stop at 6 with a bigger coin pile so this exact clears the table.
	await _throw_slot(s, 6)
	await _throw_slot(s, 6)
	s.select_die(0)
	await _throw_slot(s, 3)
	r.coin += 40
	var states: Array = []
	s.run_state_shown.connect(func(st: BurnLineRun.State) -> void: states.append(st))
	res = await s.stop_hand()
	check(res.get("kind") == &"exact", "exact with Bone as the last die")
	check(states == [BurnLineRun.State.TABLE_CLEARED] and s.burn_hud.end_panel.visible, "table-cleared screen shows")
	var soul := r.soul
	s._on_end_action(&"next")
	check(r.table_index == 1 and r.line() == 16 and r.coin + r.bet == 20 and r.soul == soul, "Next table: Line 16, coin resets, Soul carries")
	check(s.target_label3d.text == "16" and not s.burn_hud.end_panel.visible, "plate shows the new Line")
	s.queue_free()
	await process_frame
	print("test_burn_line_scene: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
