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


func make_table() -> Bonfire3D:
	var t := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var st := TableSetup.sandbox(t, 5)
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


func shown(s: Bonfire3D) -> bool:
	var c := s.bhud.countup
	return c.row.modulate.a > 0.05 or c.banner_panel.modulate.a > 0.05


func _run() -> void:
	await rethrow_flow()
	await bank_flow()
	await forfeit_flow()
	await new_run_flow()
	print("test_countup_clear_flow: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func rethrow_flow() -> void:
	var s := await make_table()
	await throw_and_pot(s, [3, 3, 3, 2, 4] as Array[int], 3)
	s._refresh_hud()
	check(s.bhud.throw_label.text.begins_with("TRIPS"), "TRIPS preview before the rethrow")
	check(s.throw_again(), "rethrow")
	check(s.bhud.throw_label.text == "", "rethrow clears the score line at once")
	await settle(s)
	# The next throw: picking it must not show the old TRIPS! / total.
	s.rig_faces([5, 2] as Array[int])
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
	await throw_and_pot(s, [3, 3, 3, 2, 4] as Array[int], 3)
	s.bank()
	check(s.bhud.throw_label.text == "", "bank clears the score line")
	await settle(s)
	check(not shown(s), "after the bank: count-up row and banner gone")
	check(s.help_corner.dismissed and not s.help_label.visible, "the first Bank fades the controls text")
	s.queue_free()
	await process_frame


func forfeit_flow() -> void:
	var s := await make_table()
	await throw_and_pot(s, [3, 3, 3, 2, 4] as Array[int], 3)
	s.throw_again()
	check(s.forfeit(), "forfeit mid-count-up")
	await create_timer(0.4).timeout
	check(not shown(s), "forfeit clears the count-up")
	check(s.bhud.throw_label.text == "", "forfeit: no score line")
	s.queue_free()
	await process_frame


func new_run_flow() -> void:
	var s := await make_table()
	await throw_and_pot(s, [3, 3, 3, 2, 4] as Array[int], 3)
	s.throw_again()
	s.new_run(7)
	await process_frame
	check(not shown(s), "new run clears the count-up at once")
	check(s.bhud.throw_label.text.begins_with("Grab"), "new run: only the deal prompt (%s)" % s.bhud.throw_label.text)
	s.queue_free()
	await process_frame
