## Screenshot of the Ember Shop with a rare die in the second dice slot
## (rare_dice_v1 PR 2): real RunScreen, real shop roll; steps the reroll
## seed until the rare roll hits.
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 \
##     --resolution 1920x1080 --script res://tools/capture_rare_shop.gd -- --out=/tmp/rare_dice_shop.png
extends SceneTree

var _out: String = "user://rare_dice_shop.png"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	var scene: RunScreen = (load("res://scenes/run.tscn") as PackedScene).instantiate()
	scene.run_seed = 1234
	root.add_child(scene)
	await process_frame
	var run := scene.run
	run.progress.embers = 60
	run.screen = MapRun.Screen.SHOP
	for k in 200:
		run.shop_rerolls = k
		run._roll_shop()
		if run.shop_dice.size() > 1 and run.shop_dice[1] != null and run.shop_dice[1].is_rare():
			break
	print("slot 2: ", run.shop_dice[1].id if run.shop_dice.size() > 1 else &"-", " rerolls ", run.shop_rerolls)
	run.shop_rerolls = 0
	scene.refresh()
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(_out.get_base_dir())
	root.get_texture().get_image().save_png(_out)
	print("saved ", _out)
	scene.queue_free()
	await process_frame
	quit()
