## Rare dice v1 (design/rare_dice_v1.md, PR 1): data, rarity, the shop's rare
## roll (odds and prices per floor), shop-only, full-bag swap, the carving
## lock and price step, pre-carved faces scoring, and Nerve on a rare.
##   godot --headless --path . --script res://tests/test_rare_dice.gd
extends SceneTree

const S := MapRun.Screen
const RARES := [&"pyre", &"gilt", &"lodestone", &"ossuary"]

var _passed: int = 0
var _failed: int = 0
var _run: RunData
var _t: BonfireTuning


func _initialize() -> void:
	_run = load("res://resources/map/bonfire_run.tres") as RunData
	_t = load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	_test_data()
	_test_odds()
	_test_prices_and_sell()
	_test_swap()
	_test_carving()
	_test_scoring()
	_test_nerve()
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
	var want := {&"pyre": [30, {6: &"hellfire", 5: &"ember_pip"}], &"gilt": [22, {1: &"gilded", 5: &"gilded"}],
		&"lodestone": [26, {6: &"wild"}], &"ossuary": [28, {3: &"twin", 6: &"twin"}]}
	for id: StringName in want:
		var s := _shape(id)
		_check(s != null and s.enabled and s.is_rare() and s.faces == ([1, 2, 3, 4, 5, 6] as Array[int]) and s.weights.is_empty(),
			"data: %s is an enabled rare plain d6" % id)
		_check(s != null and s.price == want[id][0] and s.preset_mods == want[id][1], "data: %s price and preset_mods" % id)
		_check(DiceIds.is_die(id) and DiceIds.shape_of(id) == DiceIds.SHAPE_D6 and DiceIds.asset_key(id) == StringName("%s_d6" % id),
			"ids: %s is a d6 die id" % id)
	var commons := 0
	for s in _run.shapes:
		commons += 0 if s.is_rare() else 1
	_check(commons == 9 and _run.special_dice.all(func(d): return not d.is_rare()), "data: other dice stay common")
	_check(_run.shop_rare_die_chance == ([0.10, 0.20, 0.30] as Array[float]), "data: shop_rare_die_chance [0.1, 0.2, 0.3]")


func _shop_run(seed: int, floor_i: int) -> MapRun:
	var run := MapRun.new(_run, seed)
	run.floor_index = floor_i
	run.screen = S.SHOP
	run._roll_shop()
	return run


func _test_odds() -> void:
	var want := [0.10, 0.20, 0.30]
	for f in 3:
		var hits := 0
		var by := {}
		var slot0_rare := false
		var n := 3000
		for s in n:
			var run := _shop_run(s, f)
			slot0_rare = slot0_rare or run.shop_dice[0].is_rare()
			if run.shop_dice[1].is_rare():
				hits += 1
				by[run.shop_dice[1].id] = int(by.get(run.shop_dice[1].id, 0)) + 1
		var rate := float(hits) / n
		_check(absf(rate - want[f]) < 0.025, "odds: floor %d rare rate %.3f ~ %.2f" % [f + 1, rate, want[f]])
		_check(not slot0_rare, "odds: floor %d never puts a rare in slot 1" % [f + 1])
		var even := by.size() == 4
		for id in by:
			even = even and absf(float(by[id]) / hits - 0.25) < 0.06
		_check(even, "odds: floor %d four rares equally weighted %s" % [f + 1, by])
	# Elite rewards / common pools never offer a rare.
	var leak := false
	for s in 500:
		var run := MapRun.new(_run, s)
		for o in run._dice_offers(run._rng(&"test", s), 4):
			leak = leak or o.is_rare()
	_check(not leak, "shop-only: _dice_offers (shop slots, Elite) never draws a rare")
	# No owned rare offered again.
	var dup := false
	for s in 1500:
		var run := MapRun.new(_run, s)
		run.floor_index = 2
		run.progress.add_die(&"pyre")
		run.screen = S.SHOP
		run._roll_shop()
		dup = dup or run.shop_dice[1].id == &"pyre"
	_check(not dup, "odds: an owned rare isn't offered again")
	# GD ruling on #174: all four owned -> the roll misses, slot 2 keeps its normal offer.
	var all_ok := true
	for s in 400:
		var run := MapRun.new(_run, s)
		run.floor_index = 2
		run.progress.dice.resize(2)
		for id in RARES:
			run.progress.add_die(id)
		run.screen = S.SHOP
		run._roll_shop()
		all_ok = all_ok and run.shop_dice.size() == 2 and run.shop_dice[1] != null and not run.shop_dice[1].is_rare()
	_check(all_ok, "odds: owning all four rares, slot 2 keeps a normal (non-empty) offer")


func _test_prices_and_sell() -> void:
	var want := {&"pyre": [30, 38, 45], &"gilt": [22, 28, 33], &"lodestone": [26, 33, 39], &"ossuary": [28, 35, 42]}
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


