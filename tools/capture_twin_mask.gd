## Capture strip for the Twin Face glow mask: rolling dark / 3-up landed lit /
## other-face-up dark. Uses the stand-in mask and a UV-mapped quad (batch-3
## keg mesh lands in 3D Artist's follow-up).
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver vulkan \\
##       --resolution 960x320 --script res://tools/capture_twin_mask.gd -- \\
##       --out=/workspace/dice/captures/twin_mask/
extends SceneTree

var OUT := "user://captures_twin_mask/"

func _initialize() -> void:
	_run.call_deferred()

func wait(t: float) -> void:
	await create_timer(t, true, false, true).timeout

func shot(path: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(path)
	print("saved ", path)

func _make_face(mat: ShaderMaterial, world_n: Vector3) -> MeshInstance3D:
	# Quad in XY facing +Z in local space; we rotate so its normal becomes world_n.
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.12)
	mi.mesh = q
	mi.material_override = mat
	# Map UV to cell 2 (value 3) of a 5x5 atlas: u 0.4..0.6, v 0..0.2
	# QuadMesh uses full 0..1 UV — we bake cell UVs via a custom ArrayMesh instead.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var u0 := 2.0 / 5.0
	var u1 := 3.0 / 5.0
	var v0 := 0.0
	var v1 := 1.0 / 5.0
	var h := 0.06
	# Quad facing +Y (up) in local space so BASIS can aim it.
	var n := Vector3.UP
	var verts = [
		Vector3(-h, 0, -h), Vector3(h, 0, -h), Vector3(h, 0, h), Vector3(-h, 0, h),
	]
	var uvs = [Vector2(u0, v1), Vector2(u1, v1), Vector2(u1, v0), Vector2(u0, v0)]
	for idx in [[0, 1, 2], [0, 2, 3]]:
		for i in idx:
			st.set_normal(n)
			st.set_uv(uvs[i])
			st.add_vertex(verts[i])
	mi.mesh = st.commit()
	# Rotate local +Y to world_n.
	mi.basis = _basis_from_up(world_n)
	return mi


func _basis_from_up(up: Vector3) -> Basis:
	up = up.normalized()
	if up.is_equal_approx(Vector3.UP):
		return Basis.IDENTITY
	if up.is_equal_approx(Vector3.DOWN):
		return Basis(Vector3.RIGHT, PI)
	var axis := Vector3.UP.cross(up).normalized()
	return Basis(axis, Vector3.UP.angle_to(up))


func _panel(label: String, settled: float, world_n: Vector3, x: float) -> Node3D:
	var sh := load("res://shaders/3d/toon_noir_twin.gdshader") as Shader
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("albedo", Color("#C9C14D"))
	mat.set_shader_parameter("light_gain", 0.35)
	mat.set_shader_parameter("wrap", 0.3)
	mat.set_shader_parameter("twin_mask", load("res://art/fx/twin_face/twin_face_mask_standin.png"))
	mat.set_shader_parameter("twin_glow", Palette.EMBER)
	mat.set_shader_parameter("twin_strength", 1.35)
	mat.set_shader_parameter("twin_unlit", Color("#6A2E1C"))
	mat.set_shader_parameter("settled", settled)
	mat.set_shader_parameter("up_threshold", 0.92)
	var root3 := Node3D.new()
	root3.position = Vector3(x, 0, 0)
	var face := _make_face(mat, world_n)
	root3.add_child(face)
	# Tiny label card as unshaded text substitute: coloured bar under the face.
	var bar := MeshInstance3D.new()
	var bq := QuadMesh.new()
	bq.size = Vector2(0.11, 0.02)
	bar.mesh = bq
	bar.position = Vector3(0, -0.02, 0.08)
	bar.rotation_degrees.x = -60
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.albedo_color = Palette.EMBER if settled > 0.5 and world_n.y > 0.5 else Color("#3A3028")
	bar.material_override = bm
	root3.add_child(bar)
	root3.set_meta("label", label)
	return root3

func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			OUT = a.trim_prefix("--out=").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(OUT)
	var world := Node3D.new()
	root.add_child(world)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0.22, 0.28)
	cam.fov = 35
	world.add_child(cam)
	cam.look_at(Vector3(0, 0.02, 0), Vector3.UP)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0.1, 0.35, 0.2)
	lamp.light_color = Color("#FFB070")
	lamp.light_energy = 2.2
	lamp.omni_range = 2.0
	world.add_child(lamp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#0B1A14")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#1A080C")
	e.ambient_light_energy = 0.3
	e.glow_enabled = true
	e.glow_intensity = 0.6
	env.environment = e
	world.add_child(env)
	# Three panels.
	world.add_child(_panel("rolling", 0.0, Vector3.UP, -0.16))
	world.add_child(_panel("landed", 1.0, Vector3.UP, 0.0))
	# Tilted toward camera but well below up_threshold → settled yet dark.
	world.add_child(_panel("other", 1.0, Vector3(0.0, 0.35, 1.0).normalized(), 0.16))
	await wait(0.35)
	await shot(OUT + "twin_mask_strip.png")
	# Also save singles for QA.
	await shot(OUT + "twin_mask_strip_native.png")
	print("labels: rolling(settled=0,3-up,dark) | landed(settled=1,3-up,Ember) | other(settled=1,side,dark)")
	quit()
