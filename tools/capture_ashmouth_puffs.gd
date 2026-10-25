## Capture: Ashmouth taunt puffs v2 in the game_phone framing (render_ashmouth
## view=game: Bonfire3D camera on the Hearth board, dealer at DEALER_POS,
## CapturePhone phone=844x390). Needs the Ashmouth assets (art/boss-dealers).
## xvfb-run -a godot --path . --rendering-method forward_plus --rendering-driver vulkan --resolution 1920x1080 --script res://tools/capture_ashmouth_puffs.gd -- phone=844x390
extends SceneTree

const SCENE := "res://art/models/characters/bosses/ashmouth/scenes/ashmouth%s.tscn"
const HEARTH := "res://art/models/boards/hearth/scenes/hearth_board%s.tscn"
const DEALER_POS := Vector3(-0.42, -0.47, -0.86)
const OUT := "/workspace/dice/captures/ashmouth_puffs/ashmouth_puffs_strip_v3.png"
const TIMES := [0.10, 0.24, 0.36, 0.55, 1.18, 1.26, 1.32, 1.38]
const CROP := 0.8  # m around the dealer for the zoom row

var _phone := CapturePhone.new()

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var method := RenderingServer.get_current_rendering_method()
	var driver := RenderingServer.get_current_rendering_driver_name()
	print("RENDERER: method=%s driver=%s" % [method, driver])
	if method != "forward_plus" or driver != "vulkan":
		push_error("not Forward+/Vulkan"); quit(1); return
	_phone.parse_args()
	var t := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = TableSetup.sandbox(t, 5)
	s.tutorial_override = 0
	_phone.add_table(root, s)
	await process_frame
	await process_frame
	var tbl := s.find_child("Table", true, false)
	if tbl != null:
		for c in tbl.get_children():
			if c is MeshInstance3D and c.name != "WallBack":
				(c as MeshInstance3D).visible = false
	var lod := "_mobile" if _phone.screen != Vector2.ZERO else ""
	s.add_child((load(HEARTH % lod) as PackedScene).instantiate())
	var b := (load(SCENE % lod) as PackedScene).instantiate() as Node3D
	b.position = DEALER_POS
	var fx := AshmouthPuffFx.new()
	b.add_child(fx)
	s.add_child(b)
	_phone.frame(s)
	s.camera.snap_home()
	for i in 8:
		await process_frame
	var cam := s.camera.cam
	if OS.get_cmdline_user_args().has("probe=1"):
		for m in s.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			if mi.visible and mi.is_visible_in_tree():
				var ab := mi.global_transform * mi.get_aabb()
				if ab.end.y > -0.6 and absf(ab.get_center().z + 0.8) < 0.6:
					print("MESH ", s.get_path_to(mi), " ", ab)
		print("DOOR ", (b.get_node(AshmouthPuffFx.DOOR_SOCKET) as Node3D).global_position, " PIPE ", (b.get_node(AshmouthPuffFx.PIPE_SOCKET) as Node3D).global_position)
		print("CAM ", cam.global_position, " vp ", cam.get_viewport().get_visible_rect().size)
		quit(0)
		return
	var puffs: Array = []
	var bursts: Array = []
	fx.burst_spawned.connect(func(k, n): bursts.append(n); puffs.append("%s@%.3f->%s y=%.3f k=%.2f" % [k, fx.player.current_animation_position, n.get_parent().name, n.global_position.y, float(n.get_meta("soot_k", 1.0))]))
	fx.player.play(&"taunt")
	var frames: Array[Image] = []
	var tt := 0.0
	var guard := 0
	for target in TIMES:
		while tt < target - 0.001 and fx.player.is_playing() and guard < 4000:
			guard += 1
			await process_frame
			tt = fx.player.current_animation_position
		# Freeze the dealer and bursts, grab with and without the puffs: the diff is the puff.
		paused = true  # freezes the clip, the particles and the bursts' free timers
		var live: Array = bursts.filter(func(n): return is_instance_valid(n))
		await RenderingServer.frame_post_draw
		await process_frame
		await RenderingServer.frame_post_draw
		var img := _phone.image(root)
		for n in live:
			n.visible = false
		await process_frame
		await RenderingServer.frame_post_draw
		var bare := _phone.image(root)
		for n in live:
			n.visible = true
		var tag := "%02d_t%.2f" % [frames.size(), target]
		img.save_png(OUT.get_base_dir() + "/v3_full/" + tag + ".png")
		bare.save_png(OUT.get_base_dir() + "/v3_full/" + tag + "_nofx.png")
		paused = false
		var vs := cam.get_viewport().get_visible_rect().size
		var sc := float(img.get_width()) / vs.x
		var c := cam.unproject_position(b.global_position + Vector3(0, 0.62, 0)) * sc
		var e := cam.unproject_position(b.global_position + Vector3(CROP * 0.5, 0.62, 0)) * sc
		var half := int(absf(e.x - c.x))
		half = mini(half, img.get_height() / 2)
		var x0 := clampi(int(c.x) - half, 0, img.get_width() - half * 2)
		var y0 := clampi(int(c.y) - half, 0, img.get_height() - half * 2)
		var r := Rect2i(x0, y0, half * 2, half * 2)
		frames.append(img.get_region(r))
	var rail := cam.unproject_position(Vector3(DEALER_POS.x, fx.rail_top_y(), -0.505)) * (_phone.screen.y * 2.0 / cam.get_viewport().get_visible_rect().size.y)
	print("RAIL_LIP_IMG_Y: %.1f (image px, %dx%d)" % [rail.y, int(_phone.screen.x * 2), int(_phone.screen.y * 2)])
	print("PUFFS: ", puffs, " TIMES: ", TIMES, " crop px: ", frames[0].get_size())
	var big := 240
	var strip := Image.create(big * frames.size(), big + 52, false, Image.FORMAT_RGB8)
	strip.fill(Color(0.08, 0.08, 0.08))
	for i in frames.size():
		var a: Image = frames[i].duplicate(); a.resize(big, big, Image.INTERPOLATE_LANCZOS)
		strip.blit_rect(a, Rect2i(0, 0, big, big), Vector2i(i * big, 0))
		var m: Image = frames[i].duplicate(); m.resize(48, 48, Image.INTERPOLATE_LANCZOS)
		strip.blit_rect(m, Rect2i(0, 0, 48, 48), Vector2i(i * big + (big - 48) / 2, big + 2))
	strip.save_png(OUT)
	print("WROTE ", OUT)
	quit(0)
