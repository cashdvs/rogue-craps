## Counter pads under shop goods (Nov 7 handoff): size, omit, input, states.
##   godot --headless --path . --script res://tests/test_shop_counter_pad.gd
extends SceneTree

var _passed := 0
var _failed := 0
var scene: RunScreen
var run: MapRun


func _initialize() -> void:
	_test_math()
	_test_texture()
	scene = (load("res://scenes/run.tscn") as PackedScene).instantiate()
	scene.run_seed = 1234
	root.add_child(scene)
	await process_frame
	run = scene.run
	run.enter_for_sandbox(MapGenData.NodeType.SHOP, 0, null)
	scene.refresh()
	await process_frame
	_test_pc_pads()
	_test_states()
	_test_phone_omit()
	_test_ghost_alpha()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", what)


func _test_math() -> void:
	_check(ShopCounterPad.logical_width(200.0) == 64.0, "wide slot uses the 64 px pad")
	_check(is_equal_approx(ShopCounterPad.logical_width(60.0), 52.0), "slot 60 -> width 52")
	_check(is_equal_approx(ShopCounterPad.logical_width(56.0), 48.0), "slot 56 is the smallest pad")
	_check(ShopCounterPad.logical_width(55.9) == 0.0, "under 48 plus clearance omits the pad")
	var foot := Vector2(60, 100)
	var r := ShopCounterPad.rect_at(foot, 200.0, 2.0)
	_check(is_equal_approx(r.size.x, 128.0) and is_equal_approx(r.size.y, 40.0), "k=2 scales 64x20 to 128x40")
	_check(is_equal_approx(r.position.x + r.size.x * 0.5, foot.x), "pad is centred on the foot")
	_check(is_equal_approx(r.end.y, foot.y + 4.0), "bottom sits 2 logical px below the foot")
	_check(ShopCounterPad.rect_at(foot, 40.0, 1.0).size == Vector2.ZERO, "narrow slot returns an empty rect")
	var a := Rect2(0, 0, 64, 20)
	var b := Rect2(72, 0, 64, 20)  # 8 px gap
	var edge := Rect2(68, 0, 64, 20)  # exactly 4 px, the minimum
	var close := Rect2(67, 0, 64, 20)  # 3 px gap
	_check(ShopCounterPad.separated(a, b, 4.0), "8 px gap is enough")
	_check(ShopCounterPad.separated(a, edge, 4.0), "4 px gap is the minimum")
	_check(not ShopCounterPad.separated(a, close, 4.0), "3 px gap is too close")
	_check(ShopCounterPad.separated(a, Rect2(0, 40, 64, 20), 4.0), "another shelf is not a neighbour")
	var plain := ShopCounterPad.modulate_for(false)
	var ghost := ShopCounterPad.modulate_for(true)
	_check(plain == Color(1, 1, 1, 1), "normal pad is untinted")
	_check(is_equal_approx(ghost.a, ShopCounterPad.SOLD_ALPHA) and ghost.r == 1.0 and ghost.b == 1.0, "ghost is the same colour at 35% alpha")


func _test_texture() -> void:
	var img := ShopCounterPad.TEXTURE.get_image()
	_check(img.get_width() == 128 and img.get_height() == 40, "pad asset is 128x40")
	var mid := img.get_pixel(64, 20)
	_check(mid.a8 > 200 and mid.r8 < 40 and mid.g8 < 40 and mid.b8 < 40, "centre is the dark matte fill (got %s)" % mid)
	var bad := 0
	for y in img.get_height():
		for x in img.get_width():
			var p := img.get_pixel(x, y)
			if p.a < 0.04:
				continue
			if p.b > p.r + 0.02:
				bad += 1  # Cyan / blue.
			if p.r > 0.85 and p.g < 0.35 and p.b < 0.45:
				bad += 1  # Danger red.
			if p.r > 0.4 and p.b > 0.4 and p.g + 0.1 < minf(p.r, p.b):
				bad += 1  # Violet.
	_check(bad == 0, "pad art has no violet, cyan or danger red (%d)" % bad)


func _pad(it: ShopItem) -> TextureRect:
	return it.icon.find_child("CounterPad", true, false) as TextureRect


