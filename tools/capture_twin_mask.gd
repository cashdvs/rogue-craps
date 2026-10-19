## Capture strip for the Twin Face glow mask: rolling dark / 3-up landed lit /
## other-face-up dark. Default uses the stand-in mask. Pass --final to load
## 3D Artist's local final mask + faces from twin_mark_mock/final/ (not in repo)
## and write twin_mask_strip_final.png.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver vulkan \\
##       --resolution 960x320 --script res://tools/capture_twin_mask.gd -- \\
##       --out=/workspace/dice/captures/twin_mask/ [--final]
extends SceneTree

const FINAL_DIR := "/workspace/dice/art/source/twin_mark_mock/final/"
const FINAL_MASK := FINAL_DIR + "powder_keg_twin_mask.png"
const FINAL_FACES := FINAL_DIR + "powder_keg_faces.png"

var OUT := "user://captures_twin_mask/"
var USE_FINAL := false
var _mask_tex: Texture2D
var _faces_tex: Texture2D

func _initialize() -> void:
	_run.call_deferred()

func wait(t: float) -> void:
	await create_timer(t, true, false, true).timeout

func shot(path: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(path)
	print("saved ", path)

func _load_file_tex(path: String) -> Texture2D:
	var img := Image.load_from_file(path)
	if img == null:
		push_error("failed to load " + path)
		return null
	return ImageTexture.create_from_image(img)

func _make_face(mat: ShaderMaterial, world_n: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var u0 := 2.0 / 5.0
	var u1 := 3.0 / 5.0
	var v0 := 0.0
	var v1 := 1.0 / 5.0
	var h := 0.06
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
	mi.material_override = mat
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
	mat.set_shader_parameter("twin_mask", _mask_tex)
	mat.set_shader_parameter("twin_glow", Palette.EMBER)
	mat.set_shader_parameter("twin_strength", 1.6)
	mat.set_shader_parameter("twin_halo_strength", 1.6)
	mat.set_shader_parameter("twin_unlit", Color("#403440"))
	mat.set_shader_parameter("settled", settled)
	mat.set_shader_parameter("up_lo", 0.80)
	mat.set_shader_parameter("up_hi", 0.92)
	if USE_FINAL and _faces_tex != null:
		mat.set_shader_parameter("use_overlay", true)
		mat.set_shader_parameter("overlay_tex", _faces_tex)
		mat.set_shader_parameter("overlay_tint", Color(1, 1, 1, 1))
	var root3 := Node3D.new()
	root3.position = Vector3(x, 0, 0)
	root3.add_child(_make_face(mat, world_n))
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
		elif a == "--final":
			USE_FINAL = true
	DirAccess.make_dir_recursive_absolute(OUT)
	if USE_FINAL:
		_mask_tex = _load_file_tex(FINAL_MASK)
		_faces_tex = _load_file_tex(FINAL_FACES)
		if _mask_tex == null or _faces_tex == null:
			quit(1)
			return
		print("using FINAL mask+faces from ", FINAL_DIR)
	else:
		_mask_tex = load("res://art/fx/twin_face/twin_face_mask_standin.png") as Texture2D
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
	e.glow_hdr_threshold = 1.0
	env.environment = e
	world.add_child(env)
	world.add_child(_panel("rolling", 0.0, Vector3.UP, -0.16))
	world.add_child(_panel("landed", 1.0, Vector3.UP, 0.0))
	world.add_child(_panel("other", 1.0, Vector3(0.0, 0.35, 1.0).normalized(), 0.16))
	await wait(0.35)
	var name := "twin_mask_strip_final.png" if USE_FINAL else "twin_mask_strip.png"
	await shot(OUT + name)
	print("labels: rolling(settled=0,3-up,dark) | landed(settled=1,3-up,Ember) | other(settled=1,side,dark)")
	quit()
