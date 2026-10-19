## Run-side batch-3 dice (design/nonstandard_dice.md §10; Powder Keg on):
## DieShape data, N-face RunDie / mods / Heavy weights / event picks, shop
## and Elite offers (shape slot ~1 in 4, enabled shapes only), and the
## TableDie the run builds (6-slot d6 arrays until TableDie.shape lands,
## then N-sized + shape; Ferryman's Coin per Godot Dev's spec).
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
	_test_table_shapes()
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
	var want := {&"powder_keg": ["Powder Keg", 18, [1, 1, 2, 2, 3, 3], {3: &"twin"}, &""],
		&"ferryman": ["Ferryman's Coin", 18, [5, 0], {}, &"ferryman"],
		&"caltrop": ["Caltrop", 18, [1, 2, 3, 4], {}, &"caltrop"],
		&"lantern": ["Lantern", 18, [1, 2, 3, 4, 5, 6, 7, 8], {8: &"wild"}, &""],
		&"tithe": ["Tithe", 18, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], {10: &"gilded"}, &""],
		&"midnight": ["Midnight", 18, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], {12: &"hellfire"}, &""],
		&"verdict": ["Verdict", 18, range(1, 21), {20: &"hellfire", 1: &"blood"}, &""],
		&"knucklebone": ["Knucklebone", 18, [1, 3, 4, 6], {}, &"knucklebone"]}
	_check(by.size() == 9 and by.has(&"bone") and not by.has(&"d3") and not by.has(&"d20"), "data: d6 + the 8 named §10 dice; no plain Coin / d3 / dN")
	for id in want:
		var sh: DieShape = by.get(id)
		var w: Array = want[id]
		_check(sh != null and sh.display_name == w[0] and sh.price == w[1] and Array(sh.faces) == w[2]
			and sh.preset_mods == w[3] and sh.table_special == w[4], "data: %s matches §10 (name, price, faces, pre-carved, hook)" % id)
	var coin: DieShape = by[&"ferryman"]
	_check(coin.weights == ([1.0, 1.0] as Array[float]), "data: Ferryman's Coin weights 1/1 (heads, tails)")
	var on: Array[StringName] = []
	for s: DieShape in _run.shapes:
		if s.enabled:
			on.append(s.id)
	_check(on == ([&"powder_keg"] as Array[StringName]), "data: only the Powder Keg is enabled")
	_check(is_equal_approx(_run.shape_offer_chance, 0.25), "data: shape slot about 1 in 4 of dice offers")


func _test_dice() -> void:
	var roomy := _run.duplicate() as RunData
	roomy.max_dice = 7
	var p := RunProgress.new(roomy)
	_check(p.add_die(&"powder_keg") and p.add_die(&"ferryman"), "dice: buy a Powder Keg and a Coin")
	var keg := p.dice[5]
	var coin := p.dice[6]
	_check(keg.shape == &"powder_keg" and keg.faces.size() == 6 and keg.special_id == &"" and coin.faces.size() == 2 and keg.id == &"powder_keg_5",
		"dice: plain dice of that shape, faces sized 6 / 2, ids by shape")
	_check(keg.faces == ([&"", &"", &"", &"", &"twin", &"twin"] as Array[StringName]) and keg.free_faces() == ([0, 1, 2, 3] as Array[int]),
		"dice: the Keg arrives with Twin carved on both 3s; the other faces stay free")
	_check(p.die_name(5) == "Powder Keg" and p.die_name(6) == "Ferryman's Coin" and p.die_name(0) == "Bone" and p.sell_value(5) == 9, "dice: names; sells for half (9)")
	var twin: FaceModData = load("res://resources/mods/twin.tres")
	var plain_price := p.mod_price(twin, 0)
	_check(p.mod_price(twin, 5) == plain_price, "mods: pre-carved faces don't count toward the +50% step (§5/§10 silent)")
	p.set_face(5, 0, &"wild")
	_check(p.mod_price(twin, 5) == plain_price * 3 / 2, "mods: a carved face does (+50% per mod, §5)")
	var run := MapRun.new(roomy, 3)
	run.progress.add_die(&"ferryman")
	_check(run.free_face(Vector2i(5, 1)) and not run.free_face(Vector2i(5, 2)), "picks: a Coin has faces 0-1 only")
	_check(EventApplier.pick_ok(_add_fx(), run.progress, Vector2i(5, 0)) and not EventApplier.pick_ok(_add_fx(), run.progress, Vector2i(5, 4)),
		"events: picked faces bounded by the die's face count")
	run.progress.add_die(&"powder_keg")
	_check(not run.free_face(Vector2i(6, 4)) and run.free_face(Vector2i(6, 3)), "picks: the Keg's Twin 3s are taken, its 2s are free")
	var m := RunProgress.new(_run)
	m.add_die(&"mirror")
	m.add_die(&"cracked")
	_check(m.dice[5].shape == &"bone" and m.dice[5].faces.size() == 6 and m.table_dice()[6].special == &"cracked", "specials: Mirror / Cracked stay d6 specials")


func _add_fx() -> EventEffectData:
	var e := EventEffectData.new()
	e.kind = EventEffectData.Kind.ADD_FACE_MOD
	e.target = EventEffectData.Target.PICKED
	e.mod = load("res://resources/mods/wild.tres")
	return e


