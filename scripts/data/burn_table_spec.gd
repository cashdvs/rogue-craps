## One Burn Line table in a run: its Line, coin start/target, hands and bets.
class_name BurnTableSpec
extends Resource

@export var display_name: String = "Table 1"
## Land on this total exactly for the best return; over it = BURN.
@export var line: int = 15
## Coin at the start of the table (coin resets every table).
@export var start_coin: int = 20
## Clear the table by ending any hand with coin >= this.
@export var coin_target: int = 40
## Hands you get to reach the target.
@export var hands: int = 8
## Most you can bet on one hand.
@export var bet_cap: int = 10
