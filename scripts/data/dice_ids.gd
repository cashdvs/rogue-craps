## Canonical dice ids: the one name each die and each die shape goes by in code, data,
## audio, VFX and art. See docs/DICE_IDS.md for the table, the old aliases and who renames what.
##
## Two separate concepts:
## - **Shape id** (SHAPE_*): the physical body and face count (d4, d6, coin, ...). Physics,
##   meshes and face layout key off it (TableDie.shape, DiceSim).
## - **Die id** (DIE_*): the named gameplay die the player buys (caltrop, ferryman, ...).
##   Run data, shop, scoring hooks and audio cues key off it (DieShape.id, RunDie, SfxManager).
##
## Derived keys follow fixed rules so nobody invents a new spelling:
## - Art asset key = "<die_id>_<shape_id>" (caltrop_d4, ferryman_coin, bone_d6, mirror_d6).
## - Pre-carved / special face key = "<die_id>_<face value>" in Arabic digits (verdict_20,
##   midnight_12, powder_keg_3). Coin faces use "ferryman_heads" / "ferryman_tails".
## - Audio cue ids start with the die id (ferryman_heads_copy, caltrop_run).
class_name DiceIds
extends RefCounted

# --- Shape ids -------------------------------------------------------------
const SHAPE_COIN: StringName = &"coin"
## Valid shape (#61); no die uses it today. Powder Keg is SHAPE_D6.
const SHAPE_D3: StringName = &"d3"
const SHAPE_D4: StringName = &"d4"
const SHAPE_D6: StringName = &"d6"
const SHAPE_D8: StringName = &"d8"
const SHAPE_D10: StringName = &"d10"
const SHAPE_D12: StringName = &"d12"
const SHAPE_D20: StringName = &"d20"
const SHAPE_TALUS: StringName = &"talus"

## shape id -> number of physical faces.
const SHAPES: Dictionary = {
	SHAPE_COIN: 2, SHAPE_D3: 3, SHAPE_D4: 4, SHAPE_D6: 6, SHAPE_D8: 8,
	SHAPE_D10: 10, SHAPE_D12: 12, SHAPE_D20: 20, SHAPE_TALUS: 4,
}

# --- Die ids: standard + d6 specials (on main) -----------------------------
const DIE_BONE: StringName = &"bone"
const DIE_BELLOWS: StringName = &"bellows"
const DIE_BLOOD_PACT: StringName = &"blood_pact"
const DIE_COVEN: StringName = &"coven"
const DIE_CRACKED: StringName = &"cracked"
const DIE_EXTRA: StringName = &"extra"
const DIE_LAST_BREATH: StringName = &"last_breath"
const DIE_MIRROR: StringName = &"mirror"
const DIE_TWIN_FLAME: StringName = &"twin_flame"
const DIE_WANDERER: StringName = &"wanderer"

# --- Die ids: batch-3 shaped dice (nonstandard_dice.md §10) ----------------
const DIE_CALTROP: StringName = &"caltrop"
const DIE_LANTERN: StringName = &"lantern"
const DIE_TITHE: StringName = &"tithe"
const DIE_MIDNIGHT: StringName = &"midnight"
const DIE_VERDICT: StringName = &"verdict"
const DIE_FERRYMAN: StringName = &"ferryman"
const DIE_POWDER_KEG: StringName = &"powder_keg"
const DIE_KNUCKLEBONE: StringName = &"knucklebone"

