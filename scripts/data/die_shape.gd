## A die shape (design/nonstandard_dice.md): how many faces a die has and
## the value on each (`faces`, inherited). The shop sells the named batch-3
## dice of §10 (Ferryman's Coin, Powder Keg d3, Caltrop d4, Lantern d8, Tithe
## d10, Midnight d12, Verdict d20, Knucklebone); d6 is the plain Bone. The
## Powder Keg is stored as 1, 2, 3 (the table shows it on a d6 mesh as
## 1-1-2-2-3-3, and a mod on a value covers both sides). `enabled` decides
## which can be offered (Game Designer data; dice with faces above 6 or that
## need a new table hook stay off until the table supports them).
class_name DieShape
extends SpecialDieData

## Offered in shops / Elite rewards when true.
@export var enabled: bool = false
## Pre-carved faces (design/nonstandard_dice.md §10): face value -> face-mod
## id, e.g. {8: &"wild"}. RunProgress.add_die carves them on purchase; they
## are ordinary face mods (same rules and art), and the other faces stay free.
@export var preset_mods: Dictionary = {}


func face_count() -> int:
	return faces.size()
