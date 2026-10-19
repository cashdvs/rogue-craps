## Run-side event effects (data in tests/support/event_effects_demo.tres):
## max Soul +/-, give a die, sell a die, free shop rerolls, next-table twist.
##   godot --headless --path . --script res://tests/test_event_effects.gd
extends SceneTree

const S := MapRun.Screen
const NT := MapGenData.NodeType
const C := {&"max_up": 0, &"max_down": 1, &"mirror": 2, &"bone": 3, &"sell": 4, &"sell_random": 5,
	&"rerolls": 6, &"twist": 7, &"paid_reroll": 8}

var _passed: int = 0
var _failed: int = 0
var _run: RunData
var _ev: EventData


func _initialize() -> void:
	_run = load("res://resources/map/bonfire_run.tres") as RunData
	_ev = load("res://tests/support/event_effects_demo.tres") as EventData
	_test_data()
	_test_max_soul()
	_test_give_die()
	_test_sell_die()
	_test_rerolls()
	_test_twist()
	_test_flow()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	_run = null
	_ev = null
	quit(1 if _failed > 0 else 0)


func _check(c: bool, name: String) -> void:
	if c:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", name)


func _ch(key: StringName) -> EventChoiceData:
	return _ev.choices[C[key]]


func _apply(key: StringName, p: RunProgress, picks: Array[Vector2i] = [], seed_v: int = 1) -> Array[String]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	return EventApplier.apply(_ch(key), p, rng, picks)


func _test_data() -> void:
	var K := EventEffectData.Kind
	var kinds: Array = []
	for c in _ev.choices:
		for e in c.effects:
			kinds.append(e.kind)
	_check(kinds.has(K.MAX_SOUL) and kinds.has(K.GIVE_DIE) and kinds.has(K.SELL_DIE) and kinds.has(K.FREE_SHOP_REROLL)
		and kinds.has(K.NEXT_TABLE_TWIST), "data: every new effect kind loads from an event .tres")
	_check(_ch(&"mirror").effects[0].die == &"mirror" and _ch(&"twist").effects[0].rule.id == &"cold_hands", "data: die id and twist rule are data")
	var ids: Array = []
	for e in _run.events:
		ids.append(e.id)
	_check(not ids.has(&"event_effects_demo"), "data: the fixture isn't in the run's event pool")


func _test_max_soul() -> void:
	var p := RunProgress.new(_run)
	var max0 := p.max_soul
	p.soul = 20
	var lines := _apply(&"max_up", p)
	_check(p.max_soul == max0 + 5 and p.soul == 20 and lines[0].begins_with("Max Soul +5"), "max soul: +5 raises the cap, doesn't heal")
	p.soul = p.max_soul
	_apply(&"max_down", p)
	_check(p.max_soul == max0 - 5 and p.soul == p.max_soul, "max soul: -10 cuts Soul down to the new cap")
	p.soul = 3
	_apply(&"max_down", p)
	_check(p.max_soul == max0 - 15 and p.soul == 3, "max soul: Soul under the new cap is untouched")
	var q := RunProgress.new(_run)
	q.max_soul = 10
	q.soul = 10
	_check(EventApplier.why_not(_ch(&"max_down"), q) == "Not enough max Soul.", "max soul: can't cut max Soul to 0 or below (greyed)")
	q.max_soul = 11
	_check(EventApplier.can_choose(_ch(&"max_down"), q) and _apply(&"max_down", q)[0].begins_with("Max Soul -10") and q.max_soul == 1 and q.soul == 1,
		"max soul: down to exactly 1 is allowed; Soul floors at 1")
	_check(not q.is_over(), "max soul: losing max Soul never ends the run")
	_check(q.change_max_soul(-50) == 0 and q.max_soul == 1, "max soul: change_max_soul floors at 1")


