## Shop redesign PR A (art/concept/shop_redesign/HANDOFF_SPEC.md): the
## counter, shelves, item icons and brass price tags, driven by the real
## RunScreen on the Shop screen; clicks go through ShopItem's input.
##   godot --headless --path . --script res://tests/test_shop_counter.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0
var scene: RunScreen
var run: MapRun


func _initialize() -> void:
	scene = (load("res://scenes/run.tscn") as PackedScene).instantiate()
	scene.run_seed = 1234
	root.add_child(scene)
	await process_frame
	run = scene.run
	_open_shop_with_rare()
	_test_counter_shows()
	_test_art_keys()
	_test_prices_and_red()
	_test_layouts()
	_test_felt()
	_test_rows()
	_test_click_buy_die()
	_test_click_unaffordable()
	_test_click_soul()
	_test_click_mod_opens_picker()
	_test_reroll_and_leave()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", what)


## Step the reroll seed until slot 2 holds a rare die, then show the shop.
func _open_shop_with_rare() -> void:
	run.screen = MapRun.Screen.SHOP
	for k in 300:
		run.shop_rerolls = k
		run._roll_shop()
		if run.shop_dice.size() > 1 and run.shop_dice[1] != null and run.shop_dice[1].is_rare():
			break
	run.shop_rerolls = 0
	run.progress.embers = 100
	scene.refresh()


func _item(kind: ShopOffer.Kind, index: int = 0) -> ShopItem:
	for it in scene.shop_screen.items:
		if it.offer.kind == kind and it.offer.index == index:
			return it
	return null


func _click(it: ShopItem) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	it._gui_input(e)


func _test_counter_shows() -> void:
	var ss := scene.shop_screen
	_check(ss.visible and not scene._panel_root.visible, "Shop screen shows the counter, not the text panel")
	var want := 0
	for d in run.shop_dice:
		want += 1 if d != null else 0
	for m in run.shop_mods:
		want += 1 if m != null else 0
	for s in run.shop_seals:
		want += 1 if s != &"" else 0
	want += (1 if run.shop_premium_seal != &"" else 0) + (1 if run.data.shop_soul_amount > 0 else 0)
	_check(ss.items.size() == want and want >= 7, "one ShopItem per offer (%d / %d)" % [ss.items.size(), want])
	_check(ss.embers_label.text == str(run.progress.embers), "Embers plate shows the bank")


## Art keys come from data: DiceIds.body_key for dice (rare stand-ins), and
## the token glyph table for the rest.
func _test_art_keys() -> void:
	var rare := _item(ShopOffer.Kind.DIE, 1)
	_check(rare != null and rare.offer.rare, "slot 2 die is rare (from SpecialDieData.rarity)")
	if rare != null:
		_check(rare.offer.art_key == DiceIds.body_key(rare.offer.id), "rare die art key = DiceIds.body_key")
		_check(DiceIds.RARE_ART_BODIES.values().has(rare.offer.art_key), "rare die uses its stand-in body until its .glb lands")
		_check(rare.icon.die_view != null and rare.icon.die_view.get_child_count() >= 2, "rare die icon is the 3D model in a SubViewport")
	var common := _item(ShopOffer.Kind.DIE, 0)
	_check(common != null and not common.offer.rare and common.offer.art_key == DiceIds.body_key(common.offer.id), "common die art key")
	for k in [&"pyre", &"gilt", &"lodestone", &"ossuary"]:
		_check(ShopIcon.model_path(DiceIds.body_key(k)) != "", "%s draws a model that exists" % k)
	_check(ShopIcon.GLYPHS[&"mod_wild"] == "spark" and _item(ShopOffer.Kind.SOUL).offer.art_key == &"soul", "token glyph keys")


func _test_prices_and_red() -> void:
	var die := _item(ShopOffer.Kind.DIE, 0)
	_check(die.tag.label.text == str(run.die_price(0)), "die tag = die_price")
	var mod := _item(ShopOffer.Kind.MOD, 0)
	var r := run.mod_price_range(0)
	_check(mod.tag.label.text == (str(r.x) if r.x == r.y else "%d-%d" % [r.x, r.y]), "mod tag = mod_price_range")
	_check(_item(ShopOffer.Kind.SOUL).tag.label.text == str(run.soul_price()), "Draught tag = soul_price")
	_check(not die.tag.is_red(), "affordable tag is cream")
	run.progress.embers = run.die_price(0) - 1
	scene.refresh()
	_check(_item(ShopOffer.Kind.DIE, 0).tag.is_red(), "tag turns red one Ember short")
	run.progress.embers = run.die_price(0)
	scene.refresh()
	_check(not _item(ShopOffer.Kind.DIE, 0).tag.is_red(), "tag is cream at exactly the price")
	run.progress.embers = 100
	scene.refresh()


