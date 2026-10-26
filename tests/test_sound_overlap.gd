## Playtest sound fixes (Sound Designer, Oct 24):
##  1. dice_shake (0.45 s) replayed every 0.22 s while held must not stack:
##     SfxManager.play_alone stops the last copy first.
##  2. The 2D table's impact sounds use the 3D per-die rate limit.
##  (3. The crowd-stop checks went with the ambience bed, Oct 25: see
##  tests/test_no_ambience.gd.)
##   godot --headless --path . --script res://tests/test_sound_overlap.gd
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


func copies(sfx: SfxManager, event: StringName) -> int:
	var n := 0
	for c in sfx.get_children():
		if c is AudioStreamPlayer and c.playing and c.get_meta(&"event", &"") == event:
			n += 1
	return n


func _run() -> void:
	await shake_test()
	await impact_test()
	print("test_sound_overlap: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func shake_test() -> void:
	var sfx := SfxManager.new()
	root.add_child(sfx)
	await process_frame
	sfx.play(&"dice_shake")
	sfx.play(&"dice_shake")
	check(copies(sfx, &"dice_shake") == 2, "plain play stacks (%d)" % copies(sfx, &"dice_shake"))
	sfx.play_alone(&"dice_shake")
	check(copies(sfx, &"dice_shake") == 1, "play_alone leaves one copy (%d)" % copies(sfx, &"dice_shake"))
	for k in 5:
		sfx.play_alone(&"dice_shake", 1.0, -8.0)
	check(copies(sfx, &"dice_shake") == 1, "five rattle ticks: still one copy")
	sfx.play(&"chip_place")
	sfx.play_alone(&"dice_shake")
	check(copies(sfx, &"chip_place") == 1, "other sounds keep playing")
	check(sfx.stop_event(&"dice_shake") == 1 and copies(sfx, &"dice_shake") == 0, "stop_event stops it")
	# The 3D and 2D tables both use play_alone for the held rattle.
	for path in ["res://scripts/table3d/table_3d.gd", "res://scripts/table/table_scene.gd"]:
		var src := FileAccess.get_file_as_string(path)
		check(src.contains("sfx.play_alone(&\"dice_shake\"") and not src.contains("sfx.play(&\"dice_shake\""), "%s: held rattle uses play_alone" % path)
	sfx.queue_free()


func impact_test() -> void:
	var sfx := SfxManager.new()
	root.add_child(sfx)
	await process_frame
	sfx.impact_clock = 10.0
	check(sfx.impact_allowed(7), "first hit sounds")
	check(not sfx.impact_allowed(7), "same die, same moment: throttled")
	check(sfx.impact_allowed(8), "another die is not")
	sfx.impact_clock = 10.0 + ThrowSynth.IMPACT_MIN_GAP_S + 0.001
	check(sfx.impact_allowed(7), "after the gap it sounds again")
	# 2D table: two impacts of one die at once make one dice_hit.
	var t := (load("res://scenes/table.tscn") as PackedScene).instantiate()
	root.add_child(t)
	await process_frame
	var hits := [0]
	t.sfx.played.connect(func(e: StringName) -> void:
		if e == &"dice_hit":
			hits[0] += 1)
	t.sfx.impact_clock = 50.0
	var d: DieView = t._dice[0]
	t._on_die_impact(d, 0.4)
	t._on_die_impact(d, 0.4)
	check(hits[0] == 1, "2D: one die chattering makes one sound (%d)" % hits[0])
	t._on_die_impact(t._dice[1], 0.4)
	check(hits[0] == 2, "2D: a second die still sounds")
	t.queue_free()
	sfx.queue_free()
	await process_frame
