## Shelf "CHIPS" label and shop-card titles (shop label clip).
## The label must sit inside the counter, under the brass rail, clear of other
## labels. Every shop item name must fit on the card title at desktop, phone
## landscape and phone portrait (no clip, text width within the title slot).
## Reverting either fix fails the matching check.
##   godot --headless --path . --script res://tests/test_shop_labels.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	var wins: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(844, 390), Vector2i(390, 844)]
	for win in wins:
		await _test_chips(win)
		await _test_titles(win)
	print("=== test_shop_labels: %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", what)


## Viewport the size a real window of `win` stretches to (canvas expand).
func _vp_size(win: Vector2i) -> Vector2i:
	if win.y > win.x:
		return Vector2i(1920, int(round(1920.0 * float(win.y) / float(win.x))))
	if float(win.x) / float(win.y) > 1.9:
		return Vector2i(int(round(1080.0 * float(win.x) / float(win.y))), 1080)
	return Vector2i(1920, 1080)


func _open(win: Vector2i) -> Array:
	var vp := SubViewport.new()
	vp.size = _vp_size(win)
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
	var ss := scene.shop_screen
	ss.window_override = win
	ss.touch_override = 0
	return [vp, scene]


## Counter wood under the top brass rail: the shelf a player can read.
func _visible_shelf(ss: ShopScreen) -> Rect2:
	var wood := Rect2()
	var rail := Rect2()
	for c in ss.get_children():
		if c is ColorRect and (c as ColorRect).color == ShopScreen.WOOD and (c as ColorRect).size.x > wood.size.x:
			wood = (c as ColorRect).get_global_rect()
		if c is ColorRect and (c as ColorRect).color == ShopScreen.BRASS and (c as ColorRect).position.x <= 1.0:
			rail = (c as ColorRect).get_global_rect()
	return Rect2(wood.position.x, rail.end.y, wood.size.x, maxf(0.0, wood.end.y - rail.end.y))


