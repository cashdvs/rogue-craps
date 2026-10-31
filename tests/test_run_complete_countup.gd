## Headless tests for RunCompleteCountup (scripts/fx/run_complete_countup.gd):
## final values, Embers line before Final score, reduced motion, skip, colour.
##
## Run:
##   godot --headless --path . --script res://tests/test_run_complete_countup.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	print("=== Dice of the Damned: run complete count-up tests ===")
	_test_final_values()
	_test_order()
	_test_reduced_motion()
	_test_skip()
	_test_hook()
	_test_attach_real_run()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _make(reduced: bool) -> Array:
	var e := Label.new()
	var t := Label.new()
	var c := RunCompleteCountup.new()
	root.add_child(c)
	c.set_process(false)
	c.setup(e, t, 7, 10, 70, 1234, 1304, reduced)
	return [c, e, t]


func _test_final_values() -> void:
	var r := _make(false)
	var c: RunCompleteCountup = r[0]
	_check(r[1].text == "Embers left: 0 x10 = +0" and r[2].text == "Final score: 1234", "start: Embers 0, Final = points banked")
	_check(r[1].get_theme_color("font_color") == Palette.EMBER and r[2].get_theme_color("font_color") == Palette.EMBER, "colour: both lines Ember #E8622A")
	_check(Palette.EMBER == Color("#E8622A"), "colour: Palette.EMBER is #E8622A")
	_check(c.duration() <= 2.0, "short: whole count-up <= 2 s")
	var steps := 0
	while not c.done and steps < 1000:
		c.advance(1.0 / 60.0)
		steps += 1
	_check(c.done and r[1].text == "Embers left: 7 x10 = +70" and r[2].text == "Final score: 1304", "end: Embers 7 x10 = +70, Final 1304")
	c.queue_free()


func _test_order() -> void:
	var r := _make(false)
	var c: RunCompleteCountup = r[0]
	var embers_done_at := -1.0
	var total_moved_at := -1.0
	var mono := true
	var last := [0, 1234]
	while not c.done:
		c.advance(1.0 / 60.0)
		var now := [c.shown_embers(), c.shown_total()]
		mono = mono and now[0] >= last[0] and now[1] >= last[1]
		last = now
		if embers_done_at < 0.0 and now[0] == 7:
			embers_done_at = c.elapsed
		if total_moved_at < 0.0 and now[1] > 1234:
			total_moved_at = c.elapsed
	_check(embers_done_at > 0.0 and total_moved_at > embers_done_at, "order: Embers line lands before Final score moves")
	_check(mono, "order: both values only count up")
	c.queue_free()


func _test_reduced_motion() -> void:
	var r := _make(true)
	var c: RunCompleteCountup = r[0]
	_check(c.done and c.duration() == 0.0, "reduced motion: done at once, 0 s")
	_check(r[1].text == "Embers left: 7 x10 = +70" and r[2].text == "Final score: 1304", "reduced motion: final values straight away")
	c.queue_free()


func _test_skip() -> void:
	var r := _make(false)
	var c: RunCompleteCountup = r[0]
	var fired := [0]
	c.finished.connect(func() -> void: fired[0] += 1)
	c.advance(0.3)
	var tap := InputEventScreenTouch.new()
	tap.pressed = true
	c._input(tap)
	_check(c.done and r[2].text == "Final score: 1304" and r[1].text == "Embers left: 7 x10 = +70", "skip: a tap jumps to the final values")
	c.finish()
	_check(fired[0] == 1, "skip: finished fires once")
	var r2 := _make(false)
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_SPACE
	r2[0]._input(key)
	_check(r2[0].done, "skip: a key press finishes too")
	c.queue_free()
	r2[0].queue_free()


func _test_hook() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/map/run_screen.gd")
	_check(src.contains("RunCompleteCountup.attach(_panel_box, run, _panel_box.get_child(3), _panel_box.get_child(4))"), "hook: RunScreen attaches the count-up on RUN COMPLETE")
	var lines := ["Points banked: 1", "Embers left: 7 x10 = +70", "Final score: 71"]
	_check(RunSummary.embers_line(7, 70, 10) == lines[1], "hook: Embers row text matches RunSummary")


func _test_attach_real_run() -> void:
	var shared := load("res://resources/map/bonfire_run.tres") as RunData
	var data := shared.duplicate() as RunData
	data.ember_score_mult = 7
	var run := MapRun.new(data, 4242)
	run.progress.embers = 9
	run.run_points = 777
	var e := Label.new()
	var t := Label.new()
	var c := RunCompleteCountup.attach(root, run, e, t, false)
	c.set_process(false)
	_check(c.final_total == RunSummary.final_score(run) and c.ember_pts == RunSummary.ember_points(run), "attach: targets come from RunSummary")
	while not c.done:
		c.advance(1.0 / 60.0)
	_check(t.text == RunSummary.text("run_complete_total", {"n": RunSummary.final_score(run)}), "attach: real MapRun ends on RunSummary.final_score")
	_check(e.text == "Embers left: 9 x%d = +%d" % [run.data.ember_score_mult, RunSummary.ember_points(run)], "attach: rendered Embers line is 'Embers left: 9 x{mult} = +{pts}'")
	_check(e.text == RunSummary.complete_lines(run)[1], "attach: Embers line ends on RunSummary's row")
	_check(e.text.contains("x7") and e.text.contains("+63"), "attach: mult 7 shows x7 and +63 (9 Embers x 7)")
	_check(c.final_total == 777 + 63 and t.text == "Final score: 840", "attach: Final score includes the +63")
	_check(shared.ember_score_mult == 10, "attach: shared bonfire_run.tres data not mutated")
	c.queue_free()


func _check(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		print("  FAIL  ", label)
