## Headless test: the Hearth set dressing near the dealer stays clear of Smiles in every clip
## (art/models/characters/smiles README "Clips"), with Smiles at the dealer spot used on main
## (CameraFraming.DEALER_XZ, y -0.47 as tools/capture_camera_framing.gd). Like the rail-clearance test:
##   intersection  no skinned Smiles vertex inside any near-dealer dressing part (padded 4 mm), at any
##                 sampled frame (10 fps) of idle, taunt, grudging, cheat, deal, mc_idle, mc_cheer;
##   occlusion     the service bell stays >= 85 % visible from the game camera (PC 16:9 and phone landscape:
##                 rays from the camera to its vertices, tested against Smiles' triangles) at every frame;
##   brazier read  the bell never overlaps the brazier bowl / goal plaque on screen.
## Smiles is skinned on the CPU here (Skeleton3D poses x Skin binds x vertex weights), so it runs headless.
##
## Run:
##   godot --headless --path . --script res://tests/test_hearth_dealer_clear.gd
extends SceneTree

const H := "res://art/models/boards/hearth/scenes/"
const SMILES := "res://art/models/characters/smiles/scenes/smiles%s.tscn"
const DEALER_Y := -0.47
const CLIPS: Array[String] = ["idle", "taunt", "grudging", "cheat", "deal", "mc_idle", "mc_cheer"]
const PAD := 0.004
const MIN_VISIBLE := 0.85
const NEAR_DEALER := AABB(Vector3(-1.0, 0.0, -0.95), Vector3(1.2, 0.6, 0.45))  # far rail around Smiles

var _passed := 0
var _failed := 0


func _initialize() -> void:
	print("=== Dice of the Damned: Hearth dressing vs Smiles clips ===")
	_run.call_deferred()


func _run() -> void:
	for mobile in [false, true]:
		await _check(mobile)
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _cams() -> Array:
	return [["pc", _a153087(Vector3(0, 0, 0.26), 2.40), 1920.0 / 1080.0], ["phone", _a153087(Vector3(0, 0, 0.34), 2.04), 844.0 / 390.0]]


func _a153087(pivot: Vector3, d: float) -> Transform3D:
	var rig := Transform3D(Basis.from_euler(Vector3(deg_to_rad(-55), 0, 0)), pivot)
	return rig * Transform3D(Basis.from_euler(Vector3(deg_to_rad(7.5), 0, 0)), Vector3(0, 0, d))


func _ndc(cam: Transform3D, aspect: float, p: Vector3) -> Vector2:
	var tn := tan(deg_to_rad(36.0) * 0.5)
	var v := cam.affine_inverse() * p
	return Vector2(v.x / (-v.z * tn * aspect), v.y / (-v.z * tn))


func _check(mobile: bool) -> void:
	var lod := "_mobile" if mobile else ""
	var label := "hearth_board%s + smiles%s" % [lod, lod]
	var board := (load(H + "hearth_board%s.tscn" % lod) as PackedScene).instantiate() as Node3D
	var smiles := (load(SMILES % lod) as PackedScene).instantiate() as Node3D
	smiles.position = Vector3(CameraFraming.DEALER_XZ.x, DEALER_Y, CameraFraming.DEALER_XZ.y)
	root.add_child(board)
	root.add_child(smiles)
	await process_frame
	var d := board.get_node("Hearth/Dressing") as Node3D
	# near-dealer dressing parts: per-mesh vertex boxes inside the far-rail region around Smiles
	var parts: Array = []  # [name, AABB]
	for mi: MeshInstance3D in d.find_children("*", "MeshInstance3D", true, false):
		var path := str(d.get_path_to(mi))
		if path.begins_with("Ambient") or path == "Backdrop" or path.begins_with("Under") or path.begins_with("Tail"):
			continue
		# split merged meshes into 6 cm cells so one cluster is one box
		var cells := {}
		var xf := mi.global_transform
		for s in mi.mesh.get_surface_count():
			for v: Vector3 in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				var w := xf * v
				if not NEAR_DEALER.has_point(w):
					continue
				var key := Vector3i(floori(w.x / 0.06), 0, floori(w.z / 0.06))
				if cells.has(key):
					cells[key] = (cells[key] as AABB).expand(w)
				else:
					cells[key] = AABB(w, Vector3.ZERO)
		for k in cells:
			parts.append([path, (cells[k] as AABB).grow(PAD)])
	var bell := d.get_node("Bell") as Node3D
	var bell_pts: PackedVector3Array = []
	for mi: MeshInstance3D in bell.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			for v: Vector3 in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				bell_pts.append(mi.global_transform * v)
	_check_ok(parts.size() > 0 and bell_pts.size() > 0, "%s: %d near-dealer dressing boxes, bell %d verts" % [label, parts.size(), bell_pts.size()])
	# brazier bowl + plaque screen rects (static)
	var braz: PackedVector3Array = []
	var plate := board.get_node("Anchors/TargetPlate/Plate")
	for mi: MeshInstance3D in plate.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh is QuadMesh:
			continue  # fire cards / sparks
		for s in mi.mesh.get_surface_count():
			for v: Vector3 in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				braz.append(mi.global_transform * v)
	var braz_ok := true
	for c in _cams():
		if _rect(c, braz).intersects(_rect(c, bell_pts)):
			braz_ok = false
	_check_ok(braz_ok, label + ": the bell never overlaps the brazier bowl / goal plaque on screen (PC + phone)")
	# Smiles: CPU skinning
	var ap := smiles.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var skel := smiles.find_child("Skeleton3D", true, false) as Skeleton3D
	var skinned: Array[MeshInstance3D] = []
	for mi: MeshInstance3D in skel.find_children("*", "MeshInstance3D", false, false):
		if mi.skin != null:
			skinned.append(mi)
	for clip in CLIPS:
		_check_ok(ap.has_animation(clip), "%s: Smiles has clip %s" % [label, clip])
		if not ap.has_animation(clip):
			continue
		var ln := ap.get_animation(clip).length
		var hit := ""
		var worst_vis := 1.0
		var worst_at := ""
		ap.play(clip)
		var t := 0.0
		while t <= ln + 0.001:
			ap.seek(t, true)
			var tris := _skin(skel, skinned)
			# intersection
			if hit == "":
				for i in range(0, tris.size()):
					var p := tris[i]
					for part in parts:
						if (part[1] as AABB).has_point(p):
							hit = "%s at %.2f s (%s)" % [part[0], t, p]
							break
					if hit != "":
						break
			# occlusion of the bell
			for c in _cams():
				var vis := _visible(c[1], bell_pts, tris)
				if vis < worst_vis:
					worst_vis = vis
					worst_at = "%.2f s %s" % [t, c[0]]
			t += 0.1
		ap.stop()
		_check_ok(hit == "", "%s: %s never intersects the near-dealer dressing %s" % [label, clip, hit])
		_check_ok(worst_vis >= MIN_VISIBLE, "%s: %s keeps the bell >= %d %% visible (worst %.0f %% at %s)" % [label, clip, int(MIN_VISIBLE * 100), worst_vis * 100.0, worst_at])
	root.remove_child(board)
	root.remove_child(smiles)
	board.free()
	smiles.free()