func _test_chips(win: Vector2i) -> void:
	var opened: Array = await _open(win)
	var vp: SubViewport = opened[0]
	var scene: RunScreen = opened[1]
	var run := scene.run
	run.shop_chips = [&"thumb", &"fuse_cord", &"double_down"]
	var ss := scene.shop_screen
	ss.build(scene)
	await process_frame
	var shelf := _visible_shelf(ss)
	var labels: Array[Label] = []
	for n in ss.find_children("ChipShelfTitle", "Label", true, false):
		labels.append(n)
	_check(not labels.is_empty(), "%s has a CHIPS label" % win)
	var rails: Array[Rect2] = []
	for c in ss.find_children("*", "ColorRect", true, false):
		if (c as ColorRect).color == ShopScreen.BRASS:
			rails.append((c as ColorRect).get_global_rect())
	for lab in labels:
		var r := lab.get_global_rect()
		var font := lab.get_theme_font(&"font")
		var fs := lab.get_theme_font_size(&"font_size")
		var tw: float = font.get_string_size(lab.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_check(lab.text == ChipStrings.get_text("chip_shelf_label"), "%s label reads CHIPS" % win)
		_check(r.size.x >= tw - 1.0 and r.size.y > 1.0, "%s CHIPS rect covers the word (%s)" % [win, r])
		_check(shelf.encloses(r), "%s CHIPS inside the shelf %s vs %s" % [win, r, shelf])
		_check(ss.get_viewport().get_visible_rect().encloses(r), "%s CHIPS on screen" % win)
		for rail in rails:
			_check(not r.intersects(rail), "%s CHIPS misses the rail %s vs %s" % [win, r, rail])
		for other in ss.find_children("*", "Label", true, false):
			if other == lab:
				continue
			var orect := (other as Label).get_global_rect()
			if orect.size.x < 1.0 or orect.size.y < 1.0:
				continue
			_check(not r.intersects(orect), "%s CHIPS misses '%s'" % [win, (other as Label).text])
		for it in ss.items:
			_check(not r.intersects(it.get_global_rect()), "%s CHIPS misses %s" % [win, it.offer.display_name])
	vp.queue_free()
	await process_frame


## Names the card can show, taken from the run's pools (not one roll).
func _catalog(run: MapRun) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for d in run.data.special_dice:
		if d.display_name != "":
			out.append({"name": d.display_name, "rare": d.is_rare(), "lo": d.price, "hi": d.price})
	for s in run.data.shapes:
		if s.display_name != "":
			out.append({"name": s.display_name, "rare": s.is_rare(), "lo": s.price, "hi": s.price})
	for m in run.data.face_mods:
		if m.display_name != "":
			out.append({"name": m.display_name, "rare": false, "lo": m.price, "hi": m.price})
	for id in run.data.seal_combos:
		out.append({"name": "%s Seal" % String(id).capitalize(), "rare": false, "lo": run.data.shop_seal_price, "hi": run.data.shop_seal_price})
	for id in run.data.rare_seals:
		out.append({"name": String(id).capitalize(), "rare": true, "lo": run.data.shop_premium_rare_price, "hi": run.data.shop_premium_rare_price})
	for id in ChipLooks.LOOKS:
		var look: Dictionary = ChipLooks.LOOKS[id]
		out.append({"name": str(look["name"]), "rare": look["tier"] == &"R", "lo": 10, "hi": 10})
	out.append({"name": ShopCardStrings.get_text("shop_card_soul_name"), "rare": false, "lo": run.data.shop_soul_price, "hi": run.data.shop_soul_price})
	return out


func _layout(n: Node) -> void:
	if n is Container:
		(n as Container).notification(Container.NOTIFICATION_SORT_CHILDREN)
	for c in n.get_children():
		_layout(c)


func _test_titles(win: Vector2i) -> void:
	var opened: Array = await _open(win)
	var vp: SubViewport = opened[0]
	var scene: RunScreen = opened[1]
	var ss := scene.shop_screen
	ss.build(scene)
	await process_frame
	var names := _catalog(scene.run)
	_check(names.size() >= 20, "%s catalog has the shop names (%d)" % [win, names.size()])
	var min_px := int(round(16.0 * ss.k))
	for spec: Dictionary in names:
		var name: String = spec["name"]
		var o := ShopOffer._make(ShopOffer.Kind.CHIP, 0, &"thumb", name, &"thumb", int(spec["lo"]), int(spec["hi"]))
		o.rare = bool(spec["rare"])
		ss.card._build(o)
		ss.card.visible = true
		ss.card.reset_size()
		_layout(ss.card)
		var title := ss.card.find_child("ItemTitle", true, false) as Label
		_check(title != null and title.text == name, "%s title text '%s'" % [win, name])
		if title == null:
			continue
		var font := title.get_theme_font(&"font")
		var fs := title.get_theme_font_size(&"font_size")
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
		if row.custom_minimum_size.x < 1.0:
			slot = ss.card.size.x - 32.0 * ss.k - used - sep * float(gaps)
		_check(not title.clip_text, "%s '%s' does not clip" % [win, name])
		_check(title.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING, "%s '%s' overrun off" % [win, name])
		_check(tw <= slot + 1.0, "%s '%s' width %.0f fits slot %.0f at %dpx" % [win, name, tw, slot, fs])
		_check(title.size.x + 1.0 >= tw, "%s '%s' title rect %.0f holds the word %.0f" % [win, name, title.size.x, tw])
		_check(fs + 1 >= min_px, "%s '%s' font %d still reads (min %d)" % [win, name, fs, min_px])
		_check(ss.card.size.x <= ShopCard.WIDTH[ss.layout] * ss.k + 1.5, "%s '%s' card stays at its width" % [win, name])
	vp.queue_free()
	await process_frame