func _test_table() -> void:
	var p := RunProgress.new(_run)
	p.add_die(&"powder_keg")
	p.add_die(&"ferryman")
	p.set_face(5, 2, &"heavy")
	var td := p.table_dice()
	var k := td[5]
	_check(k.faces == ([1, 1, 2, 2, 3, 3] as Array[int]) and k.mods.size() == 6 and k.mods[4] != null and k.mods[4].id == &"twin"
		and k.mods[5] != null and k.mods[5].id == &"twin" and k.mods[0] == null and k.special == &"",
		"table: Powder Keg = 1,1,2,2,3,3 with Twin on slots 4 and 5")
	_check(k.weights == ([1.0, 1.0, 2.0, 1.0, 1.0, 1.0] as Array[float]), "table: Heavy on one 2-face weighs that slot 2")
	_check(td[0].faces.size() == 6 and td[0].mods.size() == 6 and td[0].weights.is_empty(), "table: plain d6 unchanged")
	var c := td[6]
	_check(c.special == &"ferryman", "table: Ferryman's Coin is TableDie special &\"ferryman\"")
	if "shape" in c:
		_check(c.get("shape") == &"coin" and c.faces == ([5, 0] as Array[int]) and c.weights == ([1.0, 1.0] as Array[float])
			and c.mods == [null, null] and k.get("shape") == &"powder_keg", "table: with TableDie.shape the Coin is N-sized (heads, tails), shape coin")
	else:
		_check(c.faces == ([5, 5, 5, 0, 0, 0] as Array[int]) and c.mods.size() == 6 and c.weights == ([1.0, 1.0, 1.0, 1.0, 1.0, 1.0] as Array[float]),
			"table: no TableDie.shape yet, so the Coin is 6 d6 slots with the same odds")
	# The exact spec emission (Godot Dev): N-sized arrays + shape when TableDie has it.
	var e := _shaped_emission(p, 6)
	_check(e.faces == ([5, 0] as Array[int]) and e.weights == ([1.0, 1.0] as Array[float]) and e.mods.size() == 2
		and e.special == &"ferryman" and e.shape == &"coin", "table: shaped emission = special ferryman, shape coin, faces [heads, tails], weights [1,1]")
	var d6s := TableDie.new()
	d6s.faces = [1, 2, 3] as Array[int]
	d6s.mods = [null, &"x", null]
	d6s.weights = [1.0, 1.0, 2.0] as Array[float]
	TableDieSlots.to_d6_slots(d6s)
	_check(d6s.faces == ([1, 1, 2, 2, 3, 3] as Array[int]) and d6s.mods == [null, null, &"x", &"x", null, null]
		and d6s.weights == ([1.0, 1.0, 1.0, 1.0, 2.0, 2.0] as Array[float]), "table: 6-slot mapping puts each value's mod and weight on both its slots")
	var run := MapRun.new(_run, 5)
	run.progress.add_die(&"powder_keg")
	for n: MapNode in run.map.nodes.values():
		if n.type == NT.TABLE:
			run.map.current_id = n.prev[0] if not n.prev.is_empty() else -1
			run.choose_node(n.id)
			break
	var ts := run.table_setup().to_table_setup(load("res://resources/tuning/bonfire_tuning.tres"))
	_check(ts.dice.size() == 6 and ts.dice[5].faces.size() == 6 and ts.owned_dice_count == 6, "setup: the Keg goes to the table as a 6-slot die")


## What table_dice() emits for die i once TableDie has `shape` (simulated
## with the pre-conversion arrays): RunProgress.shaped_table_die.
## #107: RunDie.shape holds a die id; the table gets DiceIds.shape_of it.
func _test_table_shapes() -> void:
	var p := RunProgress.new(_run)
	_check(p.table_shape(0) == DiceIds.SHAPE_D6, "table shape: a starting Bone rolls as d6")
	var want := {DiceIds.DIE_FERRYMAN: DiceIds.SHAPE_COIN, DiceIds.DIE_CALTROP: DiceIds.SHAPE_D4,
		DiceIds.DIE_LANTERN: DiceIds.SHAPE_D8, DiceIds.DIE_TITHE: DiceIds.SHAPE_D10,
		DiceIds.DIE_MIDNIGHT: DiceIds.SHAPE_D12, DiceIds.DIE_VERDICT: DiceIds.SHAPE_D20,
		DiceIds.DIE_POWDER_KEG: DiceIds.SHAPE_D6, DiceIds.DIE_KNUCKLEBONE: DiceIds.SHAPE_TALUS}
	for id: StringName in want:
		var q := RunProgress.new(_run)
		var ok := q.add_die(id)
		var i := q.dice.size() - 1
		_check(ok and q.dice[i].shape == id and q.table_shape(i) == want[id],
			"table shape: %s rolls as %s (got %s)" % [id, want[id], q.table_shape(i) if ok else &"-"])


func _shaped_emission(p: RunProgress, i: int) -> Dictionary:
	var td: TableDie = p.shaped_table_die(i)
	return {"faces": td.faces, "weights": td.weights, "mods": td.mods, "special": td.special, "shape": p.table_shape(i)}


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
	_check(rate > 0.15 and rate < 0.32 and kinds.keys() == [&"powder_keg"], "offers: shaped slot offers only the Powder Keg (%.2f)" % rate)
	var run := MapRun.new(_run, 9)
	run.screen = S.SHOP
	run.shop_dice = [_run.shapes[1]] as Array[SpecialDieData]
	run.progress.embers = 26
	_check(run.buy_die(0) and run.progress.dice[5].shape == &"powder_keg" and run.progress.embers == 8, "shop: buy a Powder Keg for 18")
