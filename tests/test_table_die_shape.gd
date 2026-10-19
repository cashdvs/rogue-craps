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
		&"d8": [1, 2, 3, 4, 5, 6, 7, 8], &"d10": range(1, 11), &"d12": range(1, 13), &"d20": range(1, 21), &"talus": [1, 3, 4, 6]}
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

	# Caltrop d4: read from the vertex that points up.
	var vert_ok := true
	for vk in range(1, 5):
		vert_ok = vert_ok and PolyDie.up_slot(&"d4", PolyDie.remap_basis(&"d4", Basis.IDENTITY, vk)) == vk
		vert_ok = vert_ok and PolyDie.up_slot(&"d4", Basis(Vector3.UP, 1.3) * PolyDie.remap_basis(&"d4", Basis.IDENTITY, vk)) == vk
	check(vert_ok, "d4: the vertex pointing up is the slot read (any spin about vertical)")
	var tilted := Basis(Vector3.RIGHT, deg_to_rad(10)) * PolyDie.remap_basis(&"d4", Basis.IDENTITY, 3)
	check(PolyDie.up_slot(&"d4", tilted) == 3, "d4: a slightly tilted landing still reads its top vertex")
	# Knucklebone = talus (4 resting faces), read from the top face.
	var kb := TableDie.new(&"knucklebone", "Knucklebone", &"talus")
	kb.special = &"knucklebone"
	check(kb.faces == [1, 3, 4, 6] and PolyDie.body_shape_for(kb) == &"talus", "talus: faces 1, 3, 4, 6; its own body")
	check(PolyDie.values(&"talus") == [1, 3, 4, 6] and PolyDie.read_mode(&"talus") == &"face" and PolyDie.read_mode(&"d4") == &"vertex", "talus reads its top face; the d4 its top vertex")
	var talus_ok := true
	for ts in range(1, 5):
		var tb := PolyDie.remap_basis(&"talus", Basis.IDENTITY, ts)
		talus_ok = talus_ok and PolyDie.up_slot(&"talus", tb) == ts
	check(talus_ok, "talus: each face slot read back after a remap")
	var keg := TableDie.new(&"powder_keg", "Powder Keg")
	keg.faces = [1, 1, 2, 2, 3, 3] as Array[int]
	check(keg.shape == &"d6" and PolyDie.body_shape_for(keg) == &"keg", "Powder Keg: d6 data, barrel body")
	var keg_ok := PolyDie.values(&"keg") == [1, 1, 2, 2, 3, 3]
	for ks in range(1, 7):
		keg_ok = keg_ok and PolyDie.up_slot(&"keg", PolyDie.remap_basis(&"keg", Basis.IDENTITY, ks)) == ks and keg.value_at(ks) == PolyDie.values(&"keg")[ks - 1]
	check(keg_ok, "Powder Keg: the stave pointing up is the slot read (6 staves -> slots 1-6, values 1-2-3 x2)")

	# Independent face read (QA #61): every slot, turned up by the remap, must
	# show its printed value by the 3D Artist's labelled directions in
	# batch3_faces.json (not DieHullData, which is generated from them).
	var art: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/models/dice/batch3_faces.json"))
	var keys := {&"d4": "caltrop_d4", &"d8": "lantern_d8", &"d10": "tithe_d10", &"d12": "midnight_d12",
		&"d20": "verdict_d20", &"talus": "knucklebone_talus", &"keg": "powder_keg_d6"}
	for sh: StringName in keys:
		var printed: Array = [1, 1, 2, 2, 3, 3] if sh == &"keg" else Array(TableDie.default_values(sh))
		var art_ok := true
		for slot_k in range(1, printed.size() + 1):
			for yaw in [0.0, 1.1, 2.7]:
				var pose := PolyDie.remap_basis(sh, Basis(Vector3.UP, yaw) * Basis(Vector3(1, 0.3, 0.2).normalized(), 0.8), slot_k)
				var up := pose.orthonormalized().inverse() * Vector3.UP
				var best := -2.0
				var val := -1
				for e: Array in (art[keys[sh]] as Dictionary)["dirs"]:
					var art_dir := Vector3(e[1][0], e[1][1], e[1][2]).normalized()
					if art_dir.dot(up) > best:
						best = art_dir.dot(up)
						val = int(e[0])
				art_ok = art_ok and val == int(printed[slot_k - 1])
		check(art_ok, "%s: each slot turned up shows its printed value by batch3_faces.json" % sh)

	print("test_table_die_shape: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
