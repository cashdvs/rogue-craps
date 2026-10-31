## Capture: Hot Hand pulse 48 px strip. Rows: lit (no Hot Hand) | pulse low
## (t=0, 1.0x #E8622A) | pulse peak (t=0.45 s, 1.5x #FFA13A) | reduced motion
## (static 1.25x). Also die0_<low|peak>_<48|96>.png singles (same die) for
## the labelled low-vs-peak pair; columns: three lit bone dice, 48 px each. Refuses to run
## unless the renderer is Vulkan Forward+:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-method forward_plus \\
##       --rendering-driver vulkan --resolution 1280x720 --script res://tools/capture_hot_hand_pulse.gd -- --out=/workspace/dice/captures/hot_hand_pulse/
extends SceneTree

const CROP_PX := 48
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
		push_error("capture_hot_hand_pulse: need Vulkan Forward+, got %s / %s" % [driver, method])
		quit(1)
		return
	print("renderer: ", driver, " ", method)
	var t := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = TableSetup.sandbox(t, 5)
	s.setup.table_seed = 5
	s.tutorial_override = 0
	root.add_child(s)
	await create_timer(0.6).timeout
	for k in 2000:
		if s.phase == Table3D.Phase.BET:
			break
		await process_frame
	await create_timer(0.3).timeout
	s.rig_faces([4, 4, 4, 5, 2] as Array[int])
	s.quick_throw()
	await s.throw_resolved
	await s.sequence_finished
	await create_timer(0.4).timeout
	var fx := s.find_children("*", "HotHandPulseFx", true, false)[0] as HotHandPulseFx
	fx.set_process(false)
	var base: Vector3 = s.throw_dice[0].global_position
	var dice: Array[DieVisual] = []
	for i in 3:
		var d: DieVisual = s.throw_dice[i]
		d.global_position = Vector3(base.x + (i - 1) * 0.13, base.y, base.z)
		d.set_glow_state(true, false, true)
		dice.append(d)
	for i in range(3, s.throw_dice.size()):
		s.throw_dice[i].visible = false
	var rows := ["lit", "low", "peak", "reduced"]
	var strip := Image.create(CROP_PX * 3, CROP_PX * rows.size(), false, Image.FORMAT_RGB8)
	for r in rows.size():
		match rows[r]:
			"lit": fx.stop()
			"low": fx.reduced_motion = false; fx.start(); fx.step(HotHandPulseFx.IGNITE_TIME + HotHandPulseFx.PERIOD * 0.5)
			"peak": fx.step(HotHandPulseFx.PERIOD * 0.5)
			"reduced": fx.reduced_motion = true; fx.start()
		var m := dice[0].hull_outline.material_override as ShaderMaterial
		var sc: Color = (m.get_shader_parameter("color") as Color) * (1.0 + float(m.get_shader_parameter("emission_energy")))
		print("%s: width=%.4f color=%s on_screen=%s emission=%.2f" % [rows[r], m.get_shader_parameter("width"), (m.get_shader_parameter("color") as Color).to_html(false), Color(sc.r, sc.g, sc.b).to_html(false), m.get_shader_parameter("emission_energy")])
		for i in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		if r == 2:
			img.save_png("%shot_hand_pulse_frame_peak.png" % _out)
		var cam := root.get_camera_3d()
		var k := float(img.get_width()) / root.get_visible_rect().size.x
		for i in 3:
			var c := cam.unproject_position(dice[i].global_position) * k
			var e := cam.unproject_position(dice[i].global_position + cam.global_basis.x * 0.06) * k
			var half := int(ceil(c.distance_to(e)))
			var crop := img.get_region(Rect2i(int(c.x) - half, int(c.y) - half, half * 2, half * 2))
			crop.convert(Image.FORMAT_RGB8)
			crop.resize(CROP_PX, CROP_PX, Image.INTERPOLATE_LANCZOS)
			if i == 0 and rows[r] in ["low", "peak"]:
				# Same die, low vs peak: 48 px and 2x (96 px) singles for the labelled pair.
				var big2 := img.get_region(Rect2i(int(c.x) - half, int(c.y) - half, half * 2, half * 2))
				big2.convert(Image.FORMAT_RGB8)
				big2.resize(CROP_PX * 2, CROP_PX * 2, Image.INTERPOLATE_LANCZOS)
				crop.save_png("%sdie0_%s_48.png" % [_out, rows[r]])
				big2.save_png("%sdie0_%s_96.png" % [_out, rows[r]])
			strip.blit_rect(crop, Rect2i(0, 0, CROP_PX, CROP_PX), Vector2i(i * CROP_PX, r * CROP_PX))
	strip.save_png("%shot_hand_pulse_48_strip.png" % _out)
	var big := strip.duplicate() as Image
	big.resize(strip.get_width() * 8, strip.get_height() * 8, Image.INTERPOLATE_NEAREST)
	big.save_png("%shot_hand_pulse_48_strip_x8.png" % _out)
	print("capture_hot_hand_pulse: done")
	quit(0)
