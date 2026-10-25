## Lit-cue gate stills for the HUD playtest fix (art/concept/hud_playtest_fix):
##   <out>lit_families_frame<suffix>.png      the whole frame: wood + obsidian, lit and unlit, side by side, plus frosted glass lit
##   <out>lit_<family>_<lit|unlit>_48px<suffix>.png (+ _x8)  48 px crops of each die
##   <out>lit_families_48px<suffix>.png (+ _x8)  wood lit | wood unlit | obsidian lit | obsidian unlit
##   <out>lit_frosted_glass_48px<suffix>.png (+ _x8)
## Body colours for wood / obsidian / frosted glass are stand-ins (no such
## dice families on main yet). Refuses to run unless the renderer is Vulkan Forward+:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-method forward_plus \\
##       --rendering-driver vulkan --resolution 1280x720 --script res://tools/capture_lit_dice.gd -- --out=/tmp/ --suffix=_v3
extends SceneTree

const LOOKS := {
	"wood": [Color("#9C6B40"), Color("#0E1414")],
	"obsidian": [Color("#1E1B22"), Color("#E8DCC0")],
	"frosted_glass": [Color("#D8E2E2"), Color("#0E1414")],
}
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
	# Line the five dice up across the felt, same height and depth as die 0.
	var plan := [["wood", true], ["wood", false], ["obsidian", true], ["obsidian", false], ["frosted_glass", true]]
	var base: Vector3 = _s.throw_dice[0].global_position
	var dice: Array[DieVisual] = []
	for i in plan.size():
		var d: DieVisual = _s.throw_dice[i]
		var fam: String = plan[i][0]
		d.material = fam
		d.set_look(LOOKS[fam][0], LOOKS[fam][1], d.labels)
		# The four wood / obsidian dice in a row; the glass die one row nearer.
		d.global_position = Vector3(base.x + (i - 1.5) * 0.13, base.y, base.z) if i < 4 else Vector3(base.x, base.y, base.z + 0.16)
		d.set_glow_state(plan[i][1], false, true)
		dice.append(d)
	for i in 8:
		await process_frame
	for i in plan.size():
		if (dice[i].glow_lit > 0.99) != bool(plan[i][1]):
			push_error("capture_lit_dice: die %d lit state wrong" % i)
			quit(1)
			return
	var img := root.get_texture().get_image()
	print("frame: %dx%d" % [img.get_width(), img.get_height()])
	img.save_png("%slit_families_frame%s.png" % [_out, _suffix])
	var cam := root.get_camera_3d()
	var strip := Image.create(CROP_PX * 4, CROP_PX, false, Image.FORMAT_RGB8)
	for i in plan.size():
		var d := dice[i]
		# unproject_position works in the viewport's design space (content scale);
		# convert to the rendered image's pixels.
		var k := float(img.get_width()) / root.get_visible_rect().size.x
		var c := cam.unproject_position(d.global_position) * k
		var e := cam.unproject_position(d.global_position + cam.global_basis.x * 0.06) * k
		var half := int(ceil(c.distance_to(e)))
		var crop := img.get_region(Rect2i(int(c.x) - half, int(c.y) - half, half * 2, half * 2))
		crop.convert(Image.FORMAT_RGB8)
		crop.resize(CROP_PX, CROP_PX, Image.INTERPOLATE_LANCZOS)
		var name := "lit_frosted_glass_48px%s" % _suffix if plan[i][0] == "frosted_glass" else "lit_%s_%s_48px%s" % [plan[i][0], "lit" if plan[i][1] else "unlit", _suffix]
		print("%s: on-screen %d px at %s" % [name, half * 2, c])
		_save_pair(crop, name)
		if i < 4:
			strip.blit_rect(crop, Rect2i(0, 0, CROP_PX, CROP_PX), Vector2i(i * CROP_PX, 0))
	_save_pair(strip, "lit_families_48px%s" % _suffix)
	print("capture_lit_dice: done")
	quit(0)


func _save_pair(im: Image, name: String) -> void:
	im.save_png("%s%s.png" % [_out, name])
	var big := im.duplicate() as Image
	big.resize(im.get_width() * 8, im.get_height() * 8, Image.INTERPOLATE_NEAREST)
	big.save_png("%s%s_x8.png" % [_out, name])