func _test_give_die() -> void:
	var p := RunProgress.new(_run)
	var n := p.dice.size()
	_apply(&"mirror", p)
	_check(p.dice.size() == n + 1 and p.dice[n].special_id == &"mirror", "give die: a Mirror Die joins the bag")
	_apply(&"bone", p)
	_check(p.dice.size() == n + 2 and p.dice[n + 1].special_id == &"" and p.dice[n + 1].shape == &"d6" and p.die_name(n + 1) == "Bone",
		"give die: an empty die id gives a plain Bone")
	_check(p.dice.size() == _run.max_dice, "give die: bag now full (%d)" % _run.max_dice)
	_check(EventApplier.why_not(_ch(&"mirror"), p) == "Your bag is full (%d dice)." % _run.max_dice, "give die: full bag greys the choice")
	var lines := _apply(&"mirror", p)
	_check(lines[0].begins_with("refused") and p.dice.size() == _run.max_dice, "give die: refused on a full bag, nothing changes")
	var q := RunProgress.new(_run)
	var keg := EventChoiceData.new()
	var e := EventEffectData.new()
	e.kind = EventEffectData.Kind.GIVE_DIE
	e.die = &"powder_keg"
	keg.effects.assign([e])
	EventApplier.apply(keg, q, RandomNumberGenerator.new())
	_check(q.dice[q.dice.size() - 1].shape == &"powder_keg" and q.dice[q.dice.size() - 1].faces[4] == &"twin", "give die: a shaped die arrives with its pre-carved faces")


func _test_sell_die() -> void:
	var p := RunProgress.new(_run)
	_check(EventApplier.why_not(_ch(&"sell"), p) == "You have no die to spare." and _apply(&"sell", p, [Vector2i(0, 0)])[0].begins_with("refused"),
		"sell die: at the starting bag size the choice is greyed")
	p.add_die(&"mirror")
	var e0 := p.embers
	_check(EventApplier.picks_needed(_ch(&"sell")) == 1, "sell die: a picked sell needs one pick")
	_check(_apply(&"sell", p, [Vector2i(9, 0)])[0].begins_with("refused") and p.dice.size() == 6, "sell die: an invalid die pick changes nothing")
	var lines := _apply(&"sell", p, [Vector2i(5, 3)])
	_check(p.dice.size() == 5 and p.embers == e0 + 6 + 2 and lines[0].contains("Mirror Die"), "sell die: Mirror sells for half (6) + 2 bonus")
	_check(EventApplier.why_not(_ch(&"sell"), p) != "", "sell die: the last spare die gone, the bag can't drop below 5")
	var q := RunProgress.new(_run)
	q.add_die(&"d6")
	var e1 := q.embers
	_apply(&"sell", q, [Vector2i(2, 0)])
	_check(q.dice.size() == 5 and q.embers == e1 + 2, "sell die: a plain die sells for 0 (+ bonus); any die may be picked")
	var r := RunProgress.new(_run)
	r.add_die(&"mirror")
	r.add_die(&"cracked")
	var before: Array = []
	for d in r.dice:
		before.append(d.id)
	_apply(&"sell_random", r, [], 4)
	_check(r.dice.size() == 6 and EventApplier.picks_needed(_ch(&"sell_random")) == 0, "sell die: RANDOM needs no pick and removes one die")
	var a := RunProgress.new(_run)
	a.add_die(&"mirror")
	var two := EventChoiceData.new()
	for i in 2:
		var e := EventEffectData.new()
		e.kind = EventEffectData.Kind.SELL_DIE
		two.effects.append(e)
	_check(EventApplier.apply(two, a, RandomNumberGenerator.new(), [Vector2i(5, 0), Vector2i(5, 1)] as Array[Vector2i])[0].begins_with("refused"),
		"sell die: two sells can't pick the same die")


func _shop_run() -> MapRun:
	var run := MapRun.new(_run, 3)
	run.screen = S.SHOP
	run.shop_rerolls = 0
	run.progress.embers = 100
	return run


