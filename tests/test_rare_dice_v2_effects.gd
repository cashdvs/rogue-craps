## Rare dice v2 PR 2a: Fortune, Usurer's, and the Barrel's Fuse roll + bank factor.
extends SceneTree

var _passed: int = 0
var _failed: int = 0
var _t: BonfireTuning
var _data: RunData
var _ev: Array = []


func _initialize() -> void:
	_t = load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	_data = load("res://resources/map/bonfire_run.tres") as RunData
	_test_data()
	_test_effects()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	_t = null
	_data = null
	quit(1 if _failed > 0 else 0)


func _check(c: bool, name: String) -> void:
	_passed += int(c)
	_failed += int(not c)
	if not c: print("FAIL: ", name)


func _mod(id: StringName) -> FaceModData:
	return load("res://resources/mods/%s.tres" % id)


func _run(specials: Array, soul: int = 10, entries: Array = [], seed_value: int = 7) -> BonfireRun:
	var r := BonfireRun.new(_t, null, soul, 6)
	r.set_rules(TableRules.build(entries, specials), seed_value)
	_ev.clear()
	r.table_event.connect(func(id: StringName, d: Variant) -> void: _ev.append([id, d]))
	return r


func _events(id: StringName) -> Array:
	return _ev.filter(func(e: Array) -> bool: return e[0] == id).map(func(e: Array) -> Variant: return e[1])


func _land(r: BonfireRun, faces: Array, mods: Array = [], boom: Variant = null) -> bool:
	var g: RandomNumberGenerator = null if boom == null else RandomNumberGenerator.new()
	while g != null and (g.randf() < RareDiceRules.BOOM_CHANCE) != boom:
		g.seed += 1
	if g != null: g.seed = g.seed  # rewind to the found seed
	return r.land_throw(TableThrow.make(Array(faces, TYPE_INT, "", null), mods, [], g))


func _pot(r: BonfireRun, idx: Array) -> void:
	for i in idx: r.toggle(i)


func _test_data() -> void:
	var want := {&"barrel": [false, {6: &"fuse"}], &"fortune": [true, {6: &"jackpot", 1: &"hex"}],
		&"usurer": [true, {1: &"ember_pip", 2: &"ember_pip", 3: &"ember_pip", 4: &"ember_pip", 5: &"ember_pip", 6: &"ember_pip"}]}
	for s: DieShape in _data.shapes:
		if want.has(s.id):
			_check(s.is_rare() and s.risky and s.enabled == want[s.id][0] and s.preset_mods == want[s.id][1] and s.table_special == s.id
				and DiceIds.asset_key(s.id) == StringName("%s_d6" % s.id), "data: %s" % s.id)
			var rules := TableRules.build([], [s.id])
			_check(rules.size() == 1 and rules[0] is RareDiceRules and rules[0].id == s.id, "install: %s's RareDiceRules" % s.id)
			var a := _run([s.id])
			var b := _run([])
			for r in [a, b]:
				_land(r, [5, 5, 5, 2])
				_pot(r, [0, 1, 2])
			_check(a.selection() == b.selection() and a.bank()["gain"] == b.bank()["gain"], "install: %s plain hand unchanged" % s.id)
	_check(_data.rare_face_mods.size() == 3 and not _data.face_mods.has(_mod(&"jackpot")), "data: rare mods never offered")
	_check(_mod(&"jackpot").effect == FaceModData.Effect.MULT_FACTOR and _mod(&"jackpot").mult_factor == 2.0
		and _mod(&"hex").mult_factor == 1.0 and _mod(&"fuse").mult_factor == 1.0, "data: Jackpot x2 (Hellfire path); Hex/Fuse plain")
	_check(EconomyStrings.RARE_V2_RISK_TAG == "Risk", "strings: rare_v2_risk_tag")


