## Headless test: the batch-3 non-d6 special dice (art/models/dice/, build_batch3.py + write_batch3.py).
## A value_up-style check of the face mapping: each die's value -> local direction table (hard-coded below, mirrored in
## batch3_faces.json and art/models/dice/BATCH3.md) matches the mesh (a real face, or the d4's top vertex, lies on every
## direction, and the face is UV-mapped to that value's atlas cell, which carries ink); turning any value's direction to
## +Y reads that value back; the opposite direction is a resting face. Also: budgets with mobile LODs, centring, toon +
## ink hull, no emission, reserved colours off the bodies, the coin's heads/tails symmetry (Oct 19: "the coin keeps
## landing the same side") and the keg's domed ends.
##
## Run:
##   godot --headless --path . --script res://tests/test_batch3_dice.gd
extends SceneTree

const DIR: String = "res://art/models/dice/"
const PC_MAX_TRIS: int = 650
const MOBILE_MAX_TRIS: int = 320
const TOON_SHADER: String = "res://shaders/3d/toon_noir.gdshader"
const OUTLINE_SHADER: String = "res://shaders/3d/outline.gdshader"
## Reserved for UI / roles, never on a body: Soul cyan, Danger, Satanic violet glow, felt green, Ember.
const RESERVED: Array[Color] = [Color("#4FE6E0"), Color("#FF2E3E"), Color("#9B3DFF"), Color("#123A36"), Color("#0B2724"), Color("#FF6A1A")]
const LAMP: Color = Color("#FFB070")
## Atlas: 5 x 5 cells, value v in cell v - 1 (row-major, cell (v - 1) % 5, (v - 1) / 5).
const CELLS: int = 5
## Value -> local direction (Godot space, +Y up), as read by the game: the value whose direction is most nearly
## world-up is the result. The d4 ("vertex") reads its top vertex; the others read the top face. The keg's opposite
## staves carry the same value.
const TABLE: Dictionary = {
	"caltrop_d4": [[1, Vector3(0.00000, 1.00000, 0.00000)], [2, Vector3(0.00000, -0.33333, 0.94281)], [3, Vector3(-0.81650, -0.33333, -0.47140)], [4, Vector3(0.81650, -0.33333, -0.47140)]],
	"ferryman_d2": [[1, Vector3(0.00000, 1.00000, 0.00000)], [2, Vector3(0.00000, -1.00000, 0.00000)]],
	"knucklebone_talus": [[1, Vector3(0.00000, 0.00000, 1.00000)], [3, Vector3(0.00000, 1.00000, 0.00000)], [4, Vector3(0.00000, -1.00000, 0.00000)], [6, Vector3(0.00000, 0.00000, -1.00000)]],
	"lantern_d8": [[1, Vector3(0.57735, -0.57735, 0.57735)], [2, Vector3(-0.57735, -0.57735, 0.57735)], [3, Vector3(-0.57735, -0.57735, -0.57735)], [4, Vector3(0.57735, -0.57735, -0.57735)], [5, Vector3(-0.57735, 0.57735, 0.57735)], [6, Vector3(0.57735, 0.57735, 0.57735)], [7, Vector3(0.57735, 0.57735, -0.57735)], [8, Vector3(-0.57735, 0.57735, -0.57735)]],
	"midnight_d12": [[1, Vector3(0.00000, -1.00000, 0.00000)], [2, Vector3(0.52573, -0.44721, 0.72361)], [3, Vector3(-0.52573, -0.44721, 0.72361)], [4, Vector3(-0.85065, -0.44721, -0.27639)], [5, Vector3(0.00000, -0.44721, -0.89443)], [6, Vector3(0.85065, -0.44721, -0.27639)], [7, Vector3(-0.85065, 0.44721, 0.27639)], [8, Vector3(0.00000, 0.44721, 0.89443)], [9, Vector3(0.85065, 0.44721, 0.27639)], [10, Vector3(0.52573, 0.44721, -0.72361)], [11, Vector3(-0.52573, 0.44721, -0.72361)], [12, Vector3(0.00000, 1.00000, 0.00000)]],
	"powder_keg_d3": [[1, Vector3(0.00000, 1.00000, 0.00000)], [1, Vector3(0.00000, -1.00000, 0.00000)], [2, Vector3(0.00000, 0.50000, 0.86603)], [2, Vector3(0.00000, -0.50000, -0.86603)], [3, Vector3(0.00000, -0.50000, 0.86603)], [3, Vector3(0.00000, 0.50000, -0.86603)]],
	"tithe_d10": [[1, Vector3(0.22920, -0.67071, 0.70541)], [2, Vector3(-0.60006, -0.67071, 0.43597)], [3, Vector3(-0.60006, -0.67071, -0.43597)], [4, Vector3(0.22920, -0.67071, -0.70541)], [5, Vector3(0.74172, -0.67071, 0.00000)], [6, Vector3(-0.74172, 0.67071, 0.00000)], [7, Vector3(-0.22920, 0.67071, 0.70541)], [8, Vector3(0.60006, 0.67071, 0.43597)], [9, Vector3(0.60006, 0.67071, -0.43597)], [10, Vector3(-0.22920, 0.67071, -0.70541)]],
	"verdict_d20": [[1, Vector3(-0.00000, -1.00000, 0.00000)], [2, Vector3(0.00000, -0.74536, 0.66667)], [3, Vector3(-0.57735, -0.74536, -0.33333)], [4, Vector3(0.57735, -0.74536, -0.33333)], [5, Vector3(0.93417, -0.33333, 0.12732)], [6, Vector3(0.57735, -0.33333, 0.74536)], [7, Vector3(-0.57735, -0.33333, 0.74536)], [8, Vector3(-0.93417, -0.33333, 0.12732)], [9, Vector3(-0.35682, -0.33333, -0.87268)], [10, Vector3(0.35682, -0.33333, -0.87268)], [11, Vector3(-0.35682, 0.33333, 0.87268)], [12, Vector3(0.35682, 0.33333, 0.87268)], [13, Vector3(0.93417, 0.33333, -0.12732)], [14, Vector3(0.57735, 0.33333, -0.74536)], [15, Vector3(-0.57735, 0.33333, -0.74536)], [16, Vector3(-0.93417, 0.33333, -0.12732)], [17, Vector3(-0.57735, 0.74536, 0.33333)], [18, Vector3(0.57735, 0.74536, 0.33333)], [19, Vector3(0.00000, 0.74536, -0.66667)], [20, Vector3(-0.00000, 1.00000, 0.00000)]],
}
const READ: Dictionary = {"caltrop_d4": "vertex"}
## The knucklebone's sides are curved (an astragalus), so "a face on the direction" is the extreme surface patch.
const FACE_DOT: Dictionary = {"knucklebone_talus": 0.9, "powder_keg_d3": 0.99}
## Size by resting-pose AABB volume, cube root, vs the 0.08 m d6 (the coin is the agreed thin exception).
## The three dice scaled down to the 0.050 m extent cap (Oct 19) sit a little under the d6's volume.
const VOL_RANGE: Dictionary = {"ferryman_d2": [0.055, 0.07], "caltrop_d4": [0.07, 0.09], "lantern_d8": [0.07, 0.09], "knucklebone_talus": [0.07, 0.09]}
## Size cap for non-d6 dice: max per-axis half-extent from the origin (the centre of mass) is 0.050 m, per PM and
## Godot Dev (Oct 19). The test allows 0.051 m because the Tithe d10 passes at 0.0507 (~2% over) by PM's ruling.
## (d6s keep tests/test_special_dice.gd's 0.042 m box cap.)
const MAX_EXTENT: float = 0.051
## Scaled to the cap on Oct 19 (Caltrop x0.849, Knucklebone x0.866, Lantern x0.943, PC and mobile alike).
const CAPPED: Dictionary = {"caltrop_d4": 0.050, "knucklebone_talus": 0.050, "lantern_d8": 0.050}
## Godot Dev builds every non-d6 hull from the *mobile* mesh: its extents must match the PC visual within 0.5 mm.
const HULL_TOL: float = 0.0005
## Symmetric by design: their mobile meshes (and hulls) keep the PC mesh's mirror symmetries. The knucklebone is
## organic (only centred).
const SYMMETRIC: Array[String] = ["caltrop_d4", "lantern_d8", "tithe_d10", "midnight_d12", "verdict_d20", "ferryman_d2", "powder_keg_d3"]

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	print("=== Dice of the Damned: batch-3 special dice (value -> direction) tests ===")
	var faces: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "batch3_faces.json"))
	_check(faces != null and faces.size() == TABLE.size(), "batch3_faces.json lists the %d dice" % TABLE.size())
	if faces == null:
		quit(1)
		return
	for die: String in TABLE:
		_check(faces.has(die), "%s: in batch3_faces.json" % die)
		if not faces.has(die):
			continue
		_check_table(die, faces[die])
		var pc := _check_mesh(die, String(faces[die]["file"]), faces[die], true)
		var mob := _check_mesh(die, String(faces[die]["mobile"]), faces[die], false)
		_check(mob > 0 and mob < pc, "%s: mobile LOD %d tris < PC %d" % [die, mob, pc])
	_check_coin()
	_check_keg_ends()
	var prints: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "batch3_face_prints.json"))
	for die: String in TABLE:
		_check_extents(die, faces[die])
		_check_face_prints(die, prints.get(die, {}))
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


