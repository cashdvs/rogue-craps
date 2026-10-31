## QA #160: after a hand moves on, the score line and the count-up row and
## banner ("TRIPS!" / "117") are gone, through the real flows: rethrow then
## the next throw, bank, forfeit and a new run. The first Bank also fades
## the first-table controls text (AD spec Addendum A, G1).
##   godot --headless --path . --script res://tests/test_countup_clear_flow.gd
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


## 3 dice by default, so potting the trips is a Hot Hand (the only rethrow).
func make_table(count: int = 3) -> Bonfire3D:
	var t := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var st := TableSetup.sandbox(t, count)
	st.table_seed = 5
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = st
	s.tutorial_override = 0
	s.test_speed = 10.0
	root.add_child(s)
	await process_frame
	await process_frame
	return s


## Throws these faces and pots the first [param pot] dice.
func throw_and_pot(s: Bonfire3D, faces: Array[int], pot: int) -> void:
	s.rig_faces(faces)
	s.quick_throw()
	await s.sequence_finished
	for i in pot:
		s.pick_die(i)


## Waits until the count-up is done and its fade has run.
func settle(s: Bonfire3D) -> void:
	for k in 600:
		if not s.bhud.countup.is_playing() and s.phase == Table3D.Phase.BET:
			break
		await process_frame
	await create_timer(0.4).timeout


## The three lines under the Pot, joined: preview | notes | risk.
func lines(s: Bonfire3D) -> String:
	return "%s|%s|%s" % [s.bhud.throw_label.text, s.bhud.notes_label.text, s.bhud.risk_label.text]


## Pots TRIPS and checks the old preview, notes and risk are showing, so the
## checks after rethrow / bank / leave / new run start from a stale line.
func pot_with_preview(s: Bonfire3D, what: String) -> void:
	await throw_and_pot(s, [3, 3, 3] as Array[int], 3)
	await process_frame
	check(s.bhud.throw_label.text.begins_with("TRIPS") and s.bhud.risk_label.text != "", "%s: preview and risk shown first (%s)" % [what, lines(s)])


func shown(s: Bonfire3D) -> bool:
	var c := s.bhud.countup
	return c.row.modulate.a > 0.05 or c.banner_panel.modulate.a > 0.05


