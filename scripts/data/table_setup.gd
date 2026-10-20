## How the run opens a Bonfire table: the handful (any count, each a
## TableDie with faces / weights / per-face mods), the goal, Soul (starting
## and max are separate), the tuning (e.g. RunProgress.leveled_tuning) and a
## seed. Set Bonfire3D.setup before adding the scene to the tree; with no
## setup the table is the sandbox (5 Bone + Table 1, Restart / Quit to title).
class_name TableSetup
extends RefCounted

var dice: Array[TableDie] = []
var goal: TableGoal
## null = the scene's bonfire_tuning.
var tuning: BonfireTuning
var starting_soul: int = 35
var max_soul: int = 35
## -1 = random.
var table_seed: int = -1
## Run mode: no Restart / Quit to title; Esc offers Forfeit; the table emits
## Bonfire3D.finished(TableOutcome) and never changes scenes.
var run_mode: bool = true
## The table's twists / boss cheats, enforced by the table (TableRules).
## Each entry: {"id": StringName, "params": Dictionary}, e.g.
##   [{"id": &"cold_sixes", "params": {"face": 6}}, {"id": &"pit_boss", "params": {}}]
## Optional "name" / "description" override the HUD text; a RunRuleData
## resource is accepted as an entry too. Short Table / Heavy Burn are
## labels only: set goal.hands / tuning.bust_soul_loss for them.
var rules: Array = []
## Dice the player owns in the run bag (Cracked never shatters at <= 5).
## -1 = dice.size().
var owned_dice_count: int = -1
## The run's first table (the sandbox counts as one): only it gets the
## Table 1 tutorial seeds and TH hints (Game Designer's
## design/onboarding_hints_v1.md, in the design docs outside this repo).
var first_table: bool = true
## The run's Seal steps for the Knucklebone (NonStdDice.seal_steps(run_data));
## empty = res://resources/map/bonfire_run.tres.
var seal_steps: Dictionary = {}


## The sandbox table: `count` plain Bone dice, the tuning's Table 1.
static func sandbox(t: BonfireTuning, count: int = 5) -> TableSetup:
	var s := TableSetup.new()
	for i in count:
		s.dice.append(TableDie.new())
	s.goal = t.table_goal
	s.tuning = t
	s.starting_soul = t.starting_soul
	s.max_soul = t.starting_soul
	s.run_mode = false
	return s