func _test_rerolls() -> void:
	var run := _shop_run()
	_apply(&"rerolls", run.progress)
	_apply(&"rerolls", run.progress)
	_check(run.progress.free_rerolls == 4, "rerolls: two grants of 2 stack to 4")
	_check(run.reroll_price() == 0, "rerolls: the shop reroll is free while any are banked")
	var stock: Array = run.shop_dice.duplicate()
	var changed := false
	for i in 4:
		_check(run.shop_reroll(), "rerolls: free reroll %d" % (i + 1))
		changed = changed or run.shop_dice != stock
	_check(run.progress.embers == 100 and run.progress.free_rerolls == 0 and run.shop_rerolls == 0, "rerolls: free ones cost nothing and don't raise the price step")
	_check(changed, "rerolls: a free reroll restocks the shop")
	_check(run.reroll_price() == _run.reroll_base and run.shop_reroll() and run.progress.embers == 100 - _run.reroll_base, "rerolls: then the normal price (3)")
	var map_run := MapRun.new(_run, 3)
	map_run.progress.free_rerolls = 1
	_check(not map_run.shop_reroll() and map_run.progress.free_rerolls == 1, "rerolls: kept until a shop (no use off the shop screen)")
	var p := RunProgress.new(_run)
	p.embers = 4
	_check(EventApplier.why_not(_ch(&"paid_reroll"), p) == "Not enough Embers.", "rerolls: a priced grant still checks its cost")


func _enter(run: MapRun, type: int) -> bool:
	for n: MapNode in run.map.nodes.values():
		if n.type == type:
			run.map.current_id = n.prev[0] if not n.prev.is_empty() else -1
			run.screen = S.MAP
			return run.choose_node(n.id)
	return false


func _test_twist() -> void:
	var cold: RunRuleData = load("res://resources/map/rules/cold_hands.tres")
	var run := MapRun.new(_run, 6)
	_apply(&"twist", run.progress)
	_check(run.progress.next_table_twist == cold, "twist: banked for the next table")
	_enter(run, NT.SHOP)
	_check(run.progress.next_table_twist == cold, "twist: a shop / event / rest doesn't use it up")
	_enter(run, NT.TABLE)
	var base_hands: int = run.floor_data().hands
	_check(run.rules == ([cold] as Array[RunRuleData]) and run.goal.hands == base_hands + cold.hands_delta, "twist: the next Table gets it (with its hands_delta)")
	var ids := run.table_setup().to_table_setup(load("res://resources/tuning/bonfire_tuning.tres")).rules
	_check(ids.size() == 1 and ids[0]["id"] == &"cold_hands", "twist: the table setup sends it as a rule")
	_check(run.progress.next_table_twist == null, "twist: cleared once that table starts")
	_enter(run, NT.TABLE)
	_check(run.rules.is_empty(), "twist: the table after has no twist")
	var el := MapRun.new(_run, 6)
	el.progress.next_table_twist = cold
	_enter(el, NT.ELITE)
	var has_twice := el.rules.count(cold) > 1
	_check(el.rules.has(cold) and not has_twice and el.progress.next_table_twist == null, "twist: on an Elite it adds to the Elite twist (never twice)")
	var bo := MapRun.new(_run, 6)
	bo.progress.next_table_twist = cold
	_enter(bo, NT.BOSS)
	_check(bo.rules.has(cold) and bo.rules.size() >= 2, "twist: a boss table gets it on top of the cheat")
	var rp := MapRun.new(_run, 6)
	var first := EventChoiceData.new()
	var e := EventEffectData.new()
	e.kind = EventEffectData.Kind.NEXT_TABLE_TWIST
	e.rule = load("res://resources/map/rules/greedy_pot.tres")
	first.effects.assign([e])
	EventApplier.apply(first, rp.progress, RandomNumberGenerator.new())
	_apply(&"twist", rp.progress)
	_enter(rp, NT.TABLE)
	_check(rp.rules == ([cold] as Array[RunRuleData]), "twist: a newer event twist replaces an unplayed one")


func _test_flow() -> void:
	var run := MapRun.new(_run, 2)
	run.screen = S.EVENT
	run.event = _ev
	var lines := run.choose_event(C[&"rerolls"])
	_check(not lines.is_empty() and run.screen == S.MAP and run.progress.free_rerolls == 2, "flow: MapRun.choose_event applies the effect and returns to the map")
	var view := EventView.new()
	var p := RunProgress.new(_run)
	p.add_die(&"mirror")
	view._progress = p
	var e: EventEffectData = _ch(&"sell").effects[0]
	_check(view._pick_allowed(e, Vector2i(5, 2), [] as Array[Vector2i]) and not view._pick_allowed(e, Vector2i(5, 3), [Vector2i(5, 0)] as Array[Vector2i])
		and not view._pick_allowed(e, Vector2i(9, 0), [] as Array[Vector2i]), "view: the sell picker takes any face of a die, never the same die twice")
	view.free()
