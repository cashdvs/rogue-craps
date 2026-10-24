extends SceneTree
## Pit Boss blockout renders (Forward+ / Vulkan only; the renderer is printed so every log proves it).
##   xvfb-run -a godot --path . --rendering-driver vulkan --resolution 1200x1200 --script res://.../render_ashmouth.gd -- view=front|side|sil [out=<png>] [lod=_mobile]
##   xvfb-run -a godot --path . --rendering-driver vulkan --resolution 1920x1080 --script res://.../render_ashmouth.gd -- view=game [phone=844x390] [out=<png>]
## studio: grey cyclorama, one key + fill, idle @0. sil: flat black on white at 48 px tall (+ an 8x nearest blow-up).
## game: the real Bonfire3D camera on the Hearth board, the dealer at DEALER_POS; prints mean felt luma.
const SCN := "res://art/models/characters/bosses/ashmouth/scenes/ashmouth%s.tscn"
const HEARTH := "res://art/models/boards/hearth/scenes/hearth_board%s.tscn"
const DEALER_POS := Vector3(-0.42, -0.47, -0.86)
var _phone := CapturePhone.new()


func _initialize() -> void:
	_run.call_deferred()


func _arg(k: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


func _run() -> void:
	print("RENDERER %s | driver %s | adapter %s" % [ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		RenderingServer.get_current_rendering_driver_name(), RenderingServer.get_video_adapter_name()])
	var view := _arg("view", "front")
	var out := _arg("out", "/tmp/ashmouth_%s.png" % view)
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	if view == "game":
		await _game(out)
	else:
		await _studio(view, out, _arg("lod", ""))
	quit()


func _boss(lod: String) -> Node3D:
	var b := (load(SCN % lod) as PackedScene).instantiate() as Node3D
	return b


func _pose(b: Node3D) -> void:
	var ap := b.find_child("AnimationPlayer", true, false) as AnimationPlayer
	ap.play(_arg("clip", "idle"))
	ap.seek(float(_arg("t", "0")), true)
	ap.pause()


func _studio(view: String, out: String, lod: String) -> void:
	var sil := view == "sil"
	var vp := SubViewport.new()
	vp.size = Vector2i(48, 48) if sil else Vector2i(1200, 1200)
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(1, 1, 1) if sil else Color(0.16, 0.16, 0.17)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.35, 0.37)
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var b := _boss(lod)
	vp.add_child(b)
	await process_frame
	_pose(b)
	if sil:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color.BLACK
		for mi: MeshInstance3D in b.find_children("*", "MeshInstance3D", true, false):
			mi.material_override = m
	else:
		var key := DirectionalLight3D.new()
		key.rotation_degrees = Vector3(-35, 30 if view == "front" else 60, 0)
		key.light_energy = 1.2
		key.shadow_enabled = true
		vp.add_child(key)
		var fill := DirectionalLight3D.new()
		fill.rotation_degrees = Vector3(-10, -120, 0)
		fill.light_energy = 0.35
		vp.add_child(fill)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.05  # waist-down to cap: trousers stub z -0.22 .. cap 0.74 (glTF y)
	var ctr := Vector3(0, 0.26, 0)
	cam.position = ctr + (Vector3(0, 0, 3) if view != "side" else Vector3(3, 0, 0))
	vp.add_child(cam)
	cam.look_at(ctr)
	cam.current = true
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.save_png(out)
	if sil:
		# 48 px silhouette: also an 8x nearest blow-up for review, and the filled height in px
		var top := 48
		var bot := -1
		for y in 48:
			for x in 48:
				if img.get_pixel(x, y).v < 0.5:
					top = mini(top, y)
					bot = maxi(bot, y)
		print("SIL filled rows %d..%d = %d px tall in a 48 px frame" % [top, bot, bot - top + 1])
		var big := img.duplicate() as Image
		big.resize(384, 384, Image.INTERPOLATE_NEAREST)
		big.save_png(out.get_basename() + "_x8.png")
	print("WROTE %s" % out)


func _game(out: String) -> void:
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
	var mob := _phone.screen != Vector2.ZERO
	var lod := "_mobile" if mob else ""
	var board := (load(HEARTH % lod) as PackedScene).instantiate() as Node3D
	s.add_child(board)
	var b := _boss(lod)
	b.position = DEALER_POS
	if _arg("noboss", "0") != "1":  # noboss=1: same frame without the dealer (felt baseline)
		s.add_child(b)
	await create_timer(0.3).timeout
	if b.is_inside_tree():
		_pose(b)
	_phone.frame(s)
	s.camera.snap_home()
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var cam := s.camera.cam
	var img := _phone.image(root)
	img.save_png(out)
	# felt luma: mean Rec.709 luma (sRGB, 0..1) over felt sample points around the play area
	var vs := cam.get_viewport().get_visible_rect().size
	var sc := Vector2(img.get_width(), img.get_height()) / vs
	var sum := 0.0
	var n := 0
	for fx in [-0.5, -0.25, 0.0, 0.25, 0.5]:
		for fz in [-0.4, -0.2, 0.0, 0.2]:
			var sp := cam.unproject_position(Vector3(fx, 0.0, fz)) * sc
			if sp.x < 0 or sp.y < 0 or sp.x >= img.get_width() or sp.y >= img.get_height():
				continue
			var c := img.get_pixelv(Vector2i(sp))
			sum += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			n += 1
	print("GAME %s vp %s | felt luma mean %.1f%% over %d samples (>= 30%%)" % ["phone" if mob else "pc", vs, 100.0 * sum / maxf(n, 1), n])
	print("WROTE %s" % out)
