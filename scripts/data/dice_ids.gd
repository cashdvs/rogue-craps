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
## - Die-specific audio cue ids start with the die id (ferryman_heads_copy, caltrop_run,
##   powder_keg_3). Generic or flavour cues use "trigger_flavor_<die_id>" (trigger_flavor_lantern,
##   trigger_flavor_powder_keg); cue files carry the "trigger_" prefix.
## - A few art asset keys have no die id at all (ASSET_ONLY_KEYS): retired or showcase models.
class_name DiceIds
extends RefCounted

# --- Shape ids: the physical body (TableDie.shape, DiceSim, meshes) -----------
## Shape: two-sided coin (heads/tails). Ferryman's Coin. Old art alias "d2".
const SHAPE_COIN: StringName = &"coin"
## Shape: 3 faces. Valid shape (#61); no die uses it today. Powder Keg is SHAPE_D6.
const SHAPE_D3: StringName = &"d3"
## Shape: tetrahedron d4. Caltrop.
const SHAPE_D4: StringName = &"d4"
## Shape: cube d6. Bone, the d6 specials and Powder Keg (printed 1-1-2-2-3-3).
const SHAPE_D6: StringName = &"d6"
## Shape: d8. Lantern.
const SHAPE_D8: StringName = &"d8"
## Shape: d10. Tithe.
const SHAPE_D10: StringName = &"d10"
## Shape: d12. Midnight.
const SHAPE_D12: StringName = &"d12"
## Shape: d20. Verdict.
const SHAPE_D20: StringName = &"d20"
## Shape: 4-sided astragalus (values 1, 3, 4, 6). Knucklebone. Not SHAPE_D4 (Caltrop's body).
const SHAPE_TALUS: StringName = &"talus"

## shape id -> number of physical faces.
const SHAPES: Dictionary = {
	SHAPE_COIN: 2, SHAPE_D3: 3, SHAPE_D4: 4, SHAPE_D6: 6, SHAPE_D8: 8,
	SHAPE_D10: 10, SHAPE_D12: 12, SHAPE_D20: 20, SHAPE_TALUS: 4,
}

# --- Die ids: standard + d6 specials (on main, resources/dice/) -------------
## Die: the standard die (resources/dice/standard_d6.tres). Old ids "standard", and "d6" in #50.
const DIE_BONE: StringName = &"bone"
## Die: Bellows Die (resources/dice/special/bellows.tres).
const DIE_BELLOWS: StringName = &"bellows"
## Die: Blood Pact Die (resources/dice/special/blood_pact.tres).
const DIE_BLOOD_PACT: StringName = &"blood_pact"
## Die: Coven Die (resources/dice/special/coven.tres).
const DIE_COVEN: StringName = &"coven"
## Die: Cracked Die (resources/dice/special/cracked.tres).
const DIE_CRACKED: StringName = &"cracked"
## Die: Extra Die (resources/dice/special/extra.tres).
const DIE_EXTRA: StringName = &"extra"
## Die: Last Breath Die (resources/dice/special/last_breath.tres).
const DIE_LAST_BREATH: StringName = &"last_breath"
## Die: Mirror Die (resources/dice/special/mirror.tres).
const DIE_MIRROR: StringName = &"mirror"
## Die: Twin Flame Die (resources/dice/special/twin_flame.tres). Not the face mod "twin".
const DIE_TWIN_FLAME: StringName = &"twin_flame"
## Die: Wanderer Die (resources/dice/special/wanderer.tres).
const DIE_WANDERER: StringName = &"wanderer"

