## Headless tests for Coin, bets and payouts.
##
## Run:
##   godot --headless --path /workspace/dice/game --script res://tests/test_betting.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0
var _catalog: BetCatalog


func _initialize() -> void:
	print("=== The Gambler's Descent: betting tests ===")
	_catalog = load("res://resources/bets/bet_catalog.tres") as BetCatalog
	_check(_catalog != null and _catalog.bets.size() == 3, "data: bet catalog has Pass, Field, Hard 8")
	if _catalog == null:
		quit(1)
		return
	_test_bet_data()
	_test_bankroll()
	_test_integer_ratios()
	_test_pass_payouts()
	_test_field_payouts()
	_test_hard_8_payouts()
	_test_odds_rule()
	_test_table_limits()
	_test_table_money_flow()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(condition: bool, name: String, detail: String = "") -> void:
	if condition:
		_passed += 1
		print("PASS  ", name)
	else:
		_failed += 1
		print("FAIL  ", name, ("  -> " + detail) if detail != "" else "")


func _check_eq(actual: Variant, expected: Variant, name: String) -> void:
	_check(actual == expected, name, "expected %s, got %s" % [str(expected), str(actual)])


## Makes a RollResult the way CrapsRound would, from dice in a given state.
## point = 0 means come-out.
func _roll(dice: Array[int], point: int = 0) -> RollResult:
	var craps := CrapsRound.new()
	if point != 0:
		craps.resolve_total(point)
	return craps.resolve_dice(dice)


## Any two dice that add up to total, avoiding pairs when possible
## (so hard-way tests choose pairs explicitly).
func _dice_for(total: int) -> Array[int]:
	var a := clampi(total - 6, 1, 6)
	var b := total - a
	if a == b and a > 1 and b < 6:
		a -= 1
		b += 1
	var out: Array[int] = [a, b]
	return out


func _settle(bet_id: StringName, roll: RollResult, stake: int = 10) -> BetPayout:
	return BetResolver.resolve_one(roll, ActiveBet.new(_catalog.find(bet_id), stake))


# --- Data ------------------------------------------------------------------------

func _test_bet_data() -> void:
	var pass_bet := _catalog.find(&"pass")
	_check(pass_bet != null and pass_bet.is_starter() and pass_bet.ratio_text() == "1:1", "data: Natural (Pass) is a 1:1 starter")
	var field := _catalog.find(&"field")
	_check(field != null and field.unlock_cost == 20 and field.ratio_text(2) == "2:1" and field.ratio_text(12) == "3:1",
		"data: Field costs 20, 2 pays 2:1, 12 pays 3:1")
	var hard := _catalog.find(&"hard_8")
	_check(hard != null and hard.hard_number == 8 and hard.ratio_text() == "9:1" and hard.unlock_cost == 45,
		"data: Hard 8 pays 9:1, costs 45")


# --- Bankroll ----------------------------------------------------------------------

func _test_bankroll() -> void:
	var bank := Bankroll.new(50)
	var changes: Array = []
	bank.coin_changed.connect(func(new_coin: int, delta: int) -> void: changes.append([new_coin, delta]))
	_check(bank.spend(20) and bank.coin == 30, "bankroll: spend 20 of 50 leaves 30")
	_check(not bank.spend(31) and bank.coin == 30, "bankroll: can't spend more than you have")
	_check(bank.spend(30) and bank.coin == 0, "bankroll: can spend exactly everything")
	_check(not bank.spend(1), "bankroll: can't spend at 0")
	bank.add(15)
	_check_eq(bank.coin, 15, "bankroll: add 15")
	print("      (next line prints an EXPECTED error about a negative amount)")
	bank.add(-5)
	_check_eq(bank.coin, 15, "bankroll: negative add refused")
	_check(Bankroll.new(-10).coin == 0, "bankroll: never starts negative")
	_check(changes == [[30, -20], [0, -30], [15, 15]], "bankroll: coin_changed fires once per real change", str(changes))


# --- Integer payout math -------------------------------------------------------------

func _test_integer_ratios() -> void:
	var bet := BetType.new()
	bet.payout_numerator = 6
	bet.payout_denominator = 5
	_check_eq(bet.profit_for(5), 6, "ratio: 6:5 on 5 pays 6")
	_check_eq(bet.profit_for(10), 12, "ratio: 6:5 on 10 pays 12")
	_check_eq(bet.profit_for(7), 8, "ratio: 6:5 on 7 pays 8 (8.4 rounded down)")
	bet.payout_numerator = 3
	bet.payout_denominator = 2
	_check_eq(bet.profit_for(5), 7, "ratio: 3:2 on 5 pays 7 (7.5 rounded down)")
	_check_eq(bet.profit_for(25), 37, "ratio: 3:2 on 25 pays 37")


