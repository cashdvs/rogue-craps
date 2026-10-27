## Shop redesign PR C (HANDOFF_SPEC §2-3, shop_cards_v1 §4): the bag row, the
## sell card, Sell / Swap mode and the reroll card, driven by the real
## RunScreen shop. Clicks and taps go through each control's own input.
##   godot --headless --path . --script res://tests/test_shop_bag.gd
extends SceneTree

const PC := Vector2i.ZERO
const LANDSCAPE := Vector2i(844, 390)
const PORTRAIT := Vector2i(390, 844)

var _passed: int = 0
var _failed: int = 0
var scene: RunScreen
var run: MapRun
var ss: ShopScreen


func _initialize() -> void:
	scene = (load("res://scenes/run.tscn") as PackedScene).instantiate()
	scene.run_seed = 77
	root.add_child(scene)
	await process_frame
	run = scene.run
	ss = scene.shop_screen
	run.screen = MapRun.Screen.SHOP
	run.progress.embers = 100
	_test_bag_row()
	_test_sell_card()
	_test_sell_floor_and_bone()
	_test_sell_mode()
	_test_hover_and_pin()
	_test_reroll_pc()
	_test_reroll_uses_reroll_step()
	_test_sell_hint_from_strings()
	_test_reroll_phone()
	_test_portrait_buttons()
	_test_reroll_card_placement()
	_test_reroll_button_text()
	_test_floor_note()
	_test_icon_mouse_filter()
	print("=== test_shop_bag: %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", what)


func _show(win: Vector2i) -> void:
	ss.window_override = win
	ss.touch_override = 0 if win == PC else 1  # Phone sizes stand in for a touchscreen.
	scene.refresh()


## A left click / tap on `c` through its real input handler.
func _tap(c: Control) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	c._gui_input(e)


## Every Label text under `n`.
func _texts(n: Node, out: Array[String] = []) -> Array[String]:
	for c in n.get_children():
		if c is Label:
			out.append((c as Label).text)
		_texts(c, out)
	return out


## Bag of 5 Bones plus one Mirror (slot 5), as in the sell-view mock.
func _bag_with_mirror() -> void:
	while run.progress.dice.size() > run.data.starting_dice:
		run.progress.dice.remove_at(run.progress.dice.size() - 1)
	run.progress.add_die(&"mirror")


