## Headless tests for Table goals PR1 (design/handoff/table_goals_v1_pr1.md
## §1-§3): target-only tables, pass on banked points, flat miss Soul, boss
## re-sit, per-floor data, the points cap and TableGoalState.
##
## Run:
##   godot --headless --path . --script res://tests/test_table_goals.gd
extends SceneTree

const NT := MapGenData.NodeType
const S := MapRunState.Screen

var _passed := 0
var _failed := 0
var _data: RunData
var _tuning: BonfireTuning


func _initialize() -> void:
	print("=== Dice of the Damned: table goals PR1 tests ===")
	_data = load("res://resources/map/bonfire_run.tres") as RunData
	_tuning = load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	_test_data()
	_test_pass()
	_test_miss()
	_test_map_flow()
	_test_rules()
	_test_state()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	_data = null
	_tuning = null
	quit(1 if _failed > 0 else 0)


func _check(c: bool, what: String) -> void:
	if c:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


## Jump straight into a node of `type` on the current floor.
func _enter(run: MapRun, type: int) -> bool:
	for n: MapNode in run.map.nodes.values():
		if n.type == type:
			run.map.current_id = n.prev[0] if not n.prev.is_empty() else -1
			run.screen = S.MAP
			return run.choose_node(n.id)
	return false


func _goal(target: int, hands: int = 3, boss := false) -> TableGoal:
	var g := TableGoal.new()
	g.target = target
	g.hands = hands
	g.clear_embers = 14
	g.miss_soul = 5
	g.is_boss = boss
	return g


## Bank a pair of 4s (a real throw, pot and bank). Returns the bank result.
func _bank_pair(r: BonfireRun) -> Dictionary:
	r.set_throw([4, 4, 1, 2, 6])
	if r.bust_pending:  # a rule (e.g. Pit Boss) can make it a bust
		r.confirm_bust()
		return {}
	r.toggle(0)
	r.toggle(1)
	return r.bank()



## The gain of one _bank_pair on a fresh run (for exact-target checks).
func _pair_gain() -> int:
	var r := BonfireRun.new(_tuning, _goal(100000), 30, 5)
	_bank_pair(r)
	return r.points


func _test_data() -> void:
	var want := [[300, 400, 700, 14], [1000, 1300, 2500, 16], [2500, 3000, 3500, 18]]
	for f in 3:
		var fd: FloorData = _data.floors[f]
		_check([fd.target_table, fd.target_elite, fd.target_boss, fd.clear_embers] == want[f] and fd.miss_soul == 5,
			"data: floor %d targets %s and clear Embers" % [f + 1, want[f]])
		var run := MapRun.new(_data, 11)
		run._start_floor(f)
		for t in [NT.TABLE, NT.ELITE, NT.BOSS]:
			_enter(run, t)
			var g := run.goal
			var tw: int = want[f][[NT.TABLE, NT.ELITE, NT.BOSS].find(t)]
			_check(g.required.is_empty() and g.bonus.is_empty() and g.target == tw and g.miss_soul == 5
				and g.clear_embers == want[f][3] and g.is_boss == (t == NT.BOSS),
				"make_goal: floor %d type %d -> target %d, no bounties" % [f + 1, t, tw])
	var f0: FloorData = _data.floors[0]
	f0.miss_soul = 7
	var m := MapRun.new(_data, 11)
	_enter(m, NT.TABLE)
	f0.miss_soul = 5
	_check(m.goal.miss_soul == 7, "make_goal: miss_soul comes from the floor")
	_check(_tuning.points_embers_cap == 6 and BonfireRun.points_to_embers(_tuning, 5000) == 6 and BonfireRun.points_to_embers(_tuning, 500) == 5,
		"cap: points pay up to 6 Embers per table")


func _test_pass() -> void:
	var gain := _pair_gain()
	_check(gain > 0, "pass: a pair bank scores (%d)" % gain)
	var r := BonfireRun.new(_tuning, _goal(gain * 2), 30, 5)
	var e0 := r.embers
	_bank_pair(r)
	_check(not r.cleared and not r.can_leave(), "pass: under the target, not passed and can't leave")
	r.points = gain * 2 - gain - 1  # one short after the next bank
	var res := _bank_pair(r)
	_check(not r.cleared and not res["cleared_now"], "pass: target - 1 does not pass")
	var x := BonfireRun.new(_tuning, _goal(gain * 2), 30, 5)
	x.points = gain
	res = _bank_pair(x)
	_check(x.points == gain * 2 and x.cleared and res["cleared_now"] and x.can_leave(), "pass: banking exactly the target passes, Leave unlocks")
	_check(x.embers - e0 == 14, "pass: clear Embers paid on the pass (%d)" % (x.embers - e0))
	res = _bank_pair(x)
	_check(x.cleared and not res["cleared_now"] and x.embers - e0 == 14, "pass: clear Embers paid once")
	# A bust keeps banked points and the target.
	var b := BonfireRun.new(_tuning, _goal(gain * 5), 30, 5)
	_bank_pair(b)
	var soul := b.soul
	b.set_throw([2, 4, 6])
	b.confirm_bust()
	_check(b.points == gain and b.goal.target == gain * 5 and b.soul < soul, "bust: banked points and target kept, Soul lost")