# --- Pass ----------------------------------------------------------------------------

func _test_pass_payouts() -> void:
	for total in range(2, 13):
		var p := _settle(&"pass", _roll(_dice_for(total)))
		var expected := BetPayout.Result.STAYS
		var profit := 0
		if total == 7 or total == 11:
			expected = BetPayout.Result.WIN
			profit = 10
		elif total in [2, 3, 12]:
			expected = BetPayout.Result.LOSE
		_check(p.result == expected and p.profit == profit,
			"pass: come-out %d -> %s +%d" % [total, BetPayout.Result.keys()[expected], profit],
			"got %s +%d" % [BetPayout.Result.keys()[p.result], p.profit])
	for point in [4, 5, 6, 8, 9, 10]:
		var hit := _settle(&"pass", _roll(_dice_for(point), point))
		_check(hit.result == BetPayout.Result.WIN and hit.profit == 10 and hit.coin_returned() == 20,
			"pass: point %d hit pays 1:1 (10 -> 20 back)" % point)
		var seven := _settle(&"pass", _roll(_dice_for(7), point))
		_check(seven.result == BetPayout.Result.LOSE and seven.net() == -10, "pass: point %d seven-out loses stake" % point)
		var other := 3 if point != 3 else 11
		_check(_settle(&"pass", _roll(_dice_for(other), point)).result == BetPayout.Result.STAYS,
			"pass: point %d, roll %d stays up" % [point, other])


# --- Field ---------------------------------------------------------------------------

func _test_field_payouts() -> void:
	# Doc: wins on 2,3,4,9,10,11,12; 1:1, but 2 pays 2:1 and 12 pays 3:1.
	var expected_profit := {2: 20, 3: 10, 4: 10, 5: -1, 6: -1, 7: -1, 8: -1, 9: 10, 10: 10, 11: 10, 12: 30}
	for phase_point in [0, 6]:
		for total in range(2, 13):
			var roll := _roll(_dice_for(total), phase_point)
			var p := _settle(&"field", roll)
			var want: int = expected_profit[total]
			var phase_name := "come-out" if phase_point == 0 else "point phase"
			if want < 0:
				_check(p.result == BetPayout.Result.LOSE and p.net() == -10, "field (%s): %d loses" % [phase_name, total])
			else:
				_check(p.result == BetPayout.Result.WIN and p.profit == want,
					"field (%s): %d pays +%d on 10" % [phase_name, total, want], "got +%d" % p.profit)


# --- Hard 8 --------------------------------------------------------------------------

func _test_hard_8_payouts() -> void:
	var hard: Array[int] = [4, 4]
	var p := _settle(&"hard_8", _roll(hard, 6))
	_check(p.result == BetPayout.Result.WIN and p.profit == 90, "hard 8: 4-4 pays 9:1 (+90 on 10)")
	p = _settle(&"hard_8", _roll(hard))
	_check(p.result == BetPayout.Result.WIN, "hard 8: 4-4 also wins on the come-out (always working)")
	for easy in [[2, 6], [6, 2], [3, 5], [5, 3]]:
		var dice: Array[int] = []
		dice.assign(easy)
		_check(_settle(&"hard_8", _roll(dice, 6)).result == BetPayout.Result.LOSE, "hard 8: easy %s loses" % str(easy))
	for sev in [[1, 6], [3, 4], [6, 1]]:
		var dice: Array[int] = []
		dice.assign(sev)
		_check(_settle(&"hard_8", _roll(dice, 5)).result == BetPayout.Result.LOSE, "hard 8: seven %s loses" % str(sev))
	_check(_settle(&"hard_8", _roll(_dice_for(7))).result == BetPayout.Result.LOSE, "hard 8: come-out 7 loses too")
	for total in [2, 3, 4, 5, 6, 9, 10, 11, 12]:
		_check(_settle(&"hard_8", _roll(_dice_for(total), 5)).result == BetPayout.Result.STAYS,
			"hard 8: %d stays up" % total)
	var invalid := RollResult.new()
	invalid.outcome = RollResult.Outcome.INVALID
	_check(_settle(&"hard_8", invalid).result == BetPayout.Result.STAYS, "resolver: invalid roll settles nothing")


# --- Odds rule (data paused, logic kept) ----------------------------------------------

