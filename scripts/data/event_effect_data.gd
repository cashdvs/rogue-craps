## One effect of an event choice (events §2). Data only; EventApplier runs it.
class_name EventEffectData
extends Resource

enum Kind { SOUL, EMBERS, ADD_FACE_MOD, REMOVE_FACE_MOD, SEAL_LEVEL }
## Which face an ADD/REMOVE_FACE_MOD targets.
## PICKED: the player picks die and face (REMOVE: one of their mods).
## RANDOM_OTHER_SAME_DIE: a random other face of the die the previous
## effect touched. RANDOM: a random free face of a random die.
enum Target { PICKED, RANDOM_OTHER_SAME_DIE, RANDOM }

@export var kind: Kind = Kind.SOUL
## SOUL / EMBERS: the change (negative = a cost). SEAL_LEVEL: levels added.
@export var amount: int = 0
## ADD_FACE_MOD: the mod to carve.
@export var mod: FaceModData
## SEAL_LEVEL: the combo id, e.g. &"trips".
@export var seal: StringName = &""
@export var target: Target = Target.PICKED


func needs_pick() -> bool:
	return target == Target.PICKED and (kind == Kind.ADD_FACE_MOD or kind == Kind.REMOVE_FACE_MOD)
