## Headless tests for the run state outside the table (build content v0.3):
## RunProgress Soul / Embers / handful, face mods per die face (Blank is a
## curse, not a carving), Seal levels feeding a leveled BonfireTuning copy,
## Game Designer prices (escalating mods, die sell value), the rare Seals
## (Transference, Black, Ashen) and contract pieces.
##
## Run:
##   godot --headless --path . --script res://tests/test_run_progress.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0
var _run: RunData


func _initialize() -> void:
	print("=== Dice of the Damned: run progress tests ===")
	_run = load("res://resources/map/bonfire_run.tres") as RunData
	_test_basics()
	_test_face_mods()
	_test_seals()
	_test_prices()
	_test_rare_seals()
	_test_contract()
	_test_table_dice()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	_run = null
	quit(1 if _failed > 0 else 0)


func _check(condition: bool, name: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", name)


func _test_basics() -> void:
	var p := RunProgress.new(_run)
	_check(p.soul == 35 and p.max_soul == 35 and p.embers == 0 and p.dice.size() == 5, "start: Soul 35/35, 0 Embers, 5 dice")
	_check(p.change_soul(5) == 0 and p.change_soul(-10) == -10 and p.soul == 25, "soul: clamped to max")
	_check(p.change_embers(-3) == 0 and p.change_embers(7) == 7, "embers: never below 0")
	_check(p.add_die(&"coven") and p.add_die(&"extra") and not p.add_die(&"mirror") and p.dice.size() == 7, "dice: max 7")
	var ended: Array[bool] = [false]
	p.run_ended.connect(func() -> void: ended[0] = true)
	_check(p.change_soul(-99) == -25 and p.is_over() and ended[0], "soul: 0 ends the run")


func _test_face_mods() -> void:
	var hell: FaceModData = load("res://resources/mods/hellfire.tres")
	var blank: FaceModData = load("res://resources/mods/blank.tres")
	var wild: FaceModData = load("res://resources/mods/wild.tres")
	var twin: FaceModData = load("res://resources/mods/twin.tres")
	_check(hell.mult_factor == 1.5 and wild.effect == FaceModData.Effect.WILD and twin.effect == FaceModData.Effect.TWIN
		and blank.effect == FaceModData.Effect.BLANK and blank.is_curse, "mods: Hellfire x1.5, Wild, Twin, Blank (curse)")
	var p := RunProgress.new(_run)
	_check(not p.has_face_mod() and p.dice[0].free_faces().size() == 6, "mods: none at the start")
	p.set_face(0, 0, RunDie.BLANK)
	_check(not p.has_face_mod(), "mods: a Blank face isn't a carving")
	p.set_face(2, 3, &"wild")
	_check(p.modded_faces().size() == 1 and p.modded_faces()[0] == Vector2i(2, 3) and p.dice[2].free_faces().size() == 5, "mods: carved face tracked")
	_check(not p.set_face(9, 0, &"wild") and not p.set_face(0, 6, &"wild"), "mods: out-of-range faces refused")


func _test_seals() -> void:
	var base: BonfireTuning = load("res://resources/tuning/bonfire_tuning.tres")
	var p := RunProgress.new(_run)
	p.add_seal_levels(&"trips", 2)
	p.add_seal_levels(&"pair", 1)
	p.soul = 20
	var t := p.leveled_tuning(base)
	var ok: bool = true
	for i in base.combos.size():
		var c := base.combos[i]
		var lv := p.seal_level(c.id)
		ok = ok and t.combos[i].base == c.base + lv * int(_run.seal_base_step.get(c.id, 0)) \
			and t.combos[i].mult == c.mult + lv * int(_run.seal_mult_step.get(c.id, 0))
	_check(ok and p.seal_level(&"trips") == 2, "seals: levels add base/mult per the build-content steps")
	var trips_ok: bool = false
	for i in base.combos.size():
		if base.combos[i].id == &"trips":
			trips_ok = t.combos[i].base == base.combos[i].base + 30 and t.combos[i].mult == base.combos[i].mult + 2
	_check(trips_ok, "seals: Trips Lv2 = +30 base / +2 mult")
	_check(t.starting_soul == 20 and base.starting_soul == 35, "seals: the table copy starts at the run's Soul; shipped tuning untouched")


func _price(id: String) -> int:
	return (load("res://resources/mods/%s.tres" % id) as FaceModData).price


func _test_prices() -> void:
	var ok: bool = true
	for pair in [["ember_pip", 6], ["gilded", 6], ["heavy", 6], ["step", 6], ["kindling", 6], ["blood", 6],
			["wild", 9], ["twin", 9], ["stair", 9], ["hellfire", 14]]:
		ok = ok and _price(pair[0]) == pair[1]
	_check(ok and _run.face_mods.size() == 10, "prices: 10 face mods at 6 / 9 / 14")
	var dice_ok: bool = true
	var prices: Dictionary = {}
	for d in _run.special_dice:
		prices[d.id] = d.price
	for pair in [[&"extra", 12], [&"mirror", 12], [&"cracked", 12], [&"twin_flame", 18], [&"wanderer", 18],
			[&"bellows", 18], [&"blood_pact", 18], [&"coven", 24], [&"last_breath", 24]]:
		dice_ok = dice_ok and prices.get(pair[0], -1) == pair[1]
	_check(dice_ok and _run.special_dice.size() == 9, "prices: 9 special dice at 12 / 18 / 24")
	var p := RunProgress.new(_run)
	var hell: FaceModData = load("res://resources/mods/hellfire.tres")
	_check(p.mod_price(hell, 0) == 14, "prices: Hellfire 14 on a fresh die")
	p.set_face(0, 0, &"wild")
	_check(p.mod_price(hell, 0) == 21, "prices: +50% with one mod on the die")
	p.set_face(0, 1, &"twin")
	p.set_face(0, 2, RunDie.BLANK)
	_check(p.mod_price(hell, 0) == 28 and p.mod_price(hell, 1) == 14, "prices: +100% with two (Blank doesn't count), per die")
	p.add_die(&"coven")
	_check(p.sell_value(5) == 12 and p.sell_value(0) == 0, "sell: special die for half its price; plain dice 0")
	_check(p.sell_die(5) == 12 and p.embers == 12 and p.dice.size() == 5 and p.sell_die(0) == -1, "sell: never below 5 dice")


func _test_rare_seals() -> void:
	var p := RunProgress.new(_run)
	_check(p.transference(&"pair", &"trips", 2) == 0, "transference: nothing above the start to move")
	p.add_seal_levels(&"pair", 3)
	_check(p.transference(&"pair", &"trips", 5) == 2, "transference: moves at most 2 mult")
	_check(p.seal_bonus(&"pair") == Vector2i(5, 1) and p.seal_bonus(&"trips") == Vector2i(10, 2), "transference: Pair -10/-2, Trips +10/+2")
	_check(p.transference(&"pair", &"trips", 2) == 1 and p.seal_bonus(&"pair") == Vector2i.ZERO, "transference: never below the starting values")
	_check(not p.black_seal(), "black: nothing banked -> refused")
	p.record_bank(&"pair")
	p.record_bank(&"run3")
	p.record_bank(&"run3")
	_check(p.most_banked() == &"run3" and p.black_seal() and p.seal_level(&"run3") == 1, "black: +1 level to the most-banked combo")
	p.add_seal_levels(&"two_pair", 2)
	_check(p.ashen_seal(&"two_pair", &"pair") == 0, "ashen: can't move to a commoner combo")
	_check(p.ashen_seal(&"two_pair", &"full_house") == 2 and p.seal_level(&"two_pair") == 0 and p.seal_level(&"full_house") == 2,
		"ashen: reset to Lv1, levels move to a rarer combo")


func _test_contract() -> void:
	var p := RunProgress.new(_run)
	p.soul = 10
	p.gain_contract_piece()
	_check(p.contract_pieces == 1 and p.max_soul == 40 and p.soul == 40, "contract: +5 max Soul and heal to full")


func _test_table_dice() -> void:
	var p := RunProgress.new(_run)
	p.set_face(0, 3, &"hellfire")
	p.set_face(1, 0, RunDie.BLANK)
	p.add_die(&"cracked")
	var td := p.table_dice()
	_check(td.size() == 6 and td[0].mod_at(4) != null and td[0].mod_at(4).id == &"hellfire" and td[0].mod_at(1) == null,
		"table dice: per-face mods ride on TableDie (RunDie face i = slot i+1)")
	_check(td[1].mod_at(1) != null and td[1].mod_at(1).effect == FaceModData.Effect.BLANK, "table dice: Blank faces too")
	_check(td[5].special == &"cracked" and td[2].special == &"" and td[5].run_die_id == p.dice[5].id and td[0].run_die_id == &"bone_0",
		"table dice: special kind and run die id on every TableDie")
	_check(td[5].id == &"cracked" and td[5].faces == ([1, 2, 3, 4, 5, 6] as Array[int]) and td[2].id == &"bone",
		"table dice: special die id and faces from its data")
	var all_defined := true
	for d in _run.special_dice:
		all_defined = all_defined and d.faces == ([1, 2, 3, 4, 5, 6] as Array[int]) and d.weights.is_empty()
	_check(_run.special_dice.size() == 9 and all_defined, "special dice: plain Bone 1-6, equal weights (GD spec)")
	var q := RunProgress.new(_run)
	q.add_die(&"cracked")
	q.add_die(&"cracked")
	var ids: Array[StringName] = []
	for d in q.dice:
		ids.append(d.id)
	_check(ids.size() == 7 and ids[5] == &"cracked_5" and ids[6] == &"cracked_6" and ids[0] == &"bone_0" and not ids.slice(1).has(ids[0]),
		"run dice: unique ids (two Cracked dice told apart)")
	q.set_face(5, 2, &"hellfire")
	_check(q.remove_dice([&"cracked_5", &"nope"]) == 1 and q.dice.size() == 6 and q.die_index(&"cracked_6") == 5
		and q.modded_faces().is_empty(), "remove_dice: only that die goes, with its mods")
	_check(q.remove_dice([&"cracked_6", &"bone_0"]) == 1 and q.dice.size() == 5 and q.die_index(&"bone_0") == 0,
		"remove_dice: never below 5 dice (Cracked ruling); extra removals ignored")
	var h := RunProgress.new(_run)
	h.set_face(2, 2, &"heavy")
	h.set_face(2, 4, &"heavy")
	var hd := h.table_dice()
	_check(hd[2].weights == ([1.0, 1.0, 2.0, 1.0, 2.0, 1.0] as Array[float]) and hd[0].weights.is_empty(),
		"Heavy: each Heavy face weighs heavy_weight (2) on the TableDie; plain dice stay even")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var hits := 0
	for k in 6000:
		if hd[2].roll_slot(rng) == 3:
			hits += 1
	_check(hits > 1400 and hits < 1850, "Heavy: the face lands about twice as often (2/8 of rolls: %d of 6000)" % hits)
	var b := RunProgress.new(_run)
	b.record_banks([&"pair", &"single", &"run3", &"pair", &"run3", &"single", &"single"])
	_check(b.banked[&"pair"] == 2 and b.banked[&"run3"] == 2 and b.most_banked() == &"run3",
		"banked: counts per combo, repeats kept; tie goes to the higher-ranked combo; singles never count")
	b.record_banks([&"pair"])
	_check(b.most_banked() == &"pair" and b.black_seal() and b.seal_level(&"pair") == 1, "Black Seal: +1 to the most-banked combo")
