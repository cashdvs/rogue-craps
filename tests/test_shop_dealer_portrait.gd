## Shop PR E: in portrait, Smiles' backdrop band is taller than before (106
## spec px) and still stays clear of the shelves, the counter, the bag and
## the card. Built through the real RunScreen -> ShopScreen path.
extends SceneTree

const PORTRAIT := Vector2i(390, 844)
## The old portrait band: counter top 170 - dealer top 64.
const OLD_BAND_PX := 106.0

var _passed: int = 0
var _failed: int = 0
var scene: RunScreen
var ss: ShopScreen


func _initialize() -> void:
	scene = (load("res://scenes/run.tscn") as PackedScene).instantiate()
	scene.run_seed = 77
	root.add_child(scene)
	await process_frame
	scene.run.screen = MapRun.Screen.SHOP
	scene.run.progress.embers = 100
	ss = scene.shop_screen
	root.size = PORTRAIT  # A real portrait window, not just the layout switch.
	ss.window_override = PORTRAIT
	ss.touch_override = 1  # Portrait phones are touchscreens.
	scene.refresh()
	await _test_band()
	print("=== test_shop_dealer_portrait: %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", what)


## A tap on `c` through its real input handler.
func _tap(c: Control) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	c._gui_input(e)


## True if `band` and `r` share any area (touching edges is fine).
func _hits(band: Rect2, r: Rect2) -> bool:
	return band.intersection(r).get_area() > 0.5


func _test_band() -> void:
	_check(ss.layout == ShopScreen.Layout.PORTRAIT and ss.dealer != null, "portrait shop has a dealer band")
	var band := ss.dealer.get_global_rect()
	var smiles := ss.dealer.still.get_global_rect()
	_check(band.size.y / ss.k > OLD_BAND_PX + 40.0, "band is taller than before (%.0f vs %.0f spec px)" % [band.size.y / ss.k, OLD_BAND_PX])
	_check(smiles.size.y / ss.k > OLD_BAND_PX, "Smiles himself is drawn bigger (%.0f spec px tall)" % (smiles.size.y / ss.k))
	_check(ss.dealer.get_index() < ss.shelves[0].get_index(), "band is drawn beneath (before) the shelves")
	var first_shelf_top := INF
	for s in ss.shelves:
		first_shelf_top = minf(first_shelf_top, s.get_global_rect().position.y)
		_check(not _hits(band, s.get_global_rect()), "band clear of shelf at y %.0f" % s.position.y)
	_check(band.end.y <= first_shelf_top, "band sits above every shelf")
	var counter: Rect2
	for c in ss.get_children():
		if c is ColorRect and (c as ColorRect).color == ShopScreen.WOOD:
			counter = (c as ColorRect).get_global_rect()  # The wood counter panel.
			break
	_check(counter.size.y > 0 and not _hits(band, counter), "band ends where the counter starts (no overlap)")
	var clear_items := true
	for it in ss.items:
		clear_items = clear_items and not _hits(band, it.get_global_rect())
	_check(clear_items, "band clear of every counter item")
	var clear_bag := true
	for b in ss.bag:
		clear_bag = clear_bag and not _hits(band, b.get_global_rect())
	_check(not ss.bag.is_empty() and clear_bag and not _hits(band, ss.bag_label.get_global_rect()), "band clear of the bag row")
	# Cards: an item on the bottom shelf, a bag die, and the reroll card.
	_tap(ss.items[ss.items.size() - 1])
	await process_frame  # Let the card size itself.
	_check(ss.card.visible and ss.card.size.y > 0 and not _hits(band, ss.card.get_global_rect()), "item card clear of the band")
	_tap(ss.bag[0])
	await process_frame
	_check(ss.card.visible and ss.card.size.y > 0 and not _hits(band, ss.card.get_global_rect()), "sell card clear of the band")
	ss.reroll_button.pressed.emit()
	await process_frame
	_check(ss.card.visible and ss.card.size.y > 0 and not _hits(band, ss.card.get_global_rect()), "reroll card clear of the band")
