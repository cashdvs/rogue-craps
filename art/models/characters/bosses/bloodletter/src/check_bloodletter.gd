extends SceneTree
## Bloodletter blockout checks in the Smiles test framing (tests/test_smiles.gd camera v3: GAME_CAMS, DEALER_POS,
## BRAZIER_HULL, rail-occlusion rule). Prints rig bone count, tri counts, and per clip the smallest on-screen
## clearance (px) to the brazier + goal plaque for PC 1920x1080 and phone 844x390, sweeping every 0.05 s.
##   godot --headless --path . --script res://art/models/characters/bosses/bloodletter/src/check_bloodletter.gd [-- scene=res://...tscn]
const DEALER_POS := Vector3(-0.42, -0.47, -0.86)
const RAIL_TOP := 0.14
## Game camera from feat/bonfire-sandbox a153087: rig at the pivot pitched -55, camera dolly d, look-up 7.5, fov 36.
const GAME_CAMS: Dictionary = {"pc": [Vector2i(1920, 1080), 2.40, Vector3(0, 0, 0.26)], "phone": [Vector2i(844, 390), 2.04, Vector3(0, 0, 0.34)]}
const CAM_RAIL_TOP := 0.11  # RAIL_TOP_Y in the sandbox: the band is measured from here
## Brazier bowl + goal plaque (Hearth board, art/board-hearth f25a745: Anchors/TargetPlate/Plate/Model/brazier),
## world-space hull points (support points in 600 directions). Smiles keeps >= BRAZIER_CLEAR_PX of clear dark from
## it on screen in both game cameras, every dealer clip.
const BRAZIER_HULL: Array[Vector3] = [
	Vector3(-0.134, 0.213, -0.77), Vector3(-0.134, 0.22, -0.77), Vector3(-0.129, 0.213, -0.805), Vector3(-0.129, 0.213, -0.735), Vector3(-0.129, 0.22, -0.805), Vector3(-0.129, 0.22, -0.735),
	Vector3(-0.128, 0.17, -0.773), Vector3(-0.128, 0.17, -0.767), Vector3(-0.116, 0.213, -0.837), Vector3(-0.116, 0.22, -0.837), Vector3(-0.116, 0.22, -0.703), Vector3(-0.115, 0.165, -0.801),
	Vector3(-0.107, 0.173, -0.832), Vector3(-0.103, 0.165, -0.83), Vector3(-0.095, 0.213, -0.865), Vector3(-0.095, 0.22, -0.865), Vector3(-0.095, 0.22, -0.675), Vector3(-0.087, 0.173, -0.857),
	Vector3(-0.084, 0.165, -0.854), Vector3(-0.078, 0.137, -0.617), Vector3(-0.078, 0.141, -0.611), Vector3(-0.078, 0.203, -0.647), Vector3(-0.077, 0.174, -0.627), Vector3(-0.074, 0.174, -0.625),
	Vector3(-0.067, 0.213, -0.886), Vector3(-0.067, 0.22, -0.886), Vector3(-0.067, 0.22, -0.654), Vector3(-0.066, 0.17, -0.879), Vector3(-0.061, 0.17, -0.882), Vector3(-0.045, 0.09, -0.77),
	Vector3(-0.043, 0.09, -0.782), Vector3(-0.043, 0.09, -0.758), Vector3(-0.039, 0.09, -0.793), Vector3(-0.039, 0.09, -0.748), Vector3(-0.035, 0.213, -0.899), Vector3(-0.035, 0.22, -0.899),
	Vector3(-0.035, 0.22, -0.641), Vector3(-0.032, 0.09, -0.802), Vector3(-0.032, 0.09, -0.738), Vector3(-0.031, 0.165, -0.885), Vector3(-0.023, 0.09, -0.809), Vector3(-0.012, 0.09, -0.813),
	Vector3(-0.012, 0.09, -0.727), Vector3(-0, 0.09, -0.815), Vector3(-0, 0.09, -0.725), Vector3(-0, 0.165, -0.889), Vector3(-0, 0.173, -0.893), Vector3(-0, 0.213, -0.904),
	Vector3(-0, 0.22, -0.904), Vector3(-0, 0.22, -0.636), Vector3(0.012, 0.09, -0.813), Vector3(0.012, 0.09, -0.727), Vector3(0.022, 0.09, -0.809), Vector3(0.031, 0.165, -0.885),
	Vector3(0.032, 0.09, -0.802), Vector3(0.032, 0.09, -0.738), Vector3(0.035, 0.213, -0.899), Vector3(0.035, 0.22, -0.899), Vector3(0.035, 0.22, -0.641), Vector3(0.039, 0.09, -0.793),
	Vector3(0.039, 0.09, -0.748), Vector3(0.043, 0.09, -0.782), Vector3(0.043, 0.09, -0.758), Vector3(0.045, 0.09, -0.77), Vector3(0.061, 0.17, -0.882), Vector3(0.066, 0.17, -0.879),
	Vector3(0.067, 0.213, -0.886), Vector3(0.067, 0.22, -0.886), Vector3(0.067, 0.22, -0.654), Vector3(0.074, 0.174, -0.625), Vector3(0.077, 0.174, -0.627), Vector3(0.078, 0.137, -0.617),
	Vector3(0.078, 0.141, -0.611), Vector3(0.078, 0.203, -0.647), Vector3(0.084, 0.165, -0.854), Vector3(0.095, 0.213, -0.865), Vector3(0.095, 0.22, -0.865), Vector3(0.095, 0.22, -0.675),
	Vector3(0.103, 0.165, -0.83), Vector3(0.107, 0.173, -0.832), Vector3(0.115, 0.165, -0.801), Vector3(0.116, 0.213, -0.837), Vector3(0.116, 0.22, -0.837), Vector3(0.116, 0.22, -0.703),
	Vector3(0.128, 0.17, -0.773), Vector3(0.128, 0.17, -0.767), Vector3(0.129, 0.213, -0.805), Vector3(0.129, 0.213, -0.735), Vector3(0.129, 0.22, -0.805), Vector3(0.129, 0.22, -0.735),
	Vector3(0.134, 0.213, -0.77), Vector3(0.134, 0.22, -0.77),
]
const BRAZIER_CLEAR_PX := 20.0
const CLIPS: Array[String] = ["idle", "taunt", "grudging", "cheat", "deal"]
var _closest := Vector3.ZERO


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scenes := ["res://art/models/characters/bosses/bloodletter/scenes/bloodletter.tscn", "res://art/models/characters/bosses/bloodletter/scenes/bloodletter_mobile.tscn"]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("scene="):
			scenes = [a.substr(6)]
	for p in scenes:
		await _check(p)
	quit()


