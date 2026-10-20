## A special die (build content v0.3, Game Designer prices): takes a slot
## in the handful and can still take face mods. Data only.
## Faces: all 9 are plain Bone 1-6, equal weights (design/
## bonfire_build_content.md, "Special die faces"); identity is the ability.
class_name SpecialDieData
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Second tooltip line (strings_v1.md "details" row): the rest of the
## rule that didn't fit the short line. Empty = none.
@export var details: String = ""


## The tooltip: the short line, then the details line if any.
func tooltip() -> String:
	return description if details == "" else "%s\n%s" % [description, details]

## Shop price in Embers; it sells for RunData.die_sell_percent of this.
@export var price: int = 12
## Value on each face slot (slot k = faces[k-1]), as TableDie.faces.
@export var faces: Array[int] = [1, 2, 3, 4, 5, 6]
## Roll weight per face slot; empty = even.
@export var weights: Array[float] = []
