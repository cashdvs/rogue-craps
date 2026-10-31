## Capture: GoalFx states on the real Bonfire HUD target plate, 1280x720
## (the size where a die reads at 48 px). Writes goal_v2_<idle|reached|missed>.png
## crops (plate plus the Soul tag area); the labelled strip is assembled
## outside Godot. Refuses to run unless the renderer is Vulkan Forward+:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-method forward_plus \\
##       --rendering-driver vulkan --resolution 1280x720 --script res://tools/capture_goal_fx.gd -- --out=/workspace/dice/captures/goal_fx/
extends SceneTree

var _out := "user://"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	var method := RenderingServer.get_current_rendering_method()
	var driver := RenderingServer.get_current_rendering_driver_name()
	if method != "forward_plus" or driver != "vulkan":
		push_error("capture_goal_fx: need Vulkan Forward+, got %s / %s" % [driver, method])
		quit(1)
		return
	print("renderer: ", driver, " ", method)
	var t := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = TableSetup.sandbox(t, 5)
	s.setup.table_seed = 5
	s.tutorial_override = 0
	root.add_child(s)
	await create_timer(0.8).timeout
	var fx := s.find_children("*", "GoalFx", true, false)[0] as GoalFx
	fx.hold = true
	var plate := fx.find_plate()
	plate.visible = true
	# Real reached state: banked at/over target, so line 3 reads PASSED.
	var gi := TableGoalState.new()
	gi.set_for_test(350, 220, 2)
	plate.bind(gi)
	await create_timer(0.3).timeout
	var xf := root.get_final_transform() * plate.get_global_transform_with_canvas()
	var pr := xf * Rect2(Vector2.ZERO, plate.size)
	pr.size.y += 70.0 * xf.get_scale().y
	var r := Rect2i(pr.grow(8)).intersection(Rect2i(Vector2i.ZERO, root.get_texture().get_size()))
	print("plate rect ", r)
	await _grab(r, "idle")
	# Real reached state: banked at/over target, so line 3 reads PASSED.
	var g := TableGoalState.new()
	g.set_for_test(350, 380, 2)
	plate.bind(g)
	print("reached line3: ", plate.line3.text, " ", plate.line3_extra.text)
	s.events.goal_reached.emit()
	await _grab(r, "reached")
	fx.clear()
	var gm := TableGoalState.new()
	gm.set_for_test(350, 180, 0)
	plate.bind(gm)
	s.events.goal_missed.emit(5)
	fx.advance(GoalFx.DIM_TIME)
	await _grab(r, "missed")
	print("missed tag: ", (fx.soul_tag.get_child(0) as Label).text, " ", (fx.soul_tag.get_child(1) as Label).text)
	quit(0)


func _grab(r: Rect2i, label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image().get_region(r)
	img.save_png(_out.path_join("goal_v2_%s.png" % label))
	if label == "missed":
		root.get_texture().get_image().save_png(_out.path_join("goal_v2_full_missed.png"))
	print("saved ", label)