func _test_pc_pads() -> void:
	var ss := scene.shop_screen
	ss.window_override = Vector2i(1920, 1080)
	ss.build(scene)
	_check(ss.layout == ShopScreen.Layout.PC, "PC layout")
	var art: float = ShopScreen.LAYOUTS[ss.layout].art * ss.k
	var die_foot := -1.0
	var chip_foot := -1.0
	var pads := 0
	for it in ss.items:
		_check(is_equal_approx(it.icon.custom_minimum_size.x, art), "icon scale stays the shelf art size")
		_check(it.tag.label.text == it.offer.price_text(), "price text unchanged")
		for c in it.get_children():
			_check(c.name != "CounterPad", "pad is not a row child (would move the good)")
		var pad := _pad(it)
		_check(pad != null, "PC slot fits a pad for %s" % it.offer.display_name)
		if pad == null:
			continue
		pads += 1
		_check(pad.mouse_filter == Control.MOUSE_FILTER_IGNORE, "pad ignores the mouse")
		_check(pad.show_behind_parent, "pad draws behind the good")
		_check(pad.get_parent() == it.icon and it.icon.get_child(0) == pad, "pad is the icon's back child")
		_check(is_equal_approx(pad.size.x, 64.0 * ss.k), "PC pad width is 64 logical px")
		_check(is_equal_approx(pad.size.y, pad.size.x * 20.0 / 64.0), "pad height keeps 20/64")
		_check(pad.modulate == Color(1, 1, 1, 1), "can't-afford does not tint the pad")
		var foot := ShopCounterPad.foot_in_icon(it.icon as ShopIcon)
		_check(is_equal_approx(pad.position.x + pad.size.x * 0.5, foot.x), "centred on the foot")
		_check(is_equal_approx(pad.position.y + pad.size.y, foot.y + 2.0 * ss.k), "2 logical px below the foot")
		_check(not pad.get_global_rect().intersects(it.tag.get_global_rect()), "pad misses the price tag")
		if it.offer.kind == ShopOffer.Kind.DIE:
			die_foot = foot.y / it.icon.size.y
		elif chip_foot < 0.0:
			chip_foot = foot.y / it.icon.size.y
	_check(pads == ss.items.size() and pads >= 7, "every PC good has a pad (%d)" % pads)
	_check(die_foot > chip_foot and chip_foot > 0.0, "dice feet sit lower in the icon than flat goods")
	for s in ss.bag:
		_check(s.find_child("CounterPad", true, false) == null, "bag dice are not shop goods")
	if ss.dealer != null:
		_check(ss.dealer.find_child("CounterPad", true, false) == null, "dealer has no pad")
	# Hitbox: the item still takes the click. Embers are 0, so the buy is refused.
	var die := ss.items[0]
	var embers := run.progress.embers
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	die._gui_input(e)
	_check(run.progress.embers == embers and run.shop_dice[0] != null, "pad does not change the buy hit")


func _test_states() -> void:
	var ss := scene.shop_screen
	run.progress.embers = 100
	run.shop_chips = [&"thumb", &"double_down", &"cold_comfort"]
	ss.build(scene)
	var unafford := _pad(ss.items[0]).size
	var chip: ShopItem = null
	var risky: ShopItem = null
	for it in ss.items:
		var pad := _pad(it)
		_check(pad != null and pad.modulate == Color(1, 1, 1, 1), "affordable pad stays untinted")
		_check(not it.tag.is_red(), "100 embers affords the shelf")
		if it.offer.kind == ShopOffer.Kind.CHIP and it.offer.id == &"double_down":
			risky = it
		elif it.offer.kind == ShopOffer.Kind.CHIP and chip == null:
			chip = it
	_check(risky != null and risky.offer.rare and _pad(risky).size == _pad(chip).size, "RISKY / rare chip uses the same pad")
	var before := _pad(chip).size
	var gy := _pad(chip).global_position.y
	chip.lift(true)
	_check(_pad(chip).size == before, "hover does not resize the pad")
	_check(is_equal_approx(_pad(chip).global_position.y, gy - 10.0 * ss.k), "pad stays under the lifted good")
	chip.lift(false)
	# Sold slot: an empty chip id is not drawn, so it has no pad.
	run.shop_chips = [&"", &"thumb"]
	ss.build(scene)
	var left: Array[ShopItem] = []
	for it in ss.items:
		if it.offer.kind == ShopOffer.Kind.CHIP:
			left.append(it)
	_check(left.size() == 1 and left[0].offer.id == &"thumb" and _pad(left[0]) != null, "sold chip is gone, and the one left keeps its pad")
	var n := ss.items.size()
	left[0].offer.buy(scene)
	var chips_left := 0
	for it in ss.items:
		if it.offer.kind == ShopOffer.Kind.CHIP:
			chips_left += 1
	_check(chips_left == 0 and ss.items.size() == n - 1, "bought chip leaves the shelf and takes its pad")
	run.progress.embers = 0
	ss.window_override = Vector2i(1920, 1080)
	ss.build(scene)
	_check(ss.items[0].tag.is_red() and _pad(ss.items[0]).modulate == Color(1, 1, 1, 1), "can't-afford reddens the price only")
	_check(is_equal_approx(_pad(ss.items[0]).size.x, unafford.x), "can't-afford keeps the pad size")


