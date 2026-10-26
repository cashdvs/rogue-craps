## Frame strip of the Nerve "spent" cue (NerveSpentFx): crops around the die
## at a few times after the cue, for normal and reduced motion. Until #143
## lands there's no table.events.nerve_spent, so this calls the handler
## directly after a real nudge. Needs Forward+/Vulkan (lavapipe under xvfb):
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-method forward_plus \\
##       --rendering-driver vulkan --resolution 1920x1080 --script res://tools/capture_nerve_spent.gd -- --out=/tmp/spent/
extends SceneTree

const TIMES: Array[float] = [0.0, 0.04, 0.09, 0.15, 0.21, 0.27]
const CROP := 360
var OUT := "user://captures_nerve_spent/"
var s: Bonfire3D


func _initialize() -> void:
	var method := RenderingServer.get_current_rendering_method()
	var driver := RenderingServer.get_current_rendering_driver_name()
	if method != "forward_plus" or driver != "vulkan":
		push_error("capture_nerve_spent: need Forward+/Vulkan, got %s/%s (GL fallback?)" % [method, driver])
		quit(1)
		return
	_run.call_deferred()


func wait(t: float) -> void:
	await create_timer(t, true, false, true).timeout


func frame() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img


func strip(tag: String, die: Node3D) -> void:
	var cam := root.get_camera_3d()
	var fx := s.get_node("NerveSpentFx") as NerveSpentFx
	var out := Image.create(CROP * TIMES.size(), CROP, false, Image.FORMAT_RGBA8)
	fx.hold = true
	fx._on_nerve_spent(s.event_id(die), 3, 4)
	var c := cam.unproject_position(die.global_position)
	var r := Rect2i(Vector2i(c) - Vector2i(CROP / 2, CROP / 2), Vector2i(CROP, CROP))
	var at := 0.0
	for i in TIMES.size():
		fx.advance(TIMES[i] - at)
		at = TIMES[i]
		out.blit_rect(await frame(), r, Vector2i(CROP * i, 0))
	fx.hold = false
	fx.clear()
	out.save_png(OUT + "nerve_spent_%s_strip.png" % tag)
	print("saved ", OUT + "nerve_spent_%s_strip.png" % tag)


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
	s.rig_faces([3, 3, 3, 3, 6] as Array[int])
	if s.quick_throw():
		await s.sequence_finished
	await wait(0.8)
	var die := s.throw_dice[3]
	s.nerve.nudge(3, NerveState.UP)
	await wait(0.8)
	await strip("normal", die)
	s.set_reduced_motion(true)
	await strip("reduced", die)
	print("done")
	quit()
