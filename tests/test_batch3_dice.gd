## Headless test: the batch-3 non-d6 special dice (art/models/dice/, build_batch3.py + write_batch3.py).
## A value_up-style check of the face mapping: each die's value -> local direction table (hard-coded below, mirrored in
## batch3_faces.json and art/models/dice/BATCH3.md) matches the mesh (a real face, or the d4's top vertex, lies on every
## direction, and the face is UV-mapped to that value's atlas cell, which carries ink); turning any value's direction to
## +Y reads that value back; the opposite direction is a resting face. Also: budgets with mobile LODs, centring, toon +
## ink hull, no emission, reserved colours off the bodies. The shape checks (extent cap, mobile hulls, the coin's
## symmetry, the keg's staves and ends, face prints) are in test_batch3_dice_shapes.gd.
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
	"ferryman_coin": [[1, Vector3(0.00000, 1.00000, 0.00000)], [2, Vector3(0.00000, -1.00000, 0.00000)]],
	"knucklebone_talus": [[1, Vector3(0.00000, 0.00000, 1.00000)], [3, Vector3(0.00000, 1.00000, 0.00000)], [4, Vector3(0.00000, -1.00000, 0.00000)], [6, Vector3(0.00000, 0.00000, -1.00000)]],
	"lantern_d8": [[1, Vector3(0.57735, -0.57735, 0.57735)], [2, Vector3(-0.57735, -0.57735, 0.57735)], [3, Vector3(-0.57735, -0.57735, -0.57735)], [4, Vector3(0.57735, -0.57735, -0.57735)], [5, Vector3(-0.57735, 0.57735, 0.57735)], [6, Vector3(0.57735, 0.57735, 0.57735)], [7, Vector3(0.57735, 0.57735, -0.57735)], [8, Vector3(-0.57735, 0.57735, -0.57735)]],
	"midnight_d12": [[1, Vector3(0.00000, -1.00000, 0.00000)], [2, Vector3(0.52573, -0.44721, 0.72361)], [3, Vector3(-0.52573, -0.44721, 0.72361)], [4, Vector3(-0.85065, -0.44721, -0.27639)], [5, Vector3(0.00000, -0.44721, -0.89443)], [6, Vector3(0.85065, -0.44721, -0.27639)], [7, Vector3(-0.85065, 0.44721, 0.27639)], [8, Vector3(0.00000, 0.44721, 0.89443)], [9, Vector3(0.85065, 0.44721, 0.27639)], [10, Vector3(0.52573, 0.44721, -0.72361)], [11, Vector3(-0.52573, 0.44721, -0.72361)], [12, Vector3(0.00000, 1.00000, 0.00000)]],
	"powder_keg_d6": [[1, Vector3(0.00000, 1.00000, 0.00000)], [1, Vector3(0.00000, -1.00000, 0.00000)], [2, Vector3(0.00000, 0.50000, 0.86603)], [2, Vector3(0.00000, -0.50000, -0.86603)], [3, Vector3(0.00000, -0.50000, 0.86603)], [3, Vector3(0.00000, 0.50000, -0.86603)]],
	"tithe_d10": [[1, Vector3(0.22920, -0.67071, 0.70541)], [2, Vector3(-0.60006, -0.67071, 0.43597)], [3, Vector3(-0.60006, -0.67071, -0.43597)], [4, Vector3(0.22920, -0.67071, -0.70541)], [5, Vector3(0.74172, -0.67071, 0.00000)], [6, Vector3(-0.74172, 0.67071, 0.00000)], [7, Vector3(-0.22920, 0.67071, 0.70541)], [8, Vector3(0.60006, 0.67071, 0.43597)], [9, Vector3(0.60006, 0.67071, -0.43597)], [10, Vector3(-0.22920, 0.67071, -0.70541)]],
	"verdict_d20": [[1, Vector3(-0.00000, -1.00000, 0.00000)], [2, Vector3(0.00000, -0.74536, 0.66667)], [3, Vector3(-0.57735, -0.74536, -0.33333)], [4, Vector3(0.57735, -0.74536, -0.33333)], [5, Vector3(0.93417, -0.33333, 0.12732)], [6, Vector3(0.57735, -0.33333, 0.74536)], [7, Vector3(-0.57735, -0.33333, 0.74536)], [8, Vector3(-0.93417, -0.33333, 0.12732)], [9, Vector3(-0.35682, -0.33333, -0.87268)], [10, Vector3(0.35682, -0.33333, -0.87268)], [11, Vector3(-0.35682, 0.33333, 0.87268)], [12, Vector3(0.35682, 0.33333, 0.87268)], [13, Vector3(0.93417, 0.33333, -0.12732)], [14, Vector3(0.57735, 0.33333, -0.74536)], [15, Vector3(-0.57735, 0.33333, -0.74536)], [16, Vector3(-0.93417, 0.33333, -0.12732)], [17, Vector3(-0.57735, 0.74536, 0.33333)], [18, Vector3(0.57735, 0.74536, 0.33333)], [19, Vector3(0.00000, 0.74536, -0.66667)], [20, Vector3(-0.00000, 1.00000, 0.00000)]],
}
const READ: Dictionary = {"caltrop_d4": "vertex"}
## The knucklebone's sides are curved (an astragalus), so "a face on the direction" is the extreme surface patch.
const FACE_DOT: Dictionary = {"knucklebone_talus": 0.9, "powder_keg_d6": 0.99}
## Size by resting-pose AABB volume, cube root, vs the 0.08 m d6 (the coin is the agreed thin exception).
## The three dice scaled down to the 0.050 m extent cap (Oct 19) sit a little under the d6's volume.
const VOL_RANGE: Dictionary = {"ferryman_coin": [0.055, 0.07], "caltrop_d4": [0.07, 0.09], "lantern_d8": [0.07, 0.09], "knucklebone_talus": [0.07, 0.09]}

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
				if die != "knucklebone_talus" and die != "powder_keg_d6":
					in_cell = in_cell and cc == cell
		if die == "knucklebone_talus" or die == "powder_keg_d6":
			in_cell = hits > 0 and Vector2i(int(best_c.x), int(best_c.y)) == cell  # the outermost patch on d
		_check(hits > 0 and in_cell, "%s: value %d has a face on %s mapped to atlas cell %s" % [tag, v, d, cell])
		if pc and tex != null:
			_check(_cell_has_ink(tex, cell), "%s: atlas cell %s (value %d) carries a printed mark" % [tag, cell, v])
	inst.free()
	return tris


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
