## Madame Shuffle (boss): "After each throw, she rerolls one random lit die."
## Order (design/strings_v1.md, issue #70): the throw lands, the lit check
## runs, then ONE random lit die of this throw (every die of a fresh throw
## is unpotted) is rerolled with its own face weights, and BonfireRun's
## normal lit check runs again on the result. If nothing lights after her
## reroll it's an ordinary bust (a full throw that lights nothing keeps its
## free rethrow, nonstandard_dice.md §4, once that lands).
## Randomness: the throw's rng (the run's seeded rng), so the same seed and
## throw always pick and roll the same die. params.count (default 1) =
## rerolls per throw (each picks among the dice lit at that moment).
class_name RuleMadameShuffle
extends TableRule


func on_throw_landed(run: BonfireRun, th: TableThrow) -> void:
	var done: Array[int] = []
	for k in int(param("count", 1)):
		var lit := lit_now(run, th)
		var choices: Array[int] = []
		for i in lit:
			if not done.has(i):
				choices.append(i)
		if choices.is_empty():
			return
		var pick: int = choices[th.rng.randi_range(0, choices.size() - 1)]
		done.append(pick)
		th.reroll(pick, id)


## Indices of this (not yet applied) throw that light right now, with every
## rule's lit check (cold faces, mods off, Greedy Pot...).
static func lit_now(run: BonfireRun, th: TableThrow) -> Array[int]:
	var dice: Array = []
	for i in th.size():
		dice.append(BonfireScoring.make_die(th.values[i], th.mods[i] if i < th.mods.size() else null, th.special(i)))
	# rule_ctx sizes min_dice / throw_size from throw_faces: point it at this
	# throw first (land_throw overwrites it right after the rules run).
	run.throw_faces = th.values.duplicate()
	return BonfireScoring.lit_indices(dice, run.tuning, run.rule_ctx())
