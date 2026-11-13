## Phone portrait shop at a real 390x844 window (canvas expand: 1920 x 4155).
## Sell / reroll / leave must show their whole labels (no clip). Side-card
## titles use ShopCard.fit_title_px. Cards, buttons, labels, chips and shelf
## labels must sit inside the viewport and not cover each other.
##   godot --headless --path . --script res://tests/test_shop_portrait.gd
extends SceneTree

const WIN := Vector2i(390, 844)

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", what)


func _run() -> void:
	var opened: Array = await _open(false)
	await _buttons(opened[1], "paid")
	_overlap(opened[1], "resting")
	await _titles(opened[1])
	opened[0].queue_free()
	await process_frame
	var free_open: Array = await _open(true)
	await _buttons(free_open[1], "free")
	_overlap(free_open[1], "free reroll")
	free_open[0].queue_free()
	await process_frame
	print("=== test_shop_portrait: %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _vp_size() -> Vector2i:
	return Vector2i(1920, int(round(1920.0 * float(WIN.y) / float(WIN.x))))


func _open(free: bool) -> Array:
	var vp := SubViewport.new()
	vp.size = _vp_size()
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(vp)
	var scene: RunScreen = (load("res://scenes/run.tscn") as PackedScene).instantiate()
	scene.run_seed = 7
	vp.add_child(scene)
	await process_frame
	var run := scene.run
	run.screen = MapRun.Screen.SHOP
	run._roll_shop()
	run.progress.embers = 200
	run.progress.data.starting_dice = 4  # Five dice is then above the floor, so Sell / Swap shows.
	run.shop_chips = [&"thumb", &"fuse_cord", &"double_down"]
	if free:
		run.progress.free_rerolls = 1
	var ss := scene.shop_screen
	ss.window_override = WIN
	ss.touch_override = 1
	ss.build(scene)
	await process_frame
	return [vp, scene]


func _buttons(scene: RunScreen, tag: String) -> void:
	var ss := scene.shop_screen
	_check(ss.layout == ShopScreen.Layout.PORTRAIT, "%s: portrait layout" % tag)
	var row: Array[Button] = [ss.sell_button, ss.reroll_button, ss.leave_button]
	var view := ss.get_viewport().get_visible_rect()
	for b in row:
		_check(b != null and b.visible, "%s: %s is on the row" % [tag, b.text if b != null else "?"])
		if b == null or not b.visible:
			continue
		var font: Font = b.get_theme_font(&"font")
		var fs: int = b.get_theme_font_size(&"font_size")
		var tw: float = font.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var sb: StyleBox = b.get_theme_stylebox(&"normal")
		var inner := b.size.x
		if sb != null:
			inner -= sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT)
		_check(not b.clip_text, "%s: '%s' does not clip" % [tag, b.text])
		_check(b.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING, "%s: '%s' overrun off" % [tag, b.text])
		_check(tw <= inner + 1.0, "%s: '%s' width %.0f fits %.0f at %dpx" % [tag, b.text, tw, inner, fs])
		_check(fs + 1 >= int(round(11.0 * ss.k)), "%s: '%s' font %d still reads" % [tag, b.text, fs])
		_check(view.encloses(b.get_global_rect()), "%s: '%s' stays on screen" % [tag, b.text])
	_check(row[0].text == "Sell / Swap", "%s: sell button reads Sell / Swap" % tag)