func _test_odds_rule() -> void:
	var odds := BetType.new()
	odds.id = &"odds"
	odds.rule = BetType.Rule.ODDS
	odds.payout_overrides = {4: Vector2i(2, 1), 10: Vector2i(2, 1), 5: Vector2i(3, 2), 9: Vector2i(3, 2), 6: Vector2i(6, 5), 8: Vector2i(6, 5)}
	var want := {4: 20, 5: 15, 6: 12, 8: 12, 9: 15, 10: 20}
	for point in want:
		var p := BetResolver.resolve_one(_roll(_dice_for(point), point), ActiveBet.new(odds, 10))
		_check(p.result == BetPayout.Result.WIN and p.profit == want[point], "odds: point %d pays +%d on 10" % [point, want[point]])


# --- CrapsTable ----------------------------------------------------------------------

func _test_table_limits() -> void:
	var table := CrapsTable.new(Bankroll.new(50))
	var pass_bet := _catalog.find(&"pass")
	_check(table.place_bet(pass_bet, 4) != "", "table: below minimum 5 is refused")
	_check(table.place_bet(pass_bet, 5) == "" and table.bankroll.coin == 45, "table: Pass 5 placed, Coin 45")
	_check(table.place_bet(pass_bet, 20) == "" and table.stake_on(&"pass") == 25, "table: raise Pass to 25 (cap)")
	_check(table.place_bet(pass_bet, 5) != "", "table: over the 25 cap is refused")
	_check(table.place_bet(_catalog.find(&"field"), 25) == "" and table.bankroll.coin == 0, "table: Field 25 uses the rest")
	_check(table.place_bet(_catalog.find(&"hard_8"), 5) != "" and table.bankroll.coin == 0, "table: can't bet more Coin than you have")
	_check(table.clear_bet(&"field") == "" and table.bankroll.coin == 25, "table: clearing Field returns 25")

	var t2 := CrapsTable.new(Bankroll.new(50))
	t2.place_bet(pass_bet, 10)
	var point_roll: Array[int] = [2, 4]
	t2.roll(point_roll)
	_check(t2.craps.point == 6, "table: 2+4 sets Point 6")
	_check(t2.place_bet(pass_bet, 5) != "", "table: Pass can't be placed with a Point on")
	_check(t2.clear_bet(&"pass") != "" and t2.stake_on(&"pass") == 10, "table: Pass can't be taken down with a Point on")


func _test_table_money_flow() -> void:
	var table := CrapsTable.new(Bankroll.new(50))
	table.place_bet(_catalog.find(&"pass"), 10)
	table.place_bet(_catalog.find(&"field"), 5)
	table.place_bet(_catalog.find(&"hard_8"), 5)
	_check_eq(table.bankroll.coin, 30, "flow: 20 Coin on the felt, 30 in hand")

	# Come-out 11: Pass +10, Field +5, Hard 8 stays.
	var eleven: Array[int] = [5, 6]
	var r := table.roll(eleven)
	_check(r.net == 15 and table.bankroll.coin == 30 + 20 + 10, "flow: come-out 11 nets +15 (Pass & Field win)", "net %d coin %d" % [r.net, table.bankroll.coin])
	_check(table.active_bets.size() == 1 and table.find_bet(&"hard_8") != null, "flow: only Hard 8 stays up")

	# Hard 8 hits on 4-4 (also sets the Point 8 for an empty Pass line).
	var hard: Array[int] = [4, 4]
	r = table.roll(hard)
	_check(r.net == 45 and table.bankroll.coin == 60 + 50, "flow: 4-4 pays Hard 8 9:1 (+45, 50 back)", "net %d coin %d" % [r.net, table.bankroll.coin])
	_check(table.active_bets.is_empty() and table.craps.point == 8, "flow: felt empty, Point 8 on")

	# Rejected roll changes nothing.
	print("      (next line prints an EXPECTED warning about total 13)")
	var bad: Array[int] = [6, 7]
	var before := table.bankroll.coin
	r = table.roll(bad)
	_check(r.rejected and table.bankroll.coin == before and table.rolls_made == 2 and table.craps.point == 8,
		"flow: invalid total is rejected without using a roll")

	# Seven-out loses the Field bet placed during the Point.
	table.place_bet(_catalog.find(&"field"), 10)
	var seven: Array[int] = [3, 4]
	r = table.roll(seven)
	_check(r.roll.outcome == RollResult.Outcome.SEVEN_OUT and r.net == -10 and table.bankroll.coin == before - 10,
		"flow: seven-out, Field 10 lost")
