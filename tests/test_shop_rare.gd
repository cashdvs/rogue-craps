## Shop redesign PR D (HANDOFF_SPEC §4-§5): the rare treatment, on the real
## RunScreen shop. Rare items get a RARE chip on the shelf and the card; rare
## dice stand on a plinth; pre-carved faces get a brass border and a lock.
##   godot --headless --path . --script res://tests/test_shop_rare.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0
var scene: RunScreen
var run: MapRun
var ss: ShopScreen
const RARE_IDS := [&"pyre", &"gilt", &"lodestone", &"ossuary"]


func _initialize() -> void:
	scene = (load("res://scenes/run.tscn") as PackedScene).instantiate()
	scene.run_seed = 1234
	root.add_child(scene)
	await process_frame
	run = scene.run
	ss = scene.shop_screen
	_open_shop_with_rare()
	_test_body_aliases()
	for win in [Vector2i(1920, 1080), Vector2i(844, 390), Vector2i(390, 844)]:
		await _test_shelf(win)
	_test_card_chip_and_locks()
	print("=== test_shop_rare: %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", what)


func _open_shop_with_rare() -> void:
	run.screen = MapRun.Screen.SHOP
	for k in 300:
		run.shop_rerolls = k
		run._roll_shop()
		if run.shop_dice.size() > 1 and run.shop_dice[1] != null and run.shop_dice[1].is_rare():
			break
	run.shop_rerolls = 0
	run.progress.embers = 100


func _show(win: Vector2i) -> void:
	ss.window_override = win
	ss.touch_override = 1 if win.x < 1000 else 0
	scene.refresh()


func _item(kind: ShopOffer.Kind, index: int = 0) -> ShopItem:
	for it in ss.items:
		if it.offer.kind == kind and it.offer.index == index:
			return it
	return null


func _named(n: Node, name: String) -> Array:
	return n.find_children(name, "", true, false)


## All four rare dice use a stand-in body until their own .glb lands.
func _test_body_aliases() -> void:
	var want := {&"pyre": &"hellfire_d6", &"gilt": &"gilded_d6", &"lodestone": &"mirror_d6", &"ossuary": &"bone_d6"}
	for id: StringName in RARE_IDS:
		_check(DiceIds.body_key(id) == want[id], "%s body_key -> %s (got %s)" % [id, want[id], DiceIds.body_key(id)])
	_check(DiceIds.body_key(&"standard") == DiceIds.asset_key(&"standard"), "normal die keeps its own body")


## Chip and plinth come only from offer.rare, at every layout.
func _test_shelf(win: Vector2i) -> void:
	_show(win)
	await process_frame
	var tag := " @%s" % win
	for it in ss.items:
		var chips := _named(it, "RareChip").size()
		var plinths := _named(it, "Plinth").size()
		var die: bool = it.offer.kind == ShopOffer.Kind.DIE
		_check(chips == (1 if it.offer.rare else 0), "%s chip only if rare%s" % [it.offer.display_name, tag])
		_check(plinths == (1 if it.offer.rare and die else 0), "%s plinth only on rare dice%s" % [it.offer.display_name, tag])
	var rare := _item(ShopOffer.Kind.DIE, 1)
	_check(rare != null and rare.offer.rare, "slot 2 die is rare" + tag)
	if rare == null:
		return
	var chip: Label = _named(rare, "RareChip")[0]
	_check(chip.text == "RARE" and chip.get_index() < rare.icon.get_index(), "chip reads RARE and sits above the icon" + tag)
	var sb := chip.get_theme_stylebox("normal") as StyleBoxFlat
	_check(sb != null and sb.bg_color == Color("#C9A24A"), "chip is brass #C9A24A" + tag)
	_check(chip.custom_minimum_size.is_equal_approx(Vector2(52, 20) * ss.k), "chip is 52x20 spec px" + tag)
	var p: Control = _named(rare, "Plinth")[0]
	_check(p.get_parent() == rare.icon and p.show_behind_parent, "plinth rides the icon, behind the die" + tag)
	_check(p.position.y > rare.icon.size.y * 0.5 and p.size.x >= rare.icon.size.x, "plinth sits under the die, at least as wide" + tag)
	var rs := _item(ShopOffer.Kind.RARE_SEAL)
	if rs != null:
		_check(_named(rs, "RareChip").size() == 1 and _named(rs, "Plinth").is_empty(), "Rare Seal: chip, no plinth" + tag)
	var common := _item(ShopOffer.Kind.DIE, 0)
	if common != null and not common.offer.rare:
		_check(common.icon.get_global_rect().end.y == rare.icon.get_global_rect().end.y, "chip doesn't shift the rare icon off the row" + tag)


## Card: the chip is the shared RareMarks chip; pre-carved faces have the mod
## badge top-left, the lock bottom-right and a brass border.
func _test_card_chip_and_locks() -> void:
	_show(Vector2i(1920, 1080))
	ss.card.show_for(_item(ShopOffer.Kind.DIE, 1))
	_check(_named(ss.card, "RareChip").size() == 1, "card has one RARE chip")
	var d: DieShape = run.shop_dice[1]
	var faces: Array = _named(ss.card, "FaceStrip")[0].get_children()
	var locked := 0
	for f: Control in faces:
		var mod := f.find_child("ModIcon", false, false) as Control
		var lock := f.find_child("Lock", false, false) as Control
		if f.get_meta("locked", false):
			locked += 1
			_check(mod != null and mod.position == Vector2.ZERO, "mod badge top-left")
			_check(lock != null and lock.position.x > 0 and lock.position.y > 0, "lock bottom-right")
	_check(locked == d.preset_mods.size() and locked > 0, "every pre-carved face is brass-locked (%d)" % locked)
	ss.card.show_for(_item(ShopOffer.Kind.MOD, 0))
	_check(_named(ss.card, "RareChip").is_empty(), "normal item card: no chip")
	ss.card.close()
