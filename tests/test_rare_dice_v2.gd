## Rare dice v2, PR 1 (design/rare_dice_v2.md §4): Gallows (d4, 4 Twin) and
## Beacon (d8, 8 Wild, 7 Step) as data on the v1 rare system: rarity, prices
## per floor, sell value, the shop rare roll (now six rares), never re-offered
## when owned, the carving lock, art keys, and Twin on a d4 / Step past 6.
##   godot --headless --path . --script res://tests/test_rare_dice_v2.gd
extends SceneTree

const S := MapRun.Screen
const NEW := [&"gallows", &"beacon"]
const ALL_RARES := [&"pyre", &"gilt", &"lodestone", &"ossuary", &"gallows", &"beacon", &"fortune", &"usurer", &"barrel"]

var _passed: int = 0
var _failed: int = 0
var _run: RunData
var _t: BonfireTuning


func _initialize() -> void:
	_run = load("res://resources/map/bonfire_run.tres") as RunData
	_t = load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	_test_data()
	_test_ids()
	_test_prices_and_sell()
	_test_pool()
	_test_carving()
	_test_table_and_scoring()
	_test_handoff_checklist()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	_run = null
	_t = null
	quit(1 if _failed > 0 else 0)


func _check(c: bool, name: String) -> void:
	if c:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", name)


func _shape(id: StringName) -> DieShape:
	for s in _run.shapes:
		if s.id == id:
			return s
	return null


func _test_data() -> void:
	var g := _shape(&"gallows")
	_check(g != null and g.enabled and g.is_rare() and g.faces == ([1, 2, 3, 4] as Array[int]) and g.weights.is_empty(),
		"data: Gallows is an enabled rare 1-4")
	_check(g != null and g.price == 20 and g.preset_mods == {4: &"twin"} and g.table_special == &"",
		"data: Gallows price 20, 4 Twin, no Caltrop run rule")
	var b := _shape(&"beacon")
	_check(b != null and b.enabled and b.is_rare() and b.faces == ([1, 2, 3, 4, 5, 6, 7, 8] as Array[int]) and b.weights.is_empty(),
		"data: Beacon is an enabled rare 1-8")
	_check(b != null and b.price == 24 and b.preset_mods == {8: &"wild", 7: &"step"} and b.table_special == &"",
		"data: Beacon price 24, 8 Wild, 7 Step")
	_check(g != null and g.display_name == "Gallows Die" and g.description == "Four faces; its 4 counts as two 4s.",
		"data: Gallows name and card text (rare_v2_gallows)")
	_check(b != null and b.display_name == "Beacon Die" and b.description == "Eight faces; 8 is Wild and 7 is Step.",
		"data: Beacon name and card text (rare_v2_beacon)")
	var rares: Array = []
	for s in _run.shapes:
		if s.is_rare():
			rares.append(s.id)
	rares.sort()
	var want := ALL_RARES.duplicate()
	want.sort()
	_check(rares == want, "data: the rare shapes are exactly these (%s)" % [rares])
	var lan := _shape(&"lantern")
	var cal := _shape(&"caltrop")
	_check(not lan.enabled and not lan.is_rare() and not cal.enabled and not cal.is_rare() and cal.table_special == &"caltrop",
		"data: the Caltrop / Lantern bodies stay common and off")


func _test_ids() -> void:
	var want := {&"gallows": [DiceIds.SHAPE_D4, &"gallows_d4", &"caltrop_d4", "Gallows Die"],
		&"beacon": [DiceIds.SHAPE_D8, &"beacon_d8", &"lantern_d8", "Beacon Die"]}
	for id: StringName in want:
		var w: Array = want[id]
		_check(DiceIds.is_die(id) and DiceIds.shape_of(id) == w[0] and DiceIds.display_name(id) == w[3],
			"ids: %s is a %s die id" % [id, w[0]])
		_check(DiceIds.asset_key(id) == w[1] and DiceIds.canonical(w[1]) == id, "ids: %s art key %s" % [id, w[1]])
		_check(DiceIds.body_key(id) == w[2] and ResourceLoader.exists("res://art/models/dice/%s.glb" % w[2]),
			"art: %s stands in on the %s body" % [id, w[2]])


