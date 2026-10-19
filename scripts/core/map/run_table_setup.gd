## Everything a Bonfire table needs from the run (map/events spec §1): the
## handful (dice with per-face mods), the goal with its bounties and hands,
## start and max Soul, a seed, and the Elite twist / boss cheat rules.
## MapRun builds it; to_table_setup() hands it to Godot Dev's Bonfire3D.
class_name RunTableSetup
extends RefCounted

var goal: TableGoal
var dice: Array[RunDie] = []
## The same handful as Bonfire TableDie (RunProgress.table_dice()).
var table_dice: Array[TableDie] = []
var start_soul: int = 35
var max_soul: int = 35
var seed_value: int = 0
## Every die the player owns (can exceed the dice brought to the table);
## the table's Cracked floor reads it (TableSetup.owned_dice_count).
var owned_dice_count: int = 0
## Twist / cheat ids and params, for the table to enforce.
var rules: Array[RunRuleData] = []
## Soul per bust after rules (Heavy Burn); -1 = the table's normal value.
var bust_soul_loss: int = -1
## Combo id -> base / mult the run's Seals add (x = base, y = mult).
var seal_bonus: Dictionary[StringName, Vector2i] = {}
## The run's first table (TableSetup.first_table: the tutorial seeds).
var first_table: bool = false


func rule_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for r in rules:
		out.append(r.id)
	return out


## Godot Dev's TableSetup for Bonfire3D.setup: every run die as a TableDie
## (special die faces + per-face mods), the goal and its bounties, starting
## and max Soul, the seed, run mode, and `base` with the Seal levels and the
## rules' bust cost applied. Rules go to TableSetup.rules
## ({id, params} each).
func to_table_setup(base: BonfireTuning) -> TableSetup:
	var ts := TableSetup.new()
	ts.dice = table_dice.duplicate()
	ts.goal = goal
	ts.tuning = leveled(base)
	ts.starting_soul = start_soul
	ts.max_soul = max_soul
	ts.table_seed = seed_value
	ts.run_mode = true
	ts.rules = rule_entries()
	ts.owned_dice_count = owned_dice_count
	ts.first_table = first_table
	return ts


## TableSetup.rules: one {"id", "params"} per twist / cheat, in order.
## Short Table / Heavy Burn are labels at the table; their hands / bust cost
## are already in goal.hands / tuning.bust_soul_loss.
func rule_entries() -> Array:
	var out: Array = []
	for r in rules:
		out.append({"id": r.id, "params": r.params.duplicate(true)})
	return out


## A copy of `base` with Seal-leveled combos, this goal and the bust cost.
func leveled(base: BonfireTuning) -> BonfireTuning:
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
