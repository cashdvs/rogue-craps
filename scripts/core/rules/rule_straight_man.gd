## The Straight Man (boss): "Only 5-die runs count." Run combos shorter than
## params.min_run (default 5) don't count; sets still do.
class_name RuleStraightMan
extends TableRule


func excluded_combos(run: BonfireRun) -> Array:
	var out: Array = []
	for c: BonfireCombo in run.tuning.combos:
		if c.kind == BonfireCombo.Kind.RUN and c.n < int(param("min_run", 5)):
			out.append(c.id)
	return out
