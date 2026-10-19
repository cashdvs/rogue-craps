## Headless test: the batch-3 non-d6 dice's shapes and face artwork (art/models/dice/, build_batch3.py +
## write_batch3.py). Split from test_batch3_dice.gd (the value -> direction table and per-mesh checks live there).
## Checks: the 0.050 m extent cap; every mobile LOD is centred and its convex hull matches the PC extents within
## 0.5 mm and keeps the PC hull's mirror symmetries (Godot Dev builds the hull colliders from the mobile meshes);
## the Ferryman's Coin is heads/tails symmetric with a barrelled edge; the Powder Keg is a 6-stave d6 printed
## 1,2,3,1,2,3 with domed ends; and each face shows its own mark (batch3_face_prints.json).
##
## Run:
##   godot --headless --path . --script res://tests/test_batch3_dice_shapes.gd
extends SceneTree

const DIR: String = "res://art/models/dice/"

## Size cap for non-d6 dice: max per-axis half-extent from the origin (the centre of mass) is 0.050 m, per PM and
## Godot Dev (Oct 19), on the PC mesh, the mobile mesh and a convex hull of the mobile mesh (Godot Dev's collider).
## (d6s keep tests/test_special_dice.gd's 0.042 m box cap.)
const MAX_EXTENT: float = 0.050
## Scaled to the cap on Oct 19 (Caltrop x0.849, Knucklebone x0.866, Lantern x0.943, PC and mobile alike; the Tithe
## x0.978 to 0.0498 m is checked by MAX_EXTENT).
const CAPPED: Dictionary = {"caltrop_d4": 0.050, "knucklebone_talus": 0.050, "lantern_d8": 0.050}
## Godot Dev builds every non-d6 hull from the *mobile* mesh: its extents must match the PC visual within 0.5 mm.
const HULL_TOL: float = 0.0005
## Symmetric by design: their mobile meshes (and hulls) keep the PC mesh's mirror symmetries. The knucklebone is
## organic (only centred).
const SYMMETRIC: Array[String] = ["caltrop_d4", "lantern_d8", "tithe_d10", "midnight_d12", "verdict_d20", "ferryman_coin", "powder_keg_d6"]

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	print("=== Dice of the Damned: batch-3 special dice (shapes, hulls, face artwork) tests ===")
	var faces: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "batch3_faces.json"))
	var prints: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "batch3_face_prints.json"))
	_check(faces != null and faces.size() == 8 and prints != null, "batch3_faces.json and batch3_face_prints.json load (8 dice)")
	if faces == null or prints == null:
		quit(1)
		return
	_check_coin()
	_check_keg(faces.get("powder_keg_d6", {}))
	for die: String in faces:
		_check_extents(die, faces[die])
		_check_face_prints(die, faces[die], prints.get(die, {}))
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


