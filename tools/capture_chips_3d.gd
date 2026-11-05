## QA captures for 3D chips (AD chips_3d_nov5 §7).
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 \
##     --resolution 1920x1080 --script res://tools/capture_chips_3d.gd -- --out=/workspace/shots/chips_3d/
extends SceneTree

var _out := "/workspace/shots/chips_3d/"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6).trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(_out)
	await _shop_shots()
	await _sheet_48()
	await _hud_row()
	print("done -> ", _out)
	quit()


func _shot(name: String) -> void:
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_out + name)
	print("saved ", name)


func _open_shop(seed: int, chips: Array[StringName], embers: int) -> RunScreen:
	var scene: RunScreen = (load("res://scenes/run.tscn") as PackedScene).instantiate()
	scene.run_seed = seed
	root.add_child(scene)
	await process_frame
	var run := scene.run
	run.screen = MapRun.Screen.SHOP
	run._roll_shop()
	run.shop_chips = chips.duplicate()
	run.progress.embers = embers
	run.progress.chips = [&"thumb", &"leaning", &"fuse_cord"]
	scene.refresh()
	await process_frame
	await process_frame
	return scene


## PC + phone shop with Common / Special / Rare + RISKY; can't-afford / hover / sold.
func _shop_shots() -> void:
	# PC: one of each tier + RISKY on the shelf (inject 4; shop may show extras).
	var scene := await _open_shop(7, [&"thumb", &"fuse_cord", &"double_down"], 100)
	scene.shop_screen.window_override = Vector2i(1920, 1080)
	scene.shop_screen.build(scene)
	await _shot("shop_pc_tiers.png")
	# Hover: lift first chip item.
	for it in scene.shop_screen.items:
		if it.offer.kind == ShopOffer.Kind.CHIP:
			it.lift(true)
			break
	await _shot("shop_pc_hover.png")
	# Can't afford.
	scene.run.progress.embers = 0
	scene.shop_screen.build(scene)
	await _shot("shop_pc_cant_afford.png")
	# Sold: clear first slot.
	scene.run.progress.embers = 100
	scene.run.shop_chips = [&"", &"fuse_cord", &"double_down"]
	scene.shop_screen.build(scene)
	await _shot("shop_pc_sold.png")
	scene.queue_free()
	await process_frame
	# Phone landscape
	scene = await _open_shop(7, [&"thumb", &"fuse_cord", &"double_down"], 80)
	scene.shop_screen.window_override = Vector2i(844, 390)
	scene.shop_screen.touch_override = 1
	scene.shop_screen.build(scene)
	await _shot("shop_phone_landscape.png")
	scene.queue_free()
	await process_frame
	# Phone portrait
	scene = await _open_shop(7, [&"leaning", &"second_wind", &"double_down"], 80)
	scene.shop_screen.window_override = Vector2i(390, 844)
	scene.shop_screen.touch_override = 1
	scene.shop_screen.build(scene)
	await _shot("shop_phone_portrait.png")
	scene.queue_free()
	await process_frame


## 48 px sheet of the First Batch five under the shop light (live SubViewports).
func _sheet_48() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	root.add_child(row)
	var renders: Array[ShopDieRender] = []
	for id in ChipLooks.FIRST_BATCH:
		var o := ShopOffer._make(ShopOffer.Kind.CHIP, 0, id, str(ChipLooks.look(id).get("name", "")), id, 0)
		var r := ShopDieRender.make(o, 48)
		row.add_child(r)
		renders.append(r)
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	# Composite into one image.
	var sheet := Image.create(48 * 5 + 8 * 4, 48, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.12, 0.05, 0.06, 1))  # table-ish red dark
	for i in renders.size():
		var img: Image = renders[i].view.get_texture().get_image()
		sheet.blit_rect(img, Rect2i(0, 0, 48, 48), Vector2i(i * (48 + 8), 0))
	sheet.save_png(_out + "first_batch_48.png")
	# Nearest x4 for AD review.
	sheet.resize(sheet.get_width() * 4, sheet.get_height() * 4, Image.INTERPOLATE_NEAREST)
	sheet.save_png(_out + "first_batch_48_x4.png")
	print("saved first_batch_48(_x4).png")
	row.queue_free()
	await process_frame


## HUD row with 3 owned discs + a pop frame.
func _hud_row() -> void:
	var scene: RunScreen = (load("res://scenes/run.tscn") as PackedScene).instantiate()
	scene.run_seed = 3
	root.add_child(scene)
	await process_frame
	scene.run.progress.chips = [&"thumb", &"fuse_cord", &"double_down"]
	scene.run.screen = MapRun.Screen.MAP
	scene.refresh()
	await process_frame
	await process_frame
	await _shot("hud_owned_3.png")
	if scene.chip_row:
		scene.chip_row.pop(2)  # pop the RISKY one
		for _i in 6: await process_frame
		await _shot("hud_pop_frame.png")
	scene.queue_free()
