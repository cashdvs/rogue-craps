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


func frame() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img


## Steps the accent with NerveTurnFx.hold/advance so every frame lands at its
## time even when lavapipe renders at ~2 fps (real-time waits missed it all).
func strip(tag: String, die: Node3D, act: Callable) -> void:
	var cam := root.get_camera_3d()
	var fx := s.get_node("NerveTurnFx") as NerveTurnFx
	var out := Image.create(CROP * TIMES.size(), CROP, false, Image.FORMAT_RGBA8)
	fx.hold = true
	act.call()
	await wait(0.5)  # the die's own face tween settles first
	var c := cam.unproject_position(die.global_position)
	var r := Rect2i(Vector2i(c) - Vector2i(CROP / 2, CROP / 2), Vector2i(CROP, CROP))
	var at := 0.0
	for i in TIMES.size():
		fx.advance(TIMES[i] - at)
		at = TIMES[i]
		var img := await frame()
		out.blit_rect(img, r, Vector2i(CROP * i, 0))
		for p in fx.pieces:
		if tag == "up" and i == 2:
			_pips(img, cam, die)
	fx.hold = false
	out.save_png(OUT + "nerve_turn_%s_strip.png" % tag)
	print("saved ", OUT + "nerve_turn_%s_strip.png" % tag)


## Mid-sweep still: the die at 48 px (pip readability) and a 4x nearest view.
func _pips(img: Image, cam: Camera3D, die: Node3D) -> void:
	var e := float(die.get("edge"))
	var a := cam.unproject_position(die.global_position - Vector3(e, 0, e))
	var b := cam.unproject_position(die.global_position + Vector3(e, 0, e))
	var side := int(maxf(absf(b.x - a.x), absf(b.y - a.y)))
	var c := cam.unproject_position(die.global_position + Vector3(0, e * 0.5, 0))
	var crop := img.get_region(Rect2i(Vector2i(c) - Vector2i(side / 2, side / 2), Vector2i(side, side)))
	crop.resize(48, 48, Image.INTERPOLATE_LANCZOS)
	crop.save_png(OUT + "nerve_turn_pips_48px.png")
	crop.resize(192, 192, Image.INTERPOLATE_NEAREST)
	crop.save_png(OUT + "nerve_turn_pips_48px_x4.png")


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