## Ferryman's Coin: heads and tails are mirror images in thickness, rim and edge (relief lives in the texture only),
## the volume centroid sits on the origin, and the convex hull a sandbox builds from it is symmetric too.
func _check_coin() -> void:
	for file: String in ["ferryman_coin.glb", "ferryman_coin_mobile.glb"]:
		var inst := (load(DIR + file) as PackedScene).instantiate()
		var mesh := (inst.get_child(0) as MeshInstance3D).mesh
		inst.free()  # the Mesh resource stays referenced by `mesh`
		var verts := PackedVector3Array()
		var tri_v := PackedVector3Array()
		for s in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(s)
			verts.append_array(arr[Mesh.ARRAY_VERTEX])
			for i: int in (arr[Mesh.ARRAY_INDEX] as PackedInt32Array):
				tri_v.append((arr[Mesh.ARRAY_VERTEX] as PackedVector3Array)[i])
		var ymax := -INF
		var ymin := INF
		for p in verts:
			ymax = maxf(ymax, p.y)
			ymin = minf(ymin, p.y)
		_check(absf(ymax + ymin) < 1e-5 and absf(ymax - ymin - 0.024) < 2e-4, "%s: heads and tails faces at +-%.4f m (thickness %.4f, 0.024 m)" % [file, ymax, ymax - ymin])
		var twins := 0
		for p in verts:
			for q in verts:
				if q.distance_to(Vector3(p.x, -p.y, p.z)) < 2e-5:
					twins += 1
					break
		_check(twins == verts.size(), "%s: every vertex has a heads/tails mirror twin (%d/%d): same relief depth, rim and edge on both sides" % [file, twins, verts.size()])
		# Rounded edge: away from the equator the edge recedes (an edge pose rolls over onto a face).
		var r_eq := 0.0
		var r_off := 0.0
		for p in verts:
			var rr := Vector2(p.x, p.z).length()
			if absf(p.y) < 1e-4:
				r_eq = maxf(r_eq, rr)
			elif absf(p.y) > 0.005:
				r_off = maxf(r_off, rr)
		_check(r_eq > 0.0495 and r_off < r_eq - 0.0025, "%s: barrelled edge (equator r %.4f, r %.4f off the equator), so it can't stand on its edge" % [file, r_eq, r_off])
		# Solid centroid by signed tetrahedra from the origin.
		var vol := 0.0
		var cm := Vector3.ZERO
		for t in tri_v.size() / 3:
			var a := tri_v[t * 3]
			var b := tri_v[t * 3 + 1]
			var c := tri_v[t * 3 + 2]
			var v6 := a.dot(b.cross(c))
			vol += v6
			cm += (a + b + c) * v6
		cm = cm / (4.0 * vol) if absf(vol) > 1e-12 else Vector3(INF, INF, INF)
		_check(cm.length() < 2e-5, "%s: centre of mass on the origin (%s)" % [file, cm])
		var hull := mesh.create_convex_shape(true, false) as ConvexPolygonShape3D
		var hy := -INF
		var ly := INF
		var hm := 0
		for p: Vector3 in hull.points:
			hy = maxf(hy, p.y)
			ly = minf(ly, p.y)
			for q: Vector3 in hull.points:
				if q.distance_to(Vector3(p.x, -p.y, p.z)) < 3e-4:
					hm += 1
					break
		_check(absf(hy + ly) < 1e-4 and hm == hull.points.size(), "%s: convex hull symmetric heads/tails (y %.4f / %.4f, %d/%d points mirrored)" % [file, hy, ly, hm, hull.points.size()])


## Powder Keg (die id powder_keg, shape d6): a hexagonal barrel with 6 staves printed 1,2,3,1,2,3, each value on two
## opposite staves, read by the stave pointing up. Its body and hull are 6-sided, not 3-valued. Domed ends with only a
## small lid, so it rarely stands on an end (Oct 19: 0/40 random throws).
func _check_keg(spec: Dictionary) -> void:
	var dirs: Array = spec.get("dirs", [])
	var count := {}
	var opposite := dirs.size() == 6
	for e: Array in dirs:
		count[int(e[0])] = int(count.get(int(e[0]), 0)) + 1
		var d := Vector3(e[1][0], e[1][1], e[1][2])
		var twin := false
		for f: Array in dirs:
			twin = twin or (int(f[0]) == int(e[0]) and d.dot(Vector3(f[1][0], f[1][1], f[1][2])) < -0.999)
		opposite = opposite and twin
	_check(dirs.size() == 6 and count == {1: 2, 2: 2, 3: 2} and opposite, "powder_keg_d6: 6 staves, values 1,2,3 each on two opposite staves (%s)" % [count])
	var mesh := _load_mesh("powder_keg_d6_mobile.glb")
	var hull := mesh.create_convex_shape(true, false) as ConvexPolygonShape3D
	var staves := 0
	for e: Array in dirs:
		var d := Vector3(e[1][0], e[1][1], e[1][2]).normalized()
		var top := -INF
		for p: Vector3 in hull.points:
			top = maxf(top, p.dot(d))
		var on := 0
		for p: Vector3 in hull.points:
			on += 1 if p.dot(d) > top - 0.001 else 0
		staves += 1 if on >= 3 else 0
	_check(staves == 6, "powder_keg_d6 (mobile hull): a flat stave on each of the 6 directions (%d/6)" % staves)
	mesh = _load_mesh("powder_keg_d6.glb")
	var xmax := 0.0
	for s in mesh.get_surface_count():
		for p: Vector3 in mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			xmax = maxf(xmax, absf(p.x))
	var lid := 0.0
	for s in mesh.get_surface_count():
		for p: Vector3 in mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			if absf(p.x) > xmax - 0.0015:
				lid = maxf(lid, Vector2(p.y, p.z).length())
	_check(lid < 0.008, "powder_keg_d6: flat lid radius %.4f m < 0.008 (domed ends, rarely stands on an end)" % lid)