func _test_prices_and_sell() -> void:
	var want := {&"gallows": [20, 25, 30], &"beacon": [24, 30, 36], &"fortune": [24, 30, 36], &"usurer": [26, 33, 39], &"barrel": [30, 38, 45]}
	for id: StringName in want:
		for f in 3:
			var run := MapRun.new(_run, 1)
			run.floor_index = f
			run.screen = S.SHOP
			run.shop_dice = [null, _shape(id)] as Array[SpecialDieData]
			_check(run.die_price(1) == want[id][f], "price: %s floor %d = %d (got %d)" % [id, f + 1, want[id][f], run.die_price(1)])
			run.progress.embers = want[id][f]
			_check(run.buy_die(1) and run.progress.embers == 0 and run.progress.dice.size() == 6 and run.progress.dice[5].shape == id,
				"buy: %s on floor %d takes a bag slot" % [id, f + 1])
			_check(run.progress.sell_value(5) == want[id][0] / 2, "sell: %s sells for half (%d)" % [id, want[id][0] / 2])


func _test_pool() -> void:
	var hits := 0
	var by := {}
	var n := 6000
	for s in n:
		var run := MapRun.new(_run, s)
		run.floor_index = 2
		run.screen = S.SHOP
		run._roll_shop()
		if run.shop_dice[1].is_rare():
			hits += 1
			by[run.shop_dice[1].id] = int(by.get(run.shop_dice[1].id, 0)) + 1
	var even := by.size() == ALL_RARES.size()
	for id in by:
		even = even and absf(float(by[id]) / hits - 1.0 / ALL_RARES.size()) < 0.04
	_check(even, "pool: the rares equally weighted on a hit %s" % [by])
	_check(absf(float(hits) / n - 0.30) < 0.025, "pool: floor 3 odds unchanged (%.3f)" % [float(hits) / n])
	for id: StringName in NEW:
		var dup := false
		for s in 1500:
			var run := MapRun.new(_run, s)
			run.floor_index = 2
			run.progress.add_die(id)
			run.screen = S.SHOP
			run._roll_shop()
			dup = dup or run.shop_dice[1].id == id
		_check(not dup, "pool: an owned %s isn't offered again" % id)
	var all_ok := true
	var six: RunData = _run.duplicate()  # the bag holds 6: a pool of the first six
	six.shapes = six.shapes.filter(func(s: DieShape) -> bool: return not s.is_rare() or ALL_RARES.slice(0, 6).has(s.id))
	for s in 300:
		var run := MapRun.new(six, s)
		run.floor_index = 2
		run.progress.dice.clear()
		for id in ALL_RARES.slice(0, 6):
			run.progress.add_die(id)
		run.screen = S.SHOP
		run._roll_shop()
		all_ok = all_ok and run.progress.dice.size() == 6 and run.shop_dice[1] != null and not run.shop_dice[1].is_rare()
	_check(all_ok, "pool: owning every rare in the pool (6, the bag cap), slot 2 keeps a normal offer")
	var leak := false
	for s in 500:
		var run := MapRun.new(_run, s)
		for o in run._dice_offers(run._rng(&"test", s), 4):
			leak = leak or o.is_rare()
	_check(not leak, "pool: common offers (shop slots, Elite) never draw a rare")


func _test_carving() -> void:
	var p := RunProgress.new(_run)
	p.dice.resize(4)
	p.add_die(&"gallows")
	p.add_die(&"beacon")
	_check(p.dice[4].faces == ([&"", &"", &"", &"twin"] as Array[StringName]), "carve: Gallows arrives with 4 Twin")
	_check(p.dice[5].faces == ([&"", &"", &"", &"", &"", &"", &"step", &"wild"] as Array[StringName]),
		"carve: Beacon arrives with 7 Step, 8 Wild")
	_check(p.face_locked(4, 3) and not p.face_locked(4, 0) and not p.face_locked(4, 2), "carve: Gallows 4 locked, others free")
	_check(p.face_locked(5, 6) and p.face_locked(5, 7) and not p.face_locked(5, 5) and not p.face_locked(5, 0),
		"carve: Beacon 7 and 8 locked, 1-6 free")
	_check(not p.set_face(4, 3, &"wild") and not p.set_face(5, 7, &"") and not p.set_face(5, 6, RunDie.BLANK)
		and p.dice[4].faces[3] == &"twin" and p.dice[5].faces[7] == &"wild", "carve: preset faces can't be recarved or cleared")
	_check(p.set_face(4, 0, &"wild") and p.set_face(5, 0, &"hellfire"), "carve: free faces still carve")
	var rem := p.removable_faces()
	_check(rem.has(Vector2i(4, 0)) and rem.has(Vector2i(5, 0)) and not rem.has(Vector2i(4, 3))
		and not rem.has(Vector2i(5, 6)) and not rem.has(Vector2i(5, 7)), "carve: events can't remove the preset faces")


