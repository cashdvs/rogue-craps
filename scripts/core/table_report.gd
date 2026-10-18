## Everything that happened on one roll at a table, for the UI and tests.
class_name TableReport
extends RefCounted

## The craps result (total, outcome, message...).
var roll: RollResult
## One entry per bet that was on the table.
var payouts: Array[BetPayout] = []
## Sum of BetPayout.net() for this roll (positive = you won Coin).
var net: int = 0
## Coin that came back to the bankroll this roll (stakes + profit).
var coin_returned: int = 0
## True if the roll was refused (bad dice...). Nothing changed.
var rejected: bool = false
## Why it was rejected, for the UI.
var reject_reason: String = ""


## Payouts that settled (won, lost or pushed) this roll.
func settled() -> Array[BetPayout]:
	var out: Array[BetPayout] = []
	for p in payouts:
		if p.is_settled():
			out.append(p)
	return out


func lines() -> PackedStringArray:
	var out := PackedStringArray()
	for p in settled():
		out.append(p.describe())
	return out