## Extent cap, mobile LOD centring, mobile-vs-PC (mesh and hull) extents, and mirror symmetry of the mobile hull.
func _check_extents(die: String, spec: Dictionary) -> void:
	var pc := _load_mesh(String(spec["file"]))
	var mob := _load_mesh(String(spec["mobile"]))
	if pc == null or mob == null:
		_check(false, "%s: PC and mobile meshes load" % die)
		return
	var e_pc := _half_extents(_all_verts(pc))
	var e_mob := _half_extents(_all_verts(mob))
	for pair: Array in [[e_pc, "PC"], [e_mob, "mobile"]]:
		var m := _max_abs(pair[0])
		_check(m <= MAX_EXTENT + 1e-5, "%s (%s): max per-axis half-extent %.4f m <= %.3f (0.050 m cap)" % [die, pair[1], m, MAX_EXTENT])
		if CAPPED.has(die):
			_check(m <= float(CAPPED[die]) + 1e-5, "%s (%s): scaled to the cap, half-extent %.4f m <= %.3f" % [die, pair[1], m, CAPPED[die]])
	var cm := _centroid(mob)
	_check(cm.length() < 0.0005, "%s (mobile): centre of mass within 0.5 mm of the origin (%s), so a hull from it spins true" % [die, cm])
	var hull := mob.create_convex_shape(true, false) as ConvexPolygonShape3D
	var e_hull := _half_extents(hull.points)
	var mh := _max_abs(e_hull)
	_check(mh <= MAX_EXTENT + 1e-5, "%s (hull of mobile): max per-axis half-extent %.4f m <= %.3f (0.050 m cap)" % [die, mh, MAX_EXTENT])
	var worst := 0.0
	var worst_h := 0.0
	for i in 6:
		worst = maxf(worst, absf(e_mob[i] - e_pc[i]))
		worst_h = maxf(worst_h, absf(e_hull[i] - e_pc[i]))
	_check(worst <= HULL_TOL, "%s: mobile mesh extents within 0.5 mm of PC on every half-axis (worst %.2f mm)" % [die, worst * 1000.0])
	_check(worst_h <= HULL_TOL, "%s: convex hull of the mobile mesh within 0.5 mm of the PC extents (worst %.2f mm)" % [die, worst_h * 1000.0])
	if die in SYMMETRIC:
		# Candidate mirror planes: the 3 axis planes plus every plane that swaps two value directions (a polyhedron's
		# mirrors map faces onto faces; the d20 has no axis-aligned mirror with its 20 face up).
		var normals: Array[Vector3] = [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
		var dirs: Array = []
		for e: Array in spec["dirs"]:
			dirs.append([int(e[0]), Vector3(e[1][0], e[1][1], e[1][2])])
		for i in dirs.size():
			for j in range(i + 1, dirs.size()):
				var n := ((dirs[i][1] as Vector3).normalized() - (dirs[j][1] as Vector3).normalized())
				if n.length() < 1e-3:
					continue
				n = n.normalized()
				if not normals.any(func(m: Vector3) -> bool: return absf(m.dot(n)) > 0.9999):
					normals.append(n)
		var pc_hull := pc.create_convex_shape(true, false) as ConvexPolygonShape3D
		var kept := 0
		var had := 0
		for n in normals:
			if _mirrored(pc_hull.points, n):
				had += 1
				kept += 1 if _mirrored(hull.points, n) else 0
		_check(had > 0 and kept == had, "%s: mobile hull keeps all %d mirror symmetries of the PC hull" % [die, had])


## Each face shows its own mark: the face's atlas fingerprint (batch3_face_prints.json, written with the textures)
## matches the imported texture, and is nearer to that value's print than to any other value's, so a swap of two
## faces' artwork fails. The recorded labels follow the die's numbering.
func _check_face_prints(die: String, spec: Dictionary, entry: Dictionary) -> void:
	var faces: Dictionary = entry.get("faces", {})
	var values := {}
	for e: Array in spec["dirs"]:
		values[str(int(e[0]))] = true
	_check(faces.size() == values.size() and faces.keys().all(func(k: String) -> bool: return values.has(k)), "%s: a face print per value" % die)
	if faces.size() != values.size():
		return
	var scene := load(DIR + die + ".glb") as PackedScene
	var inst := scene.instantiate()
	var body := (inst.get_child(0) as MeshInstance3D).mesh.surface_get_material(0) as ShaderMaterial
	inst.free()
	var img := (body.get_shader_parameter("overlay_tex") as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	var labels_ok := true
	var own_ok := true
	var worst := 0.0
	for v: String in faces:
		var f: Dictionary = faces[v]
		labels_ok = labels_ok and _label_ok(die, int(v), String(f["label"])) and int(f["cell"]) == int(v) - 1
		var got := _print(img, int(f["cell"]), int(entry["grid"]))
		var own := _print_dist(got, f["print"])
		worst = maxf(worst, own)
		for w: String in faces:
			if w != v and _print_dist(got, faces[w]["print"]) <= own:
				own_ok = false
	_check(labels_ok, "%s: each value's face is labelled with its own numeral / name" % die)
	_check(worst < 0.03 and own_ok, "%s: every face shows its own mark (print distance %.4f, nearest to its own value)" % [die, worst])


func _label_ok(die: String, v: int, label: String) -> bool:
	match die:
		"caltrop_d4":
			return label == ""  # tip pips, counted per corner
		"ferryman_coin":
			return label == ("heads" if v == 1 else "tails")
		"midnight_d12":
			return label == ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII"][v - 1]
	return label.trim_suffix(".") == str(v)  # 6. and 9. carry an underline dot


func _print(img: Image, cell: int, grid: int) -> Array:
	var w := img.get_width() / 5.0
	var x0 := (cell % 5) * w + w * 0.1
	var y0 := (cell / 5) * w + w * 0.1
	var step := w * 0.8 / grid
	var alpha := []
	var bright := []
	for gy in grid:
		for gx in grid:
			var sa := 0.0
			var sl := 0.0
			var n := 0
			for y in range(int(y0 + gy * step), int(y0 + (gy + 1) * step), 2):
				for x in range(int(x0 + gx * step), int(x0 + (gx + 1) * step), 2):
					var c := img.get_pixel(x, y)
					sa += c.a
					sl += (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) * c.a
					n += 1
			alpha.append(sa / n)
			bright.append(sl / n)
	return alpha + bright


func _print_dist(a: Array, b: Array) -> float:
	var s := 0.0
	for i in a.size():
		s += absf(float(a[i]) - float(b[i]))
	return s / a.size()


func _load_mesh(file: String) -> Mesh:
	var scene := load(DIR + file) as PackedScene
	if scene == null:
		return null
	var inst := scene.instantiate()
	var mesh := (inst.get_child(0) as MeshInstance3D).mesh
	inst.free()
	return mesh


func _all_verts(mesh: Mesh) -> PackedVector3Array:
	var out := PackedVector3Array()
	for s in mesh.get_surface_count():
		out.append_array(mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX])
	return out


## [-x, +x, -y, +y, -z, +z] distances from the origin.
func _half_extents(pts: PackedVector3Array) -> Array:
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for p in pts:
		lo = lo.min(p)
		hi = hi.max(p)
	return [-lo.x, hi.x, -lo.y, hi.y, -lo.z, hi.z]


func _max_abs(e: Array) -> float:
	var m := 0.0
	for x: float in e:
		m = maxf(m, x)
	return m


## Is the point set symmetric under reflection across the plane through the origin with normal n?
func _mirrored(pts: PackedVector3Array, n: Vector3) -> bool:
	for p in pts:
		var q := p - 2.0 * p.dot(n) * n
		var hit := false
		for r in pts:
			if r.distance_to(q) < 3e-4:
				hit = true
				break
		if not hit:
			return false
	return true


func _centroid(mesh: Mesh) -> Vector3:
	var vol := 0.0
	var cm := Vector3.ZERO
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var vv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var ii: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		for t in ii.size() / 3:
			var a := vv[ii[t * 3]]
			var b := vv[ii[t * 3 + 1]]
			var c := vv[ii[t * 3 + 2]]
			var v6 := a.dot(b.cross(c))
			vol += v6
			cm += (a + b + c) * v6
	return cm / (4.0 * vol) if absf(vol) > 1e-12 else Vector3(INF, INF, INF)


func _check(cond: bool, name: String) -> void:
	if cond:
		_passed += 1
		print("  ok   ", name)
	else:
		_failed += 1
		print("  FAIL ", name)
