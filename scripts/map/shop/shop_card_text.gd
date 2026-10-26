## The 22 shop_card_* strings (design/strings_v1.md). DEPENDENCY: a stopgap until
## Systems Dev's strings PR lands; then point say() there and delete TEXT.
class_name ShopCardText
extends RefCounted

## strings_v1 id -> final text. "%d" marks where {n} goes.
const TEXT := {
	&"shop_card_buy": "Buy",
	&"shop_card_price": "%d Embers",
	&"shop_card_cant_afford": "Need %d more Embers.",
	&"shop_card_bag_full": "Bag full: sell a die first.",
	&"shop_card_no_free_face": "No free face to carve.",
	&"shop_card_seal_unusable": "You can't use this Seal right now.",
	&"shop_card_shape": "%d faces: rolls 1 to %d.",
	&"shop_card_faces_range": "%d faces: 1 to %d",
	&"shop_card_shape_rule": "Runs can go past 6; faces above 6 light alone.",
	&"shop_card_mod_price_note": "Costs more on a die that already has mods.",
	&"shop_card_mod_pick": "After buying, pick the die and face to carve.",
	&"shop_card_seal": "Levels up this combo for the rest of the run.",
	&"shop_card_seal_rare": "Rare Seal: one per shop.",
	&"shop_card_soul_name": "Soul Draught",
	&"shop_card_soul": "+%d max Soul, and heals %d.",
	&"shop_card_reroll_name": "Reroll",
	&"shop_card_reroll": "Restock the shop; each reroll costs 1 more.",
	&"shop_card_reroll_free": "Free rerolls left: %d",
	&"shop_card_free": "Free",
	&"shop_card_sell": "Sell for %d Embers",
	&"shop_card_sell_value": "Sells for %d Embers, half its price.",
	&"shop_card_cant_sell": "You can't sell below %d dice.",
}


## The text for `id` with every {n} filled by `n` (e.g. "8 faces: rolls 1 to 8.").
static func say(id: StringName, n: int = 0) -> String:
	return String(TEXT.get(id, String(id))).replace("%d", str(n))
