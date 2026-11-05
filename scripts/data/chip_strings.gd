## Player-facing Modifier Chip labels (strings_v1 chip_*). Cash lifted the
## "chips" ban Nov 5 2026 — shelf / owned / tiers say Chips, not Tokens.
class_name ChipStrings
extends RefCounted

const TEXT: Dictionary[String, String] = {
	"chip_shelf_label": "CHIPS",
	"chip_tier_common": "COMMON",
	"chip_tier_special": "SPECIAL",
	"chip_tier_rare": "RARE",
	"chip_risky_tag": "RISKY",
	"chip_owned_label": "CHIPS · {n}/3",
	"chip_card_hint": "A chip changes how your dice play.",
}


## Raw text for strings_v1 id `id` ("" if unknown).
static func get_text(id: String) -> String:
	return TEXT.get(id, "")


## `chip_owned_label` with `{n}` filled (owned count, capped display at 3).
static func owned(n: int) -> String:
	return get_text("chip_owned_label").replace("{n}", str(clampi(n, 0, 3)))


## COMMON / SPECIAL / RARE for a ChipLooks tier key.
static func tier_tag(tier: StringName) -> String:
	return get_text({"C": "chip_tier_common", "S": "chip_tier_special", "R": "chip_tier_rare"}.get(tier, ""))
