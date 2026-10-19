## Table rules (TableSetup.rules -> TableRule handlers): one check group per
## Elite twist / boss cheat, the new face mods (Ember Pip, Blood, Gilded,
## Step, Stair, Kindling; Heavy ignored), the special dice (Mirror, Cracked,
## Bellows and the scoring ones) and TableOutcome.banked_combos.
##   godot --headless --path . --script res://tests/test_bonfire_rules.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0
var t: BonfireTuning
var M: Dictionary = {}


class FakeRuleData:
	extends RefCounted
	var id: StringName = &"greedy_pot"
	var display_name: String = "Greedy Pot (boss text)"
	var description: String = "Pot 3."
	var params: Dictionary = {"min_pot": 3}


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


func run_with(rules: Array, specials: Array = [], tuning: BonfireTuning = null, dice: int = 5, seed_value: int = 7) -> BonfireRun:
	var r := BonfireRun.new(tuning if tuning != null else t, null, -1, dice)
	r.set_rules(TableRules.build(rules, specials), seed_value)
	return r


func rule(id: StringName, params: Dictionary = {}) -> Dictionary:
	return {"id": id, "params": params}


func die(special: StringName = &"", run_id: StringName = &"") -> TableDie:
	var d := TableDie.new(special if special != &"" else &"bone")
	d.special = special
	d.run_die_id = run_id
	return d


func pot(r: BonfireRun, idx: Array) -> void:
	for i in idx:
		r.toggle(i)


func d(v: int, m: FaceModData = null, sp: StringName = &"") -> Dictionary:
	return BonfireScoring.make_die(v, m, sp)


func sc(dice: Array, ctx: Dictionary = {}, bonus: int = 0) -> Dictionary:
	return BonfireScoring.score_selection(dice, t, bonus, ctx)


