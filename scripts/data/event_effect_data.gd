## One effect of an event choice (events §2). Data only; EventApplier runs it.
class_name EventEffectData
extends Resource

enum Kind { SOUL, EMBERS, ADD_FACE_MOD, REMOVE_FACE_MOD, SEAL_LEVEL,
	MAX_SOUL, GIVE_DIE, SELL_DIE, FREE_SHOP_REROLL, NEXT_TABLE_TWIST }
## MAX_SOUL: max Soul +/- amount (never below 1; Soul is cut to the new max,
##   a raise doesn't heal).
## GIVE_DIE: add `die` (a special-die or shape id; &"" = a plain Bone) to
##   the bag. Greyed out when the bag is full.
## SELL_DIE: give up one die (PICKED: the player picks any face of it;
##   RANDOM: a random one) for its normal sell value + amount Embers.
##   Greyed out when the bag is at the starting size.
## FREE_SHOP_REROLL: amount free shop rerolls, kept until used (they stack
##   and don't raise the reroll price).
## NEXT_TABLE_TWIST: `rule` is added to the very next table (Table, Elite
##   or Boss), then cleared. A newer one replaces an unplayed one.
## Which face an ADD/REMOVE_FACE_MOD targets.
## PICKED: the player picks die and face (REMOVE: one of their mods).
## RANDOM_OTHER_SAME_DIE: a random other face of the die the previous
## effect touched. RANDOM: a random free face of a random die.
enum Target { PICKED, RANDOM_OTHER_SAME_DIE, RANDOM }

@export var kind: Kind = Kind.SOUL
## SOUL / EMBERS / MAX_SOUL: the change (negative = a cost). SEAL_LEVEL:
## levels added. FREE_SHOP_REROLL: rerolls granted. SELL_DIE: bonus Embers.
@export var amount: int = 0
## ADD_FACE_MOD: the mod to carve.
@export var mod: FaceModData
## SEAL_LEVEL: the combo id, e.g. &"trips".
@export var seal: StringName = &""
@export var target: Target = Target.PICKED
## GIVE_DIE: the die id.
@export var die: StringName = &""
## NEXT_TABLE_TWIST: the twist for the next table.
@export var rule: RunRuleData


func needs_pick() -> bool:
	return target == Target.PICKED and kind in [Kind.ADD_FACE_MOD, Kind.REMOVE_FACE_MOD, Kind.SELL_DIE]
