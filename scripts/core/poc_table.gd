## The proof-of-concept table (design doc v0.3 section 12): one table with a
## stake, a bankroll target, a roll limit, Soul, and one disruptive rule.
##
## Pure logic, no nodes. It wraps CrapsTable (bets + craps rules) and adds:
##   * Soul damage per roll (doc section 3), modified by the table rule
##   * the roll limit and win / fail checks (doc section 2)
## Every number comes from TuningData, so design can tune without code.
class_name PocTable
extends RefCounted

enum Status { IN_PROGRESS, CLEARED, FAILED }
enum FailReason { NONE, OUT_OF_ROLLS, BUST, SOUL_SPENT }

## Fired whenever Soul changes. reason is a short label like "Seven-out".
signal soul_changed(new_soul: int, delta: int, reason: String)
## Fired once when the table is cleared or failed.
signal finished(status: Status)

var tuning: TuningData
var rule: TableRuleData
var bankroll: Bankroll
var table: CrapsTable

var soul: int = 0
var soul_at_start: int = 0
var rolls_used: int = 0
var status: Status = Status.IN_PROGRESS
var fail_reason: FailReason = FailReason.NONE

# Filled in when the table ends (for the end screen).
var clear_bonus_paid: int = 0
var unused_roll_bonus_paid: int = 0
var final_penalty: int = 0


func _init(tuning_data: TuningData, starting_soul: int = -1) -> void:
	tuning = tuning_data
	# A missing or disabled rule becomes a neutral rule (all multipliers 1).
	rule = tuning.table_rule if tuning.table_rule != null and tuning.table_rule_enabled else TableRuleData.new()
	bankroll = Bankroll.new(tuning.stake)
	table = CrapsTable.new(bankroll)
	table.min_bet = tuning.min_bet
	table.max_bet = tuning.max_bet
	table.odds_max_multiple = tuning.odds_max_multiple
	soul = tuning.soul_max if starting_soul < 0 else starting_soul
	soul_at_start = soul


# --- Read-only helpers ----------------------------------------------------------

func roll_limit() -> int:
	return maxi(tuning.roll_limit + rule.roll_limit_delta, 1)


func rolls_left() -> int:
	return maxi(roll_limit() - rolls_used, 0)


func target() -> int:
	return tuning.target_bankroll


func is_over() -> bool:
	return status != Status.IN_PROGRESS


## Your bankroll counting Coin on the felt (what the target is checked against).
func bankroll_total() -> int:
	return bankroll.coin + table.staked_total()


func soul_lost() -> int:
	return soul_at_start - soul


## Coin above what you sat down with (doc: "your shop money"). Can be negative.
func coin_surplus() -> int:
	return bankroll.coin - tuning.stake


# --- Betting (forwarded to CrapsTable, refused once the table is over) --------

func place_bet(bet: BetType, amount: int) -> String:
	if is_over():
		return "The table is over."
	return table.place_bet(bet, amount)


func clear_bet(bet_id: StringName) -> String:
	if is_over():
		return "The table is over."
	return table.clear_bet(bet_id)


# --- Rolling ----------------------------------------------------------------------

## Resolves one roll of the given die values: bets, Soul damage, end checks.
func roll(die_values: Array[int]) -> PocRollReport:
	var report := PocRollReport.new()
	if is_over():
		report.rejected = true
		report.explanation = "The table is over."
		return report
	var tr := table.roll(die_values)
	report.table_report = tr
	if tr.rejected:
		report.rejected = true
		report.explanation = tr.reject_reason
		return report

	rolls_used += 1
	for p in tr.payouts:
		if p.result == BetPayout.Result.LOSE:
			report.coin_lost += p.bet.stake
	if tuning.soul_on_loss:
		report.soul_damage = soul_damage_for(tr.roll.outcome, report.coin_lost, tuning, rule)
	report.explanation = _explain(tr, report)
	if report.soul_damage > 0:
		_change_soul(-report.soul_damage, _damage_label(tr.roll.outcome))

	_check_end()
	report.table_ended = is_over()
	return report


## Soul damage for one roll (doc v0.3 sections 3, 12):
##   Seven-out:        seven_out_base + ceil(lost / 10)   x rule multiplier (Hot Seven = 2)
##   Craps (come-out): craps_base     + ceil(lost / 10)   x rule multiplier
##   Other losing roll:                 floor(lost / 10)  x rule multiplier
## "lost" = stakes of the bets that LOST on this roll. Nothing lost = 0 Soul
## (a seven-out or craps with an empty felt is free; PM-approved, QA P2).
static func soul_damage_for(outcome: RollResult.Outcome, coin_lost: int, t: TuningData, r: TableRuleData) -> int:
	if coin_lost <= 0:
		return 0
	var per := maxi(t.soul_per_coin_lost, 1)
	@warning_ignore("integer_division")
	var rounded_up := (coin_lost + per - 1) / per
	@warning_ignore("integer_division")
	var full := coin_lost / per
	match outcome:
		RollResult.Outcome.SEVEN_OUT:
			return (t.seven_out_base + rounded_up) * r.seven_out_soul_multiplier
		RollResult.Outcome.CRAPS_LOSS:
			return (t.craps_base + rounded_up) * r.craps_soul_multiplier
	return full * r.other_loss_soul_multiplier


