## A die shape (design/nonstandard_dice.md §10): the named batch-3 dice
## (Powder Keg d3, Ferryman's Coin, Caltrop d4, Lantern d8, Tithe d10,
## Midnight d12, Verdict d20, Knucklebone); d6 is the plain Bone. `faces`
## (inherited) are the printed values, one per physical face: the Powder
## Keg is 1-1-2-2-3-3 on a d6 mesh. `enabled` decides which can be offered
## (dice needing a table hook or faces above 6 stay off until it lands).
class_name DieShape
extends SpecialDieData

## Offered in shops / Elite rewards when true.
@export var enabled: bool = false
## Pre-carved faces (design/nonstandard_dice.md §10): face value -> face-mod
## id, e.g. {8: &"wild"}. RunProgress.add_die carves them on purchase; they
## are ordinary face mods (same rules and art), and the other faces stay free.
@export var preset_mods: Dictionary = {}
## TableDie.special for dice whose rule is table logic (&"ferryman",
## &"caltrop", &"knucklebone"); &"" = plain numbers + face mods.
@export var table_special: StringName = &""


## Face i is pre-carved and still carries its preset mod (not counted by
## the per-mod price step; nonstandard_dice.md §5/§10 don't say it should).
func is_preset(face_i: int, mod_id: StringName) -> bool:
	return face_i < faces.size() and mod_id != &"" and StringName(preset_mods.get(faces[face_i], &"")) == mod_id


## Number of physical faces (the size of `faces`): Ferryman's Coin 2, the
## Powder Keg 6 (1-1-2-2-3-3), Verdict 20.
func face_count() -> int:
	return faces.size()
