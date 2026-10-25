## Capture: Ashmouth taunt puffs, Forward+ strip (frames across the taunt).
## godot --path . --rendering-method forward_plus --rendering-driver vulkan --script res://tools/capture_ashmouth_puffs.gd
extends SceneTree

const SCENE := "res://art/models/characters/bosses/ashmouth/scenes/ashmouth.tscn"
const OUT := "/workspace/dice/captures/ashmouth_puffs"
const TIMES := [0.10, 0.24, 0.36, 0.55, 1.18, 1.26, 1.30, 1.38]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var method := RenderingServer.get_current_rendering_method()
	var driver := RenderingServer.get_current_rendering_driver_name()
	print("RENDERER: method=%s driver=%s" % [method, driver])
	if method != "forward_plus" or driver != "vulkan":
		push_error("not Forward+/Vulkan"); quit(1); return
	var world := Node3D.new()
	root.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#1E3A2A")  # felt-ish
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.48, 0.45)
	var we := WorldEnvironment.new(); we.environment = env; world.add_child(we)
	var key := DirectionalLight3D.new(); key.rotation_degrees = Vector3(-40, 25, 0); world.add_child(key)
	var boss: Node3D = load(SCENE).instantiate()
	var fx := AshmouthPuffFx.new()
	boss.add_child(fx)
	world.add_child(boss)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.1
	world.add_child(cam)
	var aabb_c := Vector3(0, 0.35, 0)
	cam.position = aabb_c + Vector3(0.9, 0.2, 2.8)
	cam.look_at(aabb_c)
	await process_frame
	fx.player.play(&"taunt")
	var frames: Array[Image] = []
	var puffs: Array = []
	fx.puffed.connect(func(k): puffs.append("%s@%.3f" % [k, fx.player.current_animation_position]))
	print("TAUNT LENGTH: ", fx.player.get_animation(&"taunt").length)
	var t := 0.0
	var guard := 0
	for target in TIMES:
		while t < target - 0.001 and fx.player.is_playing() and guard < 2000:
			guard += 1
			await process_frame
			t = fx.player.current_animation_position
		await RenderingServer.frame_post_draw
		var img := root.get_viewport().get_texture().get_image()
		var s := img.get_height()
		img = img.get_region(Rect2i((img.get_width() - s) / 2, 0, s, s))
		frames.append(img)
	print("PUFFS: ", puffs)
	var big := 320
	var strip := Image.create(big * frames.size(), big + 48, false, Image.FORMAT_RGB8)
	for i in frames.size():
		var a: Image = frames[i].duplicate(); a.resize(big, big, Image.INTERPOLATE_LANCZOS)
		strip.blit_rect(a, Rect2i(0, 0, big, big), Vector2i(i * big, 0))
		var b: Image = frames[i].duplicate(); b.resize(48, 48, Image.INTERPOLATE_LANCZOS)
		strip.blit_rect(b, Rect2i(0, 0, 48, 48), Vector2i(i * big, big))
	strip.save_png(OUT + "/ashmouth_puffs_strip.png")
	print("TIMES: ", TIMES)
	print("WROTE ", OUT + "/ashmouth_puffs_strip.png")
	quit(0)
