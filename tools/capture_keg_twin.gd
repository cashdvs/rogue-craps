## In-game still of a Twin Powder Keg landed on 3, from the table camera
## at rest. The barrel (local +X) is yawed so it runs along the camera's
## frame-up. Writes a 48 px crop and a nearest x4 of the stand-in mask
## (before) and the shipped keg mask (after).
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . \
##       --rendering-driver vulkan --resolution 1920x1080 \
##       --script res://tools/capture_keg_twin.gd -- --out=/tmp/keg_twin/
extends SceneTree

const MASK := "res://art/fx/twin_face/powder_keg_twin_mask.png"
const STANDIN := "res://art/fx/twin_face/twin_face_mask_standin.png"
const CROP := 48

var _out := "user://keg_twin/"
var _frame := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
			if not _out.ends_with("/"):
				_out += "/"
		elif a == "--frame":
			_frame = true
	DirAccess.make_dir_recursive_absolute(_out)
	var td := TableDie.new(&"powder_keg", "Powder Keg", &"d6")
	var printed: Array[int] = [1, 1, 2, 2, 3, 3]
	td.faces = printed
	var mod := load("res://resources/mods/twin.tres") as FaceModData
	td.mods[4] = mod
	td.mods[5] = mod
	var st := TableSetup.new()
	st.dice.append(td)
	st.run_mode = false
	st.table_seed = 3
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = st
	s.tutorial_override = 0
	root.add_child(s)
	for i in 120:
		if s.camera != null and s.phase == Table3D.Phase.BET:
			break
		await process_frame
	s.camera.snap_home()
	if s.hud != null:
		s.hud.visible = false
	var d: DieVisual = s.all_dice[0]
	var tag := d.get_node_or_null("KegValueTag")
	if tag != null:
		tag.free()
	_land_on_three(s, d)
	var glow := d.get_node_or_null("TwinFaceGlow") as TwinFaceGlow
	if glow != null:
		glow.set_settled(true)
	await create_timer(0.25, true, false, true).timeout
	for i in 8:
		await process_frame
	print("shown ", d.shown_value(), " shader ", d.body_material.shader.resource_path)
	d.body_material.set_shader_parameter("twin_mask", load(STANDIN))
	await _shot(s, d, "before_48px")
	d.body_material.set_shader_parameter("twin_mask", load(MASK))
	await _shot(s, d, "after_48px")
	print("capture_keg_twin: wrote ", _out)
	quit(0)


## Rest pose: a 3 stave points up, and the barrel follows frame-up.
func _land_on_three(s: Bonfire3D, d: DieVisual) -> void:
	var dirs: Array = DieHullData.SHAPES[&"keg"]["dirs"]
	var up_local: Vector3 = (dirs[5] as Vector3).normalized()
	var stand := Basis(Quaternion(up_local, Vector3.UP))
	var frame_up := s.camera.cam.global_basis.y
	var flat := Vector3(frame_up.x, 0.0, frame_up.z)
	if flat.length_squared() < 1e-8:
		var fwd := s.camera.cam.global_basis.z
		flat = Vector3(fwd.x, 0.0, fwd.z)
	flat = flat.normalized()
	var barrel := stand * Vector3.RIGHT
	barrel.y = 0.0
	barrel = barrel.normalized()
	var basis := (Basis(Vector3.UP, barrel.signed_angle_to(flat, Vector3.UP)) * stand).orthonormalized()
	d.faces.quaternion = Quaternion.IDENTITY
	d.global_basis = basis
	# Rest camera stays put. Sit the die where that camera looks, on the lit felt.
	var cam := s.camera.cam
	var vp := root.get_visible_rect().size
	var origin := cam.project_ray_origin(vp * 0.5)
	var dir := cam.project_ray_normal(vp * 0.5)
	var hit := Vector3(0.0, 0.0, -0.05)
	if absf(dir.y) > 0.001:
		var t := -origin.y / dir.y
		if t > 0.0:
			hit = origin + dir * t
	d.global_position = Vector3(hit.x, PolyDie.rest_height(&"keg", basis), hit.z)
	var along := (d.global_basis * Vector3.RIGHT).normalized()
	print("barrel dot frame-up flat %.3f  up slot %d" % [along.dot(flat), d.up_slot()])


func _shot(s: Bonfire3D, d: DieVisual, name: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	if name == "after_48px" and _frame:
		img.save_png(_out + "frame.png")
	var cam := s.camera.cam
	var k := float(img.get_width()) / root.get_visible_rect().size.x
	var body := d.faces.get_node("Body") as MeshInstance3D
	var box := body.global_transform * body.mesh.get_aabb()
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	for i in 8:
		var p := cam.unproject_position(box.get_endpoint(i)) * k
		min_p = min_p.min(p)
		max_p = max_p.max(p)
	var side := int(ceil(maxf(max_p.x - min_p.x, max_p.y - min_p.y))) + 8
	var c := (min_p + max_p) * 0.5
	var rect := Rect2i(int(c.x) - side / 2, int(c.y) - side / 2, side, side)
	rect = rect.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	var crop := img.get_region(rect)
	crop.convert(Image.FORMAT_RGBA8)
	crop.resize(CROP, CROP, Image.INTERPOLATE_NEAREST)
	crop.save_png(_out + name + ".png")
	var big := crop.duplicate() as Image
	big.resize(CROP * 4, CROP * 4, Image.INTERPOLATE_NEAREST)
	big.save_png(_out + name + "_x4.png")
	print("saved ", name, " crop ", rect.size, " shown ", d.shown_value())
