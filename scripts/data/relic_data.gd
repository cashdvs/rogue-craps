## Data for a relic: a passive item that modifies a run.
##
## Relics don't contain logic themselves. Instead they list "hook ids":
## named moments in the game (e.g. &"on_roll", &"on_seven_out") the relic
## wants to react to. A future RelicSystem will look up behavior per relic
## id + hook. Keeping data and behavior apart keeps .tres files simple.
class_name RelicData
extends Resource

## Stable identifier, e.g. &"rabbit_foot".
@export var id: StringName = &""

## Player-facing name.
@export var display_name: String = ""

## Player-facing explanation.
@export_multiline var description: String = ""

## Game events this relic listens to, e.g. [&"on_seven_out"].
@export var hook_ids: Array[StringName] = []


func listens_to(hook_id: StringName) -> bool:
	return hook_ids.has(hook_id)
