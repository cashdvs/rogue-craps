## The Collector (boss): "Face mods are off on the first throw" of each
## hand: every face (incl. Blank) is plain for lighting and scoring.
## params.throws (default 1).
class_name RuleCollector
extends TableRule


func mods_active(run: BonfireRun) -> bool:
	return run.throws_this_hand > int(param("throws", 1))