func _check(path: String) -> void:
	var s := (load(path) as PackedScene).instantiate() as Node3D
	root.add_child(s)
	await process_frame
	var skel := s.find_child("Skeleton3D", true, false) as Skeleton3D
	var ap := s.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var tris := 0
	for mi: MeshInstance3D in s.find_children("*", "MeshInstance3D", true, false):
		for si in mi.mesh.get_surface_count():
			tris += (mi.mesh.surface_get_arrays(si)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	var deform := 0
	for i in skel.get_bone_count():
		if not skel.get_bone_name(i).begins_with("glow_"):
			deform += 1
	print("CHECK %s bones %d (deform %d) tris %d clips %s" % [path.get_file(), skel.get_bone_count(), deform, tris, ap.get_animation_list()])
	s.position = DEALER_POS
	var cams := {"pc": _game_cam("pc"), "phone": _game_cam("phone")}
	await process_frame
	var polys := {"pc": _brazier_poly(cams["pc"]), "phone": _brazier_poly(cams["phone"])}
	var worst := {"pc": INF, "phone": INF}
	var top := {"pc": INF, "phone": INF}
	for c in CLIPS:
		var a := ap.get_animation(c)
		var best := {"pc": INF, "phone": INF}
		var at := {}
		var t := 0.0
		while t <= a.length + 0.001:
			ap.play(c)
			ap.seek(t, true)
			var pts := _skinned(s, skel)
			for ck in cams:
				var bp := _brazier_px(cams[ck], polys[ck], pts)
				if bp < best[ck]:
					best[ck] = bp
					at[ck] = "@%.2f %s" % [t, _closest.snapped(Vector3.ONE * 0.01)]
				for q in pts:
					top[ck] = minf(top[ck], (cams[ck] as Camera3D).unproject_position(q).y)
			t += 0.05
		for ck in cams:
			worst[ck] = minf(worst[ck], best[ck])
			print("  GAP %s %-8s %6.1f px (closest %s)" % [ck, c, best[ck], at[ck]])
	print("  GAP MIN pc %.1f px | phone %.1f px | %s (>= %d) | top-most vertex y: pc %.0f px, phone %.0f px (<0 = cut by frame top)" % [worst["pc"], worst["phone"],
		"PASS" if worst["pc"] >= BRAZIER_CLEAR_PX and worst["phone"] >= BRAZIER_CLEAR_PX else "FAIL", BRAZIER_CLEAR_PX, top["pc"], top["phone"]])
	await _prop_clip(s, skel, ap)
	s.queue_free()
	await process_frame


## Prop (chip-bone mesh) vs body/head: for every clip frame where the prop is drawn (chip scale > 0.05), count prop
## vertices that sit inside the rest of the dealer (nearest triangle's outward normal faces away) and the deepest one.
func _prop_clip(s: Node3D, skel: Skeleton3D, ap: AnimationPlayer) -> void:
	var total_bad := 0
	for c in ["idle", "taunt", "grudging", "cheat", "deal", "mc_idle", "mc_cheer"]:
		var a := ap.get_animation(c)
		var t := 0.0
		var bad: Array[String] = []
		var deepest := 0.0
		while t <= a.length + 0.001:
			ap.play(c)
			ap.seek(t, true)
			var sc := skel.get_bone_pose_scale(skel.find_bone("chip")).x
			if sc > 0.05:
				var g := _geo(s, skel)
				var prop: PackedVector3Array = g[0]
				var tris: PackedVector3Array = g[1]
				var box := AABB(prop[0], Vector3.ZERO)
				for q in prop:
					box = box.expand(q)
				box = box.grow(0.03)
				var near := PackedVector3Array()
				for i in range(0, tris.size(), 3):
					if box.has_point(tris[i]) or box.has_point(tris[i + 1]) or box.has_point(tris[i + 2]):
						near.append_array([tris[i], tris[i + 1], tris[i + 2]])
				var n_in := 0
				for q in prop:
					var best := INF
					var sd := 0.0
					for i in range(0, near.size(), 3):
						var cp := _closest_on_tri(q, near[i], near[i + 1], near[i + 2])
						var d := q.distance_to(cp)
						if d < best - 1e-6:
							best = d
							var nrm := (near[i + 1] - near[i]).cross(near[i + 2] - near[i]).normalized()
							sd = (q - cp).dot(nrm)
					if best < INF and sd < -1e-4 and best < 0.03:
						n_in += 1
						deepest = maxf(deepest, best)
				if n_in > 0:
					bad.append("@%.2f sc %.2f: %d verts" % [t, sc, n_in])
			t += 0.05
		total_bad += bad.size()
		print("  PROPCLIP %-8s %s" % [c, "clean" if bad.is_empty() else "%d frames, deepest %.1f mm: %s" % [bad.size(), deepest * 1000.0, bad.slice(0, 4)]])
	print("  PROPCLIP total frames with the prop inside the hand/body: %d" % total_bad)


func _closest_on_tri(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var pl := Plane(a, b, c)
	var pp := pl.project(p)
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-14:
		return Geometry3D.get_closest_point_to_segment(p, a, b)
	if n.dot((b - a).cross(pp - a)) >= 0 and n.dot((c - b).cross(pp - b)) >= 0 and n.dot((a - c).cross(pp - c)) >= 0:
		return pp
	var best := Geometry3D.get_closest_point_to_segment(p, a, b)
	for e in [[b, c], [c, a]]:
		var q := Geometry3D.get_closest_point_to_segment(p, e[0], e[1])
		if p.distance_to(q) < p.distance_to(best):
			best = q
	return best


## [prop vertices, other triangles (flat, 3 per tri)] skinned to world space.
func _geo(s: Node3D, skel: Skeleton3D) -> Array:
	var prop := PackedVector3Array()
	var tris := PackedVector3Array()
	for mi: MeshInstance3D in s.find_children("*", "MeshInstance3D", true, false):
		var is_prop := mi.name.contains("Lancet") or mi.name.contains("Chip") or mi.name.contains("Cards")
		var skin := mi.skin
		var mats: Array[Transform3D] = []
		var gl := false
		for i in skin.get_bind_count():
			var b := skin.get_bind_name(i)
			var bi := skel.find_bone(b) if b != "" else skin.get_bind_bone(i)
			mats.append(skel.global_transform * skel.get_bone_global_pose(bi) * skin.get_bind_pose(i))
		for si in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(si)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bs: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var ws: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			var k := ws.size() / maxi(vs.size(), 1)
			var w := PackedVector3Array()
			w.resize(vs.size())
			for vi in vs.size():
				var j := 0
				for jj in k:
					if ws[vi * k + jj] > ws[vi * k + j]:
						j = jj
				w[vi] = mats[bs[vi * k + j]] * vs[vi]
			if is_prop:
				prop.append_array(w)
			else:
				var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
				var mname := (mi.get_active_material(si).resource_name if mi.get_active_material(si) else "")
				if mname.contains("glow"):
					continue
				for ti in idx:
					tris.append(w[ti])
	return [prop, tris]


func _skinned(s: Node3D, skel: Skeleton3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	var hidden_chip := skel.get_bone_pose_scale(skel.find_bone("chip")).x < 0.05
	for mi: MeshInstance3D in s.find_children("*", "MeshInstance3D", true, false):
		var skin := mi.skin
		var mats: Array[Transform3D] = []
		var bn: Array[String] = []
		for i in skin.get_bind_count():
			var b := skin.get_bind_name(i)
			var bi := skel.find_bone(b) if b != "" else skin.get_bind_bone(i)
			bn.append(skel.get_bone_name(bi))
			mats.append(skel.global_transform * skel.get_bone_global_pose(bi) * skin.get_bind_pose(i))
		for si in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(si)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bs: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var ws: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			var k := ws.size() / maxi(vs.size(), 1)
			for vi in vs.size():
				var j := 0
				for jj in k:
					if ws[vi * k + jj] > ws[vi * k + j]:
						j = jj
				var name := bn[bs[vi * k + j]]
				if name.begins_with("glow_") or (name == "chip" and hidden_chip):
					continue  # glow shells off outside the MC clips; chip/plaque palmed (scale 0) is not drawn
				out.append(mats[bs[vi * k + j]] * vs[vi])
	return out
func _game_cam(kind: String) -> Camera3D:
	var c: Array = GAME_CAMS[kind]
	var vp := SubViewport.new()
	vp.size = c[0]
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(vp)
	var rig := Node3D.new()
	vp.add_child(rig)
	rig.position = c[2]
	rig.rotation_degrees = Vector3(-55, 0, 0)
	var cam := Camera3D.new()
	rig.add_child(cam)
	cam.fov = 36.0
	cam.position = Vector3(0, 0, c[1])
	cam.rotation_degrees = Vector3(7.5, 0, 0)
	cam.current = true
	return cam


## Screen-space convex hull of the brazier + plaque (monotone chain), counter-clockwise.
func _brazier_poly(cam: Camera3D) -> PackedVector2Array:
	var p: Array[Vector2] = []
	for v in BRAZIER_HULL:
		p.append(cam.unproject_position(v))
	p.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	var h: Array[Vector2] = []
	for pass_i in 2:
		var start := h.size()
		var seq := p if pass_i == 0 else p.duplicate()
		if pass_i == 1:
			seq.reverse()
		for q in seq:
			while h.size() >= start + 2 and (h[-1] - h[-2]).cross(q - h[-2]) <= 0.0:
				h.pop_back()
			h.append(q)
		h.pop_back()
	return PackedVector2Array(h)


## Smallest on-screen distance (px) from any of `pts` to the brazier polygon (0 = touching / overlapping).
func _brazier_px(cam: Camera3D, poly: PackedVector2Array, pts: PackedVector3Array) -> float:
	var lo := INF
	for v in poly:
		lo = minf(lo, v.x)
	var best := INF
	for q in pts:
		var sp := cam.unproject_position(q)
		if sp.x < lo - best:
			continue
		if q.z < -0.72 and sp.y > cam.unproject_position(Vector3(q.x, RAIL_TOP, -0.72)).y:
			continue  # below the far rail's sight line: the rail hides it
		if Geometry2D.is_point_in_polygon(sp, poly):
			_closest = q
			return 0.0
		for i in poly.size():
			var c := Geometry2D.get_closest_point_to_segment(sp, poly[i], poly[(i + 1) % poly.size()])
			if sp.distance_to(c) < best:
				best = sp.distance_to(c)
				_closest = q
	return best


