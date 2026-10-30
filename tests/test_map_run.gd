## Headless tests for MapRun (map/events spec §1): table goals per floor,
## Elite / Boss rewards, Seal pick or skip, boss re-sit, Rest, Shop prices,
## and a full seeded run through all 3 floors with the stub table.
##
## Run:
##   godot --headless --path . --script res://tests/test_map_run.gd
extends SceneTree

const NT := MapGenData.NodeType
const S := MapRun.Screen

var _passed: int = 0
var _failed: int = 0
var _data: RunData


func _initialize() -> void:
	print("=== Dice of the Damned: map run tests ===")
	_data = load("res://resources/map/bonfire_run.tres") as RunData
	_test_goals()
	_test_rewards()
	_test_boss()
	_test_rest_and_shop()
	_test_rules_and_seals()
	_test_rule_ids()
	_test_full_run()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	_data = null
	quit(1 if _failed > 0 else 0)


func _check(condition: bool, name: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", name)


## Jump straight into a node of `type` on the current floor (test shortcut).
func _enter(run: MapRun, type: int) -> bool:
	for n: MapNode in run.map.nodes.values():
		if n.type == type:
			run.map.current_id = n.prev[0] if not n.prev.is_empty() else -1
			run.screen = S.MAP
			return run.choose_node(n.id)
	return false


func _test_goals() -> void:
	# table_goals_v1 PR1: target tables, no bounties (test_table_goals.gd has the targets).
	var ok: Array[bool] = [true, true, true]
	for s in 40:
		var run := MapRun.new(_data, s)
		for f in 3:
			run._start_floor(f)
			_enter(run, NT.TABLE)
			var g := run.goal
			var fd: FloorData = _data.floors[f]
			ok[f] = ok[f] and g.required.is_empty() and g.bonus.is_empty() and g.hands == fd.hands and g.target == fd.target_table
	_check(ok[0], "goals: floor 1 tables: target, no bounties, 5 hands")
	_check(ok[1], "goals: floor 2 tables: target, no bounties, 4 hands")
	_check(ok[2], "goals: floor 3 tables: target, no bounties, 4 hands")
	var boss_ok := true
	for f in 3:
		var run := MapRun.new(_data, 5)
		run._start_floor(f)
		_enter(run, NT.BOSS)
		boss_ok = boss_ok and run.goal.required.is_empty() and run.goal.target == _data.floors[f].target_boss and run.goal.display_name == run.boss_name()
	_check(boss_ok, "goals: bosses have the floor's boss target, no bounties")
	var a := MapRun.new(_data, 9)
	var b := MapRun.new(_data, 9)
	_enter(a, NT.TABLE)
	_enter(b, NT.TABLE)
	_check(a.goal.target == b.goal.target and a.rules == b.rules, "goals: same seed -> same goal and rules")


func _test_rewards() -> void:
	var run := MapRun.new(_data, 2)
	_enter(run, NT.TABLE)
	run.quick_resolve(true)
	_check(run.screen == S.REWARD and run.seal_options.size() == 3 and run.dice_options.is_empty() and run.progress.embers == 14,
		"reward: cleared table pays 14 Embers, pick 1 of 3 Seals")
	run.seal_options[0] = &"trips"
	run.take_seal(0)
	_check(run.screen == S.MAP and run.progress.seal_level(&"trips") == 1, "reward: taking a Seal levels it")
	_enter(run, NT.TABLE)
	run.quick_resolve(true)
	var e: int = run.progress.embers
	run.take_seal(-1)
	_check(run.progress.embers == e + 3, "reward: skip for 3 Embers")
	_enter(run, NT.ELITE)
	_check(run.rules.size() == 1 and _data.floors[0].elite_twists.has(run.rules[0]), "elite: one twist from the pool")
	run.quick_resolve(true)
	_check(run.seal_options.size() == 4 and run.dice_options.size() == 2, "elite: 1 of 2 special dice + a 4-option Seal pick")
	_check(run.take_die(1) and run.progress.dice.size() == 6 and not run.take_die(0), "elite: take one die only")
	if run.is_rare_seal(run.seal_options[0]):
		run.seal_options[0] = &"pair"
	var soul: int = run.progress.soul
	run.take_seal(0)
	_enter(run, NT.TABLE)
	run.quick_resolve(false)
	_check(run.screen == S.MAP and run.progress.soul == soul - 5, "miss: back to the map, -5 Soul")


func _test_boss() -> void:
	var run := MapRun.new(_data, 4)
	_enter(run, NT.BOSS)
	run.quick_resolve(false)
	_check(run.screen == S.TABLE and run.boss_misses == 1, "boss: a miss gives one re-sit")
	run.progress.soul = 35
	run.quick_resolve(false)
	_check(run.screen == S.RUN_OVER, "boss: a second miss ends the run")
	var win := MapRun.new(_data, 4)
	_enter(win, NT.BOSS)
	win.quick_resolve(true)
	var rare: bool = win.is_rare_seal(win.seal_options[win.seal_options.size() - 1])
	_check(win.progress.embers == 14 + 25 and win.progress.contract_pieces == 1 and rare and win.seal_options.size() == 4,
		"boss: 25 Embers, a contract piece, Seal pick with a guaranteed rare")
	_check(win.progress.max_soul == 40 and win.progress.soul == 40, "boss: contract piece +5 max Soul, heals to full")
	win.seal_options[0] = &"pair"
	win.take_seal(0)
	_check(win.floor_index == 1 and win.screen == S.MAP and win.map.current_id == -1, "boss: clearing it opens the next floor")


func _test_rest_and_shop() -> void:
	var run := MapRun.new(_data, 6)
	run.progress.soul = 30
	_enter(run, NT.REST)
	_check(not run.rest_seal(&"pair"), "rest: +1 Seal needs a Seal you own")
	_check(run.rest_heal() and run.progress.soul == 35 and run.screen == S.MAP, "rest: heal 12 (clamped to 35)")
	_enter(run, NT.REST)
	_check(run.rest_mod != null and run.rest_carve(Vector2i(0, 0)) and run.progress.dice[0].faces[0] == run.rest_mod.id,
		"rest: carve a free face mod on the picked face")
	run.progress.add_seal_levels(&"pair", 1)
	_enter(run, NT.REST)
	_check(run.rest_seal(&"pair") and run.progress.seal_level(&"pair") == 2, "rest: +1 level on an owned Seal")
	_enter(run, NT.SHOP)
	_check(run.shop_dice.size() == 2 and run.shop_mods.size() == 2 and run.shop_seals.size() == 2, "shop: 2 dice, 2 mods, 2 Seals")
	run.progress.embers = 100
	var die_price: int = run.shop_dice[0].price
	_check(run.buy_die(0) and run.progress.embers == 100 - die_price, "shop: special die at its own price")
	var mod: FaceModData = run.shop_mods[0]
	run.progress.set_face(3, 0, &"wild")
	var before: int = run.progress.embers
	_check(run.buy_mod(0, Vector2i(3, 1)) and run.progress.embers == before - mod.price * 3 / 2, "shop: mod +50% with a mod already on the die")
	before = run.progress.embers
	_check(run.sell_die(5) and run.progress.embers == before + die_price / 2 and run.progress.dice.size() == 5, "shop: sell a special die for half")
	run.progress.add_die(&"")
	var e0 := run.progress.embers
	_check(run.progress.sell_value(5) == 0 and run.sell_die(5) and run.progress.dice.size() == 5 and run.progress.embers == e0,
		"shop: a 0-Ember sale still sells and returns true")
	# Escalated mod price: greyed / picker by the die's price, not the base.
	var hell: FaceModData = load("res://resources/mods/hellfire.tres")
	run.shop_mods[0] = hell
	for f in 4:
		run.progress.set_face(4, f, &"wild")
	run.progress.embers = hell.price
	_check(run.can_buy_mod_at(0, Vector2i(2, 5)) and not run.can_buy_mod_at(0, Vector2i(4, 5)), "shop: a die with mods costs more; can't afford it there")
	_check(run.cheapest_mod_price(0) == hell.price, "shop: cheapest price over dice with a free face")
	for d in 5:
		run.progress.set_face(d, 5, &"wild")
	_check(run.cheapest_mod_price(0) > hell.price and not run.can_buy_mod_at(0, Vector2i(2, 4)), "shop: every die has a mod -> escalated price, unaffordable")
	run.progress.embers = 0
	_check(not run.shop_reroll(), "shop: can't reroll broke")
	run.progress.embers = 100
	_check(run.reroll_price() == 3 and run.shop_reroll() and run.reroll_price() == 5 and run.progress.embers == 97, "shop: reroll 3, then 5 (step 2)")
	run.shop_seals = [&"pair", &"trips"] as Array[StringName]
	_check(run.buy_seal(0) and run.progress.embers == 92 and run.seal_price(&"trips") == 7, "shop: Seal 5, next one 7 (step 2)")
	run.shop_mods[1] = load("res://resources/mods/hellfire.tres")
	_check(run.buy_mod(1, Vector2i(1, 1)) and run.progress.dice[1].faces[1] == &"hellfire" and not run.buy_mod(1, Vector2i(2, 2)), "shop: buy a face mod once")
	run.leave()
	_check(run.screen == S.MAP, "shop: leave back to the map")


## Walk every floor: always the first reachable node, first allowed event
## choice, heal at rests, stub-clear tables, take the first Seal.
func _play(seed_value: int) -> MapRun:
	var run := MapRun.new(_data, seed_value)
	for step in 200:
		match run.screen:
			S.MAP:
				run.choose_node(run.map.reachable()[0])
			S.TABLE:
				run.quick_resolve(true)
			S.REWARD:
				if not run.take_seal(0):
					run.take_seal(-1)
			S.EVENT:
				for i in run.event.choices.size():
					var c := run.event.choices[i]
					if EventApplier.can_choose(c, run.progress):
						var picks: Array[Vector2i] = []
						for k in EventApplier.picks_needed(c):
							picks.append(Vector2i(k, 0) if not c.requires_face_mod else run.progress.modded_faces()[0])
						if not run.choose_event(i, picks).is_empty() and run.screen != S.EVENT:
							break
			S.SHOP, S.REST:
				if run.screen == S.REST:
					run.rest_heal()
				else:
					run.leave()
			_:
				break
	return run


func _test_rules_and_seals() -> void:
	var f1: FloorData = _data.floors[0]
	_check(f1.elite_twists.size() == 4 and f1.boss_cheats.size() == 3 and _data.floors[2].boss_cheats.size() == 3
		and not _data.floors[2].boss_adds_twist and not f1.boss_adds_twist, "rules: 4 twists; 3 bosses on every floor (Floor 3: Wick, Vig, Bodkin)")
	var run := MapRun.new(_data, 8)
	_check(f1.boss_cheats.has(run.boss) and run.boss_twist == null, "rules: floor 1 boss drawn from its pool on entering the floor")
	var short: RunRuleData = load("res://resources/map/rules/short_table.tres")
	var heavy: RunRuleData = load("res://resources/map/rules/heavy_burn.tres")
	_enter(run, NT.ELITE)
	run.rules = [short, heavy] as Array[RunRuleData]
	var setup := run.table_setup()
	var g := run.goal
	_check(setup.bust_soul_loss == 3 and setup.rule_ids() == ([&"short_table", &"heavy_burn"] as Array[StringName]), "rules: Heavy Toll sets bust 3; ids passed in the setup")
	var hands_ok: bool = false
	for s in 30:
		var r2 := MapRun.new(_data, s)
		_enter(r2, NT.ELITE)
		hands_ok = r2.rules.size() == 1 and r2.goal.hands == _data.floors[0].hands + r2.rules[0].hands_delta and r2.rules[0].hands_delta == 1
		if not hands_ok:
			break
	_check(hands_ok, "rules: every Elite twist gives +1 hand (6 on floor 1)")
	_check(setup.dice.size() == 5 and setup.start_soul == run.progress.soul and setup.max_soul == 35 and setup.goal == g, "setup: dice, Soul, goal")
	var base: BonfireTuning = load("res://resources/tuning/bonfire_tuning.tres")
	run.progress.add_seal_levels(&"pair", 1)
	run.progress.set_face(0, 3, &"hellfire")
	var ts := run.table_setup().to_table_setup(base)
	var t := ts.tuning
	_check(t.bust_soul_loss == 3 and t.table_goal == g and t.combos[1].mult == base.combos[1].mult + 1, "TableSetup: Seal-leveled tuning with the bust cost")
	_check(ts.dice.size() == 5 and ts.dice[0].mod_at(4).id == &"hellfire" and ts.goal == g and ts.run_mode
		and ts.starting_soul == run.progress.soul and ts.max_soul == run.progress.max_soul and ts.table_seed == run.table_setup().seed_value,
		"TableSetup: dice with mods, goal, starting / max Soul, seed, run mode")
	# Outcomes from Bonfire3D.finished.
	var o := TableOutcome.new()
	o.banked_combos = [&"trips", &"pair", &"trips"] as Array[StringName]
	o.cleared = true
	o.soul_after = run.progress.soul - 2
	o.embers = 17
	var e0 := run.progress.embers
	var s0 := run.progress.soul
	run.apply_outcome(o)
	_check(run.screen == S.REWARD and run.progress.embers == e0 + 17 and run.progress.soul == s0 - 2, "outcome: cleared -> Soul / Embers applied, Seal reward")
	_check(run.progress.banked.get(&"trips", 0) == 2 and run.progress.banked.get(&"pair", 0) == 1 and run.progress.most_banked() == &"trips",
		"outcome: banked_combos counted per pot -> Black Seal target")
	var rb := MapRun.new(_data, 8)
	_enter(rb, NT.BOSS)
	var bo := TableOutcome.new()
	bo.forfeited = true
	bo.soul_after = rb.progress.soul - 9
	rb.apply_outcome(bo)
	_check(rb.screen == S.TABLE and rb.boss_misses == 1 and rb.progress.soul == 26, "outcome: boss forfeit -> -9 Soul and a re-sit")
	rb.apply_outcome(bo)
	_check(rb.screen == S.RUN_OVER, "outcome: a second boss miss ends the run")
	var rc := MapRun.new(_data, 8)
	rc.progress.add_die(&"cracked")
	rc.progress.set_face(5, 0, &"wild")
	_enter(rc, NT.TABLE)
	var plain := TableOutcome.new()
	plain.cleared = true
	plain.soul_after = rc.progress.soul
	rc.apply_outcome(plain)
	_check(rc.progress.dice.size() == 6, "outcome: nothing shattered -> handful unchanged")
	rc.take_seal(-1)
	_enter(rc, NT.TABLE)
	var cracked_id: StringName = rc.progress.dice[5].id
	var sh := TableOutcome.new()
	sh.cleared = true
	sh.soul_after = rc.progress.soul
	sh.shattered_dice = [cracked_id] as Array[StringName]
	rc.apply_outcome(sh)
	_check(rc.progress.dice.size() == 5 and rc.progress.die_index(cracked_id) == -1 and rc.progress.modded_faces().is_empty()
		and rc.screen == S.REWARD, "outcome: a shattered Cracked die leaves the bag with its face mods")
	var r3 := MapRun.new(_data, 8)
	r3.progress.record_bank(&"run3")
	_check(r3.seal_usable(&"black") and not r3.seal_usable(&"ashen", {"from": &"pair", "to": &"trips"}), "seals: Black needs a banked combo, Ashen a levelled one")
	r3.progress.add_seal_levels(&"pair", 2)
	_check(r3._grant_seal(&"ashen", {"from": &"pair", "to": &"trips"}) and r3.progress.seal_level(&"trips") == 2, "seals: Ashen through MapRun")
	_check(r3._grant_seal(&"transference", {"from": &"trips", "to": &"quads"}) and r3.progress.seal_bonus(&"quads").y == 2, "seals: Transference through MapRun")


## Every rule id the run can emit is one the table knows, with the agreed
## default params, sent to TableSetup.rules as {"id", "params"}.
func _test_rule_ids() -> void:
	var allowed := {}
	for pair in [[&"cold_sixes", {"face": 6}], [&"first_throw", {"throws": 2}], [&"first_throw", {"throws": 1}],
			[&"greedy_pot", {"min_pot": 2}], [&"greedy_pot", {"min_pot": 3}],
			[&"cold_hands", {}], [&"pit_boss", {"faces": [2, 3, 4, 5, 6]}], [&"madame_shuffle_stopgap", {"faces": [2, 4]}],
			[&"ashmouth", {}], [&"mister_wick", {"face": 6}], [&"baron_vig", {"min_pot": 3}], [&"odds_bodkin", {"throws": 1}], [&"straight_man", {"min_run": 4}], [&"collector", {"throws": 1}], [&"bloodletter", {"soul_cost_mult": 2}]]:
		if not allowed.has(pair[0]):
			allowed[pair[0]] = []
		allowed[pair[0]].append(str(pair[1]))
	var emitted: Array[RunRuleData] = []
	for f: FloorData in _data.floors:
		for r in f.elite_twists + f.boss_cheats:
			if not emitted.has(r):
				emitted.append(r)
	var ok := emitted.size() == 13
	for r in emitted:
		if not allowed.has(r.id) or not str(r.params) in allowed[r.id]:
			ok = false
			print("  bad rule: ", r.id, " ", r.params)
	_check(ok, "rules: all 13 emitted rules (Wick/Vig/Bodkin reuse twist ids, Madame Shuffle pit_boss) are the table's ids, with the agreed params")
	var base: BonfireTuning = load("res://resources/tuning/bonfire_tuning.tres")
	var seen_ids: Dictionary = {}
	for s in 30:
		var run := MapRun.new(_data, s)
		for t in [NT.ELITE, NT.BOSS]:
			_enter(run, t)
			for e: Dictionary in run.table_setup().to_table_setup(base).rules:
				seen_ids[e["id"]] = true
				var keys_ok: bool = e.keys().size() == 2 or (e.keys().size() == 3 and e.has("description") and not str(e["description"]).contains("{"))
				ok = ok and keys_ok and allowed.has(e["id"]) and str(e["params"]) in allowed[e["id"]]
	_check(ok and seen_ids.size() >= 6, "rules: TableSetup.rules entries are {id, params} (+ a filled-in description for {hands} text) with known ids (%d seen)" % seen_ids.size())
	var r2 := MapRun.new(_data, 3)
	r2.progress.add_die(&"cracked")
	_enter(r2, NT.TABLE)
	var st := r2.table_setup()
	st.table_dice.resize(5)
	var ts := st.to_table_setup(base)
	_check(st.owned_dice_count == 6 and ts.owned_dice_count == 6 and ts.dice.size() == 5,
		"setup: owned_dice_count = every die owned (6), even with 5 brought to the table")


func _test_full_run() -> void:
	var run := _play(77)
	_check(run.screen == S.RUN_WON and run.floor_index == 2, "run: a seeded run clears all 3 floors")
	_check(run.progress.contract_pieces == 3 and run.progress.max_soul == 50, "run: one contract piece per boss, +5 max Soul each")
	var again := _play(77)
	_check(again.progress.embers == run.progress.embers and again.progress.seal_levels == run.progress.seal_levels,
		"run: same seed -> same run")
	var wins: int = 0
	for s in 20:
		if _play(s).screen == S.RUN_WON:
			wins += 1
	_check(wins == 20, "run: every seed reaches the final boss (stub tables)")
