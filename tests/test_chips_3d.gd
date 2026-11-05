## 3D modifier chips + bone-token lift (AD chips_3d_nov5). Visual only.
##   godot --headless --path . --script res://tests/test_chips_3d.gd
extends SceneTree

var _passed := 0
var _failed := 0
var scene: RunScreen
var run: MapRun


func _initialize() -> void:
	scene = (load("res://scenes/run.tscn") as PackedScene).instantiate()
	scene.run_seed = 42
	root.add_child(scene)
	await process_frame
	run = scene.run
	_test_looks()
	_test_build()
	await _test_shop_shelf()
	await _test_hud_row()
	await _test_buy_and_cap()
	_test_no_emission()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", what)


## Data table covers the First Batch and Echo stays listed but not offered.
func _test_looks() -> void:
	_check(ChipLooks.FIRST_BATCH.size() == 5, "First Batch is 5 chips")
	_check(ChipLooks.LOOKS.size() == 20, "20 chip looks (Echo included)")
	_check(not ChipLooks.FIRST_BATCH.has(&"echo"), "Echo is ON HOLD, not in First Batch")
	_check(ChipLooks.look(&"double_down").risky and ChipLooks.look(&"thumb").risky == false, "RISKY flag")
	_check(ChipLooks.look(&"cold_comfort").risky == false, "Cold Comfort stays normal")
	_check(ChipLooks.look(&"kiln").risky and ChipLooks.look(&"snake_eyes").risky, "Kiln + Snake Eyes are RISKY (overlay later)")
	_check(ResourceLoader.exists(ChipLooks.face_path(&"thumb")), "thumb face PNG exists")
	_check(ChipLooks.tier_tag(&"C") == "COMMON", "tier tag")


## Mesh builder returns a Node3D with a body + face for First Batch chips.
func _test_build() -> void:
	for id in ChipLooks.FIRST_BATCH:
		var n := ShopChipBuild.make(id)
		var meshes := n.find_children("*", "MeshInstance3D", true, false)
		_check(meshes.size() >= 2, "%s has body + face meshes (%d)" % [id, meshes.size()])
		n.free()
	var risky := ShopChipBuild.make(&"double_down")
	# Same Rare tier (8 spots) without the overlay — only Double Down gets it this PR.
	var peer := ShopChipBuild.make(&"sixth_die")
	var normal := ShopChipBuild.make(&"cold_comfort")
	var rn := risky.find_children("*", "MeshInstance3D", true, false).size()
	var pn := peer.find_children("*", "MeshInstance3D", true, false).size()
	var nn := normal.find_children("*", "MeshInstance3D", true, false).size()
	_check(rn == pn + 1, "Double Down has overlay disc vs same-tier Rare (%d vs %d)" % [rn, pn])
	_check(nn >= 2 and rn > nn, "Cold Comfort is normal (no overlay); DD mesh count higher")
	risky.free()
	peer.free()
	normal.free()
	var tok := ShopChipBuild.make(&"mod_wild")
	_check(tok.find_children("*", "MeshInstance3D", true, false).size() >= 2, "mod token has body + mark")
	tok.free()


## Injected shop_chips appear as Kind.CHIP offers with a live SubViewport.
func _test_shop_shelf() -> void:
	run.screen = MapRun.Screen.SHOP
	run._roll_shop()
	run.shop_chips = [&"thumb", &"fuse_cord", &"double_down"]
	run.progress.embers = 100
	scene.refresh()
	await process_frame
	var chips: Array = scene.shop_screen.items.filter(func(it: ShopItem) -> bool: return it.offer.kind == ShopOffer.Kind.CHIP)
	_check(chips.size() == 3, "3 chip offers on the shelf (got %d)" % chips.size())
	if chips.size() == 3:
		_check(chips[0].offer.id == &"thumb" and chips[0].offer.rare == false, "Common chip not rare-tagged")
		_check(chips[2].offer.rare == true, "Rare chip is rare-tagged")
		var v: SubViewport = (chips[0].icon as ShopIcon).die_view
		_check(v != null and v.find_children("*", "MeshInstance3D", true, false).size() > 0, "chip icon is a live 3D SubViewport")


## HUD row shows 3 slots; owned chips fill discs; pop scales briefly.
func _test_hud_row() -> void:
	run.progress.chips = [&"leaning", &"second_wind"]
	scene._refresh_bar()
	await process_frame
	_check(scene.chip_row != null and scene.chip_row.get_child_count() == 3, "HUD ChipRow has 3 slots")
	var filled := 0
	for c in scene.chip_row.get_children():
		filled += 1 if c.get_child_count() > 0 else 0
	_check(filled == 2, "2 owned discs + 1 empty ring (filled %d)" % filled)
	scene.chip_row.pop(0)
	_check(true, "pop does not crash")


## Buying a chip parks it in the HUD (max 3) and clears the shelf slot.
func _test_buy_and_cap() -> void:
	run.progress.chips.clear()
	run.shop_chips = [&"thumb"]
	run.progress.embers = 100
	scene.refresh()
	await process_frame
	var it: ShopItem = null
	for x in scene.shop_screen.items:
		if x.offer.kind == ShopOffer.Kind.CHIP:
			it = x
			break
	_check(it != null, "chip on shelf to buy")
	if it:
		it.offer.buy(scene)
		_check(run.progress.chips.has(&"thumb"), "bought chip parks in HUD")
		_check(run.shop_chips[0] == &"", "shelf slot clears on buy")
	_check(run.progress.add_chip(&"leaning") and run.progress.add_chip(&"fuse_cord"), "can fill to 3")
	_check(not run.progress.add_chip(&"double_down"), "cap at 3 owned chips")
	# Can't afford: chip costs 10; refuse under that.
	run.progress.chips.clear()
	run.shop_chips = [&"thumb"]
	run.progress.embers = 9
	scene.refresh()
	await process_frame
	it = null
	for x in scene.shop_screen.items:
		if x.offer.kind == ShopOffer.Kind.CHIP:
			it = x
			break
	_check(it != null and not it.offer.affordable(9), "chip unaffordable at 9 embers")
	if it:
		it.offer.buy(scene)
		_check(not run.progress.chips.has(&"thumb"), "refuse buy under 10 embers")
		_check(run.shop_chips[0] == &"thumb", "shelf keeps chip when can't afford")
	# Seed non-empty shop_chips, then roll — must clear (visual inject only).
	run.shop_chips = [&"thumb", &"cold_comfort", &"double_down"]
	run._roll_shop()
	_check(run.shop_chips.is_empty(), "shop roll clears injected chips")


## Emission stays 0 on chip rim materials (AD: no glow).
func _test_no_emission() -> void:
	var n := ShopChipBuild.make(&"fuse_cord")
	var body: MeshInstance3D = n.get_child(0)
	var mat: ShaderMaterial = body.material_override
	_check(mat != null and float(mat.get_shader_parameter("emission_energy")) == 0.0, "Special rim emission is 0")
	n.free()
