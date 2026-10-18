## Every Burn Line sandbox number (Game Designer, Oct 18 2026). The shipped
## values live in resources/tuning/burn_line_tuning.tres; edit that file to
## tune without code. Physics/feel numbers still come from TuningData.
class_name BurnLineTuning
extends Resource

@export_group("Run")
## Soul at the start of a run. Soul carries across tables; 0 = run over.
@export var starting_soul: int = 35
## The tables of a run, in order. Clearing the last one wins the run.
@export var tables: Array[BurnTableSpec] = []

@export_group("Betting")
## Bet steps (one chip) and the minimum bet. The cap is per table.
@export var bet_chip: int = 5
@export var min_bet: int = 5

@export_group("Returns on Stop (total paid back, bet included)")
## Return multiplier by distance UNDER the Line: index 0 = exact, 1 = one
## under, 2..3 = two or three under. Anything further under returns 0.
@export var return_by_distance: PackedFloat32Array = PackedFloat32Array([2.0, 1.5, 0.5, 0.5])

@export_group("Exact Hit side bet (optional, set before the first throw)")
## Cost of the side bet, taken when it is toggled on.
@export var exact_side_cost: int = 5
## Pays this many to 1 if the hand stops exactly on the Line (returns cost +
## cost * pay). Lost otherwise, burns included.
@export var exact_side_pay: int = 2

@export_group("Burn (over the Line)")
## Soul lost on a burn (plus the busting die's burn_soul_extra). Bet is lost.
@export var burn_soul_loss: int = 2

@export_group("Dice")
## The dice you can pick from before each table.
@export var dice: Array[BurnDie] = []
## How many dice you take into a table (the "Change dice" picker).
@export var loadout_size: int = 2
## Named loadouts; the table starts with default_loadout, no pick screen.
@export var loadouts: Array[BurnLoadout] = []
@export var default_loadout: StringName = &"standard"


func find_die(id: StringName) -> BurnDie:
	for d in dice:
		if d.id == id:
			return d
	return null


func find_loadout(id: StringName) -> BurnLoadout:
	for l in loadouts:
		if l.id == id:
			return l
	return null


## The dice of the default loadout (falls back to the first loadout_size dice).
func default_dice() -> Array[BurnDie]:
	var out: Array[BurnDie] = []
	var l := find_loadout(default_loadout)
	if l != null:
		for id in l.dice:
			var d := find_die(id)
			if d != null:
				out.append(d)
	if out.is_empty():
		for i in mini(loadout_size, dice.size()):
			out.append(dice[i])
	return out


## Return multiplier for stopping `distance` under the Line (0 = exact).
func return_for(distance: int) -> float:
	if distance < 0 or distance >= return_by_distance.size():
		return 0.0
	return return_by_distance[distance]