func _test_swap() -> void:
	var run := MapRun.new(_run, 2)
	run.screen = S.SHOP
	run.progress.add_die(&"extra")
	_check(run.progress.dice.size() == 6 and not run.progress.can_add_die(), "swap: bag full at 6")
	run.shop_dice = [null, _shape(&"gilt")] as Array[SpecialDieData]
	run.progress.embers = 40
	_check(not run.buy_die(1) and run.progress.embers == 40, "swap: a rare can't be bought into a full bag")
	var got := run.progress.sell_value(5)
	_check(run.sell_die(5) and run.progress.embers == 40 + got, "swap: sell a die first")
	_check(run.buy_die(1) and run.progress.dice.size() == 6 and run.progress.dice[5].shape == &"gilt" and run.progress.embers == 40 + got - 22,
		"swap: then the rare takes its slot (cap stays 6)")


func _test_carving() -> void:
	var run := MapRun.new(_run, 3)
	run.progress.add_die(&"pyre")
	var p := run.progress
	_check(p.dice[5].faces == ([&"", &"", &"", &"", &"ember_pip", &"hellfire"] as Array[StringName]), "carve: Pyre arrives with 5 Pip, 6 Hellfire")
	_check(p.face_locked(5, 5) and p.face_locked(5, 4) and not p.face_locked(5, 0), "carve: preset faces locked, others free")
	_check(not p.set_face(5, 5, &"wild") and not p.set_face(5, 5, RunDie.BLANK) and not p.set_face(5, 5, &"")
		and p.dice[5].faces[5] == &"hellfire", "carve: a preset face can't be recarved, blanked or cleared")
	_check(not run.free_face(Vector2i(5, 5)) and run.free_face(Vector2i(5, 0)), "carve: picks skip the preset faces")
	var twin: FaceModData = load("res://resources/mods/twin.tres")
	var plain := p.mod_price(twin, 0)
	_check(p.mod_price(twin, 5) == plain, "carve price: preset faces don't count toward the step")
	_check(p.set_face(5, 0, &"wild") and p.mod_price(twin, 5) == plain * 3 / 2, "carve price: a carved free face does")
	var keg := RunProgress.new(_run)
	keg.add_die(&"powder_keg")
	_check(not keg.face_locked(5, 4) and keg.set_face(5, 4, &""), "carve: common shapes' presets aren't locked (unchanged)")


func _die_at(td: TableDie, value: int) -> Dictionary:
	return BonfireScoring.make_die(value, td.mods[td.faces.find(value)])


func _rare_td(id: StringName) -> TableDie:
	var p := RunProgress.new(_run)
	p.add_die(id)
	return p.table_dice()[5]


func _test_scoring() -> void:
	var pyre := _rare_td(&"pyre")
	_check(pyre.faces == ([1, 2, 3, 4, 5, 6] as Array[int]), "table: a rare rolls as a plain 1-6 d6")
	var plain := BonfireScoring.score_selection([BonfireScoring.make_die(6), BonfireScoring.make_die(6), BonfireScoring.make_die(6)], _t)
	var hot := BonfireScoring.score_selection([_die_at(pyre, 6), BonfireScoring.make_die(6), BonfireScoring.make_die(6)], _t)
	_check(hot["valid"] and hot["points"] == int(plain["points"] * 1.5), "score: Pyre 6 is Hellfire x1.5 (%d vs %d)" % [hot["points"], plain["points"]])
	var p5 := BonfireScoring.score_selection([_die_at(pyre, 5)], _t)
	var b5 := BonfireScoring.score_selection([BonfireScoring.make_die(5)], _t)
	_check(p5["valid"] and p5["mult"] == b5["mult"] + 2, "score: Pyre 5 is Ember Pip +2 mult")
	var gilt := _rare_td(&"gilt")
	_check(BonfireScoring.score_selection([_die_at(gilt, 1)], _t)["embers"] == 1 and BonfireScoring.score_selection([_die_at(gilt, 5)], _t)["embers"] == 1,
		"score: Gilt 1 and 5 give +1 Ember")
	var lode := _rare_td(&"lodestone")
	var w := BonfireScoring.score_selection([_die_at(lode, 6), BonfireScoring.make_die(4), BonfireScoring.make_die(4)], _t)
	_check(w["valid"] and w["combo"] == &"trips", "score: Lodestone 6 is Wild (4-4-W = Trips, got %s)" % w["combo"])
	var oss := _rare_td(&"ossuary")
	var tw := BonfireScoring.score_selection([_die_at(oss, 3), BonfireScoring.make_die(3)], _t)
	_check(tw["valid"] and tw["combo"] == &"trips", "score: Ossuary 3 counts twice (3T-3 = Trips, got %s)" % tw["combo"])


func _test_nerve() -> void:
	var p := RunProgress.new(_run)
	p.add_die(&"pyre")
	var dice := p.table_dice()
	var ns := NerveState.new()
	ns.setup(dice, 1)
	_check(not NerveState.is_copy_die(dice[5]) and dice[5].shape == DiceIds.SHAPE_D6, "nerve: a rare is a plain d6 target")
	var slots: Array[int] = [1, 1, 1, 1, 1, 5]
	ns.begin_throw(slots)
	_check(ns.can_nudge(5), "nerve: can target the Pyre")
	var to := ns.nudge(5, NerveState.UP)
	_check(to == 6 and dice[5].faces[to - 1] == 6 and (dice[5].mods[to - 1] as FaceModData).id == &"hellfire",
		"nerve: nudging Pyre 5->6 lands on its Hellfire face")
	_check(ns.undo(5) == 5, "nerve: undo window unchanged")