## The JSON the showcase / Godot Dev read agrees with the hard-coded table, and the read is unambiguous.
func _check_table(die: String, spec: Dictionary) -> void:
	var want: Array = TABLE[die]
	var got: Array = spec["dirs"]
	var same := got.size() == want.size()
	if same:
		for i in want.size():
			var g := Vector3(got[i][1][0], got[i][1][1], got[i][1][2])
			same = same and int(got[i][0]) == int(want[i][0]) and g.distance_to(want[i][1]) < 1e-3
	_check(same, "%s: batch3_faces.json dirs match the value -> direction table" % die)
	_check(String(spec["read"]) == String(READ.get(die, "face")), "%s: read by %s" % [die, READ.get(die, "face")])
	# value_up: turn each value's direction to +Y; the reader returns that value (and nothing else is within 10 deg).
	var ok := true
	for e: Array in want:
		var q := Basis(Quaternion((e[1] as Vector3).normalized(), Vector3.UP))
		var best := -2.0
		var second := -2.0
		var bv := 0
		for f: Array in want:
			var y := (q * (f[1] as Vector3)).normalized().y
			if y > best:
				second = best
				best = y
				bv = int(f[0])
			elif y > second:
				second = y
		ok = ok and bv == int(e[0]) and second < cos(deg_to_rad(10.0))
	_check(ok, "%s: value_up reads every value back when its direction is turned up" % die)