func _titles(scene: RunScreen) -> void:
	var ss := scene.shop_screen
	var long_name := "Extraordinary Powder Keg"
	ss.card._frame()
	ss.card._title(long_name, "12")
	ss.card.visible = true
	ss.card.reset_size()
	_layout(ss.card)
	var title := ss.card.find_child("CardTitle", true, false) as Label
	_check(title != null and title.text == long_name, "side card title is the full name")
	if title == null:
		return
	var font: Font = title.get_theme_font(&"font")
	var fs: int = title.get_theme_font_size(&"font_size")
	var tw: float = font.get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var row := title.get_parent() as Control
	var used := 0.0
	var gaps := 0
	for ch in row.get_children():
		if ch == title:
			continue
		used += (ch as Control).get_combined_minimum_size().x
		gaps += 1
	var sep := float(row.get_theme_constant(&"separation"))
	var slot := row.custom_minimum_size.x - used - sep * float(gaps)
	var start := ss.card._px(32)
	var min_px := int(round(16.0 * ss.k))
	_check(not title.clip_text, "side title does not clip")
	_check(title.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING, "side title overrun off")
	_check(title.autowrap_mode == TextServer.AUTOWRAP_OFF, "side title stays one line")
	_check(tw <= slot + 1.0, "side title width %.0f fits slot %.0f at %dpx" % [tw, slot, fs])
	_check(fs <= start and fs + 1 >= min_px, "side title font %d steps from %d down to at least %d" % [fs, start, min_px])
	_check(font.get_string_size(long_name, HORIZONTAL_ALIGNMENT_LEFT, -1, start).x > slot, "the long name does not fit at 32 spec px, so the step is what saves it")
	ss.card.show_sell(ss.bag[0], true)
	_layout(ss.card)
	var sell := ss.card.find_child("CardTitle", true, false) as Label
	_check(sell != null and not sell.clip_text and sell.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING, "sell card title does not clip")
	ss.card.show_reroll(ss.reroll_button, true)
	_layout(ss.card)
	var reroll := ss.card.find_child("CardTitle", true, false) as Label
	_check(reroll != null and reroll.text == ShopCardStrings.get_text("shop_card_reroll_name") and not reroll.clip_text, "reroll card title does not clip")


## Goods, buttons, bag slots and the shop's own labels (title, CHIPS, YOUR
## DICE). Nested price numerals stay inside their item. A sliver under 2
## screen px is the portrait shelf: wide price tags are ~2 px past the cell,
## and spreading them would push the row off the shelf.
func _overlap(scene: RunScreen, tag: String) -> void:
	var ss := scene.shop_screen
	var view := ss.get_viewport().get_visible_rect()
	var nodes: Array[Control] = []
	_collect(ss, nodes)
	_check(nodes.size() >= 8, "%s: found shop controls (%d)" % [tag, nodes.size()])
	var shelf := 0
	var chips := 0
	var hair := 2.0 * ss.k
	for n in nodes:
		if n is Label and n.name == "ChipShelfTitle":
			shelf += 1
		if n is ShopItem and (n as ShopItem).offer.kind == ShopOffer.Kind.CHIP:
			chips += 1
		var r := n.get_global_rect()
		if r.size.x < 1.0 or r.size.y < 1.0:
			continue
		_check(view.encloses(r), "%s: %s stays inside %s vs %s" % [tag, _label(n), r, view])
	_check(shelf >= 1, "%s: a shelf label is on the counter" % tag)
	_check(chips >= 1, "%s: a chip is on the counter" % tag)
	for i in nodes.size():
		var a := nodes[i]
		var ra := a.get_global_rect()
		if ra.size.x < 1.0 or ra.size.y < 1.0:
			continue
		for j in range(i + 1, nodes.size()):
			var b := nodes[j]
			if a.is_ancestor_of(b) or b.is_ancestor_of(a):
				continue
			var rb := b.get_global_rect()
			if rb.size.x < 1.0 or rb.size.y < 1.0 or not ra.intersects(rb):
				continue
			var hit := ra.intersection(rb)
			if hit.size.x < hair or hit.size.y < hair:
				continue
			_check(false, "%s: %s overlaps %s by %s" % [tag, _label(a), _label(b), hit])


func _collect(n: Node, out: Array[Control]) -> void:
	# visible, not is_visible_in_tree: the shop lives in a SubViewport whose
	# parent chain is not on the screen, but the rects are still the layout.
	if n is Control and (n as Control).visible and _interesting(n as Control):
		out.append(n)
	for ch in n.get_children():
		_collect(ch, out)


func _interesting(c: Control) -> bool:
	if c is ShopItem or c is BagSlot or c is Button:
		return true
	# Shelf title, header, YOUR DICE and hints. Not the numerals inside a tag.
	return c is Label and c.get_parent() is ShopScreen


func _label(n: Node) -> String:
	if n is Label:
		return "label '%s'" % (n as Label).text.substr(0, 32)
	if n is Button:
		return "button '%s'" % (n as Button).text
	if n is ShopItem:
		return "item %s" % (n as ShopItem).offer.display_name
	return n.name


func _layout(n: Node) -> void:
	if n is Container:
		(n as Container).notification(Container.NOTIFICATION_SORT_CHILDREN)
	for c in n.get_children():
		_layout(c)
