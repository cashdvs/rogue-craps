## Data describing one die the player owns.
##
## The player picks 2 starting dice. Each die has a list of faces (any count,
## not just 6), a level, and an optional ability. Rolling a die just means
## picking one of its faces at random (see DiceRoller), so changing what a
## die can roll is as easy as editing its [member faces] array.
class_name DieData
extends Resource

## Name shown to the player, e.g. "Standard Die".
@export var display_name: String = "Die"

## Upgrade level. Not used by the rules yet; abilities can scale off it.
@export_range(1, 99) var level: int = 1

## The faces this die can land on. Each entry is equally likely.
@export var faces: Array[DieFace] = []

## Identifier for this die's special ability, e.g. "lucky_seven". Empty = none.
@export var ability_id: StringName = &""

## Player-facing explanation of the ability.
@export_multiline var ability_description: String = ""


## Builds a classic six-sided die with faces 1..6. Handy for tests and
## as a fallback if a resource file fails to load.
static func make_standard_d6(die_name: String = "Standard Die") -> DieData:
	var die := DieData.new()
	die.display_name = die_name
	for v in range(1, 7):
		die.faces.append(DieFace.make(v))
	return die


func face_count() -> int:
	return faces.size()


## Returns a duplicate of this die that is safe to modify during a run.
## Why: .tres files are shared/cached by Godot. If a face modification
## edited the loaded resource directly, it would leak into every other use
## of that file. Always mutate a run copy instead.
func make_run_copy() -> DieData:
	return duplicate(true) as DieData
