## The player's Coin (design doc section 3: Coin is both bankroll and shop money).
##
## Pure logic: no nodes. All changes go through add()/spend() so the
## coin_changed signal always fires and Coin can never go negative.
class_name Bankroll
extends RefCounted

## Emitted whenever Coin changes. delta is positive for gains, negative for spends.
signal coin_changed(new_coin: int, delta: int)

## Current Coin. Read it freely, but change it with add()/spend()/set_coin().
var coin: int = 0


func _init(starting_coin: int = 0) -> void:
	coin = maxi(starting_coin, 0)


func can_afford(amount: int) -> bool:
	return amount >= 0 and amount <= coin


## Adds Coin (winnings, bonuses, returned stakes). Negative amounts are refused.
func add(amount: int) -> void:
	if amount < 0:
		push_error("Bankroll.add: amount must be >= 0 (got %d). Use spend()." % amount)
		return
	if amount == 0:
		return
	coin += amount
	coin_changed.emit(coin, amount)


## Removes Coin if you have enough. Returns false (and changes nothing)
## if you can't afford it, so you can never bet more than you have.
func spend(amount: int) -> bool:
	if amount < 0:
		push_error("Bankroll.spend: amount must be >= 0 (got %d)." % amount)
		return false
	if not can_afford(amount):
		return false
	if amount == 0:
		return true
	coin -= amount
	coin_changed.emit(coin, -amount)
	return true


## Sets Coin directly (e.g. the 10 Coin floor after a failed table).
func set_coin(new_coin: int) -> void:
	new_coin = maxi(new_coin, 0)
	var delta := new_coin - coin
	if delta == 0:
		return
	coin = new_coin
	coin_changed.emit(coin, delta)
