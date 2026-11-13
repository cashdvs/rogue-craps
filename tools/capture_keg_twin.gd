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
	# 180: atlas +X (top of the 3) points at the far rail, so the numeral
	# reads upright on the rest camera. 0 points it at the lens (backwards E).
	var yaws: Array[float] = [180.0, 180.0, 180.0]
	for i in dice.size():
		var tag := dice[i].get_node_or_null("KegValueTag")
		if tag != null:
			tag.free()
		_pose(dice[i], spots[i], yaws[i])
		var screen := cam.unproject_position(dice[i].global_position)
		print("die %d at %s screen %s" % [i, dice[i].global_position, screen])
	for tw in get_processed_tweens():
		tw.kill()
	for i in dice.size():
		_pose(dice[i], spots[i], yaws[i])
		# The table emits settled after a landing. KegStaveDim listens and
		# sets lit_stave to the shown value. Reduced motion (set above) snaps
		# the fade. The still then holds Twin settled at 0: the keg's glow
		# strength is already 0, and a settled gate would paint the glyph
		# near-black instead of the cream the AD picked.
		_land(dice[i])
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
	# Tight crop of the up stave (atlas cell 2) on the plain keg and the
	# keg-mask keg, nearest ×8, plus the per-pixel difference in that cell.
	var plain_stave := _stave(cam, dice[0])
	var mask_stave := _stave(cam, dice[2])
	_save_x8(plain_stave, "stave_plain")
	_save_x8(mask_stave, "stave_mask")
	_save_compare(plain_stave, mask_stave)
	_diff_staves(plain_stave, mask_stave)
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


## Same settle Table3D sends when a throw lands. Not a hand-written uniform.
func _land(d: DieVisual) -> void:
	var slot := d.up_slot() if PolyDie.has_shape(d.shape) else d.up_value()
	d.settled.emit(d.die_id, slot)
	var glow := d.get_node_or_null("TwinFaceGlow") as TwinFaceGlow
	if glow != null:
		glow.set_settled(false)
	var dim := d.get_node_or_null("KegStaveDim") as KegStaveDim
	var body := d.faces.get_node("Body") as MeshInstance3D
	var lit: Variant = body.get_instance_shader_parameter(&"lit_stave")
	var fade: Variant = body.get_instance_shader_parameter(&"stave_dim")
	print("landed die %d shown %d slot %d lit %s dim %s" % [d.die_id, d.shown_value(), slot, str(lit), str(fade)])


## Flat rest, the same way the numeral shots lie: barrel along world X, the
## 3 stave exactly up (no tip). [param yaw_deg] turns that stave about its
## normal. 180 puts the atlas +X (the top of the 3) toward the far rail,
## which is up on the rest camera. 0 points it at the camera, so the 3
## reads as a backwards E.
func _pose(d: DieVisual, at: Vector3, yaw_deg: float) -> void:
	var dirs: Array = DieHullData.SHAPES[&"keg"]["dirs"]
	var up_local: Vector3 = (dirs[5] as Vector3).normalized()
	var stand := Basis(Quaternion(up_local, Vector3.UP))
	var basis := Basis(Vector3.UP, deg_to_rad(yaw_deg)) * stand
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


## Screen rect of the up stave's numeral cell (UV cell 2) on [param d].
func _stave(cam: Camera3D, d: DieVisual) -> Image:
	var img := root.get_texture().get_image()
	var k := float(img.get_width()) / root.get_visible_rect().size.x
	var body := d.faces.get_node("Body") as MeshInstance3D
	var arr := body.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var xf := body.global_transform
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	for t in idx.size() / 3:
		var uv: Vector2 = uvs[idx[t * 3]]
		if uv.x < 0.4 or uv.x >= 0.6 or uv.y < 0.0 or uv.y >= 0.2:
			continue
		var n := (xf.basis * (arr[Mesh.ARRAY_NORMAL][idx[t * 3]] as Vector3)).normalized()
		if n.y < 0.5:
			continue
		for c in 3:
			var p := cam.unproject_position(xf * verts[idx[t * 3 + c]]) * k
			min_p = min_p.min(p)
			max_p = max_p.max(p)
	var pad := 2
	var rect := Rect2i(int(min_p.x) - pad, int(min_p.y) - pad, int(ceil(max_p.x - min_p.x)) + pad * 2, int(ceil(max_p.y - min_p.y)) + pad * 2)
	rect = rect.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	var crop := img.get_region(rect)
	crop.convert(Image.FORMAT_RGBA8)
	return crop


func _save_x8(crop: Image, name: String) -> void:
	var big := crop.duplicate() as Image
	big.resize(maxi(crop.get_width() * 8, 8), maxi(crop.get_height() * 8, 8), Image.INTERPOLATE_NEAREST)
	big.save_png(_out + name + "_x8.png")
	print("saved ", name, "_x8 ", crop.get_width(), "x", crop.get_height())


## Max and mean per-pixel RGB distance (0..255) inside the numeral cell.
func _diff_staves(plain: Image, mask: Image) -> void:
	var b := mask.duplicate() as Image
	if b.get_size() != plain.get_size():
		b.resize(plain.get_width(), plain.get_height(), Image.INTERPOLATE_NEAREST)
	var n := plain.get_width() * plain.get_height()
	var sum := 0.0
	var peak := 0.0
	for y in plain.get_height():
		for x in plain.get_width():
			var pa := plain.get_pixel(x, y)
			var pb := b.get_pixel(x, y)
			var dist := (absf(pa.r - pb.r) + absf(pa.g - pb.g) + absf(pa.b - pb.b)) / 3.0 * 255.0
			sum += dist
			peak = maxf(peak, dist)
	print("numeral cell diff: max %.2f mean %.2f over %d px" % [peak, sum / float(maxi(n, 1)), n])


## Plain stave | keg-mask stave, nearest ×8, same cell the diff measures.
func _save_compare(plain: Image, mask: Image) -> void:
	var a := plain.duplicate() as Image
	var b := mask.duplicate() as Image
	a.resize(maxi(plain.get_width() * 8, 8), maxi(plain.get_height() * 8, 8), Image.INTERPOLATE_NEAREST)
	b.resize(maxi(mask.get_width() * 8, 8), maxi(mask.get_height() * 8, 8), Image.INTERPOLATE_NEAREST)
	var gap := 8
	var cmp := Image.create(a.get_width() + gap + b.get_width(), maxi(a.get_height(), b.get_height()), false, Image.FORMAT_RGBA8)
	cmp.fill(Color(0.05, 0.12, 0.09, 1))
	cmp.blit_rect(a, Rect2i(0, 0, a.get_width(), a.get_height()), Vector2i(0, 0))
	cmp.blit_rect(b, Rect2i(0, 0, b.get_width(), b.get_height()), Vector2i(a.get_width() + gap, 0))
	cmp.save_png(_out + "stave_compare_x8.png")


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
