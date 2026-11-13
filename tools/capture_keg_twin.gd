## Side-by-side still of a Powder Keg landed on 3, same pipeline as the
## stave-numeral shots (PR #267): Bonfire table, Vulkan Forward+, the rest
## camera, reduced motion (brighter dice). The barrel lies along world X
## (horizontal in frame). Left to right: plain keg, Twin with the stand-in
## mask, Twin with the shipped keg mask.
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
	var st := TableSetup.new()
	st.dice.append(_keg(false))
	st.dice.append(_keg(true))
	st.dice.append(_keg(true))
	st.run_mode = false
	st.table_seed = 3
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = st
	s.tutorial_override = 0
	root.add_child(s)
	for i in 180:
		if s.camera != null and s.phase == Table3D.Phase.BET:
			break
		await process_frame
	s.camera.snap_home()
	s.set_reduced_motion(true)
	var dice: Array[DieVisual] = [s.all_dice[0], s.all_dice[1], s.all_dice[2]]
	dice[1].body_material.set_shader_parameter("twin_mask", load(STANDIN))
	var cam := s.camera.cam
	# Lamp pool, just this side of centre: the #267 numeral row. World +Z is
	# the near rail. Spacing keeps the barrels from touching.
	var spots: Array[Vector3] = [Vector3(-0.34, 0, 0.22), Vector3(0, 0, 0.22), Vector3(0.34, 0, 0.22)]
	for i in dice.size():
		var tag := dice[i].get_node_or_null("KegValueTag")
		if tag != null:
			tag.free()
		_pose(dice[i], spots[i])
		var screen := cam.unproject_position(dice[i].global_position)
		print("die %d at %s screen %s" % [i, dice[i].global_position, screen])
		var glow := dice[i].get_node_or_null("TwinFaceGlow") as TwinFaceGlow
		if glow != null:
			glow.set_settled(false)
	for tw in get_processed_tweens():
		tw.kill()
	for i in dice.size():
		_pose(dice[i], spots[i])
	s.camera.cam.current = true
	for i in 4:
		await process_frame
	if _frame:
		root.get_texture().get_image().save_png(_out + "frame.png")
	var crops: Array[Image] = []
	for i in dice.size():
		crops.append(_crop(cam, dice[i]))
		print("die %d shown %d shader %s" % [i, dice[i].shown_value(), dice[i].body_material.shader.resource_path.get_file()])
	_strip(crops, "strip_48px")
	print("capture_keg_twin: wrote ", _out)
	quit(0)


func _keg(carved: bool) -> TableDie:
	var td := TableDie.new(&"powder_keg", "Powder Keg", &"d6")
	var printed: Array[int] = [1, 1, 2, 2, 3, 3]
	td.faces = printed
	if carved:
		var mod := load("res://resources/mods/twin.tres") as FaceModData
		td.mods[4] = mod
		td.mods[5] = mod
	return td


## Barrel along world X, a 3 stave up, tipped a little toward the camera
## so that stave stays the read face and still fills the view.
func _pose(d: DieVisual, at: Vector3) -> void:
	var dirs: Array = DieHullData.SHAPES[&"keg"]["dirs"]
	var up_local: Vector3 = (dirs[5] as Vector3).normalized()
	var stand := Basis(Quaternion(up_local, Vector3.UP))
	var basis := Basis(Vector3.RIGHT, deg_to_rad(20.0)) * stand
	d.faces.quaternion = Quaternion.IDENTITY
	d.global_basis = basis
	d.global_position = Vector3(at.x, PolyDie.rest_height(&"keg", basis), at.z)


func _crop(cam: Camera3D, d: DieVisual) -> Image:
	var img := root.get_texture().get_image()
	var k := float(img.get_width()) / root.get_visible_rect().size.x
	var body := d.faces.get_node("Body") as MeshInstance3D
	var box: AABB = body.global_transform * body.mesh.get_aabb()
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	for i in 8:
		var p := cam.unproject_position(box.get_endpoint(i)) * k
		min_p = min_p.min(p)
		max_p = max_p.max(p)
	var pad := 4
	var rect := Rect2i(int(min_p.x) - pad, int(min_p.y) - pad, int(ceil(max_p.x - min_p.x)) + pad * 2, int(ceil(max_p.y - min_p.y)) + pad * 2)
	rect = rect.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	var crop := img.get_region(rect)
	crop.convert(Image.FORMAT_RGBA8)
	# Square, nearest, so the die stays about 48 px like the numeral crops.
	var side := maxi(crop.get_width(), crop.get_height())
	var square := Image.create(side, side, false, Image.FORMAT_RGBA8)
	square.fill(Color(0, 0, 0, 0))
	square.blit_rect(crop, Rect2i(0, 0, crop.get_width(), crop.get_height()), Vector2i((side - crop.get_width()) / 2, (side - crop.get_height()) / 2))
	square.resize(CROP, CROP, Image.INTERPOLATE_NEAREST)
	return square


func _strip(crops: Array[Image], name: String) -> void:
	var gap := 4
	var strip := Image.create(CROP * crops.size() + gap * (crops.size() - 1), CROP, false, Image.FORMAT_RGBA8)
	strip.fill(Color(0.05, 0.12, 0.09, 1))
	for i in crops.size():
		strip.blit_rect(crops[i], Rect2i(0, 0, CROP, CROP), Vector2i(i * (CROP + gap), 0))
	strip.save_png(_out + name + ".png")
	var big := strip.duplicate() as Image
	big.resize(strip.get_width() * 4, strip.get_height() * 4, Image.INTERPOLATE_NEAREST)
	big.save_png(_out + name + "_x4.png")