## Mesh checks; returns the triangle count.
func _check_mesh(die: String, file: String, spec: Dictionary, pc: bool) -> int:
	var tag := "%s%s" % [die, "" if pc else " (mobile)"]
	var scene := load(DIR + file) as PackedScene
	_check(scene != null, "%s: %s loads" % [tag, file])
	if scene == null:
		return 0
	var inst := scene.instantiate()
	var mi := inst.get_child(0) as MeshInstance3D if inst.get_child_count() == 1 else null
	_check(mi != null and mi.get_child_count() == 0, "%s: exactly one mesh node, nothing else" % tag)
	if mi == null:
		inst.free()
		return 0
	_check(mi.transform.is_equal_approx(Transform3D.IDENTITY), "%s: mesh at the origin, scale 1" % tag)
	var mesh := mi.mesh
	var aabb := mesh.get_aabb()
	# The origin is the centre of mass (what a physics body spins about): solid centroid within 1.5 mm. The AABB is
	# centred too, except on the d4 (a tetrahedron's centroid is not its box centre) and the asymmetric astragalus.
	var cm := _centroid(mesh)
	_check(cm.length() < 0.0015, "%s: centre of mass on the origin (%s)" % [tag, cm])
	if die != "caltrop_d4" and die != "knucklebone_talus":
		_check(aabb.get_center().length() < 0.0015, "%s: AABB centred on the origin (%s)" % [tag, aabb.get_center()])
	var tris := 0
	var names: Array[String] = []
	var toon := true
	var lit := false
	for s in mesh.get_surface_count():
		names.append(mesh.surface_get_name(s))
		tris += (mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		var m := mesh.surface_get_material(s) as ShaderMaterial
		toon = toon and m != null and m.shader.resource_path == TOON_SHADER
		var e: Variant = m.get_shader_parameter("emission_energy") if m != null else null
		lit = lit or (e != null and float(e) > 0.0)
	_check(names == Array(spec["slots"] as Array, TYPE_STRING, "", null), "%s: material slots %s" % [tag, names])
	_check(toon, "%s: every slot uses the toon shader" % tag)
	_check(not lit, "%s: no slot is emissive (no fire on the dice)" % tag)
	var cap := PC_MAX_TRIS if pc else MOBILE_MAX_TRIS
	_check(tris <= cap, "%s: %d tris <= %d" % [tag, tris, cap])
	var body := mesh.surface_get_material(0) as ShaderMaterial
	var ink := body.next_pass as ShaderMaterial if body != null else null
	_check(ink != null and ink.shader.resource_path == OUTLINE_SHADER, "%s: body carries the ink hull" % tag)
	if body != null:
		var alb := body.get_shader_parameter("albedo") as Color
		var seen := Color(alb.r * LAMP.r, alb.g * LAMP.g, alb.b * LAMP.b)  # under the #FFB070 table lamp
		var far := true
		for r: Color in RESERVED:
			# Authored and lamp-lit colour both clear in RGB; a dark lit colour may sit close in RGB if its hue is
			# clearly different (Tithe's lit navy vs the dark felt: 39 deg apart).
			var hue_apart := seen.s > 0.3 and absf(wrapf(seen.h - r.h, -0.5, 0.5)) > 25.0 / 360.0
			far = far and _rgb_dist(alb, r) > 0.12 and (_rgb_dist(seen, r) > 0.12 or hue_apart)
		_check(far, "%s: body albedo %s (lit %s) stays clear of the reserved colours" % [tag, alb.to_html(false), seen.to_html(false)])
	# Size.
	var lo := 0.075
	var hi := 0.09
	if VOL_RANGE.has(die):
		lo = VOL_RANGE[die][0]
		hi = VOL_RANGE[die][1]
	var cr := float(spec["rest_volume_cuberoot"])
	_check(cr >= lo and cr <= hi, "%s: resting AABB volume cube root %.4f m in %.3f-%.3f" % [tag, cr, lo, hi])
	# Geometry + UVs per direction (body surface).
	var arr := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var all_verts := PackedVector3Array()
	for s in mesh.get_surface_count():
		all_verts.append_array(mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX])
	var tex: Image = null
	if body != null and body.get_shader_parameter("overlay_tex") != null:
		tex = (body.get_shader_parameter("overlay_tex") as Texture2D).get_image()
		if tex != null and tex.is_compressed():
			tex.decompress()
	var thr: float = FACE_DOT.get(die, 0.995)
	for e: Array in TABLE[die]:
		var v := int(e[0])
		var d := (e[1] as Vector3).normalized()
		var cell := Vector2i((v - 1) % CELLS, (v - 1) / CELLS)
		if READ.get(die, "face") == "vertex":
			# The d4: the farthest vertex along d sits on d (a point), and -d is a flat face (it rests on it).
			var far_v := Vector3.ZERO
			for p in all_verts:
				if p.dot(d) > far_v.dot(d):
					far_v = p
			_check(far_v.normalized().dot(d) > 0.995, "%s: value %d's tip sits on its direction" % [tag, v])
			_check(_face_on(verts, idx, -d, 0.999) > 0, "%s: value %d up = resting on the opposite face" % [tag, v])
			continue
		var hits := 0
		var in_cell := true
		var best := -1.0
		var best_c := Vector3.ZERO
		for t in idx.size() / 3:
			var a := verts[idx[t * 3]]
			var b := verts[idx[t * 3 + 1]]
			var c := verts[idx[t * 3 + 2]]
			var n := (b - a).cross(c - a)
			if n.length() < 1e-12:
				continue
			n = n.normalized()
			if n.dot(d) < 0.0:
				n = -n  # winding-agnostic: what matters is the plane
			var cen := (a + b + c) / 3.0
			if n.dot(d) >= thr and cen.dot(d) > 0.0:
				hits += 1
				var uv := (uvs[idx[t * 3]] + uvs[idx[t * 3 + 1]] + uvs[idx[t * 3 + 2]]) / 3.0
				var cc := Vector2i(int(floor(uv.x * CELLS)), int(floor(uv.y * CELLS)))
				if cen.dot(d) > best:
					best = cen.dot(d)
					best_c = Vector3(cc.x, cc.y, 0)
				if die != "knucklebone_talus" and die != "powder_keg_d3":
					in_cell = in_cell and cc == cell
		if die == "knucklebone_talus" or die == "powder_keg_d3":
			in_cell = hits > 0 and Vector2i(int(best_c.x), int(best_c.y)) == cell  # the outermost patch on d
		_check(hits > 0 and in_cell, "%s: value %d has a face on %s mapped to atlas cell %s" % [tag, v, d, cell])
		if pc and tex != null:
			_check(_cell_has_ink(tex, cell), "%s: atlas cell %s (value %d) carries a printed mark" % [tag, cell, v])
	inst.free()
	return tris


