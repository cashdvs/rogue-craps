## A betting session at one craps table: Coin on the felt, bets, rolls.
##
## Pure logic (no nodes). The table scene and the greybox both drive this:
##   place_bet() / clear_bet()  -> move Coin between the Bankroll and the felt
##   roll(die_values)           -> CrapsRound + BetResolver settle the bets
##
## Money flow: placing a bet takes the stake out of the Bankroll right away
## (like pushing chips onto the felt). Winning bets return stake + profit,
## pushes return the stake, losing bets are just removed.
##
## NOT here yet (paused per PM): table Coin targets, roll limits, Soul, shop.
class_name CrapsTable
extends RefCounted

## Emitted after every accepted roll, with the full report.
signal rolled(report: TableReport)

## Doc section 2: minimum bet 5, Floor 1 table cap 25 (per bet).
var min_bet: int = 5
var max_bet: int = 25
## Doc section 5: Odds behind Pass go up to this many times the Pass bet.
var odds_max_multiple: int = 2

var bankroll: Bankroll
var craps := CrapsRound.new()
var active_bets: Array[ActiveBet] = []
var rolls_made: int = 0


func _init(table_bankroll: Bankroll) -> void:
	bankroll = table_bankroll


## Coin currently sitting on the felt in bets.
func staked_total() -> int:
	var total := 0
	for bet in active_bets:
		total += bet.stake
	return total


func find_bet(bet_id: StringName) -> ActiveBet:
	for bet in active_bets:
		if bet.id() == bet_id:
			return bet
	return null


func stake_on(bet_id: StringName) -> int:
	var bet := find_bet(bet_id)
	return bet.stake if bet != null else 0


## Returns "" if the bet can be placed, otherwise a reason for the player.
## Adding to a bet that's already up just raises its stake.
func can_place(bet_type: BetType, amount: int) -> String:
	if bet_type == null:
		return "No bet selected."
	if amount <= 0:
		return "Bet must be more than 0."
	if not bankroll.can_afford(amount):
		return "Not enough Coin (have %d, need %d)." % [bankroll.coin, amount]
	var new_stake := stake_on(bet_type.id) + amount
	# Odds are an add-on behind Pass: their own rules replace the table
	# min / cap (real craps: odds aren't bound by the table limits).
	if bet_type.rule == BetType.Rule.ODDS:
		return _can_place_odds(new_stake)
	if new_stake < min_bet:
		return "Minimum bet is %d." % min_bet
	if new_stake > max_bet:
		return "Table cap is %d per bet." % max_bet
	# Real craps: the Pass bet goes down before the come-out roll.
	if bet_type.rule == BetType.Rule.PASS and craps.has_point():
		return "Pass can only be placed before the come-out roll."
	return ""


## Odds rules (doc section 5): only while a Point is on, only with a Pass
## bet underneath, and at most odds_max_multiple x the Pass stake in total.
func _can_place_odds(new_stake: int) -> String:
	if not craps.has_point():
		return "Odds can only be placed once a Point is on."
	var pass_stake := 0
	for bet in active_bets:
		if bet.bet_type.rule == BetType.Rule.PASS:
			pass_stake += bet.stake
	if pass_stake <= 0:
		return "Odds need a Pass Line bet underneath."
	var cap := pass_stake * maxi(odds_max_multiple, 0)
	if new_stake > cap:
		return "Odds are capped at %dx your Pass bet (max %d)." % [odds_max_multiple, cap]
	return ""


## Places (or raises) a bet. Returns "" on success, else the reason it failed.
func place_bet(bet_type: BetType, amount: int) -> String:
	var reason := can_place(bet_type, amount)
	if reason != "":
		return reason
	bankroll.spend(amount)
	var existing := find_bet(bet_type.id)
	if existing != null:
		existing.stake += amount
	else:
		active_bets.append(ActiveBet.new(bet_type, amount))
	return ""


## Returns "" if the bet can be taken down, else why not.
func can_clear(bet_id: StringName) -> String:
	var bet := find_bet(bet_id)
	if bet == null:
		return "No such bet on the table."
	# A Pass bet is a contract once the Point is set (real craps rule).
	if bet.bet_type.rule == BetType.Rule.PASS and craps.has_point():
		return "Pass can't be taken down while a Point is set."
	return ""


## Takes a bet down and returns its stake to the bankroll.
func clear_bet(bet_id: StringName) -> String:
	var reason := can_clear(bet_id)
	if reason != "":
		return reason
	var bet := find_bet(bet_id)
	active_bets.erase(bet)
	bankroll.add(bet.stake)
	return ""


## Takes down every bet that's allowed to come down. Returns Coin returned.
func clear_all_removable() -> int:
	var returned := 0
	for bet in active_bets.duplicate():
		if can_clear(bet.id()) == "":
			returned += bet.stake
			clear_bet(bet.id())
	return returned


## Resolves one roll of the given die values and pays the bets.
## An invalid roll (bad dice / total outside 2-12) changes nothing.
func roll(die_values: Array[int]) -> TableReport:
	var report := TableReport.new()
	var result := craps.resolve_dice(die_values)
	report.roll = result
	if result.is_invalid():
		report.rejected = true
		report.reject_reason = result.message
		return report

	rolls_made += 1
	report.payouts = BetResolver.resolve(result, active_bets)
	for payout in report.payouts:
		report.net += payout.net()
		report.coin_returned += payout.coin_returned()
		if payout.is_settled():
			active_bets.erase(payout.bet)
			bankroll.add(payout.coin_returned())
	rolled.emit(report)
	return report
