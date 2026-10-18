## Headless tests for the Burn Line sandbox rules (BurnLineRun + the shipped
## resources/tuning/burn_line_tuning.tres numbers).
##   godot --headless --path . --script res://tests/test_burn_line.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0
var t: BurnLineTuning


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


func _initialize() -> void:
	t = load("res://resources/tuning/burn_line_tuning.tres") as BurnLineTuning
	_test_data()
	_test_returns()
	_test_burns()
	_test_leadfoot()
	_test_knucklebone()
	_test_side_bet()
	_test_table_flow()
	_test_weights()
	print("test_burn_line: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func die(id: StringName) -> BurnDie:
	return t.find_die(id)


## Slot (1..6) of a die that shows `value`.
func slot_for(d: BurnDie, value: int) -> int:
	return d.faces.find(value) + 1


## A run on table 1 with `dice` and a fresh hand; bet `bet`.
func fresh(bet: int = 10, dice: Array[StringName] = [&"bone", &"knucklebone", &"leadfoot"]) -> BurnLineRun:
	var r := BurnLineRun.new(t, 1)
	var ds: Array[BurnDie] = []
	for id in dice:
		ds.append(die(id))
	r.set_loadout(ds)
	r.place_bet(bet)
	return r


## Throws Bone values in order (each 1..6).
func throw_values(r: BurnLineRun, values: Array[int], id: StringName = &"bone") -> void:
	for v in values:
		r.add_throw(die(id), slot_for(die(id), v))


func _test_data() -> void:
	check(t.tables.size() == 3, "3 tables")
	check(t.tables[0].line == 15 and t.tables[0].start_coin == 20 and t.tables[0].coin_target == 40 and t.tables[0].hands == 8, "table 1: Line 15, 20 coin, target 40, 8 hands")
	check(t.tables[1].line == 16 and t.tables[1].coin_target == 44, "table 2: Line 16, target 44")
	check(t.tables[2].line == 18 and t.tables[2].start_coin == 40 and t.tables[2].bet_cap == 20 and t.tables[2].coin_target == 80, "High Stakes: Line 18, 40 coin, cap 20, target 80")
	check(t.starting_soul == 35 and t.burn_soul_loss == 2 and t.min_bet == 5 and t.bet_chip == 5, "Soul 35, burn 2, bets in 5s")
	var r := BurnLineRun.new(t, 3)
	check(r.loadout.size() == 2 and r.loadout[0].id == &"bone" and r.loadout[1].id == &"knucklebone" and r.loadout_id == &"standard", "default loadout is Standard: Bone + Knucklebone")
	check(r.bet == 5 and r.coin == 15, "a hand starts with the minimum bet placed (taken from coin)")
	check(r.place_bet(10) and r.bet == 10 and r.coin == 10, "bet 10 (cap) before the first throw")
	check(not r.place_bet(15) or r.bet == 10, "bet capped at 10 on table 1")
	check(not r.can_stop(), "Stop needs a first throw")


func _test_returns() -> void:
	var cases := [[15, 20, &"exact"], [14, 15, &"close"], [13, 5, &"near"], [12, 5, &"near"], [11, 0, &"miss"], [6, 0, &"miss"]]
	for c in cases:
		var r := fresh(10)
		var coin_before := r.bankroll()
		var total: int = c[0]
		var vals: Array[int] = []
		while total > 6:
			vals.append(6)
			total -= 6
		vals.append(total)
		throw_values(r, vals)
		var res := r.stop()
		check(res["kind"] == c[2] and res["returned"] == c[1] and r.bankroll() == coin_before - 10 + int(c[1]), "stop at %d (Line 15): %s returns %d of a 10 bet" % [c[0], c[2], c[1]])
	var r2 := fresh(5)
	throw_values(r2, [6, 6, 2])
	check(r2.stop()["returned"] == 7, "1 under on a 5 bet returns 7 (1.5x, rounded down)")


func _test_burns() -> void:
	var r := fresh(10)
	throw_values(r, [6, 6, 4])
	var res: Dictionary = r.last_result
	check(res["kind"] == &"burn" and res["returned"] == 0 and r.soul == 33, "over the Line burns: bet lost, -2 Soul")
	check(r.hands_left == 7 and r.bankroll() == 10 and r.bet == 5, "after a burn the next hand starts (min bet placed)")
	var r2 := fresh(10)
	throw_values(r2, [6, 6])
	r2.add_throw(die(&"leadfoot"), 4)
	check(r2.last_result["kind"] == &"burn" and r2.soul == 31, "a Leadfoot burn (Heavy) costs 2 + 2 Soul")
	var r3 := fresh(10)
	throw_values(r3, [6, 6], &"leadfoot")
	throw_values(r3, [4])
	check(r3.soul == 33, "a burn on a Bone throw after Leadfoot throws costs only 2")


func _test_leadfoot() -> void:
	var r := fresh(10)
	throw_values(r, [6, 6])
	throw_values(r, [3], &"leadfoot")
	var res := r.stop()
	check(res["kind"] == &"exact" and res["returned"] == 25, "exact with Leadfoot last returns 2.5x (25 of 10)")
	var r2 := fresh(10)
	throw_values(r2, [6, 6], &"leadfoot")
	throw_values(r2, [3])
	check(r2.stop()["returned"] == 20, "exact with Bone last after Leadfoot returns 2.0x")


func _test_knucklebone() -> void:
	var r := fresh(10)
	var k := die(&"knucklebone")
	check(r.can_throw(k) == "" and r.throws_left(k) == 1, "Knucklebone: one throw per hand")
	r.add_throw(k, 3)  # slot 3 shows 2
	check(r.total == 2, "Knucklebone slot 3 shows 2")
	check(r.can_throw(k) != "" and r.throws_left(k) == 0, "Knucklebone Cramped after one throw")
	check(r.can_throw(die(&"bone")) == "", "Bone is still reusable")
	r.stop()
	check(r.can_throw(k) == "", "Knucklebone is back next hand")


func _test_side_bet() -> void:
	var r := fresh(10)
	check(r.set_side_bet(true) and r.coin == 5, "Exact Hit side bet costs 5")
	throw_values(r, [6])
	check(not r.set_side_bet(false) and r.side_bet, "side bet locked after the first throw")
	throw_values(r, [6, 3])
	var res := r.stop()
	check(res["side_returned"] == 15 and r.bankroll() == 5 + 20 + 15, "side bet wins on exact: returns 5 + 10")
	var r2 := fresh(10)
	r2.set_side_bet(true)
	throw_values(r2, [6, 6, 2])
	check(r2.stop()["side_returned"] == 0 and r2.bankroll() == 5 + 15, "side bet lost one under")
	var r3 := fresh(10)
	r3.set_side_bet(true)
	throw_values(r3, [6, 6, 6])
	check(r3.last_result["side_returned"] == 0 and r3.bankroll() == 5, "side bet lost on a burn")
	var r4 := fresh(10)
	check(r4.set_side_bet(true) and r4.set_side_bet(false) and r4.coin == 10, "side bet can be toggled off before the first throw (refund)")


func _test_table_flow() -> void:
	# Clear: exact on a 10 bet twice from 20 -> 30 -> 40.
	var r := fresh(10)
	throw_values(r, [6, 6, 3])
	r.stop()
	check(r.state == BurnLineRun.State.HAND and r.bankroll() == 30, "after +10 profit: 30 coin")
	r.place_bet(10)
	throw_values(r, [6, 6, 3])
	r.stop()
	check(r.state == BurnLineRun.State.TABLE_CLEARED and r.coin == 40, "coin >= 40 at the end of a hand clears table 1")
	var soul := r.soul
	r.next_table()
	check(r.table_index == 1 and r.line() == 16 and r.bankroll() == 20 and r.hands_left == 8 and r.soul == soul, "table 2: Line 16, coin resets to 20, Soul carries")
	# Fail on hands: 8 misses.
	var f := fresh(5)
	for i in 8:
		if f.state != BurnLineRun.State.HAND:
			break
		throw_values(f, [6, 6, 1])  # 13 = 2 under -> 0.5x
		f.stop()
	check(f.state == BurnLineRun.State.TABLE_FAILED, "running out of hands fails the table")
	# Fail on coin < 5.
	var c := fresh(10)
	throw_values(c, [1])
	c.stop()  # miss: coin 10
	c.place_bet(10)
	throw_values(c, [1])
	c.stop()  # coin 0
	check(c.state == BurnLineRun.State.TABLE_FAILED and c.coin < 5, "coin under the 5 minimum bet fails the table")
	# Run over at 0 Soul.
	var s := fresh(5)
	s.soul = 2
	throw_values(s, [6, 6, 6])
	check(s.state == BurnLineRun.State.RUN_OVER, "0 Soul ends the run")
	# Run won after the last table.
	var w := fresh(10)
	w.table_index = 2
	w.start_table()
	w.place_bet(20)
	throw_values(w, [6, 6, 6])
	w.stop()  # 40 - 20 + 40 = 60
	w.place_bet(20)
	throw_values(w, [6, 6, 6])
	w.stop()  # 60 - 20 + 40 = 80
	check(w.state == BurnLineRun.State.RUN_WON, "clearing High Stakes wins the run")


func _test_weights() -> void:
	var lf := die(&"leadfoot")
	var counts := [0, 0, 0, 0, 0, 0, 0]
	var n := 0
	for seed_value in 400:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		for k in 20:
			counts[lf.faces[lf.roll_slot(rng) - 1]] += 1
			n += 1
	var six := float(counts[6]) / n
	check(absf(six - 0.375) < 0.02, "Leadfoot shows 6 about 3/8 of the time over 400 seeds (%.3f)" % six)
	for v in range(1, 6):
		check(absf(float(counts[v]) / n - 0.125) < 0.015, "Leadfoot shows %d about 1/8 (%.3f)" % [v, float(counts[v]) / n])
	var a := RandomNumberGenerator.new()
	a.seed = 9
	var b := RandomNumberGenerator.new()
	b.seed = 9
	var same := true
	for k in 50:
		if lf.roll_slot(a) != lf.roll_slot(b):
			same = false
	check(same, "same seed, same Leadfoot faces")
