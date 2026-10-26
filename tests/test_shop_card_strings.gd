## Shop card strings (design/shop_cards_v1.md) and the twin face text.
##   godot --headless --path . --script res://tests/test_shop_card_strings.gd
extends SceneTree

## Golden copy of strings_v1.md's "Shop card" block (22 rows). Several of
## these state economy rules, so any renamed key or changed text must fail.
const GOLDEN: Dictionary[String, String] = {
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
	"shop_card_reroll": "Restock the shop; each reroll costs 1 more.",
	"shop_card_reroll_free": "Free rerolls left: {n}",
	"shop_card_free": "Free",
	"shop_card_sell": "Sell for {n} Embers",
	"shop_card_sell_value": "Sells for {n} Embers, half its price.",
	"shop_card_cant_sell": "You can't sell below {n} dice.",
}
const TWIN_TEXT := "Two dice of its number; never in runs."

var _passed: int = 0
var _failed: int = 0


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: " + what)


func _initialize() -> void:
	_check(GOLDEN.size() == 22, "golden has 22 rows")
	_check(ShopCardStrings.TEXT.size() == 22, "22 shop_card rows")
	for id: String in GOLDEN:
		_check(ShopCardStrings.TEXT.has(id), "missing key " + id)
		_check(ShopCardStrings.get_text(id) == GOLDEN[id], "text drift " + id)
	for id: String in ShopCardStrings.TEXT:
		_check(GOLDEN.has(id), "unexpected key " + id)
	for id: String in ShopCardStrings.TEXT:
		_check(id.begins_with("shop_card_"), "id prefix " + id)
		_check(ShopCardStrings.TEXT[id] != "", "non-empty " + id)
	_check(ShopCardStrings.get_text("shop_card_soul_name") == "Soul Draught", "soul name")
	_check(ShopCardStrings.fill("shop_card_price", 12) == "12 Embers", "price fill")
	_check(ShopCardStrings.fill("shop_card_shape", 8) == "8 faces: rolls 1 to 8.", "shape fill")
	_check(ShopCardStrings.get_text("nope") == "", "unknown id")
	var twin: FaceModData = load("res://resources/mods/twin.tres")
	_check(twin.description == TWIN_TEXT, "twin text")
	_test_world_props_twin(twin.description)
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


## The twin row in docs/props/world_props_v1.md quotes twin.tres verbatim.
func _test_world_props_twin(desc: String) -> void:
	var f := FileAccess.open("res://docs/props/world_props_v1.md", FileAccess.READ)
	_check(f != null, "world_props_v1.md opens")
	if f == null:
		return
	var row := ""
	for line: String in f.get_as_text().split("\n"):
		if line.begins_with("| `twin` |"):
			row = line
	_check(row != "", "world_props twin row found")
	_check(row.ends_with("`twin` \"%s\" |" % desc), "world_props twin row matches twin.tres: " + row)