# --- Die ids: batch-3 shaped dice (#50 data, #102 art; design doc, not in repo) ---
## Die: Caltrop, d4.
const DIE_CALTROP: StringName = &"caltrop"
## Die: Lantern, d8.
const DIE_LANTERN: StringName = &"lantern"
## Die: Tithe, d10.
const DIE_TITHE: StringName = &"tithe"
## Die: Midnight, d12. Face keys midnight_1..midnight_12 (not "midnight_xii").
const DIE_MIDNIGHT: StringName = &"midnight"
## Die: Verdict, d20.
const DIE_VERDICT: StringName = &"verdict"
## Die: Ferryman's Coin, shape coin. Old ids "coin" (#50), "ferrymans_coin", "ferryman_d2".
const DIE_FERRYMAN: StringName = &"ferryman"
## Die: Powder Keg, a d6 body printed 1-1-2-2-3-3 ("d3" is display text only).
const DIE_POWDER_KEG: StringName = &"powder_keg"
## Die: Knucklebone, shape talus (#102 model knucklebone_talus).
const DIE_KNUCKLEBONE: StringName = &"knucklebone"

# --- Die ids: rare dice (design/rare_dice_v1.md; plain d6 + preset_mods, rarity rare) ---
## Die: Pyre Die, d6; 6 Hellfire, 5 Ember Pip (resources/dice/shapes/pyre.tres).
const DIE_PYRE: StringName = &"pyre"
## Die: Gilt Die, d6; 1 and 5 Gilded (resources/dice/shapes/gilt.tres).
const DIE_GILT: StringName = &"gilt"
## Die: Lodestone Die, d6; 6 Wild (resources/dice/shapes/lodestone.tres).
const DIE_LODESTONE: StringName = &"lodestone"
## Die: Ossuary Die, d6; 3 and 6 Twin (resources/dice/shapes/ossuary.tres).
const DIE_OSSUARY: StringName = &"ossuary"

# --- Die ids: rare dice v2, PR 1 (design/rare_dice_v2.md; built shapes + preset_mods) ---
## Die: Gallows Die, d4 1-4; 4 Twin (resources/dice/shapes/gallows.tres). Caltrop body, no run rule.
const DIE_GALLOWS: StringName = &"gallows"
## Die: Beacon Die, d8 1-8; 8 Wild, 7 Step (resources/dice/shapes/beacon.tres). Lantern body.
const DIE_BEACON: StringName = &"beacon"

## Rare dice v2, PR 2 (d6 + preset_mods + RareDiceRules): Powder Barrel (6 Fuse;
## not the Powder Keg), Fortune (6 Jackpot, 1 Hex), Usurer's (all Ember Pip).
const DIE_BARREL: StringName = &"barrel"
const DIE_FORTUNE: StringName = &"fortune"
const DIE_USURER: StringName = &"usurer"

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
	DIE_PYRE: {"shape": SHAPE_D6, "name": "Pyre Die"},
	DIE_GILT: {"shape": SHAPE_D6, "name": "Gilt Die"},
	DIE_LODESTONE: {"shape": SHAPE_D6, "name": "Lodestone Die"},
	DIE_OSSUARY: {"shape": SHAPE_D6, "name": "Ossuary Die"},
	DIE_GALLOWS: {"shape": SHAPE_D4, "name": "Gallows Die"},
	DIE_BEACON: {"shape": SHAPE_D8, "name": "Beacon Die"},
	DIE_BARREL: {"shape": SHAPE_D6, "name": "Powder Barrel"},
	DIE_FORTUNE: {"shape": SHAPE_D6, "name": "Fortune Die"},
	DIE_USURER: {"shape": SHAPE_D6, "name": "Usurer's Die"},
}

## Old spelling -> canonical die id. Lookups accept these during the rename window only.
const ALIASES: Dictionary = {
	&"standard": DIE_BONE, &"standard_d6": DIE_BONE,
	&"ferrymans_coin": DIE_FERRYMAN, &"ferryman_d2": DIE_FERRYMAN,
	&"keg": DIE_POWDER_KEG, &"powder_keg_d3": DIE_POWDER_KEG,
	&"knucklebone_talus": DIE_KNUCKLEBONE,
	&"caltrop_d4": DIE_CALTROP, &"lantern_d8": DIE_LANTERN, &"tithe_d10": DIE_TITHE,
	&"midnight_d12": DIE_MIDNIGHT, &"verdict_d20": DIE_VERDICT,
}

