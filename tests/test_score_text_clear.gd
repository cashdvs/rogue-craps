## Playtest (Oct 22): the score line under the Pot ("Not a combo yet." or an
## old "RUN OF 4: ... = 265") must not stick. It clears on rethrow, bank,
## hand end and a new table, stays empty during the count-up, and the old
## top-left controls text is hidden on the Bonfire table.
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
	check(not s.help_label.visible, "top-left controls text hidden")
	var h := s.bhud
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
	s._refresh_hud()
	check(h.throw_label.text.begins_with("TRIPS"), "preview shows (%s)" % h.throw_label.text)
	s.throw_again()
	check(not h.throw_label.text.begins_with("TRIPS"), "rethrow clears the preview (%s)" % h.throw_label.text)
	h.display_hold = {"pot_from": 0, "pot_add": 10, "f": 0.0}
	s._refresh_hud()
	check(h.throw_label.text == "", "empty during a count-up (%s)" % h.throw_label.text)
	h.display_hold = {}
	print("test_score_text_clear: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
