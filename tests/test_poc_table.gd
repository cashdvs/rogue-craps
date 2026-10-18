## Headless tests for the proof-of-concept table: tuning numbers, Soul
## damage formulas (doc v0.3 section 3), Hot Seven, target / roll limit /
## bust, and the end-of-table payouts and penalties.
##
## Run:
##   godot --headless --path /workspace/dice/game --script res://tests/test_poc_table.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0
var _catalog: BetCatalog
var _tuning: TuningData


func _initialize() -> void:
	print("=== The Gambler's Descent: POC table tests ===")
	_catalog = load("res://resources/bets/bet_catalog.tres") as BetCatalog
	var shipped := load("res://resources/tuning/poc_tuning.tres") as TuningData
	_check(_catalog != null and shipped != null, "data: catalog and tuning load")
	if _catalog == null or shipped == null:
		quit(1)
		return
	_check(not shipped.table_rule_enabled, "tuning: table rule ships OFF (doc v0.4 section 12)")
	# The rule logic is still tested: these tests run with Hot Seven ON.
	_tuning = shipped.duplicate() as TuningData
	_tuning.table_rule_enabled = true
	_test_tuning_matches_doc()
	_test_soul_formulas()
	_test_miss_penalty()
	_test_table_flow_soul()
	_test_hot_seven_toggle()
	_test_target_clear()
	_test_out_of_rolls()
	_test_bust()
	_test_soul_spent()
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


func _dice(a: int, b: int) -> Array[int]:
	var out: Array[int] = [a, b]
	return out


func _bet(id: StringName) -> BetType:
	return _catalog.find(id)


# --- Tuning = doc v0.3 numbers ---------------------------------------------------

func _test_tuning_matches_doc() -> void:
	var t := _tuning
	_check(t.stake == 20 and t.target_bankroll == 40, "tuning: stake 20, target bankroll 40 (net +20)")
	_check(t.roll_limit == 12 and t.min_bet == 5 and t.max_bet == 25, "tuning: 12 rolls, bets 5-25")
	_check_eq(t.soul_max, 40, "tuning: 40 Soul")
	_check(t.seven_out_base == 2 and t.craps_base == 1 and t.soul_per_coin_lost == 10, "tuning: Soul formula numbers 2 / 1 / per 10")
	_check(t.miss_base == 3 and t.miss_step_percent == 25 and t.miss_max == 7 and t.bust_penalty == 7, "tuning: miss 3 + 1 per 25% (max 7), bust 7")
	_check(t.clear_bonus == 5 and t.coin_per_unused_roll == 1, "tuning: +5 clear bonus, +1 per unused roll")
	_check(t.table_rule != null and t.table_rule.id == &"hot_seven" and t.table_rule.seven_out_soul_multiplier == 2,
		"tuning: Hot Seven doubles Seven-out Soul damage")


# --- Soul damage formulas (static) -------------------------------------------------

func _test_soul_formulas() -> void:
	var plain := TableRuleData.new()
	var hot := _tuning.table_rule
	var O := RollResult.Outcome
	# Seven-out: 2 + ceil(lost / 10).
	var cases := [[0, 2], [5, 3], [10, 3], [11, 4], [20, 4], [25, 5], [50, 7]]
	for c in cases:
		_check_eq(PocTable.soul_damage_for(O.SEVEN_OUT, c[0], _tuning, plain), c[1], "soul: seven-out losing %d -> %d" % [c[0], c[1]])
		_check_eq(PocTable.soul_damage_for(O.SEVEN_OUT, c[0], _tuning, hot), c[1] * 2, "soul: Hot Seven seven-out losing %d -> %d" % [c[0], c[1] * 2])
	# Craps: 1 + ceil(lost / 10). Hot Seven does NOT touch Craps.
	for c in [[0, 1], [5, 2], [10, 2], [15, 3], [25, 4]]:
		_check_eq(PocTable.soul_damage_for(O.CRAPS_LOSS, c[0], _tuning, hot), c[1], "soul: craps losing %d -> %d" % [c[0], c[1]])
	# Any other losing roll: floor(lost / 10).
	for c in [[5, 0], [9, 0], [10, 1], [19, 1], [25, 2]]:
		_check_eq(PocTable.soul_damage_for(O.NO_DECISION, c[0], _tuning, hot), c[1], "soul: other loss of %d -> %d" % [c[0], c[1]])
	_check_eq(PocTable.soul_damage_for(O.NATURAL_WIN, 10, _tuning, hot), 1, "soul: Field 10 lost on a Natural 7 -> 1")
	_check_eq(PocTable.soul_damage_for(O.POINT_HIT, 0, _tuning, hot), 0, "soul: winning roll with no losses -> 0")


