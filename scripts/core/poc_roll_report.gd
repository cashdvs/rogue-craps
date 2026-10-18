## What one roll did at the proof-of-concept table: bets, Soul, and a
## one-line "why" for the player.
class_name PocRollReport
extends RefCounted

## Bets and craps result (see TableReport).
var table_report: TableReport
## Coin lost on this roll: the stakes of every LOSING bet (gross, not net).
var coin_lost: int = 0
## Soul burned by this roll (before any end-of-table penalty).
var soul_damage: int = 0
## Short explanation, e.g. "Seven-out! Lost 10 -> 2+1 Soul x2 (Hot Seven) = 6".
var explanation: String = ""
## True if the table ended on this roll.
var table_ended: bool = false
## True if the roll was refused (nothing changed).
var rejected: bool = false
