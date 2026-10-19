## The Bloodletter (boss): "Soul costs are doubled": busts, the timeout /
## forfeit penalty and Blood faces. params.soul_cost_mult (default 2).
class_name RuleBloodletter
extends TableRule


## The Game Designer's HUD line (also the boss intro, from
## resources/map/rules/bloodletter.tres): "Every Soul cost is doubled: a bust
## costs 2." The bust number follows the tuning and the multiplier.
const LINE := "Every Soul cost is doubled: a bust costs %d."


func info_line(run: BonfireRun) -> String:
	return LINE % soul_cost(run, run.tuning.bust_soul_loss, &"bust")


func soul_cost(_run: BonfireRun, amount: int, _kind: StringName) -> int:
	return amount * int(param("soul_cost_mult", 2))
