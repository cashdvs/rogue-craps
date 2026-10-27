## Shop card text (design/shop_cards_v1.md), keyed by strings_v1 id with
## {n} placeholders. Example: ShopCardStrings.fill("shop_card_price", 12)
##   -> "12 Embers"
class_name ShopCardStrings
extends RefCounted

## Holds the strings_v1 "Shop card" block: shop_card_* ids plus the sell-mode
## hint shop_hint_pick_sell (shop_card_reroll's {n} is RunData.reroll_step).
## strings_v1 id -> text (copied verbatim; check_strings.py owns the source).
const TEXT: Dictionary[String, String] = {
	"shop_card_buy": "Buy",
	"shop_card_price": "{n} Embers",
	"shop_card_cant_afford": "Need {n} more Embers.",
	"shop_card_bag_full": "Bag full: sell a die first.",
	"shop_card_no_free_face": "No free face to carve.",
	"shop_card_seal_unusable": "You can't use this Seal right now.",
	"shop_card_shape": "{n} faces: rolls 1 to {n}.",
	"shop_card_faces_range": "{n} faces: 1 to {n}",
	"shop_card_shape_rule": "Runs can go past 6; faces above 6 light alone.",
	"shop_card_mod_price_note": "Costs more on a die that already has mods.",
	"shop_card_mod_pick": "After buying, pick the die and face to carve.",
	"shop_card_seal": "Levels up this combo for the rest of the run.",
	"shop_card_seal_rare": "Rare Seal: one per shop.",
	"shop_card_soul_name": "Soul Draught",
	"shop_card_soul": "+{n} max Soul, and heals {n}.",
	"shop_card_reroll_name": "Reroll",
	"shop_card_reroll": "Restock the shop; each reroll costs {n} more.",
	"shop_hint_pick_sell": "Pick a die to sell.",
	"shop_card_reroll_free": "Free rerolls left: {n}",
	"shop_card_free": "Free",
	"shop_card_sell": "Sell for {n} Embers",
	"shop_card_sell_value": "Sells for {n} Embers, half its price.",
	"shop_card_cant_sell": "You can't sell below {n} dice.",
}


## The raw text for strings_v1 id [param id] ("" if unknown).
static func get_text(id: String) -> String:
	return TEXT.get(id, "")


## The text for [param id] with every {n} replaced by [param n].
static func fill(id: String, n: int) -> String:
	return get_text(id).replace("{n}", str(n))
