## Everything a Bonfire table needs from the run (map/events spec §1): the
## handful (dice with per-face mods), the goal with its bounties and hands,
## start and max Soul, a seed, and the Elite twist / boss cheat rules.
## MapRun builds it; the table reads it. Godot Dev's setup-driven table will
## take these fields; until then RunScreen maps it onto a BonfireTuning copy.
class_name RunTableSetup
extends RefCounted

var goal: TableGoal
var dice: Array[RunDie] = []
var start_soul: int = 35
var max_soul: int = 35
var seed_value: int = 0
## Twist / cheat ids and params, for the table to enforce.
var rules: Array[RunRuleData] = []
## Soul per bust after rules (Heavy Burn); -1 = the table's normal value.
var bust_soul_loss: int = -1
## Combo id -> base / mult the run's Seals add (x = base, y = mult).
var seal_bonus: Dictionary[StringName, Vector2i] = {}


func rule_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for r in rules:
		out.append(r.id)
	return out


## The current Bonfire scene's tuning for this setup: Seal-leveled combos,
## start Soul, this goal, and the bust cost. (Max Soul, dice and rules wait
## for the setup-driven table.)
func to_tuning(base: BonfireTuning) -> BonfireTuning:
	var t := base.duplicate() as BonfireTuning
	var combos: Array[BonfireCombo] = []
	for c in base.combos:
		var copy := c.duplicate() as BonfireCombo
		var b: Vector2i = seal_bonus.get(c.id, Vector2i.ZERO)
		copy.base += b.x
		copy.mult += b.y
		combos.append(copy)
	t.combos = combos
	t.starting_soul = start_soul
	t.table_goal = goal
	if bust_soul_loss >= 0:
		t.bust_soul_loss = bust_soul_loss
	return t