func _miss(soul: int, rules: Array = []) -> BonfireRun:
	var r := BonfireRun.new(_tuning, _goal(100000, 1), soul, 5)
	if not rules.is_empty():
		r.set_rules(TableRules.build(rules, []), 3)
	_bank_pair(r)  # the last hand ends the table
	return r


func _test_miss() -> void:
	var r := _miss(30)
	_check(r.state == BonfireRun.State.FAILED and r.soul == 25 and int(r.table_summary["timeout_soul"]) == 5, "miss: -5 Soul, FAILED")
	var bl := _miss(30, [{"id": &"bloodletter", "params": {}}])
	_check(bl.soul == 20, "miss: Bloodletter doubles it to -10 (%d)" % bl.soul)
	var low := _miss(4)
	_check(low.soul == 0 and low.state == BonfireRun.State.RUN_OVER, "miss: low Soul -> 0 and RUN_OVER, no clamp")
	var gain := _pair_gain()
	var p := BonfireRun.new(_tuning, _goal(gain, 1), 30, 5)
	_bank_pair(p)
	_check(p.state == BonfireRun.State.CLEARED and p.soul == 30, "out of hands after a pass: CLEARED, no miss Soul")


## The real table -> run path: BonfireRun outcome into MapRun.apply_outcome.
func _play_miss(run: MapRun) -> BonfireRun:
	var s := run.table_setup()
	var r := BonfireRun.new(_tuning, s.goal, s.start_soul, 5)
	r.set_rules(TableRules.build(s.rules, []), 3)
	var guard := 30
	while not r.is_over() and guard > 0:
		_bank_pair(r)
		guard -= 1
	run.apply_outcome(TableOutcome.from_run(r, s.start_soul))
	return r


func _test_map_flow() -> void:
	var run := MapRun.new(_data, 4)
	_enter(run, NT.TABLE)
	var soul := run.progress.soul
	var r := _play_miss(run)
	_check(r.state == BonfireRun.State.FAILED and run.screen == S.MAP and run.progress.soul == soul - 5, "non-boss miss: -5 Soul, run continues on the map")
	var q := MapRun.new(_data, 4)
	_enter(q, NT.TABLE)
	soul = q.progress.soul
	q.quick_resolve(false)
	_check(q.screen == S.MAP and q.progress.soul == soul - 5, "stub miss: -5 Soul, back to the map")
	var low := MapRun.new(_data, 4)
	_enter(low, NT.TABLE)
	low.progress.soul = 3
	_play_miss(low)
	_check(low.screen == S.RUN_OVER, "miss with low Soul ends the run")
	var bo := MapRun.new(_data, 4)
	bo.boss = null  # a plain boss table (no cheat to dodge the pair banks)
	bo.boss_twist = null
	_enter(bo, NT.BOSS)
	var t0 := bo.goal.target
	var h0 := bo.goal.hands
	var m1 := _play_miss(bo)
	_check(bo.screen == S.TABLE and bo.boss_misses == 1 and bo.goal.target == t0 and bo.goal.hands == h0
		and int(m1.table_summary["timeout_soul"]) == 5 and bo.progress.soul == m1.soul,
		"boss miss: re-sit, same target %d and hands %d, -5 Soul" % [t0, h0])
	var m2 := _play_miss(bo)
	_check(bo.screen == S.RUN_OVER and int(m2.table_summary["timeout_soul"]) == 5 and m2.soul < m1.soul, "boss: a second miss ends the run (and costs Soul)")
	var w := MapRun.new(_data, 4)
	_enter(w, NT.TABLE)
	var e0 := w.progress.embers
	w.quick_resolve(true)
	_check(w.screen == S.REWARD and w.progress.embers - e0 == 14, "stub clear: pays the floor's 14 clear Embers")


func _test_rules() -> void:
	var ok := true
	for s in 20:
		var run := MapRun.new(_data, s)
		_enter(run, NT.ELITE)
		ok = ok and run.goal.hands == _data.floors[0].hands + _hands_delta(run.rules)
	_check(ok, "elite: twist hands_delta applies to the target table")
	var bod := load("res://resources/map/rules/odds_bodkin.tres") as RunRuleData
	var ft := load("res://resources/map/rules/first_throw.tres") as RunRuleData
	var run := MapRun.new(_data, 1)
	run._start_floor(2)
	run.boss = bod
	run.boss_twist = null
	_enter(run, NT.BOSS)
	_check(run.goal.hands == _data.floors[2].boss_hands + 1, "Odds Bodkin: +1 boss hand (%d)" % run.goal.hands)
	for rd in [bod, ft]:
		var r := BonfireRun.new(_tuning, _goal(100000, 2), 30, 5)
		r.set_rules(TableRules.build([rd], []), 3)
		_bank_pair(r)
		_bank_pair(r)
		_check(r.state == BonfireRun.State.FAILED and r.points > 0, "%s: plays a target table to the end without errors" % rd.id)


