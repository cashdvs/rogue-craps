## A disruptive table rule (design doc v0.2 section 6), e.g. Hot Seven.
##
## Rules are data: a name, a description for the felt plaque, and modifier
## numbers that the table logic (PocTable) reads. Every modifier defaults to
## "no change", so a new rule only sets the knobs it cares about. Rules that
## need brand-new behavior add a new knob here + one line in PocTable.
class_name TableRuleData
extends Resource

## Stable identifier, e.g. &"hot_seven".
@export var id: StringName = &""
## Plaque title, e.g. "Hot Seven".
@export var display_name: String = ""
## Plaque text, e.g. "Seven-outs deal double Soul damage."
@export_multiline var description: String = ""

@export_group("Soul damage multipliers (1 = normal)")
## Multiplies Soul damage from a Seven-out (Hot Seven = 2).
@export var seven_out_soul_multiplier: int = 1
## Multiplies Soul damage from Craps on the come-out.
@export var craps_soul_multiplier: int = 1
## Multiplies Soul damage from any other losing roll.
@export var other_loss_soul_multiplier: int = 1

@export_group("Table shape")
## Added to the roll limit (Short Stack would be -4).
@export var roll_limit_delta: int = 0
