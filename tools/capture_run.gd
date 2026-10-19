## Screenshots of the run screens: the floor map (a few nodes in) an event
## (The Devil's Deal, with a greyed-out choice), the shop, the boss table entry, and the
## real Bonfire3D table opened by the run with modded run dice.
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 \
##     --resolution 1920x1080 --script res://tools/capture_run.gd -- --out=/tmp/shots/
extends SceneTree

var _out: String = "user://captures_run/"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(_out)
	var scene: RunScreen = (load("res://scenes/run.tscn") as PackedScene).instantiate()
	scene.run_seed = 1234
	root.add_child(scene)
	await process_frame
	# Walk two nodes so visited / current / reachable all show.
	for i in 2:
		scene.run.choose_node(scene.run.map.reachable()[0])
		if scene.run.screen == MapRun.Screen.TABLE:
			scene.run.quick_resolve(true)
			if not scene.run.take_seal(0):
				scene.run.take_seal(-1)
		elif scene.run.screen != MapRun.Screen.MAP:
			scene.run.screen = MapRun.Screen.MAP
			scene.refresh()
	await _shot("map.png")
	scene.run.progress.embers = 10
	scene.run.event = load("res://resources/events/devils_deal.tres")
	scene.run.screen = MapRun.Screen.EVENT
	scene.refresh()
	await _shot("event.png")
	scene.run.progress.embers = 40
	scene.run.progress.add_die(&"mirror")
	scene.run.screen = MapRun.Screen.SHOP
	scene.run._roll_shop()
	scene.refresh()
	await _shot("shop.png")
	scene.run.table_type = MapGenData.NodeType.BOSS
	scene.run.goal = scene.run.make_goal(MapGenData.NodeType.BOSS)
	scene.run.screen = MapRun.Screen.TABLE
	scene.refresh()
	await _shot("boss_table.png")
	# The real Bonfire3D opened from the run: the run's dice with face mods.
	var p := scene.run.progress
	p.set_face(0, 3, &"hellfire")
	p.set_face(1, 5, &"wild")
	p.set_face(2, 1, &"twin")
	p.set_face(3, 0, RunDie.BLANK)
	scene._play_table()
	var t: Bonfire3D = scene._table
	for i in 60:
		await process_frame
	t.rig_slots([4, 6, 2, 1, 4, 3] as Array[int])
	if t.quick_throw():
		await t.sequence_finished
	for i in 30:
		await process_frame
	await _shot("run_table_mods.png")
	scene.queue_free()
	await process_frame
	quit()


func _shot(name: String) -> void:
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_out.path_join(name))
	print("saved ", _out.path_join(name))
