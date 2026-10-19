## The Bloodletter (boss): "Soul costs are doubled": busts, the timeout /
## forfeit penalty and Blood faces. params.soul_cost_mult (default 2).
class_name RuleBloodletter
extends TableRule


func soul_cost(_run: BonfireRun, amount: int, _kind: StringName) -> int:
	return amount * int(param("soul_cost_mult", 2))