## Art asset keys with NO die id: models in art/ that no gameplay die uses. canonical() and the
## other helpers return empty for them, and they must never be reused as die ids or aliases.
const ASSET_ONLY_KEYS: Dictionary = {
	# Legacy, retired: parked Burn Line d6 spec (art/models/dice/src/build_dice.py), never exported.
	# Not the Knucklebone die, whose model is #102's knucklebone_talus.
	&"knucklebone_d6": "legacy (retired)",
	# DEPRECATED (Game Designer, Oct 19): retired as dice; kept only as material reference for the
	# Gilded / Hellfire face-mod looks. Art Director decides any reuse.
	&"gilded_d6": "deprecated: face-mod material reference only",
	&"hellfire_d6": "deprecated: face-mod material reference only",
}


## Rare dice art (rare_dice_v1 §8, PR 2): asset key -> the existing body model
## (res://art/models/dice/<body>.glb) it loads until 3D Artist ships its own
## variant. Pyre/Gilt reuse the asset-only hellfire_d6/gilded_d6 bodies;
## Lodestone (glass) and Ossuary (bone) take the nearest body. Drop an entry
## once <key>.glb exists; body_key() then returns the key itself.
const RARE_ART_BODIES: Dictionary = {
	&"pyre_d6": &"hellfire_d6", &"gilt_d6": &"gilded_d6",
	&"lodestone_d6": &"mirror_d6", &"ossuary_d6": &"bone_d6",
	# rare_dice_v2 PR 1: the built shaped bodies (Caltrop d4, Lantern d8).
	&"gallows_d4": &"caltrop_d4", &"beacon_d8": &"lantern_d8",
	# rare_dice_v2 PR 2: Bone d6 until the barrel / gilt / coin-stamp materials ship.
	&"barrel_d6": &"bone_d6", &"fortune_d6": &"bone_d6", &"usurer_d6": &"bone_d6",
}


## Model body key for [param die_id]: its asset key, or the stand-in from
## RARE_ART_BODIES when that key's own .glb isn't in art/models/dice yet.
## Used by the shop and bag icons and, since #197, poly_die.art_body_path,
## which spawns a rare's d6 art body from it; other shapes' meshes are
## still picked by shape.
static func body_key(die_id: StringName) -> StringName:
	var k := asset_key(die_id)
	if RARE_ART_BODIES.has(k) and not ResourceLoader.exists("res://art/models/dice/%s.glb" % k):
		return RARE_ART_BODIES[k]
	return k


## True if [param id] is a canonical die id.
static func is_die(id: StringName) -> bool:
	return ALL.has(id)


## True if [param id] is a canonical shape id.
static func is_shape(id: StringName) -> bool:
	return SHAPES.has(id)


## Canonical die id for [param id] (itself, an old alias, or a current asset key); &"" if unknown.
static func canonical(id: StringName) -> StringName:
	if ALL.has(id):
		return id
	if ALIASES.has(id):
		return ALIASES[id]
	for d in ALL:  # Current art asset keys ("<die>_<shape>") resolve too, e.g. ferryman_coin.
		if asset_key(d) == id:
			return d
	return &""


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


## Face key "<die_id>_<value>" for a pre-carved or special face, e.g. verdict_20; &"" if unknown.
static func face_key(die_id: StringName, value: int) -> StringName:
	var c := canonical(die_id)
	return StringName("%s_%d" % [c, value]) if c != &"" else &""


## True if [param s] is lowercase snake_case (a-z, 0-9, single underscores, starts with a letter).
static func is_snake_case(s: String) -> bool:
	var re := RegEx.create_from_string("^[a-z][a-z0-9]*(_[a-z0-9]+)*$")
	return re.search(s) != null
