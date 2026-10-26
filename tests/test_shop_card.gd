## Shop redesign PR B (HANDOFF_SPEC §3-§4): the floating ShopCard, driven by
## the real RunScreen shop. Taps and clicks go through ShopItem's input.
##   godot --headless --path . --script res://tests/test_shop_card.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0
var scene: RunScreen
var run: MapRun
var ss: ShopScreen


func _initialize() -> void:
	scene = (load("res://scenes/run.tscn") as PackedScene).instantiate()
	scene.run_seed = 1234
	root.add_child(scene)
	await process_frame
	run = scene.run
	ss = scene.shop_screen
	_open_shop_with_rare()
	_test_strings()
	for win in [Vector2i(844, 390), Vector2i(390, 844)]:
		_test_second_tap_does_not_buy(win)
	_test_tap_swaps_and_empty_closes()
	await _test_pc_hover()
	_test_lines_per_type()
	_test_mod_buy_opens_picker()
	_test_blocker_order()
	print("=== test_shop_card: %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", what)


## Step the reroll seed until slot 2 holds a rare die (as test_shop_counter).
func _open_shop_with_rare() -> void:
	run.screen = MapRun.Screen.SHOP
	for k in 300:
		run.shop_rerolls = k
		run._roll_shop()
		if run.shop_dice.size() > 1 and run.shop_dice[1] != null and run.shop_dice[1].is_rare():
			break
	run.shop_rerolls = 0
	run.progress.embers = 100
	_show(Vector2i.ZERO)


func _show(win: Vector2i) -> void:
	ss.window_override = win
	scene.refresh()


func _item(kind: ShopOffer.Kind, index: int = 0) -> ShopItem:
	for it in ss.items:
		if it.offer.kind == kind and it.offer.index == index:
			return it
	return null


## A left click / tap on `c` through its real input handler (phones send a
## mouse click per tap: emulate_mouse_from_touch).
func _tap(c: Control) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	c._gui_input(e)


func _texts(card: ShopCard) -> Array[String]:
	var out: Array[String] = []
	for n in card.find_children("*", "Label", true, false):
		out.append((n as Label).text)
	return out


func _test_strings() -> void:
	_check(ShopCardText.TEXT.size() == 22, "22 shop_card_* ids (incl. shop_card_soul_name)")
	_check(ShopCardText.say(&"shop_card_cant_afford", 4) == "Need 4 more Embers.", "cant_afford fills {n}")
	_check(ShopCardText.say(&"shop_card_shape", 8) == "8 faces: rolls 1 to 8.", "shape fills both {n}")
	_check(ShopCardText.say(&"shop_card_soul_name") == "Soul Draught", "soul name (strings_v1 line 466)")


## Phone: first tap lifts + opens the card, a second tap does nothing, and
## only the card's Buy buys.
func _test_second_tap_does_not_buy(win: Vector2i) -> void:
	_show(win)
	_check(ss.touch_mode, "%s is touch mode" % win)
	var it := _item(ShopOffer.Kind.DIE, 0)
	var stock := run.shop_dice[0]
	var price := run.die_price(0)
	var bag := run.progress.dice.size()
	var embers := run.progress.embers
	_tap(it)
	_check(ss.card.visible and ss.card.item == it and it.lifted, "%s: first tap opens the card and lifts the item" % win)
	_check(run.progress.dice.size() == bag and run.progress.embers == embers, "%s: first tap buys nothing" % win)
	_tap(it)
	_check(run.progress.dice.size() == bag and run.progress.embers == embers, "%s: second tap buys nothing" % win)
	_check(ss.card.visible and ss.card.item == it, "%s: second tap keeps the card open" % win)
	var r := ss.card.get_global_rect()
	var vis := ss.get_viewport().get_visible_rect()
	_check(vis.encloses(r), "%s: card clamped on screen (%s)" % [win, r])
	ss.card.action.pressed.emit()
	_check(run.progress.dice.size() == bag + 1 and run.progress.embers == embers - price, "%s: card Buy buys" % win)
	run.progress.dice.resize(bag)
	run.shop_dice[0] = stock
	run.progress.embers = 100


func _test_tap_swaps_and_empty_closes() -> void:
	_show(Vector2i(390, 844))
	var a := _item(ShopOffer.Kind.DIE, 0)
	var b := _item(ShopOffer.Kind.SOUL)
	_tap(a)
	_tap(b)
	_check(ss.card.item == b and b.lifted and not a.lifted, "tapping another item swaps the card")
	_tap(ss)
	_check(not ss.card.visible and not b.lifted, "tapping empty counter closes the card")


