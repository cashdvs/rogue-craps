## Leave table follow-ups (QA review of #60):
##   - Blocker: on a cleared table, Pause > FORFEIT while a throw is in
##     flight (the dice have landed and show a bust, but it isn't applied
##     yet) used to end the table CLEARED with no Soul lost. FORFEIT is now
##     off from the throw until it resolves, so the bust's Soul is paid.
##   - Leave asks once (PM ruling): the first tap / L shows "LEAVE?  TAP
##     AGAIN"; a second within 2 s leaves; otherwise the text goes back.
##   godot --headless --path . --script res://tests/test_leave_forfeit_guard.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0
## Fake clock for the Leave confirm window (seconds).
var _now: float = 100.0


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


## A run-mode table whose only bounty is the Triple (easy to clear).
func _make_table() -> Bonfire3D:
	var t := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var setup := TableSetup.sandbox(t, 5)
	setup.run_mode = true
	var goal := t.table_goal.duplicate() as TableGoal
	goal.required = goal.required.slice(0, 1)
	goal.bonus = []
	setup.goal = goal
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = setup
	s.setup.nerve_uses = 0  # these checks expect a plain bust (no Nerve rescue pause)
	s.tutorial_override = 0
	s.test_speed = 10.0
	root.add_child(s)
	return s


func _throw(s: Bonfire3D, faces: Array[int]) -> void:
	s.rig_faces(faces)
	check(s.quick_throw(), "throw %s starts" % str(faces))
	await s.sequence_finished


## Bank 4-4-4 for the Triple: the table clears and stays open.
func _clear(s: Bonfire3D) -> void:
	await _throw(s, [4, 4, 4, 2, 6] as Array[int])
	s.pick_die(0)
	s.pick_die(1)
	s.pick_die(2)
	await s.bank()
	for k in 300:
		if s.phase == Table3D.Phase.BET and not s.bhud.countup.is_playing():
			break
		await process_frame
	await process_frame  # FORFEIT syncs on the next frame
	await process_frame


func _run() -> void:
	await _forfeit_mid_throw()
	await _leave_asks_once()
	print("test_leave_forfeit_guard: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _forfeit_mid_throw() -> void:
	var s := _make_table()
	await process_frame
	var r := s.run
	await _clear(s)
	check(r.cleared and not r.is_over(), "the table is cleared and still open")
	check(s.can_forfeit_now() and not s.pause_menu.forfeit_button.disabled, "between hands: FORFEIT is live")
	# Pot the 3s, then throw 2-4-6 again: a bust.
	await _throw(s, [3, 3, 4, 6, 6] as Array[int])
	s.pick_die(0)
	s.pick_die(1)
	var soul := r.soul
	var seen := {}
	# The moment the dice settle (the bust is visible, not applied yet),
	# try the pause menu's FORFEIT.
	s.dice_landed.connect(func(_v: Array[int]) -> void:
		seen["button_off"] = s.pause_menu.forfeit_button.disabled
		seen["forfeit"] = s.forfeit(), CONNECT_ONE_SHOT)
	# THROW AGAIN commits the pot and puts the 3 cold dice back in the hand;
	# then they're thrown (rigged 2-4-6).
	check(s.throw_again(), "THROW AGAIN: the 3 cold dice go back to the hand")
	for k in 300:
		if s.can_throw() == "" and not s.hand_moving():
			break
		await process_frame
	s.rig_faces([2, 4, 6] as Array[int])
	check(s.quick_throw(), "throw the 3 cold dice")
	# The cold dice hop back to the hand first, then fly.
	for k in 300:
		if s.phase != Table3D.Phase.BET:
			break
		await process_frame
	await process_frame
	check(not s.can_forfeit_now() and s.pause_menu.forfeit_button.disabled, "a throw in flight: FORFEIT greyed out")
	await s.sequence_finished
	check(seen.get("button_off", false) and seen.has("forfeit") and not seen["forfeit"], "dice landed on a bust: the FORFEIT button is off and forfeit() is refused")
	check(r.soul == soul - s.bonfire_tuning.bust_soul_loss and not r.forfeited, "the bust's Soul is paid (%d -> %d)" % [soul, r.soul])
	check(r.cleared, "the clear still stands after the bust")
	# The bust plays out (about a second), then a fresh hand.
	for k in 600:
		if s.phase == Table3D.Phase.BET and s.run.state == BonfireRun.State.AIM and not s.hand_moving():
			break
		await process_frame
	await process_frame
	check(s.can_forfeit_now() and not s.pause_menu.forfeit_button.disabled, "once the bust resolved: FORFEIT is live again")
	s.queue_free()
	await process_frame


func _leave_asks_once() -> void:
	var s := _make_table()
	await process_frame
	var r := s.run
	s.bhud.leave_clock = func() -> float: return _now
	await _clear(s)
	var btn := s.bhud.leave_button
	check(btn.visible and btn.text == BonfireHud.LEAVE_TEXT, "cleared: LEAVE TABLE shown")
	btn.pressed.emit()
	check(not r.is_over() and btn.text == BonfireHud.LEAVE_ASK_TEXT, "first tap asks: \"%s\"" % btn.text)
	_now += 2.5
	await process_frame
	check(not r.is_over() and btn.text == BonfireHud.LEAVE_TEXT, "no second tap in 2 s: the text goes back")
	btn.pressed.emit()
	_now += 2.5
	btn.pressed.emit()
	check(not r.is_over() and btn.text == BonfireHud.LEAVE_ASK_TEXT, "a second tap after the window only asks again")
	await process_frame
	_now += 3.0
	await process_frame
	# L asks, then a tap within the window leaves.
	var key := InputEventKey.new()
	key.keycode = KEY_L
	key.pressed = true
	s._unhandled_input(key)
	check(not r.is_over() and btn.text == BonfireHud.LEAVE_ASK_TEXT, "L asks too")
	_now += 1.0
	btn.pressed.emit()
	check(r.is_over() and r.state == BonfireRun.State.CLEARED and s.bhud.end_panel.visible, "a second press within 2 s leaves (table CLEARED)")
	s.queue_free()
	await process_frame
