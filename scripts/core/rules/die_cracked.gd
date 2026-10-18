## Cracked Die: "x2 mult on its pot (BonfireScoring); 1 in 6 chance it
## shatters after scoring." Rolled when its pot is committed; a shattered die
## leaves the table (and the run's bag, via TableOutcome.shattered_dice) with
## its mods. Floor: never while the player owns <= cracked_min_owned_dice (5). params.chance (default BonfireTuning.cracked_shatter_chance).
class_name DieCracked
extends TableRule


func on_pot(run: BonfireRun, info: Dictionary) -> void:
	if not run.can_shatter():
		return
	var chance := float(param("chance", run.tuning.cracked_shatter_chance))
	for i: int in info.get("indices", []):
		if run.throw_special(i) == &"cracked" and run.can_shatter() and run.rng.randf() < chance:
			run.shatter(i)