func _test_miss_penalty() -> void:
	# Gap measured against the 40 target: 3 + floor(gap% / 25), max 7.
	for c in [[39, 3], [31, 3], [30, 4], [21, 4], [20, 5], [10, 6], [1, 6], [0, 7]]:
		_check_eq(PocTable.miss_penalty_for(40, c[0], _tuning), c[1], "miss: ending on %d of 40 -> %d Soul" % [c[0], c[1]])
	_check_eq(PocTable.miss_penalty_for(40, 40, _tuning), 0, "miss: no penalty at the target")


# --- Table flow ------------------------------------------------------------------

func _test_table_flow_soul() -> void:
	var fresh := PocTable.new(_tuning)
	_check(fresh.bankroll.coin == 20 and fresh.soul == 40 and fresh.rolls_left() == 12, "table: starts with 20 Coin, 40 Soul, 12 rolls")
	# A roomier bankroll so this test can walk through several losses.
	var roomy := _tuning.duplicate() as TuningData
	roomy.stake = 60
	roomy.target_bankroll = 200
	var t := PocTable.new(roomy)
	_check(t.place_bet(_bet(&"pass"), 10) == "", "table: Pass 10 placed")
	var r := t.roll(_dice(2, 4))  # Point 6.
	_check(r.soul_damage == 0 and t.rolls_left() == 11, "table: setting a Point costs no Soul, uses a roll")
	t.place_bet(_bet(&"field"), 5)
	r = t.roll(_dice(3, 4))  # Seven-out: lost 15 -> (2 + 2) x2 = 8.
	_check(r.coin_lost == 15 and r.soul_damage == 8 and t.soul == 32, "table: Hot Seven seven-out losing 15 burns 8 Soul",
		"lost %d dmg %d soul %d" % [r.coin_lost, r.soul_damage, t.soul])
	_check(r.explanation.contains("Hot Seven") and r.explanation.contains("-8 Soul"), "table: explanation names Hot Seven and the cost", r.explanation)

	t.place_bet(_bet(&"pass"), 5)
	r = t.roll(_dice(1, 2))  # Craps 3: lost 5 -> 1 + 1 = 2.
	_check(r.soul_damage == 2 and t.soul == 30, "table: craps losing 5 burns 2 Soul")

	t.place_bet(_bet(&"field"), 5)
	r = t.roll(_dice(3, 3))  # Point 6 set; Field 5 lost -> 0 (small Field losses are free).
	_check(r.coin_lost == 5 and r.soul_damage == 0 and r.explanation.contains("no Soul"), "table: small Field loss is free", r.explanation)

	var soul_events: Array = []
	t.soul_changed.connect(func(new_soul: int, delta: int, reason: String) -> void: soul_events.append([new_soul, delta, reason]))
	t.place_bet(_bet(&"field"), 10)
	t.roll(_dice(2, 6))  # 8: Field 10 lost -> 1.
	_check(soul_events == [[29, -1, "Losses"]], "table: soul_changed fires with the reason", str(soul_events))


func _test_hot_seven_toggle() -> void:
	var off := _tuning.duplicate() as TuningData
	off.table_rule_enabled = false
	var t := PocTable.new(off)
	t.place_bet(_bet(&"pass"), 10)
	t.roll(_dice(4, 4))
	var r := t.roll(_dice(1, 6))
	_check(r.soul_damage == 3, "rule off: seven-out losing 10 burns 3 (no doubling)", str(r.soul_damage))