## Layout by window shape; phone numerals >= 24 real px.
func _test_layouts() -> void:
	var ss := scene.shop_screen
	var cases := [[Vector2i(1920, 1080), ShopScreen.Layout.PC, 2], [Vector2i(844, 390), ShopScreen.Layout.LANDSCAPE, 1],
		[Vector2i(390, 844), ShopScreen.Layout.PORTRAIT, 3]]
	for c: Array in cases:
		ss.window_override = c[0]
		ss.build(scene)
		_check(ss.layout == c[1], "layout for %s" % c[0])
		_check(ss.shelves.size() == c[2], "%d shelves for %s (got %d)" % [c[2], c[0], ss.shelves.size()])
		var real_px := ss.items[0].tag.label.get_theme_font_size("font_size") / ss.k
		_check(real_px >= 24.0, "price numerals %.1f real px >= 24 at %s" % [real_px, c[0]])
	ss.window_override = Vector2i.ZERO
	scene.refresh()


## Felt runner lightness L* >= 30 (CIE L* from relative luminance).
func _test_felt() -> void:
	var c := ShopScreen.FELT
	var lin := func(v: float) -> float: return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
	var y: float = 0.2126 * lin.call(c.r) + 0.7152 * lin.call(c.g) + 0.0722 * lin.call(c.b)
	var l := 116.0 * pow(y, 1.0 / 3.0) - 16.0
	_check(l >= 30.0, "felt L* %.1f >= 30" % l)


func _test_rows() -> void:
	var offers: Array[ShopOffer] = []
	for i in 7:
		offers.append(ShopOffer.new())
	var rows := ShopScreen._rows(offers, [3, 3, 3])
	_check(rows.size() == 3 and rows[0].size() == 3 and rows[2].size() == 1, "rows split 3/3/1")
	_check(ShopScreen._rows(offers, [3, 5])[1].size() == 4, "last row takes the rest")


func _test_click_buy_die() -> void:
	var bag := run.progress.dice.size()
	var price := run.die_price(0)
	var before := run.progress.embers
	_click(_item(ShopOffer.Kind.DIE, 0))
	_check(run.progress.dice.size() == bag + 1, "clicking a die buys it into the bag")
	_check(run.progress.embers == before - price, "die click pays die_price")
	_check(_item(ShopOffer.Kind.DIE, 0) == null, "bought die leaves the counter")


func _test_click_unaffordable() -> void:
	var it := _item(ShopOffer.Kind.DIE, 1)
	run.progress.embers = run.die_price(1) - 1
	scene.refresh()
	it = _item(ShopOffer.Kind.DIE, 1)
	var bag := run.progress.dice.size()
	_click(it)
	_check(run.progress.dice.size() == bag and _item(ShopOffer.Kind.DIE, 1) != null, "unaffordable click buys nothing")
	run.progress.embers = 100
	scene.refresh()


func _test_click_soul() -> void:
	var max_soul := run.progress.max_soul
	_click(_item(ShopOffer.Kind.SOUL))
	_check(run.progress.max_soul == max_soul + run.data.shop_soul_amount, "Draught click raises max Soul")


func _test_click_mod_opens_picker() -> void:
	_click(_item(ShopOffer.Kind.MOD, 0))
	_check(scene._panel_root.visible and not scene.shop_screen.visible, "mod click opens the face picker")
	scene.refresh()
	_check(scene.shop_screen.visible, "Back / refresh returns to the counter")


func _test_reroll_and_leave() -> void:
	var n := run.shop_rerolls + run.shop_free_rerolls
	scene.shop_screen.reroll_button.pressed.emit()
	_check(run.shop_rerolls + run.shop_free_rerolls == n + 1, "Reroll restocks")
	scene.shop_screen.sell_button.pressed.emit()
	_check(scene._panel_root.visible and not scene.shop_screen.visible, "Sell / Swap opens the sell list")
	scene.refresh()
	scene.shop_screen.leave_button.pressed.emit()
	_check(run.screen == MapRun.Screen.MAP and not scene.shop_screen.visible, "Leave returns to the map")


