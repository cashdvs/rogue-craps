## A special die (build content v0.3, Game Designer prices): takes a slot
## in the handful and can still take face mods. Data only; the table's
## rules for each die arrive with the table setup (Godot Dev).
class_name SpecialDieData
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Shop price in Embers; it sells for RunData.die_sell_percent of this.
@export var price: int = 12
