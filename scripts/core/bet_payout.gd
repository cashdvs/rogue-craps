## What happened to one ActiveBet on one roll. Produced by BetResolver.
class_name BetPayout
extends RefCounted

enum Result {
	STAYS,  ## Not decided yet; the bet stays on the table.
	WIN,    ## Pays stake + profit back to the bankroll.
	LOSE,   ## The stake is gone.
	PUSH,   ## Tie: the stake comes back, no profit.
}

var bet: ActiveBet
var result: Result = Result.STAYS
## Profit only (0 unless WIN).
var profit: int = 0


func _init(active_bet: ActiveBet = null, bet_result: Result = Result.STAYS, bet_profit: int = 0) -> void:
	bet = active_bet
	result = bet_result
	profit = bet_profit


## True if the bet comes off the table after this roll.
func is_settled() -> bool:
	return result != Result.STAYS


## Coin that goes back into the bankroll: stake + profit on a win, the
## stake on a push, nothing on a loss or if it stays up.
func coin_returned() -> int:
	match result:
		Result.WIN:
			return bet.stake + profit
		Result.PUSH:
			return bet.stake
		_:
			return 0


## Change in the player's money vs. before the bet was placed.
func net() -> int:
	match result:
		Result.WIN:
			return profit
		Result.LOSE:
			return -bet.stake
		_:
			return 0


func describe() -> String:
	var name := bet.bet_type.display_name
	match result:
		Result.WIN:
			return "%s wins +%d" % [name, profit]
		Result.LOSE:
			return "%s loses -%d" % [name, bet.stake]
		Result.PUSH:
			return "%s pushes" % name
		_:
			return "%s stays up" % name
