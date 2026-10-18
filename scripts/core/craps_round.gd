## Pure craps rules: tracks the come-out / Point state and resolves totals.
##
## This script has NO scene, node, or UI dependency on purpose:
##   * it can be unit-tested headlessly (see tests/test_craps_rules.gd),
##   * the same rules object can drive the greybox, a real UI, or an AI sim,
##   * bosses can "rig the rules" by changing the number lists below.
##
## Rule precedence (matters only when a boss rigs overlapping numbers):
##   0. A total outside MIN_TOTAL..MAX_TOTAL is rejected first (INVALID).
##   Come-out:  1. natural_totals  2. craps_totals  3. otherwise set the Point.
##              So a total in BOTH lists counts as a Natural (player-friendly).
##   Point:     1. the Point  2. seven_out_total  3. otherwise no decision.
##              So if a boss makes seven_out_total equal the Point, hitting
##              it counts as a Point hit (win), not a Seven-out.
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

## Valid totals for two six-sided dice. See the TODO in _resolve().
const MIN_TOTAL: int = 2
const MAX_TOTAL: int = 12

## Emitted after every resolved roll. Handy for UI or chip (relic) hooks.
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
## Using values (not just a total) lets the result remember what was rolled
## (hard-way bets need to know if it was a pair).
## An empty array (e.g. a failed roll) is rejected as INVALID.
func resolve_dice(die_values: Array[int]) -> RollResult:
	if die_values.is_empty():
		push_error("CrapsRound: resolve_dice() got no dice values.")
		var bad := RollResult.new()
		bad.outcome = RollResult.Outcome.INVALID
		bad.phase_before = phase
		bad.point_before = point
		bad.point_after = point
		bad.message = "No dice were rolled."
		return bad
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

	# TODO(modded dice): totals outside 2-12 are rejected for now. Face mods
	# will break this assumption: a Glass face that shatters counts as 0
	# (so 0+1 = 1 is possible), a 3rd die could go up to 18, and Pip Shift
	# could push faces past 6. When those land, decide per case: e.g. treat
	# totals below 2 as Craps and above 12 as "no decision", or let the
	# modifier clamp each face to 1-6 before summing. Until then, rejecting
	# loudly is safer than guessing a rule.
	if total < MIN_TOTAL or total > MAX_TOTAL:
		push_warning("CrapsRound: rejected total %d (valid range %d-%d)." % [total, MIN_TOTAL, MAX_TOTAL])
		result.outcome = RollResult.Outcome.INVALID
		result.point_after = point
		result.message = "Invalid roll total %d. Nothing happened." % total
		roll_resolved.emit(result)
		return result

	if phase == Phase.COME_OUT:
		_resolve_come_out(result)
	else:
		_resolve_point_phase(result)

	result.point_after = point
	roll_resolved.emit(result)
	return result


func _resolve_come_out(result: RollResult) -> void:
	var total := result.total
	# Precedence: Natural is checked before Craps (see header comment).
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
	# Precedence: the Point is checked before seven-out (see header comment).
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
