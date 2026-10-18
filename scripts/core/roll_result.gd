## The answer CrapsRound gives back after resolving one roll.
##
## A small "struct" object: it only carries data. The UI reads it to update
## labels; future bet logic will read it to pay out wagers. Nothing in here
## knows about scenes or nodes.
class_name RollResult
extends RefCounted

## Every possible outcome of a single roll in craps.
enum Outcome {
	NO_DECISION,  ## Point phase, rolled neither the Point nor 7. Keep rolling.
	NATURAL_WIN,  ## Come-out 7 or 11. Pass Line wins.
	CRAPS_LOSS,   ## Come-out 2, 3 or 12. Pass Line loses.
	POINT_SET,    ## Come-out 4/5/6/8/9/10. That number becomes the Point.
	POINT_HIT,    ## Point phase, rolled the Point again. Pass Line wins.
	SEVEN_OUT,    ## Point phase, rolled a 7. Pass Line loses.
}

## The individual die values rolled (e.g. [3, 4]).
var die_values: Array[int] = []
## Sum of [member die_values].
var total: int = 0
## What happened (see [enum Outcome]).
var outcome: Outcome = Outcome.NO_DECISION
## Phase the round was in BEFORE this roll (CrapsRound.Phase value).
var phase_before: int = 0
## Point before this roll (0 = no point).
var point_before: int = 0
## Point after this roll (0 = no point, i.e. back to come-out).
var point_after: int = 0
## Human-readable explanation, ready to show on screen.
var message: String = ""


## True for outcomes where a Pass Line bet wins.
func is_win() -> bool:
	return outcome == Outcome.NATURAL_WIN or outcome == Outcome.POINT_HIT


## True for outcomes where a Pass Line bet loses.
func is_loss() -> bool:
	return outcome == Outcome.CRAPS_LOSS or outcome == Outcome.SEVEN_OUT


## A "decision" means the round ended (win or loss) and resets to come-out.
func is_decision() -> bool:
	return is_win() or is_loss()


static func outcome_name(value: Outcome) -> String:
	return Outcome.keys()[value]


func _to_string() -> String:
	return "RollResult(%s total=%d %s point %d->%d)" % [
		str(die_values), total, outcome_name(outcome), point_before, point_after]
