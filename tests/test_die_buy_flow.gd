## die_buy_flow_v1: the 14 QA cases. Shop + event swap, confirm rules, markers.
##   godot --headless --path . --script res://tests/test_die_buy_flow.gd
extends SceneTree

const PC := Vector2i.ZERO
const LANDSCAPE := Vector2i(844, 390)
const PORTRAIT := Vector2i(390, 844)

var _passed: int = 0
var _failed: int = 0
var scene: RunScreen
var run: MapRun
var ss: ShopScreen
var _data: RunData


func _initialize() -> void:
	_data = load("res://resources/map/bonfire_run.tres") as RunData
	scene = (load("res://scenes/run.tscn") as PackedScene).instantiate()
	scene.run_seed = 11
	root.add_child(scene)
	await process_frame
	run = scene.run
	ss = scene.shop_screen
	_stock()
	_test_inspect()
	_test_enter_swap()
	_test_pc_plain_swap()
	_test_carved_confirm()
	_test_rare_confirm()
	_test_cancel_free()
	_test_retarget()
	_test_phone_confirms()
	_test_phone_card_fit()
	_test_cant_afford()
	_test_sell_hidden()
	_test_stale_state()
	_test_confirm_edges()
	await _test_event_give()
	_test_regression_cap()
	print("=== test_die_buy_flow: %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", what)


func _show(win: Vector2i, touch: bool = false) -> void:
	ss.window_override = win
	ss.touch_override = 1 if touch else 0
	scene.refresh()


func _tap(c: Control) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	c._gui_input(e)


func _click(c: Control) -> void:
	_tap(c)
	var u := InputEventMouseButton.new()
	u.button_index = MOUSE_BUTTON_LEFT
	u.pressed = false
	c._gui_input(u)


func _texts(n: Node, out: Array[String] = []) -> Array[String]:
	if n is Label:
		out.append((n as Label).text)
	elif n is Button:
		out.append((n as Button).text)
	for c in n.get_children():
		_texts(c, out)
	return out


func _item(kind: ShopOffer.Kind, index: int = 0) -> ShopItem:
	for it in ss.items:
		if it.offer.kind == kind and it.offer.index == index:
			return it
	return null


func _stock() -> void:
	ss.swap_offer = -1
	ss.done_line = ""
	run.screen = MapRun.Screen.SHOP
	while run.progress.dice.size() > 5:
		run.progress.dice.remove_at(run.progress.dice.size() - 1)
	while run.progress.dice.size() < 5:
		run.progress.add_die(DiceIds.DIE_BONE)
	for i in 5:
		if run.progress.dice[i].shape != DiceIds.DIE_BONE or run.progress.dice[i].special_id != &"":
			run.progress.swap_die(i, DiceIds.DIE_BONE)
		for f in run.progress.dice[i].faces.size():
			run.progress.set_face(i, f, &"")
	run.progress.set_face(1, 0, &"wild")  # Bone die 2
	run.progress.swap_die(4, &"gallows")
	run.progress.embers = 200
	var mirror := run.progress.special_die(&"mirror")
	var rare := run.progress.shape_data(&"fortune")
	if rare == null:
		rare = run.progress.shape_data(&"gallows")
	if run.shop_dice.is_empty():
		run._roll_shop()
	run.shop_dice[0] = mirror
	if run.shop_dice.size() < 2:
		run.shop_dice.append(rare)
	else:
		run.shop_dice[1] = rare


