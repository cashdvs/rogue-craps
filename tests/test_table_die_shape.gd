## TableDie.shape (design/nonstandard_dice.md): the shape id, face counts,
## safe defaults for bad input, from_mod_ids(shape) and the way Systems Dev's
## RunProgress.table_dice() (PR #50) fills a shaped die.
##   godot --headless --path . --script res://tests/test_table_die_shape.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


func _mod(id: StringName) -> FaceModData:
	var m := FaceModData.new()
	m.id = id
	return m


func _initialize() -> void:
	# Default: a d6 Bone, exactly as before.
	var d := TableDie.new()
	check(d.shape == &"d6" and d.faces == [1, 2, 3, 4, 5, 6] and d.mods.size() == 6, "default is a d6 with 6 faces / mods")
	check("shape" in d, "`\"shape\" in td` is true (PR #50 sets it behind this check)")

	# Every shape: face count and default values (PR #50 convention).
	var want := {&"coin": [1, 5], &"d3": [1, 2, 3], &"d4": [1, 2, 3, 4], &"d6": [1, 2, 3, 4, 5, 6],
		&"d8": [1, 2, 3, 4, 5, 6, 7, 8], &"d10": range(1, 11), &"d12": range(1, 13), &"d20": range(1, 21)}
	for sh in want:
		var s := TableDie.new(&"x", "X", sh)
		check(s.shape == sh and s.faces == Array(want[sh]) and s.mods.size() == s.faces.size() and s.weights.is_empty(),
			"%s: faces %s, mods sized" % [sh, s.faces])
		check(s.face_count() == TableDie.faces_for_shape(sh), "%s face_count" % sh)
		var rng := RandomNumberGenerator.new()
		rng.seed = 3
		var seen := {}
		for i in 400:
			var slot := s.roll_slot(rng)
			seen[slot] = true
			if slot < 1 or slot > s.face_count():
				check(false, "%s rolled slot %d out of range" % [sh, slot])
				break
		check(seen.size() == s.face_count(), "%s rolls every slot 1..%d" % [sh, s.face_count()])

	# Bad shape ids fall back to d6 (with a warning), never a broken die.
	var bad := TableDie.new(&"x", "X", &"d7")
	check(bad.shape == &"d6" and bad.faces.size() == 6 and bad.mods.size() == 6, "unknown shape -> d6")
	var bad2 := TableDie.new()
	bad2.shape = &""
	check(bad2.shape == &"d6" and bad2.faces.size() == 6, "empty shape -> d6")
	check(not TableDie.is_valid_shape(&"d2") and TableDie.is_valid_shape(&"coin"), "is_valid_shape")
	check(TableDie.faces_for_shape(&"nope") == 6, "faces_for_shape(unknown) = 6")

	# from_mod_ids: the shape sizes faces / mods; extra ids are ignored.
	var lib := [_mod(&"hellfire"), _mod(&"wild")]
	var c := TableDie.from_mod_ids([&"hellfire", &"wild", &"wild"], lib, &"coin", "Coin", &"", &"coin")
	check(c.shape == &"coin" and c.faces == [1, 5] and c.mods.size() == 2, "from_mod_ids(coin) is 2-faced")
	check(c.mod_at(1).id == &"hellfire" and c.mod_at(2).id == &"wild" and c.mod_at(3) == null, "coin mods by slot; slot 3 = none")
	var b := TableDie.from_mod_ids([&"", &"", &"", &"", &"", &"wild"], lib)
	check(b.shape == &"d6" and b.mod_at(6).id == &"wild", "from_mod_ids without shape = d6 (old callers)")
	var d20 := TableDie.from_mod_ids([], lib, &"d20", "d20", &"", &"d20")
	check(d20.faces.size() == 20 and d20.mods.size() == 20 and d20.slot_for_value(20) == 20, "from_mod_ids(d20)")

	# PR #50 flow: faces copied in, mods resized and filled, then
	# td.set("shape", ...) last. The values the run sent must survive.
	var r := TableDie.from_mod_ids([&"", &""], lib, &"coin", "Coin")
	r.faces = [1, 5] as Array[int]
	r.weights = [] as Array[float]
	r.mods.resize(2)
	r.mods[1] = lib[1]
	r.set("shape", &"coin")
	check(r.shape == &"coin" and r.faces == [1, 5] and r.mods.size() == 2 and r.mod_at(2).id == &"wild", "PR #50 order keeps faces [1,5] and mods")
	var r3 := TableDie.from_mod_ids([], lib, &"d3", "d3")
	r3.faces = [1, 2, 3] as Array[int]
	r3.mods.resize(3)
	r3.set("shape", &"d3")
	check(r3.faces == [1, 2, 3] and r3.mods.size() == 3 and r3.value_at(3) == 3, "PR #50 d3 [1,2,3]")

	# Mismatched arrays are padded / trimmed to the shape on assignment.
	var m := TableDie.new()
	m.weights = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0] as Array[float]
	m.shape = &"d8"
	check(m.faces == [1, 2, 3, 4, 5, 6, 7, 8] and m.mods.size() == 8 and m.weights.is_empty(), "d6 -> d8 pads values, drops mismatched weights")
	var k := TableDie.new()
	k.faces = [4, 4, 4, 4, 4, 4] as Array[int]
	k.shape = &"coin"
	check(k.faces == [4, 4] and k.mods.size() == 2, "d6 -> coin trims to 2, keeps values")
	k.set_shape(&"coin")
	check(k.faces == [1, 5], "set_shape resets to defaults")

	print("test_table_die_shape: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
