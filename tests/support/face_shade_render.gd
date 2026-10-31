## Helper for test_bellows_face_shade.gd (not a test itself): really renders a cube with
## bellows_body.tres through toon_noir.gdshader, once as shipped and once with face_shade = 0,
## and prints the mean top / side pixel colours as "FS_RESULT <json>". Needs a real GL renderer,
## so the test launches it with --rendering-driver opengl3 (not --headless).
extends SceneTree

const BODY := "res://art/models/dice/materials/bellows_body.tres"
const SIZE := 96


func _initialize() -> void:
	_run.call_deferred()


func _shot(mat: Material) -> Image:
	var sv := SubViewport.new()
	sv.size = Vector2i(SIZE, SIZE)
	sv.own_world_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color.BLACK
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.6
	sv.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 20, 0)
	sv.add_child(sun)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 2.2
	sv.add_child(cam)
	cam.look_at_from_position(Vector3(0, 2.5, 2.5), Vector3.ZERO)
	var mi := MeshInstance3D.new()
	mi.mesh = BoxMesh.new()
	mi.material_override = mat
	sv.add_child(mi)
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := sv.get_texture().get_image()
	sv.queue_free()
	return img


func _mean(img: Image, cy: int) -> Array:
	var s := Vector3.ZERO
	var n := 0
	for y in range(cy - 6, cy + 7):
		for x in range(SIZE / 2 - 10, SIZE / 2 + 11):
			var c := img.get_pixel(x, y)
			s += Vector3(c.r, c.g, c.b)
			n += 1
	s /= n
	return [s.x, s.y, s.z]


func _run() -> void:
	var shipped := load(BODY) as ShaderMaterial
	var off := shipped.duplicate() as ShaderMaterial
	off.set_shader_parameter("face_shade", 0.0)
	var a: Image = await _shot(shipped)
	var b: Image = await _shot(off)
	# 45-degree ortho view: the top face fills the upper half, the front side face the lower half.
	var out := {
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"top_on": _mean(a, SIZE * 3 / 10), "side_on": _mean(a, SIZE * 7 / 10),
		"top_off": _mean(b, SIZE * 3 / 10), "side_off": _mean(b, SIZE * 7 / 10),
	}
	print("FS_RESULT ", JSON.stringify(out))
	quit()
