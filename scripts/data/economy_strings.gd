## Player-facing economy lines (design/strings_v1.md, economy_balance_v1.md
## P1/P3-P5), keyed by their strings_v1 id. Numbers come from the data, so
## the shipped values read exactly as strings_v1 has them.
class_name EconomyStrings
extends RefCounted

## strings_v1 table_points_embers (P1).
const TABLE_POINTS_EMBERS := "Points: 1 Ember per %d, up to %d per table."


## "Points: 1 Ember per 100, up to 5 per table." from `t`; uncapped tuning
## drops the cap clause. Not shown run-side yet: points are explained on the
## table HUD (bonfire_hud.gd, Godot Dev's).
static func table_points_embers(t: BonfireTuning) -> String:
	if t.points_embers_cap <= 0:
		return "Points: 1 Ember per %d." % t.points_per_ember
	return TABLE_POINTS_EMBERS % [t.points_per_ember, t.points_embers_cap]


## strings_v1 shop_rare_tag (rare_dice_v1 §4): the shop card's tag on a rare die.
const SHOP_RARE_TAG := "Rare: its carved faces come with the die."
## strings_v1 rare_v2_risk_tag: the tag on a risky rare (DieShape.risky).
const RARE_V2_RISK_TAG := "Risk"
## strings_v1 rare_carved_locked (rare_dice_v1 §3): a rare's pre-carved face refuses a carve.
const RARE_CARVED_LOCKED := "Carved at the forge; this face cannot be recarved."


## strings_v1 shop_soul_button (P3): "Soul Draught: +4 max Soul, heals 4. 12 Embers".
static func shop_soul_button(amount: int, price: int) -> String:
	return "Soul Draught: +%d max Soul, heals %d. %d Embers" % [amount, amount, price]


## strings_v1 shop_premium_seal_button (P4), "Rare Seal: 12 Embers", plus
## which rare Seal it is, e.g. "Rare Seal: 12 Embers (Transference)".
static func shop_premium_seal_button(price: int, seal_name: String) -> String:
	return "Rare Seal: %d Embers (%s)" % [price, seal_name]


## strings_v1 shop_floor_price_note (P5): "Prices on this floor: 25% above Floor 1."
static func shop_floor_price_note(pct: int) -> String:
	return "Prices on this floor: %d%% above Floor 1." % pct