## Miss penalty (doc section 2): miss_base + 1 per miss_step_percent % of the
## gap, max miss_max. We measure the gap as a share of the TARGET bankroll
## (ending on 20 of 40 = 50% gap = 3 + 2 = 5 Soul).
static func miss_penalty_for(target_bankroll: int, final_bankroll: int, t: TuningData) -> int:
	var gap := maxi(target_bankroll - final_bankroll, 0)
	if gap == 0:
		return 0
	@warning_ignore("integer_division")
	var steps := (gap * 100) / maxi(target_bankroll * t.miss_step_percent, 1)
	return mini(t.miss_base + steps, t.miss_max)


func _check_end() -> void:
	if soul <= 0:
		_fail(FailReason.SOUL_SPENT, 0)
	elif bankroll_total() >= target():
		_clear()
	elif table.active_bets.is_empty() and bankroll.coin < tuning.min_bet:
		# Doc: "bankroll hits 0". We also count "can't afford the minimum bet
		# with nothing on the felt" as bust, since you can't play on.
		_fail(FailReason.BUST, tuning.bust_penalty)
	elif rolls_left() <= 0:
		# Doc: a Pass bet still unresolved when rolls run out is returned.
		table.clear_all_removable()
		_return_all_bets()
		if bankroll.coin >= target():
			_clear()
		else:
			_fail(FailReason.OUT_OF_ROLLS, miss_penalty_for(target(), bankroll.coin, tuning))


func _return_all_bets() -> void:
	for bet in table.active_bets:
		bankroll.add(bet.stake)
	table.active_bets.clear()


func _clear() -> void:
	_return_all_bets()
	status = Status.CLEARED
	clear_bonus_paid = tuning.clear_bonus
	unused_roll_bonus_paid = rolls_left() * tuning.coin_per_unused_roll
	bankroll.add(clear_bonus_paid + unused_roll_bonus_paid)
	finished.emit(status)


func _fail(reason: FailReason, penalty: int) -> void:
	_return_all_bets()
	status = Status.FAILED
	fail_reason = reason
	final_penalty = penalty
	if penalty > 0:
		_change_soul(-penalty, "Missed target" if reason == FailReason.OUT_OF_ROLLS else "Bust")
	finished.emit(status)


func _change_soul(delta: int, reason: String) -> void:
	var old := soul
	soul = maxi(soul + delta, 0)
	if soul != old:
		soul_changed.emit(soul, soul - old, reason)


static func _damage_label(outcome: RollResult.Outcome) -> String:
	match outcome:
		RollResult.Outcome.SEVEN_OUT:
			return "Seven-out"
		RollResult.Outcome.CRAPS_LOSS:
			return "Craps"
	return "Losses"


## One short line: what happened to the bets, and why Soul burned.
func _explain(tr: TableReport, report: PocRollReport) -> String:
	var parts := PackedStringArray()
	parts.append(tr.roll.message)
	var bets := tr.lines()
	if not bets.is_empty():
		parts.append(", ".join(bets) + ".")
	if report.soul_damage > 0:
		var per := tuning.soul_per_coin_lost
		var o := tr.roll.outcome
		var why := ""
		if o == RollResult.Outcome.SEVEN_OUT:
			why = "Seven-out: %d + %d (lost %d)" % [tuning.seven_out_base, ceili(report.coin_lost / float(per)), report.coin_lost]
			if rule.seven_out_soul_multiplier != 1:
				why += " x%d %s" % [rule.seven_out_soul_multiplier, rule.display_name]
		elif o == RollResult.Outcome.CRAPS_LOSS:
			why = "Craps: %d + %d (lost %d)" % [tuning.craps_base, ceili(report.coin_lost / float(per)), report.coin_lost]
			if rule.craps_soul_multiplier != 1:
				why += " x%d %s" % [rule.craps_soul_multiplier, rule.display_name]
		else:
			why = "Lost %d Coin" % report.coin_lost
		parts.append("%s = -%d Soul." % [why, report.soul_damage])
	elif report.coin_lost > 0:
		parts.append("Small loss, no Soul burned.")
	return " ".join(parts)
