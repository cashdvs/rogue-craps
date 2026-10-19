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
@export_multiline var description: String = ""
@export var kind: Kind = Kind.TWIST
## Added to the table's hands (Short Table: 5 -> 4 is -1).
@export var hands_delta: int = 0
## Soul a bust costs at this table; -1 = the normal value (Heavy Burn: 3).
@export var bust_soul_loss: int = -1
## Extra numbers the table reads, e.g. {"face": 6} for Cold Sixes.
@export var params: Dictionary = {}
