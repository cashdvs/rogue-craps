## A face mod carved onto one face of a die (build content v0.3, events §2):
## Hellfire, Wild, Twin, Blank. Data only.
##
## TODO(scoring hook): BonfireScoring (scripts/core/bonfire_scoring.gd, PR #20)
## doesn't read face mods yet. The table needs, per potted die face:
##   WILD -> counts as any value; TWIN -> counts as two dice of its value;
##   BLANK -> never lights; MULT_FACTOR -> the pot's mult x mult_factor (Hellfire 1.5).
## Until that hook lands, mods are tracked on the run but don't change scores.
class_name FaceModData
extends Resource

enum Effect { MULT_FACTOR, WILD, TWIN, BLANK }

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var effect: Effect = Effect.MULT_FACTOR
## MULT_FACTOR only: the pot's mult is multiplied by this when the face scores.
@export var mult_factor: float = 1.0
## A curse (Blank): can't be picked for removal as a "carving".
@export var is_curse: bool = false
