## Visual data for modifier chips (AD chips_3d_nov5 SPEC). Rules and prices
## live elsewhere; this only names tier, accent, risk and the face texture.
## Echo stays in the table but is ON HOLD (chips_v1) — do not offer it.
## Player-facing names say "Chip" where the SPEC does (Cash, Nov 5).
## Six ids are RISKY (cream face); this PR only Double Down ships the overlay.
class_name ChipLooks
extends RefCounted

## Tier rim: clay / brass / bone. Index matches LOOKS.tier ("C"/"S"/"R").
const TIER := {
	&"C": {"rim": Color("#7A624E"), "rough": 0.8, "metal": 0.0, "tex": "res://art/chips/rim_common.png"},
	&"S": {"rim": Color("#C9A24A"), "rough": 0.4, "metal": 0.3, "tex": "res://art/chips/rim_special.png"},
	&"R": {"rim": Color("#ECE2C8"), "rough": 0.6, "metal": 0.0, "tex": "res://art/chips/rim_rare.png"},
}

## id -> {name, tier, accent, risky}. Face PNG is art/chips/chip_face_<id>.png.
## Display names match art/concept/chips_3d_nov5 (Thumb Chip, Fuse Cord, …).
const LOOKS := {
	&"thumb": {"name": "Thumb Chip", "tier": &"C", "accent": "#D9C9A0", "risky": false},
	&"leaning": {"name": "Leaning Chip", "tier": &"C", "accent": "#3E8C74", "risky": false},
	&"pair_pin": {"name": "Pair Pin", "tier": &"C", "accent": "#C9A24A", "risky": false},
	&"spark": {"name": "Spark Chip", "tier": &"C", "accent": "#D67834", "risky": false},
	&"cold_comfort": {"name": "Cold Comfort", "tier": &"C", "accent": "#8FA6BC", "risky": false},
	&"second_wind": {"name": "Second Wind", "tier": &"C", "accent": "#8FA08A", "risky": false},
	&"nudge": {"name": "Nudge Chip", "tier": &"C", "accent": "#B89A6A", "risky": false},
	&"loose_change": {"name": "Loose Change", "tier": &"C", "accent": "#E0B84A", "risky": false},
	&"mirror": {"name": "Mirror Chip", "tier": &"S", "accent": "#B8C2CC", "risky": false},
	&"echo": {"name": "Echo Chip", "tier": &"S", "accent": "#7C8796", "risky": false},  # ON HOLD
	&"kiln": {"name": "Kiln Chip", "tier": &"S", "accent": "#A0503A", "risky": true},  # RISKY look; overlay later
	&"twin": {"name": "Twin Chip", "tier": &"S", "accent": "#C07A80", "risky": false},
	&"fuse_cord": {"name": "Fuse Cord", "tier": &"S", "accent": "#E08A3C", "risky": false},
	&"ladder": {"name": "Ladder", "tier": &"S", "accent": "#7A8A3A", "risky": false},
	&"ash_ward": {"name": "Ash Ward", "tier": &"S", "accent": "#8A8580", "risky": false},
	&"loaded": {"name": "Loaded Chip", "tier": &"R", "accent": "#8A2A22", "risky": true},
	&"snake_eyes": {"name": "Snake Eyes", "tier": &"R", "accent": "#3E9A5A", "risky": true},  # RISKY look; overlay later
	&"double_down": {"name": "Double Down", "tier": &"R", "accent": "#C9A24A", "risky": true},
	&"sixth_die": {"name": "Sixth Die", "tier": &"R", "accent": "#7A6A4A", "risky": true},
	&"devils": {"name": "Devil's Chip", "tier": &"R", "accent": "#6E2A2A", "risky": true},
}

## First Batch for the 1-floor build (chips_v1). Echo is never in this list.
const FIRST_BATCH: Array[StringName] = [&"thumb", &"leaning", &"second_wind", &"fuse_cord", &"double_down"]


## True when `id` has a look row (Echo counts; callers still skip offering it).
static func has(id: StringName) -> bool:
	return LOOKS.has(id)


static func look(id: StringName) -> Dictionary:
	return LOOKS[id]


static func face_path(id: StringName) -> String:
	return "res://art/chips/chip_face_%s.png" % id


static func tier_tag(tier: StringName) -> String:
	return ChipStrings.tier_tag(tier)
