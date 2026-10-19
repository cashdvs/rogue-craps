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


## strings_v1 shop_soul_button (P3): "Soul Draught: +4 max Soul, heals 4. 12 Embers".
static func shop_soul_button(amount: int, price: int) -> String:
	return "Soul Draught: +%d max Soul, heals %d. %d Embers" % [amount, amount, price]