func _run() -> void:
	await rethrow_flow()
	await bank_flow()
	await forfeit_flow()
	await new_run_flow()
	await hand_end_flow()
	await leave_flow()
	await still_counting_flow()
	print("test_countup_clear_flow: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func rethrow_flow() -> void:
	var s := await make_table()
	await pot_with_preview(s, "rethrow")
	check(s.throw_again(), "rethrow")
	# The same-frame HUD refresh rewrites all three lines (count-up playing).
	check(lines(s) == "||", "rethrow: no stale line under the Pot (%s)" % lines(s))
	await settle(s)
	# The next throw: picking it must not show the old TRIPS! / total.
	s.rig_faces([5, 2, 6] as Array[int])
	s.quick_throw()
	await s.sequence_finished
	await settle(s)
	check(not shown(s), "next throw: the old count-up row and banner are gone")
	check(not s.bhud.throw_label.text.begins_with("TRIPS"), "next throw: no old preview")
	s.queue_free()
	await process_frame


func bank_flow() -> void:
	var s := await make_table()
	check(s.help_label.visible, "first table: controls text shown")
	await pot_with_preview(s, "bank")
	s.bank()
	check(lines(s) == "||", "bank: no stale line under the Pot (%s)" % lines(s))
	await settle(s)
	check(not shown(s), "after the bank: count-up row and banner gone")
	check(s.help_corner.dismissed and not s.help_label.visible, "the first Bank fades the controls text")
	s.queue_free()
	await process_frame


func forfeit_flow() -> void:
	var s := await make_table()
	await throw_and_pot(s, [3, 3, 3] as Array[int], 3)
	s.throw_again()
	check(s.forfeit(), "forfeit mid-count-up")
	await create_timer(0.4).timeout
	check(not shown(s), "forfeit clears the count-up")
	check(s.bhud.throw_label.text == "", "forfeit: no score line")
	s.queue_free()
	await process_frame


func new_run_flow() -> void:
	var s := await make_table()
	await throw_and_pot(s, [3, 3, 3] as Array[int], 3)
	s.throw_again()
	s.new_run(7)
	check(s.bhud.throw_label.text.begins_with("Grab") and s.bhud.notes_label.text == "" and s.bhud.risk_label.text == "", "new run: no stale line under the Pot (%s)" % lines(s))
	await process_frame
	check(not shown(s), "new run clears the count-up at once")
	check(s.bhud.throw_label.text.begins_with("Grab"), "new run: only the deal prompt (%s)" % s.bhud.throw_label.text)
	s.queue_free()
	await process_frame


## Hand end: after a bank, the short pause before the next hand (RESET)
## shows no line under the Pot; _after_hand() clears it.
func hand_end_flow() -> void:
	var s := await make_table()
	await throw_and_pot(s, [3, 3, 3] as Array[int], 3)
	var during_reset: Array[String] = []
	var watch := func() -> void:
		if s.phase == Table3D.Phase.RESET:
			during_reset.append(s.bhud.throw_label.text + s.bhud.notes_label.text + s.bhud.risk_label.text)
	process_frame.connect(watch)
	await s.bank()
	process_frame.disconnect(watch)
	check(not during_reset.is_empty(), "hand end: the RESET pause was seen")
	check(during_reset.all(func(t: String) -> bool: return t == ""), "hand end: no line under the Pot between hands (saw %s)" % str(during_reset.filter(func(t: String) -> bool: return t != "").slice(0, 1)))
	s.queue_free()
	await process_frame


## Leave: clear the table, then Leave. Leave is only live between hands, so
## no real preview is up; the test writes old score lines into the labels
## and leave()'s HUD refresh must rewrite all three.
func leave_flow() -> void:
	var s := await make_table(5)
	for hand in [[[1, 2, 3, 6, 6], 3], [[4, 4, 4, 2, 6], 3], [[2, 2, 6, 6, 3], 4]]:
		for k in 600:
			if s.phase == Table3D.Phase.BET:
				break
			await process_frame
		await throw_and_pot(s, Array(hand[0], TYPE_INT, "", null), hand[1])
		await s.bank()
	for k in 600:
		if s.can_leave_now():
			break
		await process_frame
	check(s.can_leave_now(), "leave: table cleared, Leave is live")
	s.bhud.throw_label.text = "TRIPS: (30+9) x3 = 117"
	s.bhud.notes_label.text = "Hot Hand +1"
	s.bhud.risk_label.text = "Hot Hand, all 3 dice: 1 in 3 chance nothing lights"
	check(s.leave(), "leave")
	check(lines(s) == "||", "leave: no stale line under the Pot (%s)" % lines(s))
	s.queue_free()
	await process_frame


## The `thrown` hook (_clear_count_up_when_done) while the rethrow's
## count-up is still running: the count-up keeps going, and its row and
## banner fade only once it finishes (the `finished` one-shot).
## Note: a real Bonfire throw fast-forwards the count-up (fast_forward_juice)
## before it emits `thrown`, so this test emits `thrown` itself during a
## real count-up to reach that branch.
func still_counting_flow() -> void:
	var s := await make_table()
	await throw_and_pot(s, [3, 3, 3] as Array[int], 3)
	check(s.throw_again(), "still counting: rethrow")
	check(s.bhud.countup.is_playing(), "still counting: the rethrow's count-up runs")
	s.thrown.emit(1000.0)
	await process_frame
	check(s.bhud.countup.is_playing() and not s.bhud.countup.fast_forwarded, "still counting: the hook doesn't cut the count-up short")
	for k in 600:
		if not s.bhud.countup.is_playing():
			break
		await process_frame
	await create_timer(0.4).timeout
	check(not shown(s), "still counting: row and banner fade once it finishes")
	s.queue_free()
	await process_frame
