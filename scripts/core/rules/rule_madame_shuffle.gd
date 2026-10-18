## Madame Shuffle (boss): "Rerolls your highest unpotted die after each
## throw." Every die of a fresh throw is unpotted, so after it settles the
## highest-value die (ties: the first) is rerolled with its own weights,
## before anything lights. params.count (default 1) dice per throw.
class_name RuleMadameShuffle
extends TableRule


func on_throw_landed(_run: BonfireRun, th: TableThrow) -> void:
	var done: Array[int] = []
	for k in int(param("count", 1)):
		var best := -1
		for i in th.size():
			if done.has(i):
				continue
			if best < 0 or th.values[i] > th.values[best]:
				best = i
		if best < 0:
			return
		done.append(best)
		th.reroll(best, id)
