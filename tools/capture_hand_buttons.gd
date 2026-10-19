## The Bonfire table at the current window size with the dice in the hand,
## to review that THROW / BANK sit clear of the handful (QA full run pass 1,
## M1). Prints each hand die's screen spot and the button rects (canvas px).
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver vulkan \\
##       --resolution 1920x1080 --script res://tools/capture_hand_buttons.gd -- out=/tmp/hand.png
## Try --resolution 844x390 (phone landscape) and 390x844 (phone portrait).
extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "user://hand_buttons.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	var t := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = TableSetup.sandbox(t, 5)
	s.tutorial_override = 0
	root.add_child(s)
	# Let the dice fly back to the hand and the lights settle.
	await create_timer(1.0).timeout
	s.camera.snap_home()
	for i in 6:
		await process_frame
	var spots: Array = []
	for d in s.dice:
		spots.append(s.camera.cam.unproject_position(d.global_position).round())
	print("CAPTURE window %s canvas %s" % [root.get_window().size, root.get_visible_rect().size])
	print("  hand dice at ", spots)
	print("  THROW ", s.bhud.throw_button.get_global_rect(), "  BANK ", s.bhud.bank_button.get_global_rect())
	root.get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()