## Ferryman's Coin: heads and tails are mirror images in thickness, rim and edge (relief lives in the texture only),
## the volume centroid sits on the origin, and the convex hull a sandbox builds from it is symmetric too.
func _check_coin() -> void:
	for file: String in ["ferryman_d2.glb", "ferryman_d2_mobile.glb"]:
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


## Powder Keg: domed ends with only a small lid, so it rarely stands on an end (Oct 19: 0/40 random throws).
func _check_keg_ends() -> void:
	var inst := (load(DIR + "powder_keg_d3.glb") as PackedScene).instantiate()
	var mesh := (inst.get_child(0) as MeshInstance3D).mesh
	inst.free()
	var xmax := 0.0
	for s in mesh.get_surface_count():
		for p: Vector3 in mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			xmax = maxf(xmax, absf(p.x))
	var lid := 0.0
	for s in mesh.get_surface_count():
		for p: Vector3 in mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			if absf(p.x) > xmax - 0.0015:
				lid = maxf(lid, Vector2(p.y, p.z).length())
	_check(lid < 0.008, "powder_keg_d3: flat lid radius %.4f m < 0.008 (domed ends, rarely stands on an end)" % lid)


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
		_check(m <= MAX_EXTENT + 1e-5, "%s (%s): max per-axis half-extent %.4f m <= %.3f (0.050 m cap; Tithe passes at 0.0507 by PM's ruling)" % [die, pair[1], m, MAX_EXTENT])
		if CAPPED.has(die):
			_check(m <= float(CAPPED[die]) + 1e-5, "%s (%s): scaled to the cap, half-extent %.4f m <= %.3f" % [die, pair[1], m, CAPPED[die]])
	var cm := _centroid(mob)
	_check(cm.length() < 0.0005, "%s (mobile): centre of mass within 0.5 mm of the origin (%s), so a hull from it spins true" % [die, cm])
	var hull := mob.create_convex_shape(true, false) as ConvexPolygonShape3D
	var e_hull := _half_extents(hull.points)
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
		var dirs: Array = TABLE[die]
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
func _check_face_prints(die: String, entry: Dictionary) -> void:
	var faces: Dictionary = entry.get("faces", {})
	var values := {}
	for e: Array in TABLE[die]:
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
		"ferryman_d2":
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