## die id -> {"shape": shape id, "name": display name}.
const ALL: Dictionary = {
	DIE_BONE: {"shape": SHAPE_D6, "name": "Bone Die"},
	DIE_BELLOWS: {"shape": SHAPE_D6, "name": "Bellows Die"},
	DIE_BLOOD_PACT: {"shape": SHAPE_D6, "name": "Blood Pact Die"},
	DIE_COVEN: {"shape": SHAPE_D6, "name": "Coven Die"},
	DIE_CRACKED: {"shape": SHAPE_D6, "name": "Cracked Die"},
	DIE_EXTRA: {"shape": SHAPE_D6, "name": "Extra Die"},
	DIE_LAST_BREATH: {"shape": SHAPE_D6, "name": "Last Breath Die"},
	DIE_MIRROR: {"shape": SHAPE_D6, "name": "Mirror Die"},
	DIE_TWIN_FLAME: {"shape": SHAPE_D6, "name": "Twin Flame Die"},
	DIE_WANDERER: {"shape": SHAPE_D6, "name": "Wanderer Die"},
	DIE_CALTROP: {"shape": SHAPE_D4, "name": "Caltrop"},
	DIE_LANTERN: {"shape": SHAPE_D8, "name": "Lantern"},
	DIE_TITHE: {"shape": SHAPE_D10, "name": "Tithe"},
	DIE_MIDNIGHT: {"shape": SHAPE_D12, "name": "Midnight"},
	DIE_VERDICT: {"shape": SHAPE_D20, "name": "Verdict"},
	DIE_FERRYMAN: {"shape": SHAPE_COIN, "name": "Ferryman's Coin"},
	# Body is a d6 printed 1-1-2-2-3-3; "d3" is display-only. Art key powder_keg_d6.
	DIE_POWDER_KEG: {"shape": SHAPE_D6, "name": "Powder Keg"},
	DIE_KNUCKLEBONE: {"shape": SHAPE_TALUS, "name": "Knucklebone"},
}

## Old spelling -> canonical die id. Lookups accept these during the rename window only.
const ALIASES: Dictionary = {
	&"standard": DIE_BONE, &"standard_d6": DIE_BONE,
	&"ferrymans_coin": DIE_FERRYMAN, &"ferryman_d2": DIE_FERRYMAN,
	&"keg": DIE_POWDER_KEG, &"powder_keg_d3": DIE_POWDER_KEG,
	&"knucklebone_talus": DIE_KNUCKLEBONE, &"knucklebone_d6": DIE_KNUCKLEBONE,
	&"caltrop_d4": DIE_CALTROP, &"lantern_d8": DIE_LANTERN, &"tithe_d10": DIE_TITHE,
	&"midnight_d12": DIE_MIDNIGHT, &"verdict_d20": DIE_VERDICT,
}


## True if [param id] is a canonical die id.
static func is_die(id: StringName) -> bool:
	return ALL.has(id)


## True if [param id] is a canonical shape id.
static func is_shape(id: StringName) -> bool:
	return SHAPES.has(id)


## Canonical die id for [param id] (itself, or the target of an old alias); &"" if unknown.
static func canonical(id: StringName) -> StringName:
	if ALL.has(id):
		return id
	return ALIASES.get(id, &"")


## Shape id of die [param die_id] (aliases accepted); &"" if unknown.
static func shape_of(die_id: StringName) -> StringName:
	var c := canonical(die_id)
	return ALL[c]["shape"] if c != &"" else &""


## Display name of die [param die_id] (aliases accepted); "" if unknown.
static func display_name(die_id: StringName) -> String:
	var c := canonical(die_id)
	return ALL[c]["name"] if c != &"" else ""


## Art asset key "<die_id>_<shape_id>" for [param die_id], e.g. ferryman_coin; &"" if unknown.
static func asset_key(die_id: StringName) -> StringName:
	var c := canonical(die_id)
	return StringName("%s_%s" % [c, ALL[c]["shape"]]) if c != &"" else &""


## Face key "<die_id>_<value>" for a pre-carved or special face, e.g. verdict_20.
static func face_key(die_id: StringName, value: int) -> StringName:
	return StringName("%s_%d" % [canonical(die_id), value])


## True if [param s] is lowercase snake_case (a-z, 0-9, single underscores, starts with a letter).
static func is_snake_case(s: String) -> bool:
	var re := RegEx.create_from_string("^[a-z][a-z0-9]*(_[a-z0-9]+)*$")
	return re.search(s) != null
