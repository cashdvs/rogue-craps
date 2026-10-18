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
	var ok: Array[bool] = [true, true, true]
	for s in 40:
		var run := MapRun.new(_data, s)
		for f in 3:
			run._start_floor(f)
			_enter(run, NT.TABLE)
			var g := run.goal
			var fd: FloorData = _data.floors[f]
			var n: int = g.required.size()
			var good: bool = n >= fd.min_bounties and n <= fd.max_bounties and g.hands == fd.hands and g.bonus.size() == 1
			if not fd.featured_bounties.is_empty():
				var has: bool = false
				for b in g.required:
					has = has or fd.featured_bounties.has(b)
				good = good and has
			ok[f] = ok[f] and good
	_check(ok[0], "goals: floor 1 tables have 3 bounties, 5 hands, 1 bonus")
	_check(ok[1], "goals: floor 2 has 3-4 incl. Run of 4 or Full House, 5 hands")
	_check(ok[2], "goals: floor 3 has 4 incl. Quads or Run of 5, 6 hands")
	var run := MapRun.new(_data, 5)
	_enter(run, NT.BOSS)
	_check(run.goal.required.size() >= 4 and run.goal.required.size() <= 5 and run.goal.display_name == run.boss_name(),
		"goals: boss has 4-5 bounties")
	var a := MapRun.new(_data, 9)
	var b := MapRun.new(_data, 9)
	_enter(a, NT.TABLE)
	_enter(b, NT.TABLE)
	_check(a.goal.required == b.goal.required, "goals: same seed -> same bounties")


func _test_rewards() -> void:
	var run := MapRun.new(_data, 2)
	_enter(run, NT.TABLE)
	run.quick_resolve(true)
	_check(run.screen == S.REWARD and run.seal_options.size() == 3 and run.dice_options.is_empty() and run.progress.embers == 10,
		"reward: cleared table pays 10 Embers, pick 1 of 3 Seals")
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
	_check(run.screen == S.MAP and run.progress.soul == soul - 9, "miss: back to the map, -3 Soul per unbanked bounty")


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
	_check(win.progress.embers == 10 + 25 and win.progress.contract_pieces == 1 and rare and win.seal_options.size() == 4,
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
	run.progress.embers = 0
	_check(not run.shop_reroll(), "shop: can't reroll broke")
	run.progress.embers = 100
	_check(run.reroll_price() == 3 and run.shop_reroll() and run.reroll_price() == 4 and run.progress.embers == 97, "shop: reroll 3, then 4")
	run.shop_seals = [&"pair", &"trips"] as Array[StringName]
	_check(run.buy_seal(0) and run.progress.embers == 92 and run.seal_price(&"trips") == 6, "shop: Seal 5, next one 6")
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
	_check(f1.elite_twists.size() == 6 and f1.boss_cheats.size() == 3 and _data.floors[2].boss_cheats.size() == 6
		and _data.floors[2].boss_adds_twist and not f1.boss_adds_twist, "rules: 6 twists; 3 bosses on floors 1-2, all 6 + a twist on floor 3")
	var run := MapRun.new(_data, 8)
	_check(f1.boss_cheats.has(run.boss) and run.boss_twist == null, "rules: floor 1 boss drawn from its pool on entering the floor")
	var short: RunRuleData = load("res://resources/map/rules/short_table.tres")
	var heavy: RunRuleData = load("res://resources/map/rules/heavy_burn.tres")
	_enter(run, NT.ELITE)
	run.rules = [short, heavy] as Array[RunRuleData]
	var setup := run.table_setup()
	var g := run.goal
	_check(setup.bust_soul_loss == 3 and setup.rule_ids() == ([&"short_table", &"heavy_burn"] as Array[StringName]), "rules: Heavy Burn sets bust 3; ids passed in the setup")
	var hands_ok: bool = false
	for s in 30:
		var r2 := MapRun.new(_data, s)
		_enter(r2, NT.ELITE)
		if r2.rules[0] == short:
			hands_ok = r2.goal.hands == 4
			break
	_check(hands_ok, "rules: Short Table -> 4 hands")
	_check(setup.dice.size() == 5 and setup.start_soul == run.progress.soul and setup.max_soul == 35 and setup.goal == g, "setup: dice, Soul, goal")
	var base: BonfireTuning = load("res://resources/tuning/bonfire_tuning.tres")
	run.progress.add_seal_levels(&"pair", 1)
	var t := run.table_setup().to_tuning(base)
	_check(t.bust_soul_loss == 3 and t.table_goal == g and t.combos[1].mult == base.combos[1].mult + 1, "setup: tuning copy for the 3D table")
	var r3 := MapRun.new(_data, 8)
	r3.progress.record_bank(&"run3")
	_check(r3.seal_usable(&"black") and not r3.seal_usable(&"ashen", {"from": &"pair", "to": &"trips"}), "seals: Black needs a banked combo, Ashen a levelled one")
	r3.progress.add_seal_levels(&"pair", 2)
	_check(r3._grant_seal(&"ashen", {"from": &"pair", "to": &"trips"}) and r3.progress.seal_level(&"trips") == 2, "seals: Ashen through MapRun")
	_check(r3._grant_seal(&"transference", {"from": &"trips", "to": &"quads"}) and r3.progress.seal_bonus(&"quads").y == 2, "seals: Transference through MapRun")


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
