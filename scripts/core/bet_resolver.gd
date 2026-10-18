## Settles bets against a roll. Stateless: give it a RollResult and the
## active bets, get back one BetPayout per bet. No Coin is moved here;
## TableState applies the payouts to the Bankroll.
##
## Each BetType.Rule has its own small function below, so adding a new kind
## of bet = add a Rule value + one function.
class_name BetResolver
extends RefCounted

## Hard ways lose on a 7 (doc: "before a 7 or the soft version").
## This is the dice fact 7, not CrapsRound.seven_out_total, so a boss
## rigging seven-outs doesn't silently change side bets.
const HARD_WAY_SEVEN: int = 7


static func resolve(roll: RollResult, bets: Array[ActiveBet]) -> Array[BetPayout]:
	var payouts: Array[BetPayout] = []
	for bet in bets:
		payouts.append(resolve_one(roll, bet))
	return payouts


static func resolve_one(roll: RollResult, bet: ActiveBet) -> BetPayout:
	# A rejected roll never settles anything.
	if roll == null or roll.is_invalid():
		return BetPayout.new(bet, BetPayout.Result.STAYS)
	match bet.bet_type.rule:
		BetType.Rule.PASS:
			return _resolve_pass(roll, bet)
		BetType.Rule.ODDS:
			return _resolve_odds(roll, bet)
		BetType.Rule.ONE_ROLL:
			return _resolve_one_roll(roll, bet)
		BetType.Rule.HARD_WAY:
			return _resolve_hard_way(roll, bet)
	push_error("BetResolver: unknown rule for bet %s" % bet.id())
	return BetPayout.new(bet, BetPayout.Result.STAYS)


## Natural (Pass): follows the round itself.
static func _resolve_pass(roll: RollResult, bet: ActiveBet) -> BetPayout:
	if roll.is_win():
		return _win(bet, roll.total)
	if roll.is_loss():
		return BetPayout.new(bet, BetPayout.Result.LOSE)
	return BetPayout.new(bet, BetPayout.Result.STAYS)


## Odds: wins when the Point is hit (true odds keyed by the Point),
## loses on a Seven-out, otherwise stays.
static func _resolve_odds(roll: RollResult, bet: ActiveBet) -> BetPayout:
	match roll.outcome:
		RollResult.Outcome.POINT_HIT:
			return _win(bet, roll.point_before)
		RollResult.Outcome.SEVEN_OUT:
			return BetPayout.new(bet, BetPayout.Result.LOSE)
	return BetPayout.new(bet, BetPayout.Result.STAYS)


## One-roll bets (Field, Any Craps, ...): always settle on this roll.
static func _resolve_one_roll(roll: RollResult, bet: ActiveBet) -> BetPayout:
	if bet.bet_type.winning_totals.has(roll.total):
		return _win(bet, roll.total)
	return BetPayout.new(bet, BetPayout.Result.LOSE)


## Hard ways: win on the pair, lose on the easy way or a 7, else stay up.
static func _resolve_hard_way(roll: RollResult, bet: ActiveBet) -> BetPayout:
	var hard := bet.bet_type.hard_number
	if roll.total == hard:
		if is_pair(roll.die_values):
			return _win(bet, roll.total)
		return BetPayout.new(bet, BetPayout.Result.LOSE)  # easy way
	if roll.total == HARD_WAY_SEVEN:
		return BetPayout.new(bet, BetPayout.Result.LOSE)
	return BetPayout.new(bet, BetPayout.Result.STAYS)


## True for exactly two dice showing the same value (e.g. [3, 3]).
static func is_pair(values: Array[int]) -> bool:
	return values.size() == 2 and values[0] == values[1]


static func _win(bet: ActiveBet, number: int) -> BetPayout:
	return BetPayout.new(bet, BetPayout.Result.WIN, bet.bet_type.profit_for(bet.stake, number))