func _hands_delta(rules: Array) -> int:
	var n := 0
	for r in rules:
		n += r.hands_delta
	return n


func _test_state() -> void:
	var run := MapRun.new(_data, 2)
	_enter(run, NT.TABLE)
	var r := BonfireRun.new(_tuning, run.goal, 30, 5)
	var gs := TableGoalState.watch(r, run)
	_check(gs.target == 300 and gs.banked == 0 and gs.hands_left == r.hands_left and not gs.is_boss and gs.seals == 0
		and gs.bounties.is_empty() and gs.debuff == null, "state: initial fields")
	var got := {"banked": [], "hands": [], "changed": 0, "seals": [], "target": 0}
	gs.banked_changed.connect(func(v: int) -> void: got["banked"].append(v))
	gs.hands_left_changed.connect(func(v: int) -> void: got["hands"].append(v))
	gs.seals_changed.connect(func(v: int) -> void: got["seals"].append(v))
	gs.target_changed.connect(func(_v: int) -> void: got["target"] += 1)
	gs.changed.connect(func() -> void: got["changed"] += 1)
	_bank_pair(r)
	_check(got["banked"] == [r.points] and gs.banked == r.points and got["hands"] == [r.hands_left] and got["changed"] >= 1 and got["changed"] <= 2 and got["target"] == 0,
		"state: a bank emits banked/hands_left then one changed (%s)" % [got])
	gs.bounties.append({})
	_check(gs.bounties.is_empty(), "state: bounties is a read-only copy")
	run.quick_resolve(true)
	var i := 0
	while i < run.seal_options.size() and not _data.seal_combos.has(run.seal_options[i]):
		i += 1
	if i >= run.seal_options.size():
		run.seal_options[0] = _data.seal_combos[0]
		i = 0
	run.take_seal(i)
	_check(gs.seals == 1 and got["seals"] == [1], "state: taking a Seal -> seals 1, seals_changed (%s)" % [got["seals"]])
	_enter(run, NT.BOSS)
	var bs := TableGoalState.watch(BonfireRun.new(_tuning, run.goal, 30, 5))
	_check(bs.is_boss and bs.target == 700 and bs.seals == 0, "state: boss table, no map run -> seals 0")
	var ms := TableGoalState.watch(run)
	_check(ms.map_run == run and ms.run == null and ms.is_boss and ms.target == 700 and ms.banked == 0
		and ms.hands_left == run.goal.hands and ms.seals == 1, "state: watch(map_run) alone -> map goal, seals, banked 0")
	var both := TableGoalState.watch(run, bs.run)
	_check(both.run == bs.run and both.map_run == run, "state: watch(map_run, run) in either order")
	var seam := {"n": 0, "sig": []}
	var ts := TableGoalState.new()
	ts.changed.connect(func() -> void: seam["n"] += 1)
	ts.banked_changed.connect(func(v: int) -> void: seam["sig"].append(["b", v]))
	ts.target_changed.connect(func(v: int) -> void: seam["sig"].append(["t", v]))
	ts.hands_left_changed.connect(func(v: int) -> void: seam["sig"].append(["h", v]))
	ts.seals_changed.connect(func(v: int) -> void: seam["sig"].append(["s", v]))
	ts.debuff_changed.connect(func(v: Variant) -> void: seam["sig"].append(["d", v]))
	ts.set_for_test(300, 120, 3, null, 2, true)
	_check(ts.target == 300 and ts.banked == 120 and ts.hands_left == 3 and ts.seals == 2 and ts.is_boss and seam["n"] == 1
		and seam["sig"] == [["t", 300], ["b", 120], ["h", 3], ["s", 2]], "seam: set_for_test sets fields, emits each, one changed (%s)" % [seam])
	var dbf := {"icon_id": &"x", "text": "y"}
	ts.set_for_test(300, 120, 3, dbf, 2, true)
	_check(ts.debuff == dbf and seam["n"] == 2 and seam["sig"].back() == ["d", dbf], "seam: a debuff change emits debuff_changed")
	ts.set_for_test(300, 120, 3, dbf, 2, true)
	_check(seam["n"] == 2, "seam: no change -> no signals")
	var br := BonfireRun.new(_tuning, run.goal, 30, 5)
	_check(not br.bounties_count(), "rules: a target table counts no bounties (no cards to tick)")
	_check(TableGoalStrings.num(1234567) == "1,234,567" and TableGoalStrings.num(300) == "300"
		and TableGoalStrings.progress(1000, 640, 3) == "360 to go · 3 hands left" and TableGoalStrings.progress(1000, 640, 1) == "360 to go · 1 hand left"
		and TableGoalStrings.progress(1000, 1240, 2) == "PASSED · 2 hands left +240" and TableGoalStrings.progress(1000, 1000, 1) == "PASSED · 1 hand left",
		"strings: target lines")
