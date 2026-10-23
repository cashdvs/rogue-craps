## Headless tests for run_tuning_v1: floor 2/3 table data, the Floor 3 boss
## pool (Mister Wick, Baron Vig, Odds Bodkin), the Elite twist cut (no Short
## Table / Heavy Toll), and the Floor 1/2 boss bounty counts. Split out of
## test_map_run.gd so that file stays under ~400 lines.
##
## Run:
##   godot --headless --path . --script res://tests/test_run_tuning.gd
extends SceneTree

const NT := MapGenData.NodeType

var _passed: int = 0
var _failed: int = 0
var _data: RunData


func _initialize() -> void:
	print("=== Dice of the Damned: run tuning tests ===")
	_data = load("res://resources/map/bonfire_run.tres") as RunData
	_test_tuning_v1()
	_test_tuning_addendum()
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
			run.screen = MapRun.Screen.MAP
			return run.choose_node(n.id)
	return false


## Resource-path basenames of every rule in `a` (order preserved).
func _rule_names(a: Array) -> Array:
	var out: Array = []
	for r in a:
		out.append(r.resource_path.get_file().get_basename())
	return out


## Bounty ids of every bounty in `a` (order preserved).
func _bounty_ids(a: Array) -> Array:
	var out: Array = []
	for b in a:
		out.append(b.id)
	return out


## run_tuning_v1: floor 2/3 data and the Mister Wick boss.
func _test_tuning_v1() -> void:
	var f1: FloorData = _data.floors[0]
	var f2: FloorData = _data.floors[1]
	var f3: FloorData = _data.floors[2]
	_check(f1.clear_embers == 10 and f1.hands == 5, "tuning v1: floor 1 unchanged")
	_check(f2.max_bounties == 3 and _bounty_ids(f2.featured_bounties) == [&"run4"] and f2.clear_embers == 12
		and f2.bonus_bounties.size() == 2 and f2.bonus_bounties.all(func(b): return b.bonus_embers == 6),
		"tuning v1: floor 2 max 3, featured Run of 4, clear 12, bonuses 6")
	_check(f2.hands == 4 and f2.boss_hands == 5 and f3.boss_hands == 5 and f1.boss_hands == 7,
		"addendum 4 (Nerve): floors 2/3 hands 4, boss_hands 5; floor 1 boss 7 unchanged")
	var fh: BountyData = f3.bonus_bounties[0] if f3.bonus_bounties.size() > 0 else null
	_check(f3.hands == 4 and _bounty_ids(f3.featured_bounties) == [&"run4"] and f3.clear_embers == 14
		and _bounty_ids(f3.bonus_bounties) == [&"bonus_full_house", &"bonus_quads"]
		and fh.kind == BountyData.Kind.FULL_HOUSE and fh.n == 5
		and f3.bonus_bounties.all(func(b): return b.bonus_embers == 8),
		"tuning v1: floor 3 hands 4 (Nerve retune), featured Run of 4, clear 14, bonus Full House/Quads at 8")
	_check(f3.boss_bounties.is_empty() and f3.boss_min_bounties == 4 and f3.boss_max_bounties == 4 and not f3.boss_adds_twist,
		"tuning v1: floor 3 boss draws 4 from the floor pool, no twist")
	var wick: RunRuleData = f3.boss_cheats[0]
	_check(wick.resource_path.ends_with("mister_wick.tres") and wick.id == &"mister_wick" and wick.display_name == "Mister Wick"
		and wick.kind == RunRuleData.Kind.CHEAT and wick.bust_soul_loss == 2 and str(wick.params) == str({"face": 6}),
		"tuning v1: Mister Wick is a mister_wick cheat, face 6, bust costs 2")
	var base: BonfireTuning = load("res://resources/tuning/bonfire_tuning.tres")
	var ok := true
	var saw_wick := false
	for s in 40:
		var run := MapRun.new(_data, s)
		run._start_floor(2)
		_enter(run, NT.BOSS)
		if run.boss.display_name != "Mister Wick":
			continue
		saw_wick = true
		var ts: TableSetup = run.table_setup().to_table_setup(base)
		ok = ok and ts.rules.size() == 1 and ts.rules[0]["id"] == &"mister_wick" and ts.tuning.bust_soul_loss == 2 and run.goal.required.size() == 4
	_check(saw_wick and ok, "tuning v1: Mister Wick's table is mister_wick, bust_soul_loss 2, 4 bounties")
	_test_tuning_addendum_2()