func _td(id: StringName) -> TableDie:
	var p := RunProgress.new(_run)
	p.add_die(id)
	return p.table_dice()[5]


func _at(td: TableDie, value: int) -> Dictionary:
	return BonfireScoring.make_die(value, td.mods[td.faces.find(value)])


func _test_table_and_scoring() -> void:
	var g := _td(&"gallows")
	var b := _td(&"beacon")
	_check(g.faces == ([1, 2, 3, 4] as Array[int]) and b.faces == ([1, 2, 3, 4, 5, 6, 7, 8] as Array[int]), "table: faces 1-4 and 1-8")
	var q := RunProgress.new(_run)
	q.dice.resize(4)
	q.add_die(&"gallows")
	q.add_die(&"beacon")
	_check(q.table_shape(4) == DiceIds.SHAPE_D4 and q.table_shape(5) == DiceIds.SHAPE_D8, "table: rolls as d4 and d8")
	# Twin on a d4: the Gallows 4 counts as two 4s; its other faces don't.
	var tw := BonfireScoring.score_selection([_at(g, 4), BonfireScoring.make_die(4)], _t)
	_check(tw["valid"] and tw["combo"] == &"trips", "score: Gallows 4 + 4 = Trips (got %s)" % tw["combo"])
	var t3 := BonfireScoring.score_selection([_at(g, 3), BonfireScoring.make_die(3)], _t)
	_check(t3["valid"] and t3["combo"] == &"pair", "score: Gallows 3 + 3 stays a Pair (got %s)" % t3["combo"])
	# Beacon 8 is Wild.
	var w := BonfireScoring.score_selection([_at(b, 8), BonfireScoring.make_die(4), BonfireScoring.make_die(4)], _t, 0, {"wild_max": 8})
	_check(w["valid"] and w["combo"] == &"trips", "score: Beacon 8 is Wild (4-4-W = Trips, got %s)" % w["combo"])
	# Beacon 7 is Step, past 6: with 9 and 10 in the tray it steps to 8 (8-9-10).
	var st := BonfireScoring.score_selection([_at(b, 7), BonfireScoring.make_die(9), BonfireScoring.make_die(10)], _t, 0, {"wild_max": 10})
	var pl := BonfireScoring.score_selection([BonfireScoring.make_die(7), BonfireScoring.make_die(9), BonfireScoring.make_die(10)], _t, 0, {"wild_max": 10})
	_check(st["valid"] and st["combo"] == &"run3" and pl["combo"] != &"run3", "score: Beacon 7 steps past 6 (7S-9-10 = Run 3, got %s / plain %s)" % [st["combo"], pl["combo"]])
	# And down: 4-5-7S reads 4-5-6.
	var dn := BonfireScoring.score_selection([BonfireScoring.make_die(4), BonfireScoring.make_die(5), _at(b, 7)], _t, 0, {"wild_max": 8})
	_check(dn["valid"] and dn["combo"] == &"run3", "score: Beacon 7 steps down (4-5-7S = Run 3, got %s)" % dn["combo"])