## 1. Inspect: RunDie faces, carved highlight, rare chip, no sell lines, carved pip.
func _test_inspect() -> void:
	_stock()
	_show(PC)
	_check(ss.bag[1]._carved and not ss.bag[0]._carved, "QA1: bag slot 2 shows the Carved pip (slot 1 does not)")
	_check(ss.bag[4]._rare, "QA1: the rare bag die has the rare marker")
	ss.bag[1].mouse_entered.emit()
	var t := _texts(ss.card)
	_check(t.has("Bone") or t.has("Bone Die"), "QA1: carved Bone is named")
	_check(t.has(ShopSideCard.SWAP_TEXT.shop_bag_carved_tag), "QA1: the card says Carved")
	_check(ss.card.find_children("FaceStrip", "", true, false).size() >= 1, "QA1: RunDie face strip is on the card")
	_check(ss.card.find_children("ModIcon", "", true, false).size() >= 1, "QA1: the carved face is highlighted with a mod disc")
	_check(not t.has(ShopCardStrings.get_text("shop_card_sell_value").replace("{n}", "9")) and not t.has(ShopCardStrings.fill("shop_card_cant_sell", 5)), "QA1: no sell lines at the floor")
	ss.card.close()
	ss.bag[4].mouse_entered.emit()
	t = _texts(ss.card)
	_check(t.has("RARE"), "QA1: the rare die's card shows a RARE chip")
	_check(ss.card.find_children("Lock", "", true, false).size() >= 1, "QA1: forge faces keep the lock")


## 2. Enter swap mode: offer stays lifted, button Swap, hints, no Embers spent.
func _test_enter_swap() -> void:
	_stock()
	_show(PC)
	var e := run.progress.embers
	var it := _item(ShopOffer.Kind.DIE, 0)
	_tap(it)
	it = _item(ShopOffer.Kind.DIE, 0)
	_check(ss.swap_offer == 0 and it != null and it.lifted and ss.card.visible and ss.card.item != null, "QA2: the offer stays lifted with its card open")
	_check(ss.card.action != null and ss.card.action.text == "Swap", "QA2: the offer button reads Swap")
	_check(ss.sell_hint.visible and ss.exit_hint.visible, "QA2: both bag hints show")
	_check(ss.sell_hint.text == "Click the die to give up." and ss.exit_hint.text == "Click the counter to keep your dice.", "QA2: PC hint verbs are Click")
	_check(run.progress.embers == e and run.progress.dice.size() == 5, "QA2: no Embers are spent")
	_show(PORTRAIT, true)
	e = run.progress.embers
	it = _item(ShopOffer.Kind.DIE, 0)
	_tap(it)
	_check(ss.swap_offer == 0 and ss.card.visible and run.progress.embers == e, "QA2 phone: first tap enters swap, no extra Buy tap, nothing spent")


## 3. PC plain swap: 2 clicks, no confirm, done line, same slot, price paid.
func _test_pc_plain_swap() -> void:
	_stock()
	_show(PC)
	var price := run.die_price(0)
	var e := run.progress.embers
	var want := run.shop_dice[0].id
	ss.enter_swap(0)
	ss.bag[0].mouse_entered.emit()
	var t := _texts(ss.card)
	_check(t.has("Click to swap it for Mirror Die."), "QA3: the hover card has the plain-die hint")
	_check(ss.card.find_children("*", "Button", true, false).is_empty() or (ss.card.action == null), "QA3: no confirm buttons on a plain hover")
	var old := run.progress.dice[0].id
	_click(ss.bag[0])
	_check(run.progress.dice.size() == 5 and run.progress.dice[0].special_id == want and run.progress.dice[0].id != old, "QA3: the new die sits in the same slot")
	_check(run.progress.embers == e - price, "QA3: Embers drop by exactly the price")
	_check(ss.done_line == "Bone out, Mirror Die in.", "QA3: the done line shows")
	_check(ss.swap_offer < 0, "QA3: swap mode ends")


## 4. Carved confirm (3 clicks): strips, warnings, SWAP pays and drops the mod.
func _test_carved_confirm() -> void:
	_stock()
	_show(PC)
	var price := run.die_price(0)
	var e := run.progress.embers
	var T := ShopSideCard.SWAP_TEXT
	ss.enter_swap(0)
	_tap(ss.bag[1])
	var t := _texts(ss.card)
	_check(ss.card.pinned and t.has("Swap Bone for Mirror Die?"), "QA4: clicking Bone 2 opens a pinned confirm")
	_check(ss.card.find_children("SwapPreview", "", true, false).size() == 1, "QA4: old -> new strips")
	_check(t.has(T.shop_swap_mods_warn) and t.has(T.shop_swap_no_refund), "QA4: carved and no-refund lines")
	_check(ss.card.action != null and ss.card.action.text == ShopSideCard.swap_btn(price) and t.has("KEEP IT"), "QA4: SWAP · n Embers and KEEP IT")
	ss.card.action.pressed.emit()
	_check(run.progress.dice[1].special_id == &"mirror" and not run.progress.die_has_mods(1), "QA4: the mod is gone from the run")
	_check(run.progress.embers == e - price, "QA4: Embers drop by the price")