func _test_effects() -> void:
	var fuse := _mod(&"fuse")
	var r := _run([&"barrel"], 10, [], 99)
	for i in 30000:
		_land(r, [6], [fuse])
	var booms := _events(&"barrel_boom").size()
	_check(_events(&"fuse_lit").size() == 30000 and absf(booms / 30000.0 - 2.0 / 3.0) < 0.01, "fuse: Boom 2/3 of 30,000 (%d)" % booms)
	for boom in [true, false]:
		r = _run([&"barrel"], 5)
		var e0 := r.embers
		_land(r, [1])
		_pot(r, [0])
		r.rethrow()  # throw 1's pot is in the whole-hand factor too
		_land(r, [6, 5], [fuse, null], boom)
		_pot(r, [1])
		var pot := r.pot + int(r.selection()["points"])
		var p0 := r.points
		var g := int(r.bank()["gain"])
		_check(g == int(pot * (2.0 if boom else 0.5)) and r.points - p0 == g, "fuse: %s whole hand %d -> %d" % [boom, pot, g])
		if boom:
			var ev: Dictionary = _events(&"barrel_boom")[0]
			_check(r.embers == e0 + 1 and ev["nerve"] == 1 and ev["embers"] == 1 and ev["factor"] == 2.0 and r.soul == 5, "fuse: Boom +1 Ember now")
		else:
			_check(r.soul == 4 and _events(&"barrel_misfire")[0]["soul_lost"] == 1, "fuse: Misfire -1 Soul")
	for c: Array in [[true, true, 4.0], [true, false, 1.0], [false, false, 0.25]]:
		r = _run([&"barrel"])
		_land(r, [6, 1], [fuse, null], c[0])
		_land(r, [6, 1], [fuse, null], c[1])
		_check(RareDiceRules.barrel_rule(r).pot_factor == c[2], "fuse: two Fuses x%s" % c[2])
	r = _run([&"barrel"])
	_land(r, [6, 6, 6], [fuse, null, null], true)
	_pot(r, [0, 1, 2])
	_check(r.selection()["combo"] == &"trips" and r.bank() and RareDiceRules.barrel_rule(r).pot_factor == 1.0, "fuse: a Fuse 6 counts in a set; factor resets each hand")
	r = _run([&"barrel"], 1)
	_land(r, [6, 1], [fuse, null], false)
	_check(r.soul == 1 and _events(&"barrel_misfire")[0]["soul_lost"] == 0, "fuse: Misfire never takes the last Soul")
	r = _run([&"barrel"], 5)
	_land(r, [6, 1], [fuse, null], true)
	_land(r, [2, 3, 6])
	_check(r.last_result["kind"] == &"bust" and r.embers == 1, "fuse: Boom's Ember survives a bust")
	var hex := _mod(&"hex")
	for c: Array in [[5, [], 4], [1, [], 1], [5, [&"bloodletter"], 3], [2, [&"bloodletter"], 1]]:
		r = _run([&"fortune"], c[0], c[1])
		_land(r, [1], [hex])
		var ev := _events(&"hex")
		_check(r.soul == c[2] and ev.size() == 1 and ev[0]["soul_lost"] == c[0] - c[2], "hex: Soul %d %s -> %d" % c)
	var d := _run([&"fortune"], 5, [{"id": &"cold_sixes", "params": {"face": 1}}])
	_check(not _land(d, [1, 2], [hex, null]) and d.soul < 5, "hex: fires before the lit check; a dead throw keeps it")
	for c: Array in [[[&"usurer"], 10, [], 8], [[&"usurer"], 2, [], 1], [[&"usurer"], 1, [], 0],
			[[&"usurer"], 10, [&"bloodletter"], 6], [[&"usurer", &"usurer"], 10, [], 8], [[], 10, [], 9]]:
		r = _run(c[0], c[1], c[2])
		_land(r, [2, 3, 6])
		_check(r.soul == c[3] and r.last_result["soul_lost"] == c[1] - c[3] and _events(&"usurer_toll").size() == (1 if c[0].size() > 0 and c[1] > 1 else 0),
			"usurer: %s bust at Soul %d %s -> %d" % c)
	var o := _run([&"usurer"], 1)
	_land(o, [2, 3, 6])
	_check(o.state == BonfireRun.State.RUN_OVER, "usurer: Soul 1 bust still ends the run")
	var jack := _mod(&"jackpot")
	for n in [1, 2]:
		r = _run([&"fortune"])
		var p := _run([])
		_land(r, [6, 6, 6], [jack, jack if n == 2 else null, null])
		_land(p, [6, 6, 6])
		_pot(r, [0, 1, 2])
		_pot(p, [0, 1, 2])
		_check(int(r.selection()["points"]) == int(p.selection()["points"]) * 2 ** n and int(r.selection()["embers"]) == n, "jackpot: %d -> x%d +%d" % [n, 2 ** n, n])
		r.bank()
		_check(r.embers == n and _events(&"jackpot")[0]["embers"] == n and _events(&"jackpot")[0]["combo"] == &"trips", "jackpot: Ember at pot, outside points")
	var c := _run([&"fortune"], 10, [&"collector"])
	_land(c, [6, 6, 6], [jack, null, null])
	_pot(c, [0, 1, 2])
	_check(int(c.selection()["embers"]) == 0, "jackpot: off under The Collector")
	r = _run([&"barrel"], 5)
	_land(r, [3, 1])
	r.relight(TableThrow.make([1, 1] as Array[int], [_mod(&"hex"), null]))
	r.relight(TableThrow.make([6, 1] as Array[int], [_mod(&"fuse"), null]))
	_check(r.soul == 5 and _ev.size() == 1, "nerve: nudging onto a Hex or Fuse fires nothing")
	r = _run([&"fortune"], 5)
	_land(r, [1, 5], [_mod(&"hex"), null])
	r.relight(TableThrow.make([2, 5] as Array[int], [null, null]))
	_check(r.soul == 4, "nerve: nudging off a landed Hex doesn't refund")
	r = _run([&"fortune"])
	_land(r, [6, 6, 5])
	r.relight(TableThrow.make([6, 6, 6] as Array[int], [jack, null, null]))
	_pot(r, [0, 1, 2])
	_check(int(r.selection()["embers"]) == 1, "nerve: nudging onto a Jackpot scores it")
	r = _run([&"barrel"])
	var ns := NerveState.new()
	RareDiceRules.attach_nerve(r, ns)
	_land(r, [6, 1], [_mod(&"fuse"), null], true)
	var two := ns.uses_left() == 2
	_pot(r, [1])
	r.bank()
	_check(two and ns.uses_left() == 1, "nerve: a Boom (land_throw) is +1 Nerve, cleared next hand")