func _test_phone_omit() -> void:
	var ss := scene.shop_screen
	run.shop_chips = [&"thumb", &"cold_comfort"]
	run._roll_shop()  # Visual inject only: a roll still clears chips.
	_check(run.shop_chips.is_empty(), "shop roll still clears chips")
	ss.window_override = Vector2i(844, 390)
	ss.touch_override = 1
	ss.build(scene)
	_check(ss.layout == ShopScreen.Layout.LANDSCAPE, "landscape layout")
	var land_pads := 0
	for it in ss.items:
		land_pads += 1 if _pad(it) != null else 0
	_check(land_pads == ss.items.size() and ss.shelves.size() == 1, "landscape default shelf fits every pad (%d)" % land_pads)
	run.shop_chips = [&"thumb", &"leaning", &"second_wind", &"fuse_cord", &"double_down", &"cold_comfort"]
	ss.window_override = Vector2i(390, 844)
	ss.build(scene)
	_check(ss.layout == ShopScreen.Layout.PORTRAIT, "portrait layout")
	# Key on the icon, not the item: a RARE chip makes that item taller, so its
	# top sits higher even though the icon is on the same shelf.
	var rows := {}
	for it in ss.items:
		var key := str(int(it.icon.global_position.y))
		if not rows.has(key):
			rows[key] = []
		(rows[key] as Array).append(it)
	var ys: Array = rows.keys()
	ys.sort()
	_check(ys.size() == 3, "portrait still has 3 shelves")
	var top: Array = rows[ys[0]]
	var bot: Array = rows[ys[ys.size() - 1]]
	var top_pads := 0
	for it in top:
		top_pads += 1 if _pad(it) != null else 0
	var bot_pads := 0
	for it in bot:
		bot_pads += 1 if _pad(it) != null else 0
	_check(top.size() == 3 and top_pads == 3, "portrait top row fits a pad each")
	_check(bot.size() > 3 and bot_pads == 0, "cramped portrait row omits pads (%d items)" % bot.size())
	# Touch select opens the card and does not retint the pad.
	ss.items[0].focus_item.emit(ss.items[0])
	_check(ss.card.item == ss.items[0], "phone tap still selects")
	_check(_pad(ss.items[0]).modulate == Color(1, 1, 1, 1), "select does not retint the pad")
	ss.window_override = Vector2i(844, 390)
	ss.build(scene)
	var shown := 0
	var tag_hit := 0
	for it in ss.items:
		var pad := _pad(it)
		if pad == null:
			continue
		shown += 1
		if pad.get_global_rect().intersects(it.tag.get_global_rect()):
			tag_hit += 1
	# Goods already overlap on this one shelf (pre-existing). Pads are narrower
	# than the cell and sit above the price plates, so they still fit.
	_check(ss.shelves.size() == 1 and ss.layout == ShopScreen.Layout.LANDSCAPE, "crowded landscape stays one shelf")
	_check(shown == ss.items.size() and tag_hit == 0, "crowded landscape pads clear the price tags (%d/%d)" % [shown, ss.items.size()])
	ss.touch_override = -1
	ss.window_override = Vector2i.ZERO


func _test_ghost_alpha() -> void:
	var ss := scene.shop_screen
	ss.window_override = Vector2i(1920, 1080)
	run.shop_chips.clear()
	run.progress.embers = 100
	ss.build(scene)
	var icon := ss.items[0].icon as ShopIcon
	var old := _pad(ss.items[0])
	old.free()
	var blockers: Array[Rect2] = []
	var placed: Array[Rect2] = []
	var pad := ShopCounterPad.attach(icon, 400.0 * ss.k, ss.k, blockers, placed, true)
	_check(pad != null and is_equal_approx(pad.modulate.a, 0.35), "sold ghost draws the pad at 35% alpha")
	_check(pad.modulate.r == 1.0 and pad.mouse_filter == Control.MOUSE_FILTER_IGNORE, "ghost pad stays neutral and non-interactive")
