## The Collector (boss): "Face mods do nothing on each hand's first throw" of each
## hand: every face mod is plain for lighting and scoring. Blank is a curse
## face, not a mod, so it stays Blank (BonfireScoring keeps is_curse faces).
## params.throws (default 1).
class_name RuleCollector
extends TableRule


func mods_active(run: BonfireRun) -> bool:
	return run.throws_this_hand > int(param("throws", 1))
