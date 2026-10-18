## Data for a kind of bet the player can place (Pass Line, Field, ...).
##
## Bets start locked (except the basics) and are unlocked in the shop for
## [member unlock_cost]. The actual resolution logic for each bet lives in
## code keyed by [member id]; this Resource only holds tunable numbers/text.
class_name BetType
extends Resource

## Stable identifier used by code, e.g. &"pass_line".
@export var id: StringName = &""

## Player-facing name, e.g. "Pass Line".
@export var display_name: String = ""

## Payout ratio as "win X for every 1 wagered". 1.0 = even money (1:1).
@export var payout: float = 1.0

## Shop price to unlock. 0 = available from the start.
@export var unlock_cost: int = 0

## Player-facing rules text.
@export_multiline var description: String = ""


func is_starter() -> bool:
	return unlock_cost <= 0


## Winnings (profit, not including the returned stake) for a winning wager.
func profit_for(wager: int) -> int:
	return int(floor(wager * payout))
