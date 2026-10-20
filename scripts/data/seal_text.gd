## Seal descriptions (strings_v1.md, Seal and Rare Seal rows). Text only:
## the run screens (Systems Dev, run_screen.gd) show it next to a Seal
## option; the levels themselves live in the run data.
##   SealText.describe(&"trips") -> "Levels up Trips: +15 base and +1 mult."
class_name SealText
extends RefCounted

## Combo Seal id (= combo id) -> description.
const SEALS: Dictionary[StringName, String] = {
	&"pair": "Levels up Pair: +5 base and +1 mult.",
	&"run3": "Levels up Run of 3: +10 base and +1 mult.",
	&"two_pair": "Levels up Two Pair: +10 base and +1 mult.",
	&"trips": "Levels up Trips: +15 base and +1 mult.",
	&"run4": "Levels up Run of 4: +15 base and +2 mult.",
	&"full_house": "Levels up Full House: +20 base and +2 mult.",
	&"run5": "Levels up Run of 5: +25 base and +2 mult.",
	&"quads": "Levels up Quads: +30 base and +3 mult.",
	&"five_kind": "Levels up Five of a Kind: +40 base and +4 mult.",
}
## Rare Seal id -> description.
const RARE: Dictionary[StringName, String] = {
	&"transference": "Move up to 2 mult, plus matching base, between two combos.",
	&"black": "+1 level to the combo you have banked most this run.",
	&"ashen": "Reset one combo; move its levels to an equal or rarer combo.",
}


## The description for a combo Seal or a rare Seal id ("" if unknown).
static func describe(id: StringName) -> String:
	return SEALS.get(id, RARE.get(id, ""))


## A Seal's name from the combo's display name (not the id: "Run of 3
## Seal", not "Run3 Seal"; strings_v1.md flag 3).
static func seal_name(id: StringName, tuning: BonfireTuning) -> String:
	if tuning != null:
		for c in tuning.combos:
			if c.id == id:
				return "%s Seal" % c.display_name
	return "%s Seal" % String(id).capitalize()