func _initialize() -> void:
	t = load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	for id in ["hellfire", "blank", "ember_pip", "blood", "gilded", "step", "stair", "kindling", "heavy", "wild"]:
		M[id] = load("res://resources/mods/%s.tres" % id) as FaceModData
	_format()
	_twists()
	_bosses()
	_mods()
	_specials()
	_outcome()
	print("test_bonfire_rules: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _format() -> void:
	check("rules" in TableSetup.new() and TableSetup.new().rules.is_empty(), "TableSetup.rules exists, empty by default")
	var built := TableRules.build([rule(&"cold_sixes", {"face": 6}), FakeRuleData.new(), {"id": &"no_such_rule"}])
	check(built.size() == 3 and built[0] is RuleColdSixes and built[0].display_name == "Cold Sixes" and built[0].description == "6s never light, but you get +1 hand.", "Dictionary entry -> handler with the designer's name + line")
	# Issue #70: Mister Wick under his own name, in cheat red; retuned lines.
	var wick := TableRules.make(rule(&"mister_wick"))
	check(wick is RuleColdSixes and wick.display_name == "Mister Wick" and wick.kind == TableRule.Kind.CHEAT, "mister_wick: Cold Sixes handler, own name, a boss cheat")
	check(wick.description == "Snuffs the sixes: 6s never light. A bust costs 2 Soul." and not wick.can_light(null, 6) and wick.can_light(null, 5), "mister_wick: his line; 6s never light")
	check(TableRules.make(rule(&"straight_man")).description.contains("runs of 4"), "Straight Man line: runs of 4 count")
	check(TableRules.make(rule(&"first_throw")).description.contains("first 2 throws"), "First Throw line: the first 2 throws")
	check(TableRules.make(rule(&"madame_shuffle")).description.contains("random lit die"), "Madame Shuffle line: one random lit die")
	for id in [&"cold_sixes", &"first_throw", &"greedy_pot", &"cold_hands"]:
		var tw := TableRules.make(rule(id))
		check(tw.kind == TableRule.Kind.TWIST and tw.info_line(null).ends_with("+1 hand."), "Elite twist %s: the rules panel line shows +1 hand" % id)
	check(built[1] is RuleGreedyPot and built[1].display_name == "Greedy Pot (boss text)" and int(built[1].param("min_pot", 2)) == 3, "RunRuleData-style object accepted (its name, line, params)")
	check(built[2] is RuleLabel, "unknown id is shown only")
	var with_dice := TableRules.build([rule(&"pit_boss")], [&"mirror", &"cracked", &"mirror", &"coven"])
	check(with_dice.size() == 3 and with_dice[0] is DieMirror and with_dice[1] is DieCracked and with_dice[2] is RulePitBoss, "special dice handlers first (one per kind), then the table's rules")
	for id in [&"short_table", &"heavy_burn"]:
		var r := run_with([rule(id)])
		check(r.rules[0] is RuleLabel and r.rules[0].info_line(r) != "" and r.set_throw([4, 4, 2, 3, 6]) and r.lit() == [0, 1, 2, 3], "%s: label only, play unchanged" % id)


func _twists() -> void:
	# Cold Sixes
	var r := run_with([rule(&"cold_sixes", {"face": 6})])
	r.set_throw([6, 6, 2, 3, 4])
	check(r.lit() == [2, 3, 4], "Cold Sixes: the 6s never light (run 2-3-4 does)")
	r = run_with([rule(&"cold_sixes", {"face": 6})])
	var soul := r.soul
	check(not r.set_throw([6, 6, 6, 2, 3]) and r.soul == soul - 1, "Cold Sixes: 6-6-6-2-3 busts")
	r = run_with([rule(&"cold_sixes")])
	r.set_throw([6, 6, 3, 2, 3])
	pot(r, [2, 3, 4])
	check(not r.can_continue() or r.selection()["combo"] != &"run3", "Cold Sixes: no lit 6 means no 2-3-4 with a 6")
	# First Throw
	r = run_with([rule(&"first_throw")])
	r.set_throw([5, 2, 3, 6, 6])
	pot(r, [0])
	r.rethrow()
	r.set_throw([4, 4, 4, 2])
	pot(r, [0, 1, 2])
	r.bank()
	check(not r.is_ticked(t.table_goal.required[0]) and r.points > 0, "First Throw: trips from the 2nd throw score but don't tick Triple")
	r = run_with([rule(&"first_throw")])
	r.set_throw([4, 4, 4, 2, 6])
	pot(r, [0, 1, 2])
	r.bank()
	check(r.is_ticked(t.table_goal.required[0]), "First Throw: trips on the first throw tick Triple")
	# Greedy Pot
	r = run_with([rule(&"greedy_pot", {"min_pot": 2})], [], null, 4)
	soul = r.soul
	check(not r.set_throw([1, 5, 3, 6]) and r.soul == soul - 1, "Greedy Pot: only singles = bust")
	r = run_with([rule(&"greedy_pot", {"min_pot": 2})])
	r.set_throw([5, 2, 2, 6, 3])
	check(not r.toggle(0), "Greedy Pot: a lone 5 can't be potted")
	pot(r, [1, 2])
	check(r.can_continue() and r.selection()["combo"] == &"pair", "Greedy Pot: a pair is fine")
	r = run_with([rule(&"greedy_pot", {"min_pot": 2})])
	r.set_throw([5])
	check(r.lit() == [0], "Greedy Pot: a throw of 1 die may pot 1")
	# Cold Hands
	r = run_with([rule(&"cold_hands")])
	r.set_throw([3, 3, 3, 5, 5])
	pot(r, [0, 1, 2, 3, 4])
	check(r.is_hot() and r.rethrow().is_empty() and r.rethrow_block_reason() != "" and r.bank()["kind"] == &"bank", "Cold Hands: potting all 5 must Bank (no Hot Hand)")


func _bosses() -> void:
	# Madame Shuffle: after the lit check, ONE random lit die is rerolled
	# (seeded), then the lit check runs again.
	# [6, 6, 1, 2, 4]: lit = the 6-6 pair and the 1; the 2 and 4 never are.
	var picked := {}
	var only_lit := true
	var one_change := true
	var others_kept := true
	for seed_value in 40:
		var r := run_with([rule(&"madame_shuffle")], [], null, 5, seed_value)
		r.set_throw([6, 6, 1, 2, 4])
		var ch := r.last_throw.changes
		one_change = one_change and ch.size() == 1 and ch[0]["by"] == &"madame_shuffle"
		if ch.size() == 1:
			var i := int(ch[0]["index"])
			picked[i] = true
			only_lit = only_lit and i <= 2
			var want: Array[int] = [6, 6, 1, 2, 4]
			want[i] = int(ch[0]["to"])
			others_kept = others_kept and r.last_throw.values == want
	check(one_change, "Madame Shuffle: exactly one reroll per throw")
	check(only_lit, "Madame Shuffle: only a lit die is rerolled (never the unlit 2 or 4)")
	check(picked.size() == 3, "Madame Shuffle: the pick is random among the lit dice (%s)" % str(picked.keys()))
	check(others_kept, "Madame Shuffle: other dice untouched, rerolled value used")
	# Seed determinism: same seed + throw -> same die, same new face.
	var ma := run_with([rule(&"madame_shuffle")], [], null, 5, 1234)
	var mb := run_with([rule(&"madame_shuffle")], [], null, 5, 1234)
	ma.set_throw([6, 6, 1, 2, 4])
	mb.set_throw([6, 6, 1, 2, 4])
	check(ma.last_throw.changes == mb.last_throw.changes and ma.throw_faces == mb.throw_faces, "Madame Shuffle: same seed, same reroll")
	var same := true
	for k in 5:
		same = same and ma.set_throw([5, 1, 3, 3, 3]) == mb.set_throw([5, 1, 3, 3, 3]) and ma.last_throw.changes == mb.last_throw.changes
	check(same, "Madame Shuffle: a seeded run stays in step throw after throw")
	# Nothing lit: no reroll, a normal bust.
	var r := run_with([rule(&"madame_shuffle")])
	var hands := r.hands_left
	check(not r.set_throw([2, 4, 6]) and r.last_throw.changes.is_empty() and r.hands_left == hands - 1, "Madame Shuffle: nothing lit -> no reroll, a bust")
	# [1, 2, 4] (a 3-die rethrow): only the 1 lights; her reroll re-runs the
	# lit check: a 1/5 (single), 3 (run) or 2/4 (pair) lights, a 6 busts.
	var saw_bust := false
	var saw_lit := false
	var consistent := true
	for seed_value in 60:
		r = run_with([rule(&"madame_shuffle")], [], null, 5, seed_value)
		hands = r.hands_left
		var ok := r.set_throw([1, 2, 4])
		var to := int(r.last_throw.changes[0]["to"]) if r.last_throw.changes.size() == 1 else -1
		consistent = consistent and int(r.last_throw.changes[0]["index"]) == 0 and ok == (to != 6) and (ok or r.hands_left == hands - 1)
		saw_bust = saw_bust or not ok
		saw_lit = saw_lit or ok
	check(consistent, "Madame Shuffle: the lit check runs again on her reroll")
	check(saw_bust and saw_lit, "Madame Shuffle: her reroll can bust you (a normal bust) or still light")
	r = run_with([rule(&"madame_shuffle", {"count": 2})], [], null, 5, 3)
	r.set_throw([6, 6, 1, 2, 4])
	var two := r.last_throw.changes
	check(two.size() == 2 and int(two[0]["index"]) != int(two[1]["index"]), "Madame Shuffle: params.count 2 rerolls two different dice")
	# Pit Boss
	r = run_with([rule(&"pit_boss")])
	var pb: RulePitBoss = r.rules[0]
	var L := pb.locked
	check(L >= 1 and L <= 6 and pb.felt_text(r) == "LOCKED  %d" % L and pb.info_line(r).contains(str(L)), "Pit Boss: a value 1-6 locked, on the felt + HUD")
	var other := 2 if L != 2 else 3
	r.set_throw([L, L, L, other, 6 if other != 6 and L != 6 else 1])
	check(not r.lit().has(0) and not r.lit().has(1) and not r.lit().has(2), "Pit Boss: the locked value never lights")
	var r2 := run_with([rule(&"pit_boss")])
	var draws: Dictionary = {}
	for k in 12:
		r2.hands_left = 99
		var lone: Array[int] = [(r2.rules[0] as RulePitBoss).locked]
		r2.set_throw(lone)  # the locked value alone never lights: bust, new hand
		draws[(r2.rules[0] as RulePitBoss).locked] = true
	check(draws.size() > 1, "Pit Boss: a new value each hand (%d seen)" % draws.size())
	var a := run_with([rule(&"pit_boss")], [], null, 5, 42)
	var b := run_with([rule(&"pit_boss")], [], null, 5, 42)
	check((a.rules[0] as RulePitBoss).locked == (b.rules[0] as RulePitBoss).locked, "Pit Boss: seeded")
	# Straight Man
	r = run_with([rule(&"straight_man")])
	r.set_throw([2, 3, 4, 6, 6])
	check(r.lit() == [3, 4], "Straight Man: run of 3 doesn't count, the pair does")
	r = run_with([rule(&"straight_man")])
	r.set_throw([1, 2, 3, 4, 5])
	pot(r, [0, 1, 2, 3])
	check(not r.can_continue(), "Straight Man: run of 4 doesn't count")
	r.toggle(4)
	check(r.selection()["combo"] == &"run5", "Straight Man: run of 5 does")
	# The Collector
	r = run_with([rule(&"collector")])
	r.set_throw([4, 4, 4, 2, 6], [M.hellfire, null, null, null, null])
	pot(r, [0, 1, 2])
	check(r.throw_points() == 126, "Collector: Hellfire off on the first throw (126, not 189)")
	r = run_with([rule(&"collector")])
	r.set_throw([5, 2, 3, 6, 6], [M.blank, null, null, null, null])
	check(not r.lit().has(0) and r.lit().has(3), "Collector: Blank is a curse face, it stays Blank on the first throw")
	r = run_with([rule(&"collector")])
	r.set_throw([5, 2, 3, 6, 6])
	pot(r, [0])
	r.rethrow()
	r.set_throw([4, 4, 4, 2], [M.hellfire, null, null, null])
	pot(r, [0, 1, 2])
	check(r.throw_points() == 189, "Collector: mods back on from the second throw (189)")
	# The Bloodletter
	r = run_with([rule(&"bloodletter", {"soul_cost_mult": 2})], [], null, 2)
	var soul := r.soul
	r.set_throw([2, 6])
	check(r.soul == soul - 2 and int(r.last_result["soul_lost"]) == 2, "Bloodletter: a bust costs 2")
	r = run_with([rule(&"bloodletter")])
	soul = r.soul
	r.set_throw([4, 4, 2, 3, 6], [M.blood, null, null, null, null])
	pot(r, [0, 1])
	r.rethrow()
	check(r.soul == soul - 2, "Bloodletter: a Blood face costs 2")
	r = run_with([rule(&"bloodletter")])
	soul = r.soul
	r.forfeit()
	check(r.soul == soul - 2 * 3 * t.table_goal.timeout_soul_per_bounty and int(r.table_summary["timeout_soul"]) == 18, "Bloodletter: forfeit Soul doubled (18)")
	r = run_with([rule(&"bloodletter")], [], null, 2)
	soul = r.soul
	r.hands_left = 1
	r.set_throw([2, 6])
	check(r.state == BonfireRun.State.FAILED and int(r.table_summary["timeout_soul"]) == 18 and r.soul == soul - 2 - 18, "Bloodletter: end-of-table unticked bounties cost 6 each (18), bust 2")


func _mods() -> void:
	# Hellfire: factors multiply, rounded down ONCE on the final score.
	var hh := sc([d(4, M.hellfire), d(4, M.hellfire), d(4, null, &"cracked")])
	check(int(hh["points"]) == floori(42 * 3 * 1.5 * 1.5 * 2.0) and int(hh["points"]) == 567, "Hellfire x2 + Cracked: 42x3 x4.5 = 567 (one floor)")
	check(int(sc([d(5, M.hellfire), d(5, M.hellfire)])["points"]) == floori(20 * 2 * 2.25), "two Hellfire 5s: 20x2 x2.25 = 90")
	check(int(sc([d(1, M.hellfire)])["points"]) == 9 and int(sc([d(5, M.hellfire), d(5, M.hellfire), d(5, M.hellfire)])["points"]) == floori(45 * 3 * 3.375), "Hellfire: no intermediate rounding (455)")
	# Heavy: ignored at the table.
	check(int(sc([d(4, M.heavy), d(4)])["points"]) == int(sc([d(4), d(4)])["points"]), "Heavy: scores as a plain face")
	# Ember Pip
	var s := sc([d(4, M.ember_pip), d(4)])
	check(int(s["points"]) == (10 + 8) * (2 + 2) and int(s["adds"]) == 2, "Ember Pip: +2 mult in a pair (72)")
	# Blood
	s = sc([d(4, M.blood), d(4)])
	check(int(s["points"]) == 18 * 6 and int(s["soul_cost"]) == 1, "Blood: +4 mult (108), costs 1 Soul")
	var r := run_with([])
	var soul := r.soul
	r.set_throw([4, 4, 2, 3, 6], [M.blood, null, null, null, null])
	pot(r, [0, 1])
	check(r.soul == soul, "Blood: no Soul paid while just selected")
	r.bank()
	check(r.soul == soul - 1, "Blood: 1 Soul paid when the pot scores")
	r = run_with([])
	r.soul = 1
	r.set_throw([4, 4, 2, 3, 6], [M.blood, null, null, null, null])
	pot(r, [0, 1])
	check(r.throw_points() == 36 and r.selection()["blood_refused"], "Blood: at 1 Soul it can't pay, so no +4 (36)")
	r.bank()
	check(r.soul == 1, "Blood: ...and nothing is paid")
	r = run_with([rule(&"bloodletter")])
	r.soul = 2
	r.set_throw([4, 4, 2, 3, 6], [M.blood, null, null, null, null])
	pot(r, [0, 1])
	r.bank()
	check(r.soul == 2 and r.points == 36, "Blood under Bloodletter at 2 Soul: 2 would take the last, so no pay, no bonus")
	r = run_with([])
	r.soul = 2
	r.set_throw([4, 4, 2, 3, 6], [M.blood, null, null, null, null])
	pot(r, [0, 1])
	r.bank()
	check(r.soul == 1 and r.points == 108, "Blood at 2 Soul: pays 1, +4 mult (108)")
	# Gilded
	r = run_with([], [], null, 3)
	r.set_throw([5, 2, 6], [M.gilded, null, null])
	pot(r, [0])
	r.rethrow()
	check(r.embers == 1, "Gilded: +1 Ember when potted")
	r.set_throw([2, 6])
	check(r.embers == 1 and r.last_result["kind"] == &"bust", "Gilded: the Ember is kept through a bust")
	# Step
	check(sc([d(2), d(3), d(5, M.step)])["combo"] == &"run3", "Step: 5 counts as 4 for 2-3-(4)")
	check(not sc([d(4, M.step), d(5)])["valid"] and sc([d(4, M.step), d(4)])["combo"] == &"pair", "Step: only for runs (4S+5 isn't a pair; 4S+4 is)")
	s = sc([d(2), d(3), d(5, M.step)])
	check(int(s["faces_sum"]) == 9, "Step: the faces sum uses the stepped value")
	# Stair
	s = sc([d(1), d(2), d(3, M.stair)])
	check(int(s["stair"]) == 30 and int(s["points"]) == (20 + 30 + 6) * 2, "Stair: +10 base per die in the run (112)")
	check(int(sc([d(3, M.stair), d(3)])["stair"]) == 0, "Stair: nothing outside a run")
	# Kindling
	r = run_with([], [], null, 3)
	r.set_throw([5, 2, 6], [M.kindling, null, null])
	pot(r, [0])
	r.rethrow()
	soul = r.soul
	var hands := r.hands_left
	check(not r.set_throw([2, 6]) and r.kindling_saved and r.state == BonfireRun.State.AIM and r.soul == soul and r.hands_left == hands and r.pot > 0 and r.cold == 2, "Kindling: next throw lights nothing -> no bust, throw again")
	check(not r.set_throw([2, 6]) and r.last_result.get("kind") == &"bust" and r.soul == soul - 1, "Kindling: used up, the throw after busts")
	r = run_with([], [], null, 3)
	r.set_throw([5, 2, 6], [M.kindling, null, null])
	pot(r, [0])
	r.rethrow()
	check(r.set_throw([5, 2]) and not r.kindling_armed, "Kindling: consumed by a throw that lights")


func _specials() -> void:
	# Mirror: nearest by settled position, ties -> lower face, solo keeps.
	var r := run_with([], [&"mirror"], null, 3)
	var th := TableThrow.make([2, 5, 3], [], [die(&"mirror"), die(), die()])
	th.positions = [Vector3.ZERO, Vector3(0.1, 0, 0), Vector3(0.3, 0, 0)] as Array[Vector3]
	r.land_throw(th)
	check(r.throw_faces[0] == 5 and th.changes.size() == 1 and th.changes[0]["by"] == &"mirror", "Mirror: copies the nearest die (5)")
	r = run_with([], [&"mirror"], null, 3)
	th = TableThrow.make([2, 5, 3], [], [die(&"mirror"), die(), die()])
	th.positions = [Vector3.ZERO, Vector3(0.1, 0, 0), Vector3(-0.1, 0, 0)] as Array[Vector3]
	r.land_throw(th)
	check(r.throw_faces[0] == 3, "Mirror: a tie goes to the lower face (3)")
	r = run_with([], [&"mirror"], null, 1)
	th = TableThrow.make([5], [], [die(&"mirror")])
	th.positions = [Vector3.ZERO] as Array[Vector3]
	r.land_throw(th)
	check(r.throw_faces == [5] and th.changes.is_empty(), "Mirror: alone in the tray it keeps its roll")
	r = run_with([], [&"mirror"], null, 2)
	th = TableThrow.make([1, 6], [], [die(&"mirror"), die()])
	r.land_throw(th)
	pot(r, [0, 1])
	check(r.selection()["combo"] == &"pair" and r.throw_faces == [6, 6], "Mirror: the copy is a natural face (6-6 pair)")
	r = run_with([], [&"mirror"], null, 3)
	th = TableThrow.make([2, 6, 4], [], [die(&"mirror"), die(&"mirror"), die()])
	th.positions = [Vector3.ZERO, Vector3(0.05, 0, 0), Vector3(0.4, 0, 0)] as Array[Vector3]
	r.land_throw(th)
	check(r.throw_faces == [4, 4, 4], "Mirror: copies the nearest NON-Mirror die (both Mirrors -> 4)")
	r = run_with([], [&"mirror"], null, 2)
	th = TableThrow.make([2, 6], [], [die(&"mirror"), die(&"mirror")])
	r.land_throw(th)
	check(th.changes.is_empty(), "Mirror: only Mirrors in the tray -> each keeps its roll")
	r = run_with([rule(&"madame_shuffle")], [&"mirror"], null, 2)
	th = TableThrow.make([1, 6], [], [die(&"mirror"), die()])
	r.land_throw(th)
	check(th.changes[0]["by"] == &"mirror", "Mirror copies before the table's rules act (Madame second)")

	# Cracked: x2, shatters (chance 1 here) with its pot, gone for the table.
	check(int(sc([d(4, null, &"cracked"), d(4)])["points"]) == 72, "Cracked: x2 mult on its pot (72)")
	var tc := t.duplicate() as BonfireTuning
	tc.cracked_shatter_chance = 1.0
	r = run_with([], [&"cracked", &"cracked"], tc, 5)
	r.owned_dice_count = 7
	var tds := [die(&"cracked", &"cracked_1"), die(&"cracked", &"cracked_2"), die(), die(), die()]
	var shattered_events := [0]
	r.table_event.connect(func(e: StringName, _d: Dictionary) -> void:
		if e == &"die_shattered":
			shattered_events[0] += 1)
	r.set_throw([4, 2, 4, 1, 6], [], tds)
	pot(r, [0, 2])
	r.rethrow()
	check(r.shattered == [&"cracked_1"] and shattered_events[0] == 1, "Cracked: of two Cracked dice only the potted one shatters (run_die_id)")
	check(r.dice_count == 4 and r.cold == 3 and r.owned_dice_count == 6, "Cracked: the table has one die fewer")
	r.set_throw([2, 1, 5], [], [tds[1], tds[3], tds[4]])
	pot(r, [2])
	r.bank()
	check(r.cold == 4 and r.dice_count == 4, "Cracked: next hand throws 4 (gone for the rest of the table)")
	check(TableOutcome.from_run(r, r.soul).shattered_dice == ([&"cracked_1"] as Array[StringName]), "Cracked: TableOutcome.shattered_dice lists it")
	r = run_with([], [&"cracked"], tc, 2)
	r.owned_dice_count = 6
	r.set_throw([3, 3], [], [die(&"cracked"), die()])
	pot(r, [0, 1])
	r.bank()
	check(r.shattered == ([&"cracked"] as Array[StringName]), "Cracked: falls back to TableDie.id without a run_die_id")
	r = run_with([], [&"cracked"], tc, 5)
	r.set_throw([3, 3, 2, 6, 6], [], [die(&"cracked", &"c1"), die(), die(), die(), die()])
	pot(r, [0, 1])
	r.bank()
	check(r.owned_dice_count == 5 and r.shattered.is_empty() and r.dice_count == 5, "Cracked floor: never shatters while you own 5 dice")
	r = run_with([], [&"cracked"], tc, 6)
	r.set_throw([3, 3, 2, 6, 6, 4], [], [die(&"cracked", &"c1"), die(), die(), die(), die(), die()])
	pot(r, [0, 1])
	r.bank()
	check(r.shattered.size() == 1 and r.owned_dice_count == 5 and not r.can_shatter(), "Cracked floor: from 6 owned it shatters once, then the bag is at 5")
	tc.cracked_shatter_chance = 0.0
	r = run_with([], [&"cracked"], tc, 2)
	r.set_throw([3, 3], [], [die(&"cracked", &"c9"), die()])
	pot(r, [0, 1])
	r.bank()
	check(r.shattered.is_empty() and r.dice_count == 2, "Cracked: no shatter when the roll misses")

	# Wanderer: a run may skip one value once.
	var wd := func(v: int) -> Dictionary: return d(v, null, &"wanderer")
	var s4 := sc([d(1), d(2), wd.call(4), d(5)])
	check(s4["combo"] == &"run4" and s4["gapped"] and int(s4["faces_sum"]) == 12 and int(s4["points"]) == (35 + 12) * 4, "Wanderer: 1-2-4-5 = Run of 4, the gap adds nothing (188)")
	check(sc([d(1), d(2), d(3), d(4), wd.call(6)])["combo"] == &"run5", "Wanderer: 1-2-3-4-6 = Run of 5")
	check(not sc([d(1), d(2), d(4), d(5)])["valid"], "no Wanderer: 1-2-4-5 isn't a run")
	check(not sc([d(1), wd.call(3), d(5)])["valid"], "Wanderer: only ONE gap (1-3-5 isn't a run)")
	check(not sc([d(1), d(2), wd.call(4), d(4)])["valid"] and sc([wd.call(2), d(3), d(4)])["combo"] == &"run3", "Wanderer: still N dice for a run of N; plain runs still work")
	check(sc([d(1), d(2), wd.call(4), d(6, M.step)])["combo"] == &"run4", "Wanderer + Step: 1-2-4-6 with Step 6->5 = Run of 4")
	r = run_with([], [&"wanderer"], null, 3)
	r.set_throw([1, 2, 4], [], [die(), die(), die(&"wanderer")])
	pot(r, [0, 1, 2])
	check(r.selection()["combo"] == &"run3", "Wanderer at the table: 1-2-4 lights as a Run of 3")
	r.bank()
	check(r.is_ticked(t.table_goal.required[1]), "Wanderer: the gapped run ticks the Run of 3 bounty")
	r = run_with([rule(&"straight_man")], [&"wanderer"])
	r.set_throw([1, 2, 3, 4, 6], [], [die(), die(), die(), die(), die(&"wanderer")])
	pot(r, [0, 1, 2, 3, 4])
	check(r.selection()["combo"] == &"run5", "Straight Man allows a gapped 5-die run")

	# Bellows: Hot Hands give +2.
	r = run_with([], [&"bellows"])
	r.set_throw([3, 3, 3, 5, 5])
	pot(r, [0, 1, 2, 3, 4])
	r.rethrow()
	check(r.mult_bonus() == 2, "Bellows: a Hot Hand gives +2 mult")
	# Scoring specials.
	check(int(sc([d(4, null, &"twin_flame"), d(4)])["points"]) == 18 * 6, "Twin Flame: +4 mult on a pair")
	check(int(sc([d(4, null, &"coven"), d(4), d(4)])["points"]) == 252, "Coven: x2 on trips")
	check(int(sc([d(4, null, &"blood_pact"), d(4)], {"soul": 25, "max_soul": 35})["points"]) == 18 * 4, "Blood Pact: +1 mult per 5 missing Soul")
	check(int(sc([d(4, null, &"last_breath"), d(4)], {"throw_size": 2, "is_rethrow": true})["points"]) == 108, "Last Breath: x3 potted from a rethrow of 2")
	check(int(sc([d(4, null, &"last_breath"), d(4)], {"throw_size": 3, "is_rethrow": true})["points"]) == 36, "Last Breath: not from 3 dice")


func _outcome() -> void:
	var r := run_with([])
	r.hands_left = 9
	r.set_throw([4, 4, 4, 2, 6])
	pot(r, [0, 1, 2])
	r.rethrow()
	r.set_throw([5, 3])
	pot(r, [0])
	r.bank()
	r.set_throw([2, 2, 3, 6, 4])
	pot(r, [0, 1])
	r.rethrow()
	r.set_throw([6, 2, 3])
	pot(r, [0])
	r.rethrow()
	r.set_throw([2, 3])
	r.set_throw([1, 1, 3, 6, 4])
	pot(r, [0, 1])
	r.bank()
	var o := TableOutcome.from_run(r, 35)
	check(o.banked_combos == ([&"trips", &"single", &"pair"] as Array[StringName]), "banked_combos: one per banked pot, repeats kept, busted hand left out (%s)" % str(o.banked_combos))