func _test_target_clear() -> void:
	var t := PocTable.new(_tuning)
	t.place_bet(_bet(&"pass"), 20)
	var r := t.roll(_dice(5, 6))  # Natural: 20 -> 40 = target.
	_check(t.status == PocTable.Status.CLEARED and r.table_ended, "clear: hitting 40 clears the table immediately")
	_check(t.clear_bonus_paid == 5 and t.unused_roll_bonus_paid == 11, "clear: +5 bonus and +11 for 11 unused rolls")
	_check(t.bankroll.coin == 56 and t.coin_surplus() == 36, "clear: bankroll 56, surplus 36", "coin %d" % t.bankroll.coin)
	_check(t.place_bet(_bet(&"pass"), 5) != "" and t.roll(_dice(3, 4)).rejected, "clear: no more bets or rolls after the end")

	# Reaching the target while a Pass bet is up (counting Coin on the felt).
	var t2 := PocTable.new(_tuning)
	t2.place_bet(_bet(&"pass"), 10)
	t2.place_bet(_bet(&"any_craps"), 5)
	t2.roll(_dice(1, 3))   # Point 4; Any Craps loses 5 -> 15 total.
	t2.place_bet(_bet(&"any_craps"), 5)
	t2.roll(_dice(1, 2))   # 3: Any Craps 7:1 returns 40, + Pass 10 on the felt = 50.
	_check(t2.status == PocTable.Status.CLEARED and t2.table.active_bets.is_empty() and t2.bankroll.coin == 50 + 5 + 10,
		"clear: Coin on the felt counts, and is returned", "status %d coin %d" % [t2.status, t2.bankroll.coin])


func _test_out_of_rolls() -> void:
	var t := PocTable.new(_tuning)
	for i in 11:
		t.roll(_dice(2, 3))  # Point 5 then no decisions; no bets.
	t.place_bet(_bet(&"field"), 5)   # Can't place Pass during the Point; Field is fine.
	_check(t.rolls_left() == 1 and not t.is_over(), "limit: 1 roll left")
	var r := t.roll(_dice(2, 2))  # Field wins 5 -> 25 bankroll, short of 40.
	_check(t.status == PocTable.Status.FAILED and t.fail_reason == PocTable.FailReason.OUT_OF_ROLLS and r.table_ended, "limit: out of rolls fails")
	_check(t.final_penalty == 4 and t.soul == 36 and t.bankroll.coin == 25, "limit: ending on 25 of 40 -> 4 Soul penalty",
		"pen %d soul %d coin %d" % [t.final_penalty, t.soul, t.bankroll.coin])

	# A Pass bet still up when rolls run out is returned.
	var t2 := PocTable.new(_tuning)
	t2.place_bet(_bet(&"pass"), 10)
	t2.roll(_dice(4, 6))  # Point 10.
	for i in 11:
		t2.roll(_dice(1, 2))  # 3s: no decision.
	_check(t2.is_over() and t2.bankroll.coin == 20 and t2.table.active_bets.is_empty(), "limit: unresolved Pass is pushed back (20 Coin)")
	_check(t2.final_penalty == 5 and t2.soul_lost() == 5, "limit: ending on 20 of 40 -> 5 Soul")


func _test_bust() -> void:
	var t := PocTable.new(_tuning)
	t.place_bet(_bet(&"pass"), 20)
	var r := t.roll(_dice(1, 1))  # Craps: lose everything.
	_check(t.status == PocTable.Status.FAILED and t.fail_reason == PocTable.FailReason.BUST and r.table_ended, "bust: 0 Coin ends the table")
	_check(r.soul_damage == 3 and t.final_penalty == 7 and t.soul == 30, "bust: craps 3 Soul + bust 7 = 10 Soul lost",
		"dmg %d pen %d soul %d" % [r.soul_damage, t.final_penalty, t.soul])
	var t2 := PocTable.new(_tuning)
	t2.place_bet(_bet(&"pass"), 17)
	t2.roll(_dice(1, 2))  # 3 Coin left, can't make a 5 bet -> bust.
	_check(t2.fail_reason == PocTable.FailReason.BUST, "bust: under the minimum bet with nothing on the felt counts as bust")


func _test_soul_spent() -> void:
	var t := PocTable.new(_tuning, 3)
	_check_eq(t.soul, 3, "soul: can start a table with less Soul")
	t.place_bet(_bet(&"pass"), 10)
	t.roll(_dice(3, 3))
	t.roll(_dice(3, 4))  # Seven-out: (2 + 1) x2 = 6 > 3.
	_check(t.soul == 0 and t.status == PocTable.Status.FAILED and t.fail_reason == PocTable.FailReason.SOUL_SPENT, "soul: 0 Soul fails the table")