## design/handoff/rare_dice_v2_pr1.md §8 items not covered above.
func _test_handoff_checklist() -> void:
	# Rare rate per floor over 10,000 seeded shops, +-1%; one rare at most, always index 1.
	var want := [0.10, 0.20, 0.30]
	for f in 3:
		var hits := 0
		var bad := false
		for s in 10000:
			var run := MapRun.new(_run, s)
			run.floor_index = f
			run.screen = S.SHOP
			run._roll_shop()
			var n := 0
			for i in run.shop_dice.size():
				if run.shop_dice[i] != null and run.shop_dice[i].is_rare():
					n += 1
					bad = bad or i != 1
			bad = bad or n > 1
			hits += n
		_check(absf(float(hits) / 10000.0 - want[f]) < 0.01, "handoff: floor %d rare rate %.4f ~ %.2f +-1%%" % [f + 1, hits / 10000.0, want[f]])
		_check(not bad, "handoff: floor %d at most one rare, always slot index 1" % [f + 1])
	# Same seed, same rare roll.
	var a := MapRun.new(_run, 77)
	var b := MapRun.new(_run, 77)
	a.floor_index = 2
	b.floor_index = 2
	a._roll_shop()
	b._roll_shop()
	_check(a.shop_dice[1].id == b.shop_dice[1].id, "handoff: seeded shop rolls repeat")
	var g := _td(&"gallows")
	var bc := _td(&"beacon")
	# Gallows [4T,4,4] is a four-of-a-kind-sized set, not Trips.
	var q := BonfireScoring.score_selection([_at(g, 4), BonfireScoring.make_die(4), BonfireScoring.make_die(4)], _t)
	_check(q["valid"] and q["combo"] != &"trips" and q["combo"] != &"pair", "handoff: Gallows 4T-4-4 beats Trips (got %s)" % q["combo"])
	# A lone 4 doesn't light; as the only die thrown, a cold d4 gets the #116 free rethrow.
	# Handoff §8 says a lone 4 doesn't light, but under the existing Twin rule (same as
	# Ossuary's lone 3/6) a lone Twin 4 counts as two 4s = a Pair. Pinned as the
	# current rule; flagged to Game Designer. Its plain faces 2 and 3 don't light alone.
	var lone := BonfireScoring.score_selection([_at(g, 4)], _t)
	_check(lone["valid"] and lone["combo"] == &"pair", "handoff: a lone Gallows Twin 4 is a Pair under the Twin rule (got %s)" % lone["combo"])
	_check(not BonfireScoring.score_selection([_at(g, 2)], _t)["valid"] and not BonfireScoring.score_selection([_at(g, 3)], _t)["valid"],
		"handoff: lone Gallows 2 / 3 don't light")
	_check(NonStdDice.free_rethrow_ok(1, 1, 1, [g], 0) and not NonStdDice.free_rethrow_ok(1, 1, 1, [g], NonStdDice.MAX_FREE_RETHROWS),
		"handoff: a lone cold Gallows is rethrown free (capped)")
	# Beacon: a lone 8 lights; Wild capped at the tray's top face.
	_check(BonfireScoring.score_selection([_at(bc, 8)], _t)["valid"], "handoff: a lone Beacon 8 lights")
	_check(NonStdDice.wild_max([bc]) == 8 and NonStdDice.wild_max([g]) == 6, "handoff: Wild cap is the tray's top face (8 / 6)")
	var r4 := BonfireScoring.score_selection([BonfireScoring.make_die(4), BonfireScoring.make_die(5), BonfireScoring.make_die(6), _at(bc, 7)], _t, 0, {"wild_max": 8})
	_check(r4["valid"] and r4["combo"] == &"run4", "handoff: 4-5-6 + 7S is a Run 4 (got %s)" % r4["combo"])
	# Bag at 6: no buy, no event add.
	var run := MapRun.new(_run, 5)
	run.screen = S.SHOP
	run.progress.add_die(&"extra")
	run.shop_dice = [null, _shape(&"beacon")] as Array[SpecialDieData]
	run.progress.embers = 99
	_check(not run.buy_die(1) and run.progress.embers == 99 and not run.progress.add_die(&"gallows"), "handoff: full bag refuses a rare")
	var leak := false
	for e in _run.events:
		for c in e.choices:
			leak = leak or ALL_RARES.any(func(id): return var_to_str(c).contains('"%s"' % id))
	_check(not leak, "handoff: no event gives a rare")
	_check(EconomyStrings.RARE_CARVED_LOCKED != "", "handoff: the rare_carved_locked refusal exists")

