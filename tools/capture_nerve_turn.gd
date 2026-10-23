## Frame strip of the Nerve "die turns" accent (NerveTurnFx): crops around
## the nudged die at a few times after die_nudged, side by side, for UP and
## the undo (DOWN). Needs a display + Vulkan (lavapipe under xvfb works):
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-method forward_plus \\
##       --rendering-driver vulkan --resolution 1920x1080 --script res://tools/capture_nerve_turn.gd -- --out=/tmp/nerve/
extends SceneTree

const TIMES: Array[float] = [0.0, 0.03, 0.07, 0.11, 0.16, 0.22, 0.3]
const CROP := 360
var OUT := "user://captures_nerve_turn/"
var s: Bonfire3D


func _initialize() -> void:
	_run.call_deferred()


func wait(t: float) -> void:
	await create_timer(t, true, false, true).timeout


func strip(tag: String, die: Node3D, act: Callable) -> void:
	var cam := root.get_camera_3d()
	var c := cam.unproject_position(die.global_position)
	var out := Image.create(CROP * TIMES.size(), CROP, false, Image.FORMAT_RGBA8)
	var t0 := Time.get_ticks_msec()
	act.call()
	for i in TIMES.size():
		while (Time.get_ticks_msec() - t0) / 1000.0 < TIMES[i]:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		var r := Rect2i(Vector2i(c) - Vector2i(CROP / 2, CROP / 2), Vector2i(CROP, CROP))
		out.blit_rect(img, r, Vector2i(CROP * i, 0))
	out.save_png(OUT + "nerve_turn_%s_strip.png" % tag)
	print("saved ", OUT + "nerve_turn_%s_strip.png" % tag)


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			OUT = a.trim_prefix("--out=").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(OUT)
	s = (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.bonfire_seed = 21
	s.tutorial_override = 0
	root.add_child(s)
	await wait(1.0)
	while s.phase != Table3D.Phase.BET:
		await process_frame
	await wait(0.35)
	s.rig_faces([3, 3, 3, 2, 6] as Array[int])
	if s.quick_throw():
		await s.sequence_finished
	await wait(0.8)
	var die := s.throw_dice[3]
	await strip("up", die, func() -> void: s.nerve.nudge(3, NerveState.UP))
	await wait(0.8)
	await strip("down_undo", die, func() -> void: s.nerve.undo(3))
	print("done")
	quit()