## PC: the card waits 150 ms of hover, then opens above the item; leaving closes it.
func _test_pc_hover() -> void:
	_show(Vector2i(1920, 1080))
	_check(not ss.touch_mode, "PC is not touch mode")
	var it := _item(ShopOffer.Kind.MOD, 0)
	it.mouse_entered.emit()
	await create_timer(0.05).timeout
	_check(not ss.card.visible, "no card before 150 ms")
	await create_timer(0.2).timeout
	_check(ss.card.visible and ss.card.item == it, "card opens after 150 ms hover")
	_check(ss.card.get_global_rect().end.y <= it.get_global_rect().position.y + 1.0, "PC card sits above the item")
	it.mouse_exited.emit()
	_check(not ss.card.visible and not it.lifted, "mouse-out closes the card")


func _test_lines_per_type() -> void:
	_show(Vector2i(1920, 1080))
	var rare := _item(ShopOffer.Kind.DIE, 1)
	ss.card.show_for(rare)
	var t := _texts(ss.card)
	_check(t.has("RARE") and t.has(EconomyStrings.SHOP_RARE_TAG) and t.has(run.shop_dice[1].description), "rare die: chip, effect, shop_rare_tag")
	_check(ss.card.find_children("Lock", "", true, false).size() > 0, "rare die strip marks its forge-carved faces")
	ss.card.show_for(_item(ShopOffer.Kind.SOUL))
	t = _texts(ss.card)
	_check(t.has("Soul Draught") and t.has(ShopCardText.say(&"shop_card_soul", run.data.shop_soul_amount)), "Draught: soul name + shop_card_soul")
	var mod := _item(ShopOffer.Kind.MOD, 0)
	ss.card.show_for(mod)
	t = _texts(ss.card)
	var r := run.mod_price_range(0)
	_check(t.has(ShopCardText.say(&"shop_card_mod_pick")) and t.has(mod.offer.price_text()), "mod: pick line and mod_price_range price")
	_check(mod.offer.price_lo == r.x and mod.offer.price_hi == r.y, "mod price is mod_price_range")
	ss.card.show_for(_item(ShopOffer.Kind.SEAL, 0))
	_check(_texts(ss.card).has(ShopCardText.say(&"shop_card_seal")), "Seal: shop_card_seal")
	ss.card.show_for(_item(ShopOffer.Kind.RARE_SEAL))
	t = _texts(ss.card)
	_check(t.has("RARE") and t.has(ShopCardText.say(&"shop_card_seal_rare")), "Rare Seal: chip + shop_card_seal_rare")
	ss.card.close()


func _test_mod_buy_opens_picker() -> void:
	_show(Vector2i(390, 844))
	_tap(_item(ShopOffer.Kind.MOD, 0))
	ss.card.action.pressed.emit()
	_check(scene._panel_root.visible and not ss.visible, "mod Buy opens the face picker")
	_show(Vector2i.ZERO)


## One reason, in order: bag full > no free face > can't afford > Seal not usable.
func _test_blocker_order() -> void:
	var saved := run.progress.dice.duplicate()
	run.shop_premium_seal = &"black"  # Nothing banked yet: Black can't be used.
	_check(not scene._seal_possible(&"black"), "precondition: Black Seal unusable")
	# Everything wrong at once: the bag is full, every face carved, 0 Embers.
	while run.progress.can_add_die():
		run.progress.add_die(DiceIds.DIE_BONE)
	for d in run.progress.dice:
		d.faces.fill(&"wild")
	run.progress.embers = 0
	_show(Vector2i(390, 844))
	_check(_blocker(_item(ShopOffer.Kind.DIE, 0)) == &"shop_card_bag_full", "die: bag full beats can't afford")
	_check(_blocker(_item(ShopOffer.Kind.MOD, 0)) == &"shop_card_no_free_face", "mod: no free face beats can't afford")
	_check(_blocker(_item(ShopOffer.Kind.RARE_SEAL)) == &"shop_card_cant_afford", "Seal: can't afford beats not usable")
	var red := ss.card.action
	_check(red.disabled and red.text == ShopCardText.say(&"shop_card_cant_afford", run.premium_seal_price()), "can't afford: greyed 'Need n more Embers.'")
	_check(red.get_theme_color("font_disabled_color") == ShopCard.RED, "can't afford is red")
	run.progress.embers = 100
	_show(Vector2i(390, 844))
	_check(_blocker(_item(ShopOffer.Kind.RARE_SEAL)) == &"shop_card_seal_unusable", "Seal: not usable when affordable")
	_check(ss.card.action.get_theme_color("font_disabled_color") == ShopCard.GREY, "other blockers are grey")
	var embers := run.progress.embers
	ss.card.action.pressed.emit()
	_check(run.progress.embers == embers and run.shop_premium_seal == &"black", "a blocked card buys nothing")
	run.progress.dice.assign(saved)
	for d in run.progress.dice:
		d.faces.fill(&"")
	_show(Vector2i(390, 844))
	_check(_blocker(_item(ShopOffer.Kind.DIE, 0)) == &"" and ss.card.action.text == "Buy", "no blocker: Buy")
	_show(Vector2i.ZERO)


func _blocker(it: ShopItem) -> StringName:
	_tap(it)
	return ss.card.blocker_id
