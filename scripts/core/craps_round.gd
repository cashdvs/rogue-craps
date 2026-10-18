## Pure craps rules: tracks the come-out / Point state and resolves totals.
##
## This script has NO scene, node, or UI dependency on purpose:
##   * it can be unit-tested headlessly (see tests/test_craps_rules.gd),
##   * the same rules object can drive the greybox, a real UI, or an AI sim,
##   * bosses can "rig the rules" by changing the number lists below.
##
## Flow of a round:
##   COME-OUT roll: 7/11 = natural win, 2/3/12 = craps loss,
##                  anything else (4,5,6,8,9,10) becomes the Point.
##   POINT rolls:   the Point again = win, 7 = seven-out loss,
##                  anything else = no decision, roll again.
##   After any win/loss the round resets to COME-OUT with no Point.
class_name CrapsRound
extends RefCounted

## Which half of the round we're in.
enum Phase {
	COME_OUT,  ## No Point yet. Next roll can win, lose, or set the Point.
	POINT,     ## A Point is set. Chasing it before a 7 shows up.
}

## Emitted after every resolved roll. Handy for UI or relic hooks.
signal roll_resolved(result: RollResult)

# --- Rule numbers -----------------------------------------------------------
# These are variables (not constants) so a Dealer boss can rig them, e.g.
# `round.natural_totals = [7]` removes 11 as a natural, or
# `round.craps_totals.append(11)`. Defaults are standard casino craps.

## Come-out totals that win immediately.
var natural_totals: Array[int] = [7, 11]
## Come-out totals that lose immediately ("craps").
var craps_totals: Array[int] = [2, 3, 12]
## During the Point phase, rolling this loses ("seven-out").
var seven_out_total: int = 7

# --- State ------------------------------------------------------------------

## Current phase. Read-only from outside: use resolve()/reset() to change it.
var phase: Phase = Phase.COME_OUT
## The current Point, or 0 when there is none.
var point: int = 0


## Puts the round back to a fresh come-out with no Point.
func reset() -> void:
	phase = Phase.COME_OUT
	point = 0


func has_point() -> bool:
	return phase == Phase.POINT


## Resolves a roll given the individual die values (e.g. [3, 4]).
## Using values (not just a total) lets the result remember what was rolled.
func resolve_dice(die_values: Array[int]) -> RollResult:
	var total := 0
	for v in die_values:
		total += v
	return _resolve(total, die_values)


## Resolves a roll given only its total. Mostly useful for tests.
func resolve_total(total: int) -> RollResult:
	var no_dice: Array[int] = []
	return _resolve(total, no_dice)


func _resolve(total: int, die_values: Array[int]) -> RollResult:
	var result := RollResult.new()
	result.die_values = die_values.duplicate()
	result.total = total
	result.phase_before = phase
	result.point_before = point

	if phase == Phase.COME_OUT:
		_resolve_come_out(result)
	else:
		_resolve_point_phase(result)

	result.point_after = point
	roll_resolved.emit(result)
	return result


func _resolve_come_out(result: RollResult) -> void:
	var total := result.total
	# Order matters only if a boss makes the lists overlap; naturals win ties.
	if natural_totals.has(total):
		result.outcome = RollResult.Outcome.NATURAL_WIN
		result.message = "Natural %d! You win." % total
		reset()
	elif craps_totals.has(total):
		result.outcome = RollResult.Outcome.CRAPS_LOSS
		result.message = "Craps %d. You lose." % total
		reset()
	else:
		# Any other total becomes the Point we now have to roll again.
		result.outcome = RollResult.Outcome.POINT_SET
		phase = Phase.POINT
		point = total
		result.message = "Point is %d. Roll it again before a %d!" % [total, seven_out_total]


func _resolve_point_phase(result: RollResult) -> void:
	var total := result.total
	# Hitting the Point is checked first, so a rigged Point equal to the
	# seven-out number would still count as a win.
	if total == point:
		result.outcome = RollResult.Outcome.POINT_HIT
		result.message = "Hit the Point (%d)! You win." % total
		reset()
	elif total == seven_out_total:
		result.outcome = RollResult.Outcome.SEVEN_OUT
		result.message = "Seven out! You lose."
		reset()
	else:
		result.outcome = RollResult.Outcome.NO_DECISION
		result.message = "Rolled %d. No decision, still chasing %d." % [total, point]


static func phase_name(value: Phase) -> String:
	return "Come-out" if value == Phase.COME_OUT else "Point"