## Skinned world-space triangle soup (3 points per triangle) of the given meshes.
func _skin(skel: Skeleton3D, meshes: Array[MeshInstance3D]) -> PackedVector3Array:
	var out: PackedVector3Array = []
	var sx := skel.global_transform
	for mi in meshes:
		var skin := mi.skin
		var mats: Array[Transform3D] = []
		for b in skin.get_bind_count():
			var bone := skin.get_bind_bone(b)
			if bone < 0:
				bone = skel.find_bone(skin.get_bind_name(b))
			mats.append(sx * skel.get_bone_global_pose(bone) * skin.get_bind_pose(b))
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var verts := arr[Mesh.ARRAY_VERTEX] as PackedVector3Array
			var bones: Variant = arr[Mesh.ARRAY_BONES]
			var weights: Variant = arr[Mesh.ARRAY_WEIGHTS]
			var idx := arr[Mesh.ARRAY_INDEX] as PackedInt32Array
			var nb := (bones as PackedInt32Array).size() / verts.size() if bones != null else 0
			var sk := PackedVector3Array()
			sk.resize(verts.size())
			for i in verts.size():
				var p := Vector3.ZERO
				var wsum := 0.0
				for j in nb:
					var w: float = (weights as PackedFloat32Array)[i * nb + j]
					if w > 0.0:
						p += (mats[(bones as PackedInt32Array)[i * nb + j]] * verts[i]) * w
						wsum += w
				sk[i] = p / wsum if wsum > 0.0 else mi.global_transform * verts[i]
			for k in idx:
				out.append(sk[k])
	return out


## Fraction of the points not hidden behind any of the triangles from the camera.
func _visible(cam: Transform3D, pts: PackedVector3Array, tris: PackedVector3Array) -> float:
	var o := cam.origin
	# pre-filter: triangles in front of the points' depth that overlap their screen box
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var inv := cam.affine_inverse()
	for p in pts:
		var v := inv * p
		var q := Vector2(v.x / -v.z, v.y / -v.z)
		lo = lo.min(q)
		hi = hi.max(q)
	var box := Rect2(lo, hi - lo).grow(0.002)
	var cand: Array[int] = []
	for i in range(0, tris.size(), 3):
		var tlo := Vector2(INF, INF)
		var thi := Vector2(-INF, -INF)
		for j in 3:
			var v := inv * tris[i + j]
			if v.z > -0.01:
				continue
			var q := Vector2(v.x / -v.z, v.y / -v.z)
			tlo = tlo.min(q)
			thi = thi.max(q)
		if tlo.x <= thi.x and Rect2(tlo, thi - tlo).intersects(box, true):
			cand.append(i)
	if cand.is_empty():
		return 1.0
	var seen := 0
	for p in pts:
		var blocked := false
		var e := o + (p - o) * 0.995
		for i in cand:
			if Geometry3D.segment_intersects_triangle(o, e, tris[i], tris[i + 1], tris[i + 2]) != null:
				blocked = true
				break
		if not blocked:
			seen += 1
	return float(seen) / pts.size()


func _rect(c: Array, pts: PackedVector3Array) -> Rect2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in pts:
		var q := _ndc(c[1], c[2], p)
		lo = lo.min(q)
		hi = hi.max(q)
	return Rect2(lo, hi - lo)


func _check_ok(cond: bool, name: String) -> void:
	if cond:
		_passed += 1
		print("  ok   ", name)
	else:
		_failed += 1
		print("  FAIL ", name)
