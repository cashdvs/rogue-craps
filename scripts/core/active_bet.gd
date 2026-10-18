## A bet currently sitting on the table: which BetType, and how much Coin.
##
## The stake has already been taken out of the Bankroll when the bet was
## placed (like pushing real chips onto the felt). Winning returns the
## stake plus profit; losing just removes the bet.
class_name ActiveBet
extends RefCounted

var bet_type: BetType
var stake: int = 0


func _init(type: BetType = null, amount: int = 0) -> void:
	bet_type = type
	stake = amount


func id() -> StringName:
	return bet_type.id if bet_type != null else &""
