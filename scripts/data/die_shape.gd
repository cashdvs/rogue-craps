## A die shape (design/nonstandard_dice.md): how many faces a plain die has
## and the value on each (`faces`, inherited). Coin = 1 / 5; d3 = 1, 2, 3
## (the table shows it on a d6 mesh as 1-1-2-2-3-3, and a mod on a value
## covers both sides); dN = 1..N. Shaped dice are plain-ability dice sold in
## the same offers as special dice; `enabled` decides which can be offered
## (Game Designer data; d4-d20 stay off until the table scores faces > 6).
class_name DieShape
extends SpecialDieData

## Offered in shops / Elite rewards when true.
@export var enabled: bool = false


func face_count() -> int:
	return faces.size()
