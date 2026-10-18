## QA: payouts, bet limits, rounding, Soul damage and RUN OVER at 0 Soul.
## Run: godot --headless --path . --script res://tests/qa_/qa_payouts_soul.gd
extends SceneTree
var p := 0
var f := 0
func check(c: bool, what: String) -> void:
	if c: p += 1
	else:
		f += 1
		print("FAIL  ", what)

func roll(o: RollResult.Outcome, total: int, pb: int = 0, dice: Array[int] = []) -> RollResult:
	var r := RollResult.new()
	r.outcome = o; r.total = total; r.point_before = pb; r.die_values = dice
	return r

func _init() -> void:
	var pass_t: BetType = load("res://resources/bets/pass.tres")
	var field: BetType = load("res://resources/bets/field.tres")
	var anyc: BetType = load("res://resources/bets/any_craps.tres")
	var tun: TuningData = load("res://resources/tuning/poc_tuning.tres")
	# Doc §12 config numbers
	check(tun.stake == 20 and tun.target_bankroll == 40 and tun.roll_limit == 12, "doc §12 stake/target/rolls")
	check(tun.min_bet == 5 and tun.max_bet == 25 and tun.soul_max == 40, "doc §12 bet 5-25, 40 Soul")
	check(tun.seven_out_base == 2 and tun.craps_base == 1 and tun.soul_per_coin_lost == 10, "doc §3 Soul formula numbers")
	check(tun.miss_base == 3 and tun.miss_step_percent == 25 and tun.miss_max == 7 and tun.bust_penalty == 7, "doc §2 miss/bust numbers")
	# Pass 1:1
	for s in [5, 10, 15, 25]:
		check(pass_t.profit_for(s, 7) == s and pass_t.profit_for(s, 8) == s, "Pass 1:1 on %d" % s)
	var b := ActiveBet.new(pass_t, 10)
	check(BetResolver.resolve_one(roll(RollResult.Outcome.NATURAL_WIN, 11), b).coin_returned() == 20, "Pass natural returns 2x stake")
	check(BetResolver.resolve_one(roll(RollResult.Outcome.POINT_HIT, 6, 6), b).net() == 10, "Pass point hit +10")
	check(BetResolver.resolve_one(roll(RollResult.Outcome.SEVEN_OUT, 7, 6), b).net() == -10, "Pass seven-out -10")
	check(BetResolver.resolve_one(roll(RollResult.Outcome.CRAPS_LOSS, 12), b).net() == -10, "Pass craps 12 loses (no bar-12 push)")
	check(not BetResolver.resolve_one(roll(RollResult.Outcome.NO_DECISION, 9, 6), b).is_settled(), "Pass stays on no-decision")
	# Field: 1:1, 2 pays 2:1, 12 pays 3:1, loses 5-8
	var fb := ActiveBet.new(field, 10)
	var fexp := {2: 20, 3: 10, 4: 10, 9: 10, 10: 10, 11: 10, 12: 30}
	for t in range(2, 13):
		var o := RollResult.Outcome.NO_DECISION
		var pay := BetResolver.resolve_one(roll(o, t, 6), fb)
		if fexp.has(t): check(pay.result == BetPayout.Result.WIN and pay.profit == fexp[t], "Field %d pays %d (got %d)" % [t, fexp[t], pay.profit])
		else: check(pay.result == BetPayout.Result.LOSE, "Field loses on %d" % t)
	check(field.unlock_cost == 20, "Field unlock 20 (doc)")
	# Any Craps 7:1
	var ab := ActiveBet.new(anyc, 5)
	for t in [2, 3, 12]: check(BetResolver.resolve_one(roll(RollResult.Outcome.CRAPS_LOSS, t), ab).profit == 35, "Any Craps %d pays 7:1" % t)
	check(BetResolver.resolve_one(roll(RollResult.Outcome.NATURAL_WIN, 7), ab).result == BetPayout.Result.LOSE, "Any Craps loses on 7")
	# Odds (no resource in POC): build per doc and verify true-odds math + rounding
	var odds := BetType.new()
	odds.id = &"odds"; odds.rule = BetType.Rule.ODDS
	odds.payout_overrides = {4: Vector2i(2,1), 10: Vector2i(2,1), 5: Vector2i(3,2), 9: Vector2i(3,2), 6: Vector2i(6,5), 8: Vector2i(6,5)}
	var oexp := {4: 20, 10: 20, 5: 15, 9: 15, 6: 12, 8: 12}
	for pt in oexp:
		var ob := ActiveBet.new(odds, 10)
		check(BetResolver.resolve_one(roll(RollResult.Outcome.POINT_HIT, pt, pt), ob).profit == oexp[pt], "Odds on %d pays %d" % [pt, oexp[pt]])
		check(BetResolver.resolve_one(roll(RollResult.Outcome.SEVEN_OUT, 7, pt), ob).result == BetPayout.Result.LOSE, "Odds on %d loses on 7-out" % pt)
	check(odds.profit_for(7, 6) == 8, "6:5 on 7 rounds down to 8")
	check(odds.profit_for(5, 5) == 7, "3:2 on 5 rounds down to 7")
	# Limits on CrapsTable
	var bk := Bankroll.new(100)
	var tb := CrapsTable.new(bk)
	check(tb.place_bet(pass_t, 4) != "", "below min 5 refused")
	check(tb.place_bet(pass_t, 25) == "", "25 accepted")
	check(tb.place_bet(pass_t, 1) != "" and tb.stake_on(&"pass") == 25, "cap 25 cannot be exceeded by adding")
	check(tb.place_bet(pass_t, 0) != "" and tb.place_bet(pass_t, -5) != "", "0/negative bets refused")
	check(bk.coin == 75, "refusals spent nothing")
	tb.roll([3, 3])
	check(tb.place_bet(pass_t, 5) != "" and tb.clear_bet(&"pass") != "", "Pass locked while Point on")
	var bk2 := Bankroll.new(3)
	check(CrapsTable.new(bk2).place_bet(pass_t, 5) != "" and bk2.coin == 3, "can't bet more than bankroll; never negative")
	bk2.set_coin(-10)
	check(bk2.coin == 0, "set_coin clamps at 0")
	# Soul damage formula (doc §3)
	var r := TableRuleData.new()
	var SO := RollResult.Outcome.SEVEN_OUT
	var CR := RollResult.Outcome.CRAPS_LOSS
	var NO := RollResult.Outcome.NO_DECISION
	var cases := [[SO,5,3],[SO,10,3],[SO,11,4],[SO,25,5],[SO,0,2],[CR,5,2],[CR,10,2],[CR,25,4],[CR,0,1],[NO,9,0],[NO,10,1],[NO,25,2]]
	for c in cases:
		check(PocTable.soul_damage_for(c[0], c[1], tun, r) == c[2], "soul dmg %s lost %d = %d (got %d)" % [RollResult.outcome_name(c[0]), c[1], c[2], PocTable.soul_damage_for(c[0], c[1], tun, r)])
	# Miss penalty: 3 + 1 per 25%% of gap, max 7
	check(PocTable.miss_penalty_for(40, 40, tun) == 0, "no miss penalty at target")
	check(PocTable.miss_penalty_for(40, 30, tun) == 4, "gap 25% -> 4")
	check(PocTable.miss_penalty_for(40, 20, tun) == 5, "gap 50% -> 5")
	check(PocTable.miss_penalty_for(40, 0, tun) == 7, "gap 100% -> 7 (cap)")
	check(PocTable.miss_penalty_for(40, 39, tun) == 3, "tiny gap -> 3")
	# RUN OVER exactly at 0 and below 0
	for start in [3, 1]:
		var pt := PocTable.new(tun, start)
		check(pt.place_bet(pass_t, 5) == "", "bet 5")
		pt.roll([2, 2]); var rep := pt.roll([3, 4])  # point 4 then seven-out: 2+1 = 3
		check(rep.soul_damage == 3, "seven-out on 5 = 3 Soul")
		check(pt.soul == 0, "Soul clamps to 0 (start %d, got %d)" % [start, pt.soul])
		check(pt.is_over() and pt.fail_reason == PocTable.FailReason.SOUL_SPENT, "SOUL_SPENT at start %d" % start)
		check(pt.place_bet(pass_t, 5) != "" and pt.roll([3, 4]).rejected, "no bets/rolls after run over")
		check(pt.bankroll.coin >= 0, "bankroll non-negative")
	var pt4 := PocTable.new(tun, 4)
	pt4.place_bet(pass_t, 5); pt4.roll([2, 2]); pt4.roll([3, 4])
	check(pt4.soul == 1 and not pt4.is_over(), "1 Soul left: still alive")
	print("=== qa_payouts_soul: %d passed, %d failed ===" % [p, f])
	quit(1 if f > 0 else 0)
