## Data for a Chip: the game's relics (design doc section 8).
##
## Naming note: in this game "chips" are relics, NOT money. Money is Coin.
##
## Chips don't contain logic themselves. Instead they list "hook ids":
## named moments in the game (e.g. &"on_natural", &"on_seven_out") the chip
## wants to react to. A future ChipSystem will look up behavior per chip
## id + hook. Keeping data and behavior apart keeps .tres files simple.
class_name ChipData
extends Resource

## Stable identifier, e.g. &"devils_marker".
@export var id: StringName = &""

## Player-facing name, e.g. "Devil's Marker".
@export var display_name: String = ""

## Player-facing explanation.
@export_multiline var description: String = ""

## Game events this chip listens to, e.g. [&"on_natural"].
@export var hook_ids: Array[StringName] = []


func listens_to(hook_id: StringName) -> bool:
	return hook_ids.has(hook_id)