## 5. Rare confirm: rare warning, not the carved line unless also player-carved.
func _test_rare_confirm() -> void:
	_stock()
	_show(PC)
	var T := ShopSideCard.SWAP_TEXT
	ss.enter_swap(0)
	_tap(ss.bag[4])
	var t := _texts(ss.card)
	_check(t.has(T.shop_swap_rare_warn) and not t.has(T.shop_swap_mods_warn), "QA5: a rare with no player carves shows only the rare warning")
	ss.exit_swap()
	run.progress.set_face(4, 0, &"wild")
	ss.enter_swap(0)
	_tap(ss.bag[4])
	t = _texts(ss.card)
	_check(t.has(T.shop_swap_rare_warn) and t.has(T.shop_swap_mods_warn), "QA5: a rare with a player carve shows both warnings")


## 6. KEEP IT, a click on the counter, and Esc each back out for free.
func _test_cancel_free() -> void:
	_stock()
	_show(PC)
	var T := ShopSideCard.SWAP_TEXT
	var before := run.progress.dice.map(func(d: RunDie) -> StringName: return d.id)
	var e := run.progress.embers
	var offer0 := run.shop_dice[0]
	# KEEP IT
	ss.enter_swap(0)
	_tap(ss.bag[1])
	var keep: Button
	for b in ss.card.find_children("*", "Button", true, false):
		if (b as Button).text == T.shop_swap_cancel:
			keep = b
	_check(keep != null, "QA6: KEEP IT is on the confirm")
	keep.pressed.emit()
	_check(ss.swap_offer < 0 and run.progress.embers == e and run.progress.dice.map(func(d: RunDie) -> StringName: return d.id) == before, "QA6: KEEP IT is free and leaves the bag")
	ss.enter_swap(0)
	_check(ss.swap_offer == 0, "QA6: re-clicking the offer re-enters after KEEP IT")
	# counter click
	ss._gui_input(_left(true))
	_check(ss.swap_offer < 0 and run.progress.embers == e and run.shop_dice[0] == offer0 and run.progress.dice.map(func(d: RunDie) -> StringName: return d.id) == before, "QA6: a click on the counter exits for free")
	ss.enter_swap(0)
	_check(ss.swap_offer == 0, "QA6: re-clicking the offer re-enters after a counter click")
	# Esc
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	ss._unhandled_input(esc)
	_check(ss.swap_offer < 0 and run.progress.embers == e and run.shop_dice[0] == offer0 and run.progress.dice.map(func(d: RunDie) -> StringName: return d.id) == before, "QA6: Esc exits for free")
	ss.enter_swap(0)
	_check(ss.swap_offer == 0, "QA6: re-clicking the offer re-enters after Esc")
	ss.exit_swap()