## run_tuning_v1 addendum 2: Floor 3 boss pool (Wick, Vig, Bodkin).
func _test_tuning_addendum_2() -> void:
	var f3: FloorData = _data.floors[2]
	var names := _rule_names(f3.boss_cheats)
	var ids: Array = []
	for r in f3.boss_cheats:
		ids.append(r.id)
	_check(f3.boss_cheats.size() == 3 and names == ["mister_wick", "baron_vig", "odds_bodkin"]
		and ids == [&"mister_wick", &"baron_vig", &"odds_bodkin"]
		and f3.boss_cheats[0].display_name == "Mister Wick"
		and f3.boss_cheats[1].display_name == "Baron Vig"
		and f3.boss_cheats[2].display_name == "Odds Bodkin",
		"addendum 2: Floor 3 boss pool = Mister Wick, Baron Vig, Odds Bodkin")
	var vig: RunRuleData = f3.boss_cheats[1]
	var bod: RunRuleData = f3.boss_cheats[2]
	_check(vig.kind == RunRuleData.Kind.CHEAT and str(vig.params) == str({"min_pot": 3}) and vig.hands_delta == -1
		and bod.kind == RunRuleData.Kind.CHEAT and str(bod.params) == str({"throws": 1}) and bod.hands_delta == 1,
		"addendum 2/4: Vig min_pot 3 / hands_delta -1, Bodkin throws 1 / hands_delta +1")
	var seen: Dictionary = {}
	var hok := true
	for s in 200:
		var run := MapRun.new(_data, s)
		run._start_floor(2)
		_enter(run, NT.BOSS)
		var n: String = run.boss.display_name
		seen[n] = true
		var want_h: int = {"Odds Bodkin": 6, "Mister Wick": 5, "Baron Vig": 4}.get(n, -1)
		hok = hok and run.goal.hands == want_h and run.goal.required.size() == 4 and run.rules.size() == 1
	_check(seen.has("Mister Wick") and seen.has("Baron Vig") and seen.has("Odds Bodkin") and seen.size() == 3,
		"addendum 2: all 3 Floor 3 bosses appear across 200 seeds (%d seen)" % seen.size())
	_check(hok, "addendum 4: Odds Bodkin boss tables have 6 hands, Wick 5, Vig 4")


