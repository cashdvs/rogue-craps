## Run-side non-d6 dice (design/nonstandard_dice.md; Coin and d3 first):
## DieShape data, N-face RunDie / mods / Heavy weights / event picks, shop
## and Elite offers (shape slot ~1 in 4, enabled shapes only), and the
## TableDie the run builds (faces / weights / mods sized to the shape).
##   godot --headless --path . --script res://tests/test_die_shapes.gd
extends SceneTree

const S := MapRun.Screen
const NT := MapGenData.NodeType

var _passed: int = 0
var _failed: int = 0
var _run: RunData


func _initialize() -> void:
	_run = load("res://resources/map/bonfire_run.tres") as RunData
	_test_data()
	_test_dice()
	_test_table()
	_test_offers()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	_run = null
	quit(1 if _failed > 0 else 0)


func _check(c: bool, name: String) -> void:
	if c:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", name)


func _test_data() -> void:
	var by := {}
	for s in _run.shapes:
		by[s.id] = s
	_check(by.size() == 8 and by.has(&"d6") and by.has(&"d20"), "data: d6 + Coin, d3, d4, d8, d10, d12, d20")
	_check((by[&"coin"] as DieShape).faces == ([1, 5] as Array[int]) and (by[&"d3"] as DieShape).faces == ([1, 2, 3] as Array[int])
		and (by[&"d10"] as DieShape).faces.size() == 10 and (by[&"d10"] as DieShape).faces[9] == 10, "data: Coin 1/5, d3 1-3, d10 1-10")
	_check(by[&"coin"].price == 12 and by[&"d3"].price == 12, "data: Coin and d3 cost 12 (Game Designer)")
	var on: Array[StringName] = []
	for s: DieShape in _run.shapes:
		if s.enabled:
			on.append(s.id)
	_check(on == ([&"coin", &"d3"] as Array[StringName]), "data: only Coin and d3 enabled")
	_check(is_equal_approx(_run.shape_offer_chance, 0.25), "data: shape slot about 1 in 4 of dice offers")


func _test_dice() -> void:
	var p := RunProgress.new(_run)
	_check(p.add_die(&"coin") and p.add_die(&"d3"), "dice: buy a Coin and a d3")
	var coin := p.dice[5]
	var d3 := p.dice[6]
	_check(coin.shape == &"coin" and coin.faces.size() == 2 and coin.special_id == &"" and d3.faces.size() == 3 and coin.id == &"coin_5",
		"dice: plain dice of that shape, faces sized 2 / 3, ids by shape")
	_check(p.die_name(5) == "Coin Die" and p.die_name(0) == "Bone" and p.sell_value(5) == 6, "dice: names; sells for half (6)")
	p.set_face(5, 1, &"hellfire")
	p.set_face(6, 0, &"wild")
	var plain_price := p.mod_price(load("res://resources/mods/twin.tres"), 0)
	_check(p.mod_price(load("res://resources/mods/twin.tres"), 5) == plain_price * 3 / 2, "mods: price still +50% per mod on the die (§5), not per face count")
	var run := MapRun.new(_run, 3)
	run.progress.add_die(&"coin")
	_check(run.free_face(Vector2i(5, 1)) and not run.free_face(Vector2i(5, 2)), "picks: a Coin has faces 0-1 only")
	_check(EventApplier.pick_ok(_add_fx(), run.progress, Vector2i(5, 0)) and not EventApplier.pick_ok(_add_fx(), run.progress, Vector2i(5, 4)),
		"events: picked faces bounded by the die's face count")
	var m := RunProgress.new(_run)
	m.add_die(&"mirror")
	m.add_die(&"cracked")
	_check(m.dice[5].shape == &"d6" and m.dice[5].faces.size() == 6 and m.table_dice()[6].special == &"cracked", "specials: Mirror / Cracked stay d6 specials")


func _add_fx() -> EventEffectData:
	var e := EventEffectData.new()
	e.kind = EventEffectData.Kind.ADD_FACE_MOD
	e.target = EventEffectData.Target.PICKED
	e.mod = load("res://resources/mods/wild.tres")
	return e


func _test_table() -> void:
	var p := RunProgress.new(_run)
	p.add_die(&"coin")
	p.add_die(&"d3")
	p.set_face(5, 1, &"hellfire")
	p.set_face(6, 2, &"heavy")
	var td := p.table_dice()
	var c := td[5]
	var t3 := td[6]
	_check(c.faces == ([1, 5] as Array[int]) and c.mods.size() == 2 and c.mod_at(2) != null and c.mod_at(2).id == &"hellfire" and c.special == &"",
		"table: Coin TableDie 1/5 with its mod on the 5")
	_check(t3.faces == ([1, 2, 3] as Array[int]) and t3.mods.size() == 3 and t3.weights == ([1.0, 1.0, 2.0] as Array[float]),
		"table: d3 values 1-3, Heavy on the 3 weighs 2 (N-sized weights)")
	_check(td[0].faces.size() == 6 and td[0].mods.size() == 6 and td[0].weights.is_empty(), "table: plain d6 unchanged")
	_check(not "shape" in c or (c.get("shape") == &"coin" and td[0].get("shape") == &"d6"), "table: TableDie.shape set when the table has it")
	var run := MapRun.new(_run, 5)
	run.progress.add_die(&"d3")
	for n: MapNode in run.map.nodes.values():
		if n.type == NT.TABLE:
			run.map.current_id = n.prev[0] if not n.prev.is_empty() else -1
			run.choose_node(n.id)
			break
	var ts := run.table_setup().to_table_setup(load("res://resources/tuning/bonfire_tuning.tres"))
	_check(ts.dice.size() == 6 and ts.dice[5].faces.size() == 3 and ts.owned_dice_count == 6, "setup: the d3 goes to the table N-sized")


func _test_offers() -> void:
	var shaped := 0
	var total := 0
	var kinds := {}
	for s in 400:
		var run := MapRun.new(_run, s)
		var offers := run._dice_offers(run._rng(&"test", s), 2)
		for o in offers:
			total += 1
			if o is DieShape:
				shaped += 1
				kinds[o.id] = true
				_check((o as DieShape).enabled, "offers: only enabled shapes")
	var rate := float(shaped) / float(total)
	_check(rate > 0.18 and rate < 0.32 and kinds.size() == 2, "offers: ~1 in 4 dice offers are Coin / d3 (%.2f)" % rate)
	var run := MapRun.new(_run, 9)
	run.screen = S.SHOP
	run.shop_dice = [_run.shapes[1]] as Array[SpecialDieData]
	run.progress.embers = 20
	_check(run.buy_die(0) and run.progress.dice[5].shape == &"coin" and run.progress.embers == 8, "shop: buy a Coin for 12")
