## Playtest-fix gate stills: 48 px crops of a lit bone die and a lit pale
## frosted-glass die (thin ember rim, dark-ink pips), plus x8 views and the
## full frame. Refuses to run unless the renderer is Vulkan Forward+.
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-method forward_plus \\
##       --rendering-driver vulkan --resolution 1920x1080 --script res://tools/capture_lit_dice.gd -- --out=/tmp/
extends SceneTree

## Stand-in pale frosted glass body (no glass die family on main yet).
const FROSTED_GLASS := Color("#D8E2E2")
const CROP_PX := 48

var _out := "user://"
var _suffix := ""
var _s: Bonfire3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--suffix="):
			_suffix = a.substr(9)
	var method := RenderingServer.get_current_rendering_method()
	var driver := RenderingServer.get_current_rendering_driver_name()
	if method != "forward_plus" or driver != "vulkan":
		push_error("capture_lit_dice: need Vulkan Forward+, got %s / %s" % [driver, method])
		quit(1)
		return
	print("renderer: ", driver, " ", method)
	var t := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	_s = (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	_s.setup = TableSetup.sandbox(t, 5)
	_s.setup.table_seed = 5
	_s.tutorial_override = 0
	root.add_child(_s)
	await create_timer(0.6).timeout
	for k in 2000:
		if _s.phase == Table3D.Phase.BET:
			break
		await process_frame
	await create_timer(0.3).timeout
	_s.rig_faces([4, 4, 4, 5, 2] as Array[int])
	_s.quick_throw()
	await _s.throw_resolved
	await _s.sequence_finished
	await create_timer(0.4).timeout
	var bone: DieVisual = _s.throw_dice[0]
	var glass: DieVisual = _s.throw_dice[1]
	glass.material = "frosted_glass"
	glass.set_look(FROSTED_GLASS, Palette.PIT_BLACK, glass.labels)
	glass.set_glow_state(true, false, true)
	bone.set_glow_state(true, false, true)
	if not (_s.is_lit(bone) and _s.is_lit(glass)):
		push_error("capture_lit_dice: dice not lit")
		quit(1)
		return
	for i in 6:
		await process_frame
	var img := root.get_texture().get_image()
	img.save_png(_out + "lit_dice_full.png")
	var cam := root.get_camera_3d()
	for pair in [["bone", bone], ["frosted_glass", glass]]:
		var d: DieVisual = pair[1]
		var c := cam.unproject_position(d.global_position)
		var e := cam.unproject_position(d.global_position + cam.global_basis.x * 0.06)
		var half := int(ceil(c.distance_to(e)))
		var crop := img.get_region(Rect2i(int(c.x) - half, int(c.y) - half, half * 2, half * 2))
		print("%s: on-screen crop %d px" % [pair[0], half * 2])
		crop.resize(CROP_PX, CROP_PX, Image.INTERPOLATE_LANCZOS)
		crop.save_png("%slit_%s_48px%s.png" % [_out, pair[0], _suffix])
		var big := crop.duplicate() as Image
		big.resize(CROP_PX * 8, CROP_PX * 8, Image.INTERPOLATE_NEAREST)
		big.save_png("%slit_%s_48px%s_x8.png" % [_out, pair[0], _suffix])
	print("capture_lit_dice: done")
	quit(0)