## Six slots per layout at the spec size, one per die, empties inert.
func _test_bag_row() -> void:
	run.progress.dice.resize(5)
	for win: Vector2i in [PC, LANDSCAPE, PORTRAIT]:
		_show(win)
		var want: float = {PC: 110.0, LANDSCAPE: 40.0, PORTRAIT: 50.0}[win]
		_check(ss.bag.size() == 6, "%s: six bag slots" % win)
		_check(absf(ss.bag[0].size.x / ss.k - want) < 0.5, "%s: slot is %.1f spec px (want %.0f)" % [win, ss.bag[0].size.x / ss.k, want])
		_check(ss.bag[4].die_i == 4 and ss.bag[4].icon != null, "%s: slot 5 shows die 5" % win)
		_check(ss.bag[5].die_i == -1 and ss.bag[5].mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s: slot 6 is empty" % win)
		_check(ss.bag[1].position.x > ss.bag[0].position.x + ss.bag[0].size.x, "%s: slots sit side by side" % win)
		_check(ss.bag_label.text == "YOUR DICE  5/6", "%s: bag label counts dice" % win)
	_show(PC)
	var last := ss.bag[5]
	_check(ss.sell_button.position.x > last.position.x + last.size.x, "PC: Sell / Swap sits right of the bag")


## The Mirror's card: name, strip, effect, value line, no price, Sell sells.
func _test_sell_card() -> void:
	_bag_with_mirror()
	_show(PC)
	var y := ss.bag[5].position.y
	_tap(ss.bag[5])
	var c := ss.card
	var t := _texts(c)
	_check(c.visible and c.slot == ss.bag[5] and c.pinned, "a click opens the pinned sell card")
	_check(ss.bag[5].lifted and ss.bag[5].position.y < y, "the sold die's slot lifts")
	_check(t.has("Mirror Die") and t.has(ShopCardStrings.fill("shop_card_sell_value", 9)), "lines: name and sell value")
	_check(t.has(run.progress.die_def(5).description), "line: the die's effect")
	_check(c.find_children("FaceStrip", "", true, false).size() == 1, "line 2: the face strip")
	_check(c.find_children("*", "PriceTag", true, false).is_empty(), "sell cards show no price on line 1")
	_check(c.action != null and c.action.text == "Sell for 9 Embers" and not c.action.disabled, "button: shop_card_sell")
	var e := run.progress.embers
	c.action.pressed.emit()
	_check(run.progress.dice.size() == 5 and run.progress.embers == e + 9, "Sell sells the die for 9")
	_check(not c.visible and ss.bag[5].die_i == -1, "after selling: card closed, bag redrawn")


## At 5 dice the button greys to the floor reason; Bone dice get none.
func _test_sell_floor_and_bone() -> void:
	run.progress.dice.resize(4)
	run.progress.add_die(&"mirror")
	_show(PC)
	_tap(ss.bag[4])
	var a := ss.card.action
	_check(a != null and a.disabled and a.text == ShopCardStrings.fill("shop_card_cant_sell", 5), "5 dice: greyed shop_card_cant_sell")
	var n := run.progress.dice.size()
	ss.card.sell()
	_check(run.progress.dice.size() == n, "the greyed sell does nothing")
	_bag_with_mirror()
	_show(PC)
	_tap(ss.bag[0])
	_check(ss.card.visible and ss.card.action == null, "Bone: no sell button")
	_check(_texts(ss.card).has("Bone Die"), "Bone card is named Bone Die")


## Sell / Swap lifts the bag and shows the hint, on the counter; it lasts
## across a sale's rebuild and ends on Leave.
func _test_sell_mode() -> void:
	_bag_with_mirror()
	_show(PC)
	var y := ss.bag[0].position.y
	_check(not ss.sell_hint.visible, "no hint before Sell / Swap")
	ss.sell_button.pressed.emit()
	_check(ss.visible and ss.selling and ss.sell_hint.visible, "Sell / Swap: hint shows on the counter")
	_check(absf(y - ss.bag[0].position.y - 10 * ss.k) < 0.5, "Sell / Swap: the bag lifts 10 spec px")
	_tap(ss.bag[5])
	ss.card.action.pressed.emit()
	_check(ss.selling and ss.sell_hint.visible, "sell mode survives the sale")
	ss.leave_button.pressed.emit()
	_check(not ss.selling and run.screen == MapRun.Screen.MAP, "Leave ends sell mode")
	run.screen = MapRun.Screen.SHOP


## PC hover opens an unpinned card that closes on leave; phone taps pin;
## an item card replaces the sell card.
func _test_hover_and_pin() -> void:
	_bag_with_mirror()
	_show(PC)
	ss.bag[5].mouse_entered.emit()
	_check(ss.card.visible and ss.card.slot == ss.bag[5] and not ss.card.pinned, "PC hover opens the sell card")
	ss.bag[5].mouse_exited.emit()
	_check(not ss.card.visible and not ss.bag[5].lifted, "leaving the slot closes it")
	_tap(ss.bag[5])
	ss.bag[5].mouse_exited.emit()
	_check(ss.card.visible, "a clicked card stays open when the mouse leaves")
	ss.card.show_for(ss.items[0])
	_check(ss.card.slot == null and not ss.bag[5].lifted and ss.card.item == ss.items[0], "an item card replaces the sell card")
	_show(PORTRAIT)
	ss.bag[5].opened.emit(ss.bag[5], false)
	_check(ss.card.visible and ss.card.pinned, "phone: the sell card opens pinned")


## PC: hover opens the reroll card (lines per spec); clicking Reroll rerolls.
func _test_reroll_pc() -> void:
	run.progress.free_rerolls = 0
	_show(PC)
	ss.reroll_button.mouse_entered.emit()
	var c := ss.card
	var t := _texts(c)
	_check(c.visible and c.reroll_open, "PC hover opens the reroll card")
	_check(t.has("Reroll") and t.has(str(run.reroll_price())) and t.has(ShopCardStrings.fill("shop_card_reroll", run.data.reroll_step)), "reroll lines: name, price, what it does")
	_check(not t.has(ShopCardStrings.fill("shop_card_reroll_free", 0)), "no free-reroll line when none are banked")
	var n := run.shop_rerolls
	ss.reroll_button.pressed.emit()
	_check(run.shop_rerolls == n + 1, "PC: the Reroll button rerolls")
	run.progress.free_rerolls = 2
	_show(PC)
	ss.reroll_button.mouse_entered.emit()
	t = _texts(ss.card)
	_check(t.has(ShopCardStrings.get_text("shop_card_free")) and t.has(ShopCardStrings.fill("shop_card_reroll_free", 2)), "banked: Free and Free rerolls left: 2")
	ss.reroll_button.mouse_exited.emit()
	_check(not ss.card.visible, "PC: leaving Reroll closes its card")
	run.progress.free_rerolls = 0


## Wrong-field guard: shop_seal_step != reroll_step, then the card body must
## still use fill(..., reroll_step). Catches wiring shop_seal_step by mistake
## (both default to 2 in bonfire_run.tres).
func _test_reroll_uses_reroll_step() -> void:
	run.data.shop_seal_step = 9
	_check(run.data.shop_seal_step != run.data.reroll_step, "shop_seal_step (9) != reroll_step")
	run.progress.free_rerolls = 0
	_show(PC)
	ss.reroll_button.mouse_entered.emit()
	var want := ShopCardStrings.fill("shop_card_reroll", run.data.reroll_step)
	var wrong := ShopCardStrings.fill("shop_card_reroll", run.data.shop_seal_step)
	var t := _texts(ss.card)
	_check(t.has(want), "reroll body == fill(..., reroll_step): " + want)
	_check(not t.has(wrong), "reroll body must not use shop_seal_step: " + wrong)
	run.data.shop_seal_step = 2


## Sell-mode hint text comes from ShopCardStrings, not a hardcoded literal.
func _test_sell_hint_from_strings() -> void:
	_show(PC)
	ss.sell_button.pressed.emit()
	_check(ss.sell_hint.visible, "sell hint visible in sell mode")
	_check(ss.sell_hint.text == ShopCardStrings.get_text("shop_hint_pick_sell"), "sell hint from ShopCardStrings")
	ss.sell_button.pressed.emit()


## Phone: the first tap opens the card; only the card's button rerolls.
func _test_reroll_phone() -> void:
	for win: Vector2i in [LANDSCAPE, PORTRAIT]:
		run.progress.embers = 100
		_show(win)
		var n := run.shop_rerolls
		ss.reroll_button.pressed.emit()
		_check(ss.card.visible and ss.card.reroll_open and run.shop_rerolls == n, "%s: first tap opens the reroll card, no reroll" % win)
		ss.reroll_button.pressed.emit()
		_check(run.shop_rerolls == n, "%s: a second tap still doesn't reroll" % win)
		ss.card.action.pressed.emit()
		_check(run.shop_rerolls == n + 1 and not ss.card.visible, "%s: the card's button rerolls" % win)
	run.progress.embers = 0
	_show(PORTRAIT)
	ss.reroll_button.pressed.emit()
	var a := ss.card.action
	_check(a.disabled and a.text == ShopCardStrings.fill("shop_card_cant_afford", run.reroll_price()), "phone: can't afford greys the card's button")
	run.progress.embers = 100


## Portrait: Sell / Swap, Reroll, Leave span the width as three equal buttons, 8 px apart.
func _test_portrait_buttons() -> void:
	_show(PORTRAIT)
	var row: Array[Button] = [ss.sell_button, ss.reroll_button, ss.leave_button]
	var w := row[0].size.x
	var same := absf(row[1].size.x - w) < 0.5 and absf(row[2].size.x - w) < 0.5
	_check(same, "portrait: three equal widths")
	var g1 := (row[1].position.x - row[0].position.x - w) / ss.k
	var g2 := (row[2].position.x - row[1].position.x - w) / ss.k
	_check(absf(g1 - 8) < 0.5 and absf(g2 - 8) < 0.5, "portrait: 8 px gaps")
	var vis := ss.get_viewport().get_visible_rect().size
	_check(absf(row[0].position.x / ss.k - 16) < 0.5 and absf((vis.x - row[2].position.x - w) / ss.k - 16) < 0.5, "portrait: row spans the width (16 px margins)")


## Portrait reroll card sits on the YOUR DICE label and never covers the bag row.
func _test_reroll_card_placement() -> void:
	for free: int in [0, 2]:
		run.progress.free_rerolls = free
		run.progress.embers = 100
		_show(PORTRAIT)
		ss.reroll_button.pressed.emit()
		var r := ss.card.get_global_rect()
		var hit := false
		for s in ss.bag:
			hit = hit or r.intersects(s.get_global_rect())
		_check(ss.card.visible and not hit, "portrait reroll card (free=%d) misses the bag row" % free)
		var label_top := ss.bag_label.get_global_rect().position.y
		_check(r.end.y <= label_top + 0.5 and r.end.y >= label_top - 12 * ss.k, "portrait reroll card bottom sits on the YOUR DICE label (free=%d)" % free)
	run.progress.free_rerolls = 0


## The reroll card's button says Reroll, or Reroll free when it costs nothing.
func _test_reroll_button_text() -> void:
	run.progress.embers = 100
	run.progress.free_rerolls = 0
	_show(PC)
	ss.reroll_button.mouse_entered.emit()
	_check(ss.card.action.text == "Reroll", "paid: the card's button says Reroll")
	run.progress.free_rerolls = 1
	_show(PORTRAIT)
	ss.reroll_button.pressed.emit()
	_check(ss.card.action.text == "Reroll free" and ss.reroll_button.text == "Reroll free", "free: the card's button and the bottom button say Reroll free")
	run.progress.free_rerolls = 0


## Floor 2 marks prices up, so the note under the title says by how much;
## Floor 1 has no markup and no note.
func _test_floor_note() -> void:
	var was := run.floor_index
	for win: Vector2i in [PC, PORTRAIT]:
		run.floor_index = 1
		_show(win)
		var pct := run.floor_price_percent()
		_check(pct > 0, "Floor 2 has a markup (%d%%)" % pct)
		_check(ss.floor_note != null and ss.floor_note.visible and ss.floor_note.text.replace("\n", " ") == EconomyStrings.shop_floor_price_note(pct), "Floor 2 shows the price note for %s" % win)
		run.floor_index = 0
		_show(win)
		_check(ss.floor_note == null, "Floor 1 has no price note for %s" % win)
	run.floor_index = was
	_show(PC)


## Icons never swallow clicks: the ShopItem underneath takes them.
func _test_icon_mouse_filter() -> void:
	_show(PC)
	var icons := ss.items.map(func(it: ShopItem) -> Control: return it.icon)
	_check(not icons.is_empty() and icons.all(func(c: Control) -> bool: return c.mouse_filter != Control.MOUSE_FILTER_STOP), "shop icons don't STOP the mouse")
