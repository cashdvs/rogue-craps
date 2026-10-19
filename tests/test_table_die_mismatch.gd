## Data mismatches between the run and the table must never SCRIPT ERROR
## (QA hit one per table when a 2-faced die reached the d6 mesh code): a
## TableDie whose faces / mods / weights don't match its shape, an unknown
## shape, and DieVisual labels of the wrong length are warned about and
## padded / trimmed. The table then plays several full throws.
##   godot --headless --path . --script res://tests/test_table_die_mismatch.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# DieVisual labels: short, long, out of range.
	check(DieVisual.safe_labels([1, 5]) == [1, 5, 3, 4, 5, 6], "2 labels padded with the slot numbers")
	check(DieVisual.safe_labels([1, 2, 3, 4, 5, 6, 7, 8]) == [1, 2, 3, 4, 5, 6], "8 labels trimmed to 6")
	check(DieVisual.safe_labels([0, 9, 2, 2, 3, 3]) == [1, 6, 2, 2, 3, 3], "labels clamped to 1..6")
	check(DieVisual.safe_labels([]) == [1, 2, 3, 4, 5, 6], "no labels -> 1..6")
	var dv := DieVisual.new()
	dv.set_look(Palette.BONE, Palette.PIT_BLACK, [1, 5] as Array[int])
	check(dv.labels == [1, 5, 3, 4, 5, 6], "set_look with 2 labels is safe")
	dv.free()
	# TableDie with arrays that don't fit.
	var a := TableDie.new()
	a.faces = [1, 5] as Array[int]  # 2 values on a d6 (PR #50 before TableDie.shape)
	a.mods = [null, null, null, null, null, null, null, null, null]
	a.weights = [1.0, 2.0, 3.0] as Array[float]
	var rng := RandomNumberGenerator.new()
	for i in 50:
		var sl := a.roll_slot(rng)
		if sl < 1 or sl > a.faces.size():
			check(false, "roll_slot in range on a mismatched die")
			break
	check(a.value_at(9) == 5 and a.mod_at(12) == null and a.value_at(0) == 1, "value_at / mod_at clamp")
	a.normalize()
	check(a.faces == [1, 5, 3, 4, 5, 6] and a.mods.size() == 6 and a.weights.is_empty(), "normalize pads faces, trims mods, drops bad weights")
	var e := TableDie.new()
	e.faces = [] as Array[int]
	check(e.value_at(3) == 3, "empty faces read as the slot")
	# A table built from mismatched dice plays full throws.
	var st := TableSetup.new()
	st.run_mode = false
	st.table_seed = 4
	var d1 := TableDie.new()
	d1.faces = [1, 5] as Array[int]
	d1.mods = [null]
	st.dice.append(d1)
	var d2 := TableDie.new(&"x", "X", &"coin")
	d2.faces = [1, 5, 6] as Array[int]  # one too many for a coin
	d2.special = &"ferryman"
	st.dice.append(d2)
	var d3 := TableDie.new()
	d3.set("shape", &"d9")  # unknown -> d6
	st.dice.append(d3)
	var d4 := TableDie.new()
	d4.faces = [1, 1, 2, 2, 3, 3, 3, 3] as Array[int]
	st.dice.append(d4)
	st.dice.append(TableDie.new())
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = st
	s.test_speed = 10.0
	root.add_child(s)
	await process_frame
	await process_frame
	s.run.hands_left = 100
	check(d2.faces.size() == 2 and d3.shape == &"d6" and d4.faces.size() == 6 and d1.mods.size() == 6, "the table normalized every die")
	var done := 0
	for t in 4:
		s.new_run(4 + t)
		for f in 60:
			await process_frame
			if s.phase == Table3D.Phase.BET and s.can_throw() == "":
				break
		if not s.quick_throw():
			check(false, "throw %d starts" % t)
			continue
		await s.sequence_finished
		done += 1 if s.last_values.size() == 5 else 0
	check(done >= 3, "mismatched dice play full throws (%d resolved)" % done)
	print("test_table_die_mismatch: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