## run_tuning_v1 addendum: Floor 1/2 bosses and the Elite twists.
func _test_tuning_addendum() -> void:
	var f1: FloorData = _data.floors[0]
	var f2: FloorData = _data.floors[1]
	var f3: FloorData = _data.floors[2]
	var four := ["cold_sixes", "first_throw", "greedy_pot", "cold_hands"]
	_check(_rule_names(f1.elite_twists) == four and _rule_names(f2.elite_twists) == four and _rule_names(f3.elite_twists) == four,
		"addendum: every floor's Elites = Cold Sixes, First Throw, Greedy Pot, Cold Hands (no Short Table / Heavy Toll)")
	_check(f1.boss_bounties.is_empty() and f1.boss_min_bounties == 3 and f1.boss_max_bounties == 3, "addendum: floor 1 boss draws 3 from the floor pool")
	var x2: BountyData = f2.boss_bounties[0] if f2.boss_bounties.size() == 1 else null
	_check(x2 != null and x2.id == &"two_pairs_x2" and x2.kind == BountyData.Kind.TWO_PAIR and x2.n == 2 and x2.count_needed == 2
		and x2.display_name == "Two Pair x2" and f2.boss_min_bounties == 5 and f2.boss_max_bounties == 5, "addendum: floor 2 boss pool = Two Pair x2, 5 bounties")
	var ok := true
	for s in 10:
		var run := MapRun.new(_data, s)
		run._start_floor(1)
		_enter(run, NT.BOSS)
		var ids: Array = []
		for b in run.goal.required:
			ids.append(b.id)
		ids.sort()
		var want: Array = [&"run3", &"run4", &"triple", &"two_pairs", &"two_pairs_x2"]
		want.sort()
		ok = ok and ids == want
	_check(ok, "addendum: floor 2 boss draws Run of 4, the 3 commons and Two Pair x2")
	var want_r := {"ashmouth": [-1, "No Hot Hand, and you get one fewer hand."], "cold_sixes": [1, "6s never light, but you get +1 hand."],
		"first_throw": [1, "Bounties count only on each hand's first 2 throws; +1 hand."],
		"greedy_pot": [1, "Pot at least 2 dice every throw, but you get +1 hand."], "cold_hands": [1, "No Hot Hand, but you get +1 hand."],
		"straight_man": [0, "Runs of 3 don't count; runs of 4 or 5 still do."], "bloodletter": [0, "Every Soul cost is doubled: a bust costs 2 Soul."],
		"madame_shuffle": [0, "Each hand, a 2 or a 4 never lights."]}
	var rok := true
	for n in want_r:
		var r: RunRuleData = load("res://resources/map/rules/%s.tres" % n)
		if r.hands_delta != want_r[n][0] or r.description != want_r[n][1]:
			rok = false
			print("  rule mismatch: ", n)
	_check(rok, "addendum: rule hands_delta and descriptions")
	var ms: RunRuleData = load("res://resources/map/rules/madame_shuffle.tres")
	_check(ms.id == &"pit_boss" and ms.display_name == "Madame Shuffle" and ms.kind == RunRuleData.Kind.CHEAT and str(ms.params) == str({"faces": [2, 4]}),
		"addendum: Madame Shuffle is an interim pit_boss on faces 2 and 4")
	_check(str(ms.get_meta("stopgap", "")).contains("pit_boss") and str(ms.get_meta("stopgap", "")).contains("madame_shuffle"),
		"addendum: Madame Shuffle's .tres marks the pit_boss stopgap")
	var fs: RunRuleData = load("res://resources/map/rules/first_throw.tres")
	var sm: RunRuleData = load("res://resources/map/rules/straight_man.tres")
	_check(str(fs.params) == str({"throws": 2}) and str(sm.params) == str({"min_run": 4}), "addendum: First Throw 2 throws, Straight Man min_run 4")
	var base: BonfireTuning = load("res://resources/tuning/bonfire_tuning.tres")
	var hok := true
	for s in 20:
		var run := MapRun.new(_data, s)
		_enter(run, NT.BOSS)
		var ts: TableSetup = run.table_setup().to_table_setup(base)
		var want_h: int = f1.boss_hands + run.rules[0].hands_delta
		hok = hok and run.goal.hands == want_h
		for e: Dictionary in ts.rules:
			hok = hok and not (e["params"] as Dictionary).has("hands_delta")
	_check(hok, "addendum: hands_delta applies run-side (Ashmouth boss 6 hands), never in table params")
	_test_tuning_addendum_3()


## run_tuning_v1 addendum 3 (M7): Floor 1 boss hands 7, Pit Boss faces 2-6.
func _test_tuning_addendum_3() -> void:
	var f1: FloorData = _data.floors[0]
	_check(f1.boss_hands == 7 and f1.boss_min_bounties == 3 and f1.boss_max_bounties == 3,
		"addendum 3: Floor 1 boss_hands 7, still 3 bounties")
	var pb: RunRuleData = load("res://resources/map/rules/pit_boss.tres")
	_check(pb.id == &"pit_boss" and str(pb.params) == str({"faces": [2, 3, 4, 5, 6]})
		and pb.description == "Each hand, one number from 2 to 6 never lights.",
		"addendum 3: Pit Boss face pool is 2-6")
	var hok := true
	var saw_ash := false
	var saw_other := false
	for s in 40:
		var run := MapRun.new(_data, s)
		_enter(run, NT.BOSS)
		var want_h: int = 6 if run.boss.id == &"ashmouth" else 7
		hok = hok and run.goal.hands == want_h and run.goal.hands == f1.boss_hands + run.rules[0].hands_delta
		if run.boss.id == &"ashmouth":
			saw_ash = true
		else:
			saw_other = true
	_check(saw_ash and saw_other and hok,
		"addendum 3: Floor 1 Ashmouth boss tables have 6 hands, Pit Boss / Madame have 7")