func _face_on(verts: PackedVector3Array, idx: PackedInt32Array, d: Vector3, thr: float) -> int:
	var hits := 0
	for t in idx.size() / 3:
		var a := verts[idx[t * 3]]
		var n := (verts[idx[t * 3 + 1]] - a).cross(verts[idx[t * 3 + 2]] - a)
		if n.length() > 1e-12 and absf(n.normalized().dot(d)) >= thr and a.dot(d) > 0.0:
			hits += 1
	return hits


## The cell's middle shows a mark: ink coverage varies (overlay alpha), or the painted texels vary in brightness.
func _cell_has_ink(img: Image, cell: Vector2i) -> bool:
	var w := img.get_width() / float(CELLS)
	var x0 := int(cell.x * w + w * 0.2)
	var y0 := int(cell.y * w + w * 0.2)
	var lo := 9.0
	var hi := -9.0
	var alo := 9.0
	var ahi := -9.0
	for y in range(y0, int(y0 + w * 0.6), 3):
		for x in range(x0, int(x0 + w * 0.6), 3):
			var c := img.get_pixel(x, y)
			alo = minf(alo, c.a)
			ahi = maxf(ahi, c.a)
			if c.a > 0.5:
				lo = minf(lo, c.get_luminance())
				hi = maxf(hi, c.get_luminance())
	return ahi - alo > 0.5 or hi - lo > 0.25


func _rgb_dist(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


func _check(cond: bool, name: String) -> void:
	if cond:
		_passed += 1
		print("  ok   ", name)
	else:
		_failed += 1
		print("  FAIL ", name)
