## Data for a kind of bet the player can place (design doc section 5).
##
## This Resource only holds numbers and text. The code that decides whether
## a bet won lives in BetResolver (scripts/core/bet_resolver.gd), chosen by
## [member rule]. That way designers can tweak payouts and costs in the
## inspector without touching code.
##
## Payouts are stored as whole-number ratios ("pays 6 to 5" =
## numerator 6, denominator 5) and computed with integer math, so there is
## never any floating point rounding surprise.
class_name BetType
extends Resource

## How BetResolver settles this bet.
enum Rule {
	PASS,      ## Line bet: wins on Natural / Point hit, loses on Craps / Seven-out.
	ODDS,      ## Add-on behind Pass, placed during the Point phase. Pays true odds.
	ONE_ROLL,  ## Settles on the very next roll: wins if the total is in winning_totals.
	HARD_WAY,  ## Stays up until hard_number is rolled as a pair (win), or as a
			   ## non-pair ("easy") or a 7 shows (lose).
}

## Stable identifier used by code, e.g. &"pass".
@export var id: StringName = &""

## Player-facing name, e.g. "Natural (Pass)".
@export var display_name: String = ""

## Which settlement rule applies (see [enum Rule]).
@export var rule: Rule = Rule.PASS

## Base payout ratio: win numerator for every denominator wagered.
## 1 / 1 = even money, 7 / 1 = "7 to 1", 6 / 5 = "6 to 5".
@export var payout_numerator: int = 1
@export var payout_denominator: int = 1

## Per-number payout exceptions, as Vector2i(numerator, denominator).
## The key is the roll total, except for ODDS bets where the key is the
## Point. Examples: Field {2: (2,1), 12: (3,1)}; Odds {4: (2,1), 5: (3,2)...}.
@export var payout_overrides: Dictionary[int, Vector2i] = {}

## ONE_ROLL only: totals that win.
@export var winning_totals: Array[int] = []

## HARD_WAY only: the number that must come as a pair (4, 6, 8 or 10).
@export var hard_number: int = 0

## Shop price to unlock. 0 = available from the start (a starter bet).
@export var unlock_cost: int = 0

## Bets with the same unlock group are bought together in the shop
## (the doc sells "Hard 6 / Hard 8" as one unlock). Empty = just this bet.
@export var unlock_group: StringName = &""

## Player-facing rules text.
@export_multiline var description: String = ""


func is_starter() -> bool:
	return unlock_cost <= 0


## The shop groups bets by this id (falls back to the bet's own id).
func get_unlock_group() -> StringName:
	return unlock_group if unlock_group != &"" else id


## The payout ratio that applies for a given number (roll total, or the
## Point for ODDS). Returns Vector2i(numerator, denominator).
func ratio_for(number: int) -> Vector2i:
	if payout_overrides.has(number):
		return payout_overrides[number]
	return Vector2i(payout_numerator, payout_denominator)


## Profit (NOT including the returned stake) for a winning wager.
## Integer math, rounded down like a real casino that only pays whole Coin.
## Example: 6:5 on a 7 Coin stake = 7 * 6 / 5 = 42 / 5 = 8 (8.4 rounded down).
func profit_for(stake: int, number: int = 0) -> int:
	var ratio := ratio_for(number)
	if ratio.y <= 0:
		push_error("BetType %s: payout denominator must be > 0." % id)
		return 0
	@warning_ignore("integer_division")
	return (stake * ratio.x) / ratio.y


## Text like "7:1" or "6:5" for the UI.
func ratio_text(number: int = 0) -> String:
	var ratio := ratio_for(number)
	return "%d:%d" % [ratio.x, ratio.y]
