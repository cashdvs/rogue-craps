## Greedy Pot (Elite twist): "Pot at least 2 dice per throw." params.min_pot
## (default 2). A throw of fewer dice must pot all of them; a throw with no
## legal pot that big busts.
class_name RuleGreedyPot
extends TableRule


func min_pot(_run: BonfireRun) -> int:
	return int(param("min_pot", 2))
