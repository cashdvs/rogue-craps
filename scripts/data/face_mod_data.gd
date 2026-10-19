## A face mod carved onto one face of a die (build content v0.3, events §2,
## Game Designer prices). Data only; resources/mods/*.tres.
##
## BonfireScoring (Godot Dev) scores every effect except HEAVY, which is a
## roll weight the run puts on the TableDie (RunProgress.table_dice()).
class_name FaceModData
extends Resource

enum Effect { MULT_FACTOR, WILD, TWIN, BLANK, MULT_ADD, EMBER, HEAVY, STEP, STAIR, KINDLING }

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var effect: Effect = Effect.MULT_FACTOR
## MULT_FACTOR only: the pot's mult is multiplied by this when the face scores.
@export var mult_factor: float = 1.0
## MULT_ADD / EMBER / STAIR: the number the effect adds.
@export var amount: int = 0
## Soul paid when this face scores (Blood: 1).
@export var soul_cost: int = 0
## Shop price in Embers before the per-die escalation (0 = not sold).
@export var price: int = 0
## A curse (Blank): can't be picked for removal as a "carving".
@export var is_curse: bool = false
