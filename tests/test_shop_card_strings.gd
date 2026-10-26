## Shop card strings (design/shop_cards_v1.md) and the twin face text.
##   godot --headless --path . --script res://tests/test_shop_card_strings.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: " + what)


func _initialize() -> void:
	_check(ShopCardStrings.TEXT.size() == 22, "22 shop_card rows")
	for id: String in ShopCardStrings.TEXT:
		_check(id.begins_with("shop_card_"), "id prefix " + id)
		_check(ShopCardStrings.TEXT[id] != "", "non-empty " + id)
	_check(ShopCardStrings.get_text("shop_card_soul_name") == "Soul Draught", "soul name")
	_check(ShopCardStrings.fill("shop_card_price", 12) == "12 Embers", "price fill")
	_check(ShopCardStrings.fill("shop_card_shape", 8) == "8 faces: rolls 1 to 8.", "shape fill")
	_check(ShopCardStrings.get_text("nope") == "", "unknown id")
	var twin: FaceModData = load("res://resources/mods/twin.tres")
	_check(twin.description == "Two dice of its number; never in runs.", "twin text")
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
