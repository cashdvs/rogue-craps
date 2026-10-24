## Playtest (Oct 22): the score line under the Pot ("Not a combo yet." or an
## old "RUN OF 4: ... = 265") must not stick. It clears on rethrow, bank,
## hand end and a new table, and stays empty during the count-up. Also the
## AD spec Addendum A G1 (first-table controls text, "?" button and card)
## and G3 (the why-line hides when it repeats the prompt).
##   godot --headless --path . --script res://tests/test_score_text_clear.gd
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


func _run() -> void:
	var t := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var sv := SubViewport.new()
	sv.size = Vector2i(1920, 1080)
	root.add_child(sv)
	var st := TableSetup.sandbox(t, 5)
	st.table_seed = 5
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = st
	s.tutorial_override = 0
	s.test_speed = 10.0
	sv.add_child(s)
	await process_frame
	await process_frame
	var h := s.bhud
	var hc := s.help_corner
	# G1: the first table shows the controls text and the "?" button.
	check(s.help_label.visible, "first table shows the controls text")
	check(hc.button.size == Vector2(44, 44) and hc.button.text == "?", "44 px ? button")
	check(not hc.card.visible, "controls card starts closed")
	var f1 := InputEventKey.new()
	f1.keycode = KEY_F1
	f1.pressed = true
	s._unhandled_input(f1)
	check(hc.card.visible, "F1 opens the controls card")
	check(hc.card_text.text == s.help_label.text and hc.replay_button.text == "Replay tutorial", "card has the keys and Replay tutorial")
	hc.button.pressed.emit()
	check(not hc.card.visible, "? closes it again")
	check(not s.get_tree().paused, "the card doesn't pause")
	# G3: the deal's why-line repeats "Grab the 5 dice and flick them."
	check(HelpCorner.repeats_prompt("Grab the 5 dice and flick them. Dice that can score glow.", "Grab the 5 dice and flick them."), "repeat detected")
	check(not HelpCorner.repeats_prompt("4 lit. Click dice into the pot: one combo per throw.", "Click lit dice to pot one combo."), "lit count kept")
	check(not HelpCorner.repeats_prompt("Banked 120 points.", ""), "empty prompt never hides")
	check(not s.why_label.visible, "deal: why-line hidden (%s / %s)" % [s.why_label.text, h.throw_label.text])
	# clear_score_text empties all three lines.
	h.throw_label.text = "Not a combo yet."
	h.notes_label.text = "x"
	h.risk_label.text = "y"
	h.clear_score_text()
	check(h.throw_label.text == "" and h.notes_label.text == "" and h.risk_label.text == "", "clear_score_text empties the lines")
	# Pick a TRIPS, then rethrow: during the count-up the line is empty.
	s.rig_faces([3, 3, 3, 2, 4] as Array[int])
	s.quick_throw()
	await s.throw_resolved
	await s.sequence_finished
	s.pick_die(0)
	s.pick_die(1)
	s.pick_die(2)
	check(hc.get("_pot_timer") != null, "first pot starts the 30 s fade timer")
	s._refresh_hud()
	check(h.throw_label.text.begins_with("TRIPS"), "preview shows (%s)" % h.throw_label.text)
	s.throw_again()
	check(not h.throw_label.text.begins_with("TRIPS"), "rethrow clears the preview (%s)" % h.throw_label.text)
	h.display_hold = {"pot_from": 0, "pot_add": 10, "f": 0.0}
	s._refresh_hud()
	check(h.throw_label.text == "", "empty during a count-up (%s)" % h.throw_label.text)
	h.display_hold = {}
	# The rethrow cleared the last count-up; the new one must still show.
	await create_timer(0.4).timeout
	check(h.countup.row.modulate.a > 0.9, "rethrow count-up not hidden by clear (%.2f)" % h.countup.row.modulate.a)
	# G1: the first Bank fades the text out (0.4 s), and it stays gone.
	hc.dismissed = false
	s.help_label.visible = true
	s.help_label.modulate.a = 1.0
	hc.dismiss()
	await create_timer(0.6).timeout
	check(not s.help_label.visible, "dismiss fades the controls text")
	hc.start_table(s.help_label, false, false)
	check(not s.help_label.visible, "later tables: no controls text")
	# The card's link turns the Table 1 tutorial back on.
	var gs := root.get_node_or_null("GameSettings")
	if gs != null:
		gs.set_option(&"tutorial_enabled", false)
		hc.replay_tutorial()
		check(bool(gs.get("tutorial_enabled")), "Replay tutorial sets the flag")
	print("test_score_text_clear: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