func _left(pressed: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	return e


## 7. Re-target: a different offer moves the pending offer; nothing is paid.
func _test_retarget() -> void:
	_stock()
	_show(PC)
	var e := run.progress.embers
	var before := run.progress.dice.map(func(d: RunDie) -> StringName: return d.id)
	ss.enter_swap(0)
	_tap(_item(ShopOffer.Kind.DIE, 1))
	_check(ss.swap_offer == 1 and run.progress.embers == e and run.progress.dice.map(func(d: RunDie) -> StringName: return d.id) == before, "QA7: re-target moves the pending offer and pays nothing")
	ss.exit_swap()


## 8. Phone always confirms: a tap on a plain die opens SWAP; nothing swaps yet.
func _test_phone_confirms() -> void:
	_stock()
	_show(PORTRAIT, true)
	var e := run.progress.embers
	var it := _item(ShopOffer.Kind.DIE, 0)
	_tap(it)
	var old := run.progress.dice[0].id
	_tap(ss.bag[0])
	var t := _texts(ss.card)
	_check(ss.card.pinned and ss.card.action != null and ss.card.action.text.begins_with("SWAP"), "QA8: tapping a plain die opens the card with SWAP")
	_check(run.progress.dice[0].id == old and run.progress.embers == e, "QA8: nothing swaps on the first bag tap")
	ss.card.action.pressed.emit()
	_check(run.progress.dice[0].id != old and run.progress.embers < e, "QA8: SWAP on the third tap commits")


## Phone confirm stays 8 px inside a 390-wide viewport; closing it shows the bag hint again.
func _test_phone_card_fit() -> void:
	_stock()
	# Use the real window size so vis.x is 390, matching the phone shot.
	DisplayServer.window_set_size(PORTRAIT)
	_show(PORTRAIT, true)
	ss.enter_swap(0)
	var vis := ss.get_viewport().get_visible_rect()
	var m := 8.0 * ss.k
	for h in [ss.sell_hint, ss.exit_hint]:
		var hr: Rect2 = h.get_global_rect()
		_check(h.visible and not h.clip_text, "phone: %s is visible and unclipped" % h.text)
		_check(hr.position.x >= m - 0.5 and hr.end.x <= vis.size.x - m + 0.5, "phone: hint x stays 8 px inside the viewport (%s %s vis %s)" % [h.text, hr, vis.size])
		_check(hr.position.y >= m - 0.5 and hr.end.y <= vis.size.y - m + 0.5, "phone: hint y stays 8 px inside the viewport (%s %s vis %s)" % [h.text, hr, vis.size])
	_check(ss.exit_hint.text == "Tap the counter to keep your dice.", "phone: the exit hint keeps its full wording")
	_tap(ss.bag[1])
	var r := ss.card.get_global_rect()
	_check(r.position.x >= m - 0.5 and r.end.x <= vis.size.x - m + 0.5, "phone confirm: card x stays 8 px inside the viewport (%s vis %s)" % [r, vis.size])
	_check(r.position.y >= m - 0.5 and r.end.y <= vis.size.y - m + 0.5, "phone confirm: card y stays 8 px inside the viewport (%s vis %s)" % [r, vis.size])
	_check(ss.card.size.x <= vis.size.x - 2.0 * m + 0.5, "phone confirm: card width fits with 8 px side margins")
	var title := ss.card.find_child("CardTitle", true, false) as Label
	_check(title != null and r.grow(0.5).encloses(title.get_global_rect()), "phone confirm: the title is fully inside the card (%s)" % (title.text if title else "missing"))
	_check(title != null and not title.clip_text and (title.text == "Swap Bone for Mirror Die?" or title.text == "Swap Bone for Mirror?"), "phone confirm: title is the full or short form, never clipped")
	for b in ss.card.find_children("*", "Button", true, false):
		_check(r.grow(0.5).encloses((b as Control).get_global_rect()) and vis.grow(-m + 0.5).encloses((b as Control).get_global_rect()) or vis.encloses((b as Control).get_global_rect()), "phone confirm: %s stays on screen" % (b as Button).text)
	_check(ss.card.find_children("SwapArrow", "", true, false).size() == 1, "phone confirm: one drawn cream arrow, not a '->' glyph")
	for l in ss.card.find_children("*", "Label", true, false):
		_check((l as Label).text != "->", "phone confirm: no wrapping '->' label")
	ss.card.close()
	_check(not ss.card.visible and ss.swap_offer == 0, "phone confirm: close leaves swap mode on")
	_check(ss.bag_label.visible and "YOUR DICE" in ss.bag_label.text, "phone confirm: YOUR DICE shows after the card closes")
	_check(ss.sell_hint.visible and ss.sell_hint.text.find("die to give up") >= 0, "phone confirm: the swap hint shows after the card closes")
	DisplayServer.window_set_size(Vector2i(1920, 1080))


## 9. Can't afford: greyed Need n, no swap mode, bag doesn't lift.
func _test_cant_afford() -> void:
	_stock()
	run.progress.embers = 0
	_show(PC)
	var y := ss.bag[0].position.y
	var it := _item(ShopOffer.Kind.DIE, 0)
	ss.card.show_for(it)
	var short := it.offer.price_lo
	_check(ss.card.action != null and ss.card.action.disabled and ss.card.action.text == ShopCardStrings.fill("shop_card_cant_afford", short), "QA9: the offer card shows Need n more Embers")
	_tap(it)
	_check(ss.swap_offer < 0 and absf(ss.bag[0].position.y - y) < 0.5, "QA9: no swap mode and the bag doesn't lift")
	run.progress.embers = 200


## 10. Sell / Swap hidden at 5 on every layout; remaining buttons don't overlap.
func _test_sell_hidden() -> void:
	_stock()
	for win: Vector2i in [PC, LANDSCAPE, PORTRAIT]:
		_show(win, win != PC)
		_check(ss.sell_button != null and not ss.sell_button.visible, "%s: Sell / Swap is hidden at 5 dice" % win)
		var a := ss.reroll_button.get_global_rect()
		var b := ss.leave_button.get_global_rect()
		_check(not a.intersects(b), "%s: Reroll and Leave don't overlap" % win)


## 11. Swap then Carve Back, or Reroll: swap mode is off; reroll pays only its price.
func _test_stale_state() -> void:
	_stock()
	_show(PC)
	ss.enter_swap(0)
	var e := run.progress.embers
	var mod := _item(ShopOffer.Kind.MOD, 0)
	if mod != null and mod.offer.affordable(e):
		mod.offer.buy(scene)
		_check(ss.swap_offer < 0, "QA11: opening a Carve panel clears swap mode")
		scene.refresh()
		_check(ss.swap_offer < 0 and run.progress.embers == e, "QA11: Back from Carve: swap is off and nothing was paid")
	else:
		scene._pick("x", func(_at: Vector2i) -> void: pass)
		_check(ss.swap_offer < 0, "QA11: _pick clears swap mode")
		scene.refresh()
	_stock()
	_show(PC)
	ss.enter_swap(0)
	e = run.progress.embers
	var price := run.reroll_price()
	ss.reroll_button.pressed.emit()
	_check(ss.swap_offer < 0 and run.progress.embers == e - price, "QA11: Reroll exits swap and pays only the reroll price")


## 12. Confirm-rule edges: blanks, rare, non-d6 strip, d10+ range + highlight.
func _test_confirm_edges() -> void:
	var p := RunProgress.new(_data)
	p.set_face(0, 0, RunDie.BLANK)
	_check(not p.die_has_mods(0) and not ShopSideCard.needs_confirm(p, 0, false), "QA12: a die with only BLANK faces does not confirm on PC")
	_check(ShopSideCard.needs_confirm(p, 0, true), "QA12: the same die confirms on a phone")
	p.swap_die(0, &"gallows")
	_check(p.die_is_rare(0) and not p.die_has_mods(0) and ShopSideCard.needs_confirm(p, 0, false), "QA12: a rare with no player carves confirms")
	var lines := ShopSideCard.swap_lines(p, 0, "Mirror Die")
	_check(lines.has(ShopSideCard.SWAP_TEXT.shop_swap_rare_warn) and not lines.has(ShopSideCard.SWAP_TEXT.shop_swap_mods_warn), "QA12: rare warning only")
	_stock()
	run.progress.swap_die(2, &"lantern")
	_show(PC)
	ss.bag[2].mouse_entered.emit()
	var strip := ss.card.find_children("FaceStrip", "", true, false)
	_check(not strip.is_empty(), "QA12: a non-d6 shape shows a strip")
	var cells := 0
	for f in (strip[0] as Node).find_children("*", "Control", true, false):
		if f.name != "ModIcon" and f.name != "Lock" and (f as Control).custom_minimum_size.x >= 24.0:
			cells += 1
	_check(cells >= 8, "QA12: lantern's strip has 8 face cells of at least 24 px (got %d)" % cells)
	run.progress.swap_die(3, &"tithe")
	_check(not run.progress.die_has_mods(3), "QA12: Tithe's built-in Gilded face is not a player carve")
	run.progress.set_face(3, 0, &"wild")
	_show(PC)
	ss.bag[3].mouse_entered.emit()
	var t := _texts(ss.card)
	_check(t.has(ShopCardStrings.fill("shop_card_faces_range", 10)), "QA12: d10+ shows the range line")
	# Only the player-carved face is highlighted, not the preset Gilded 10 (which would also trip pips(10)).
	var mods := ss.card.find_children("ModIcon", "", true, false)
	_check(mods.size() == 1, "QA12: d10+ highlights only the player-carved face, not preset Gilded (got %d)" % mods.size())


## 13. Event GIVE_DIE: prompt, whole-card click, confirm rule, cancel, skip picker.
func _test_event_give() -> void:
	var p := RunProgress.new(_data)
	p.set_face(1, 0, &"wild")
	var ch := EventChoiceData.new()
	var e := EventEffectData.new()
	e.kind = EventEffectData.Kind.GIVE_DIE
	e.die = DiceIds.DIE_MIRROR
	ch.effects.assign([e])
	var ev := EventData.new()
	ev.title = "Test"
	ev.body = "x"
	ev.choices.assign([ch])
	var view := EventView.new()
	view.touch_override = 0
	root.add_child(view)
	await process_frame
	var got: Array = []
	view.choice_made.connect(func(_i: int, picks: Array[Vector2i]) -> void: got.append(picks))
	view.show_event(ev, p)
	view._on_choice(0)
	await process_frame
	var dp: Array = view.find_children("*", "DicePanel", true, false)
	_check(not dp.is_empty() and (dp[0] as DicePanel).get_child(0) is Label, "QA13: the picker opened")
	_check((dp[0] as DicePanel).get_child(0).text == "Click a die to give up for Mirror Die.", "QA13: the prompt names the new die")
	# Whole card is clickable: emit as the card would.
	(dp[0] as DicePanel).picked.emit(Vector2i(0, 0))  # plain Bone, PC: no confirm
	await process_frame
	_check(got.size() == 1 and got[0] == [Vector2i(0, 0)], "QA13: a plain die swaps on click (PC), no confirm")
	got.clear()
	view.show_event(ev, p)
	view._on_choice(0)
	await process_frame
	dp = view.find_children("*", "DicePanel", true, false)
	(dp[0] as DicePanel).picked.emit(Vector2i(1, 0))
	await process_frame
	var t := _texts(view)
	_check(t.has(ShopSideCard.SWAP_TEXT.shop_swap_mods_warn) and view.find_children("SwapPreview", "", true, false).size() == 1, "QA13: a carved die gets the shared confirm with strips")
	# KEEP IT
	var before := p.dice.map(func(d: RunDie) -> StringName: return d.id)
	for b in view.find_children("*", "Button", true, false):
		if (b as Button).text == ShopSideCard.SWAP_TEXT.shop_swap_cancel:
			(b as Button).pressed.emit()
	await process_frame
	_check(got.is_empty() and p.dice.map(func(d: RunDie) -> StringName: return d.id) == before, "QA13: KEEP IT returns to the choices, bag unchanged")
	# Back: start again and press Back on the picker
	view.show_event(ev, p)
	view._on_choice(0)
	await process_frame
	for b in view.find_children("*", "Button", true, false):
		if (b as Button).text == "Back":
			(b as Button).pressed.emit()
	await process_frame
	_check(got.is_empty() and p.dice.map(func(d: RunDie) -> StringName: return d.id) == before, "QA13: Back returns to the choices, nothing applied")
	# Non-full bag: no picker (don't mutate the shared RunData).
	var room := _data.duplicate() as RunData
	room.max_dice = 6
	var roomy := RunProgress.new(room)
	view.show_event(ev, roomy)
	view._on_choice(0)
	await process_frame
	_check(got.size() == 1 and (got[0] as Array).is_empty(), "QA13: with room, the die is added with no picker")
	view.queue_free()


## 14. A run never exceeds 5 dice after these swaps.
func _test_regression_cap() -> void:
	_stock()
	_show(PC)
	ss.enter_swap(0)
	_click(ss.bag[0])
	_check(run.progress.dice.size() == 5 and run.data.max_dice == 5, "QA14: a full run still never exceeds 5 dice")
