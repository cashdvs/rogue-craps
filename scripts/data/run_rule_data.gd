## An Elite twist or a boss cheat (map/events spec §1, Game Designer pools).
## Data only. MapRun picks them (seeded) and passes them to the table in
## RunTableSetup.rules; the table enforces them (Godot Dev). Only the two
## setup-value rules change numbers on the run's side: hands_delta (Short
## Table) and bust_soul_loss (Heavy Burn).
class_name RunRuleData
extends Resource

enum Kind { TWIST, CHEAT }

@export var id: StringName = &""
## Twists: the rule's name. Cheats: the boss's name (e.g. "Madame Shuffle").
@export var display_name: String = ""
## "{hands}" is replaced by the table's real hands (text()).
@export_multiline var description: String = ""
@export var kind: Kind = Kind.TWIST
## Added to the table's hands (Short Table: 5 -> 4 is -1).
@export var hands_delta: int = 0
## Soul a bust costs at this table; -1 = the normal value (Heavy Burn: 3).
@export var bust_soul_loss: int = -1
## Extra numbers the table reads, e.g. {"face": 6} for Cold Sixes.
@export var params: Dictionary = {}
## Rules with the same non-empty group do the same thing (e.g. Ashmouth and
## Cold Hands: &"no_hot_hand"); a boss never rolls a twist that repeats its cheat.
@export var effect_group: StringName = &""


## The description with "{hands}" filled in from the table's hands.
func text(hands: int) -> String:
	return description.replace("{hands}", str(hands))


## Same rule or same effect as `other` (same id, or same effect_group).
func same_effect(other: RunRuleData) -> bool:
	return other != null and (other.id == id or (effect_group != &"" and other.effect_group == effect_group))
