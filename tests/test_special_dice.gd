## Headless test: the Blender-built special dice (art/models/dice/, build_special_dice.py) match
## the face convention the 3D table reads (DieVisual.FACE_AXES + DieVisual.PIPS), are centred and
## die-sized, stay on budget, use the toon materials + ink hull, and keep their silhouettes
## distinct (chips, spikes, beads, chamfer; batch 2: waist, fins, steps, seals, coves, collar). See
## art/models/dice/SPECIAL_DICE.md.
##
## Run:
##   godot --headless --path . --script res://tests/test_special_dice.gd
extends SceneTree

const DIR: String = "res://art/models/dice/"
## Triangle budget per die (~2k, same as the Bone d6's 1,988).
const MAX_TRIS: int = 2000
const TOON_SHADERS: Array[String] = ["res://shaders/3d/toon_noir.gdshader", "res://art/models/dice/shaders/toon_mirror.gdshader"]
const OUTLINE_SHADER: String = "res://shaders/3d/outline.gdshader"
## name -> [material slots, min AABB, max AABB, silhouette check]
const DICE: Dictionary = {
	"mirror_d6": [["mirror_body", "mirror_pip"], 0.08, 0.08, "chamfer"],
	"cracked_d6": [["cracked_body", "cracked_pip", "cracked_crack"], 0.08, 0.08, "chips"],
	"hellfire_d6": [["hellfire_body", "hellfire_pip", "hellfire_seam"], 0.088, 0.096, "spikes"],
	"gilded_d6": [["gilded_body", "gilded_pip", "gilded_panel"], 0.084, 0.09, "beads"],
	# batch 2
	"twin_flame_d6": [["twin_flame_body", "twin_flame_pip", "twin_flame_half", "twin_flame_pip_light", "twin_flame_cleft"], 0.08, 0.08, "waist"],
	"wanderer_d6": [["wanderer_body", "wanderer_pip", "wanderer_fin"], 0.088, 0.096, "fins"],
	"bellows_d6": [["bellows_body", "bellows_pip", "bellows_pleat"], 0.08, 0.08, "steps"],
	"blood_pact_d6": [["blood_pact_body", "blood_pact_pip", "blood_pact_seal"], 0.088, 0.098, "seals"],
	"coven_d6": [["coven_body", "coven_pip", "coven_cove"], 0.08, 0.08, "coves"],
	"last_breath_d6": [["last_breath_body", "last_breath_pip", "last_breath_collar"], 0.08, 0.092, "collar"],
}

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	print("=== Dice of the Damned: special dice model tests ===")
	var edge := TuningData.new().die_size
	for die: String in DICE:
		_check_die(die, DICE[die], edge)
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check_die(die: String, spec: Array, edge: float) -> void:
	var path := DIR + die + ".glb"
	var scene := load(path) as PackedScene
	_check(scene != null, "%s: loads" % die)
	if scene == null:
		return
	var inst := scene.instantiate()
	var meshes: Array[MeshInstance3D] = []
	_find_meshes(inst, meshes)
	_check(meshes.size() == 1 and inst.get_child_count() == 1, "%s: exactly one mesh node" % die)
	_check(_no_extras(inst), "%s: no physics bodies, animations, cameras or lights" % die)
	if meshes.is_empty():
		inst.free()
		return
	var mi := meshes[0]
	_check(mi.transform.is_equal_approx(Transform3D.IDENTITY), "%s: mesh at the origin, scale 1" % die)
	var mesh := mi.mesh
	var aabb := mesh.get_aabb()
	_check(aabb.get_center().length() < 0.0015 or (spec[3] == "collar" and absf(aabb.get_center().x) < 0.0005 and absf(aabb.get_center().z) < 0.0005), "%s: centred on the origin (%s)" % [die, aabb.get_center()])
	var lo := float(spec[1])
	var hi := float(spec[2])
	var sized := true
	for i in 3:
		sized = sized and aabb.size[i] >= lo - 0.0005 and aabb.size[i] <= hi + 0.0005
	_check(sized, "%s: AABB %s within %.3f-%.3f m" % [die, aabb.size, lo, hi])
	var tris := 0
	var names: Array[String] = []
	var toon := true
	var all_verts := PackedVector3Array()
	var pip_verts := PackedVector3Array()
	var accent_verts := PackedVector3Array()
	for s in mesh.get_surface_count():
		var mat := mesh.surface_get_material(s) as ShaderMaterial
		toon = toon and mat != null and mat.shader.resource_path in TOON_SHADERS
		var sname: String = mesh.surface_get_name(s)
		names.append(sname)
		var arrays := mesh.surface_get_arrays(s)
		tris += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		all_verts.append_array(arrays[Mesh.ARRAY_VERTEX])
		if sname.ends_with("_pip") or sname.ends_with("_pip_light"):
			pip_verts.append_array(arrays[Mesh.ARRAY_VERTEX])  # Twin Flame: dark + light pips
		elif not sname.ends_with("_body"):
			accent_verts = arrays[Mesh.ARRAY_VERTEX]
	_check(names == Array(spec[0] as Array, TYPE_STRING, "", null), "%s: material slots %s" % [die, names])
	_check(toon, "%s: every slot uses a toon shader" % die)
	var body := mesh.surface_get_material(0) as ShaderMaterial
	var ink := body.next_pass as ShaderMaterial if body != null else null
	_check(ink != null and ink.shader.resource_path == OUTLINE_SHADER, "%s: body carries the ink hull" % die)
	_check(tris <= MAX_TRIS, "%s: %d tris <= %d" % [die, tris, MAX_TRIS])
	# The 6 face planes sit at +-edge/2 (0.08 m die), whatever sticks out past the corners.
	var planes := true
	for slot: int in DieVisual.FACE_AXES:
		var n := DieVisual.FACE_AXES[slot] as Vector3
		var on_plane := 0
		for v in all_verts:
			if absf(v.dot(n) - edge * 0.5) < 0.0003 and (v - n * v.dot(n)).length() < edge * 0.56:
				on_plane += 1
		planes = planes and on_plane >= 3
	_check(planes, "%s: all 6 face planes at %.3f m from the centre" % [die, edge * 0.5])
	# Pips where DieVisual puts them.
	var step := DieVisual.PIP_STEP * edge
	for slot: int in DieVisual.FACE_AXES:
		var n := DieVisual.FACE_AXES[slot] as Vector3
		var found := {}
		for v in pip_verts:
			if v.dot(n) > edge * 0.41 and absf((v - n * v.dot(n)).x) < edge * 0.4 and absf((v - n * v.dot(n)).y) < edge * 0.4 and absf((v - n * v.dot(n)).z) < edge * 0.4:
				found[Vector3i(((v - n * v.dot(n)) / step).round())] = true
		var u := Vector3.UP if absf(n.y) < 0.5 else Vector3.RIGHT
		u = (u - n * u.dot(n)).normalized()
		var w := n.cross(u)
		var want := {}
		for spot: Vector2 in DieVisual.PIPS[slot]:
			want[Vector3i((u * spot.x + w * spot.y).round())] = true
		_check(found.size() == want.size() and found.keys().all(func(k: Vector3i) -> bool: return want.has(k)),
			"%s: slot %d (%s) shows %d pips where DieVisual puts them" % [die, slot, n, slot])
	_check(_silhouette(String(spec[3]), all_verts, accent_verts, edge), "%s: silhouette cue (%s) present" % [die, spec[3]])
	inst.free()


## The per-die silhouette cue that makes it read in a pile.
func _silhouette(kind: String, verts: PackedVector3Array, accent: PackedVector3Array, edge: float) -> bool:
	var h := edge * 0.5
	match kind:
		"chamfer":
			# Flat 2-facet chamfer: no vertex near the sharp-cube corner, corners cut well inside.
			var far := 0.0
			for v in verts:
				far = maxf(far, v.length())
			return far < h * sqrt(3.0) * 0.86
		"chips":
			# 3 corners bitten off: a round bevel corner sits ~0.0094 m from the cube corner,
			# a chipped one has no geometry within 0.013 m.
			var empty := 0
			for c in _corners(h):
				var hit := false
				for v in verts:
					if v.distance_to(c) < 0.013:
						hit = true
						break
				empty += 0 if hit else 1
			return empty >= 3 and accent.size() > 0
		"spikes":
			# All 8 corners carry a spike tip beyond the cube.
			for c in _corners(h):
				var hit := false
				for v in verts:
					if v.normalized().dot(c.normalized()) > 0.995 and v.length() > h * sqrt(3.0) * 1.05:
						hit = true
						break
				if not hit:
					return false
			return accent.size() > 0
		"beads":
			# A bead on every corner, poking past the 0.08 m cube.
			for c in _corners(h):
				var hit := false
				for v in verts:
					if v.normalized().dot(c.normalized()) > 0.98 and maxf(absf(v.x), maxf(absf(v.y), absf(v.z))) > h + 0.001:
						hit = true
						break
				if not hit:
					return false
			return accent.size() > 0
		"waist":
			# The 4 edges crossing the x = 0 seam are notched (no geometry near their midpoints), the corners are
			# whole, and the second half is its own surface.
			for m in [Vector3(0, h, h), Vector3(0, h, -h), Vector3(0, -h, h), Vector3(0, -h, -h)]:
				if _nearest(verts, m) < 0.009:
					return false
			return _nearest(verts, Vector3(h, h, h)) < 0.012 and accent.size() > 0
		"fins":
			# A compass point past the bevel at the middle of all 12 edges.
			for m in _edge_mids(h):
				var hit := false
				for v in verts:
					if v.normalized().dot(m.normalized()) > 0.995 and v.length() > m.length() * 1.06:
						hit = true
						break
				if not hit:
					return false
			return accent.size() > 0
		"steps":
			# Every edge is folded into a staircase: its midpoint is carved away, and the 3 step risers exist.
			for m in _edge_mids(h):
				if _nearest(verts, m) < 0.006:
					return false
			for depth in [0.003, 0.0062, 0.0095]:
				var hit := false
				for v in accent:
					if absf(absf(v.x) - (h - depth)) < 0.0004 and absf(v.y) > h - 0.011:
						hit = true
						break
				if not hit:
					return false
			return true
		"seals":
			# Seals stand proud on the (+,+,+) and (-,-,-) corners only.
			var proud := 0
			for c in _corners(h):
				var far := 0.0
				for v in verts:
					if v.normalized().dot(c.normalized()) > 0.99:
						far = maxf(far, v.length())
				if far > h * sqrt(3.0) * 0.98:
					proud += 1 if signf(c.x) == signf(c.y) and signf(c.y) == signf(c.z) else 100
			return proud == 2 and accent.size() > 0
		"coves":
			# All 12 edges scooped concave: midpoints carved away, and the face plane runs out to >= 0.03 m
			# while the cove surface dips in (accent verts inside the cube's edge region).
			for m in _edge_mids(h):
				if _nearest(verts, m) < 0.007:
					return false
			var concave := false
			for v in accent:
				var a := absf(v.x)
				var b := absf(v.y)
				if a > h - 0.006 and b > h - 0.006 and a < h - 0.001 and b < h - 0.001:
					concave = true  # a cove point sits inside the corner square, not on a convex bevel
					break
			return concave
		"collar":
			# A hoop stands proud of the 4 side faces near the +Y end only.
			var ring := 0
			for v in verts:
				if maxf(absf(v.x), absf(v.z)) > h + 0.002:
					if v.y < 0.025 or v.y > 0.036:
						return false
					ring += 1
			return ring >= 16 and accent.size() > 0
	return false


func _nearest(verts: PackedVector3Array, p: Vector3) -> float:
	var best := INF
	for v in verts:
		best = minf(best, v.distance_to(p))
	return best


func _edge_mids(h: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for a in [-1, 1]:
		for b in [-1, 1]:
			out.append(Vector3(0, a, b) * h)
			out.append(Vector3(a, 0, b) * h)
			out.append(Vector3(a, b, 0) * h)
	return out


func _corners(h: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for x in [-1, 1]:
		for y in [-1, 1]:
			for z in [-1, 1]:
				out.append(Vector3(x, y, z) * h)
	return out


func _find_meshes(n: Node, out: Array[MeshInstance3D]) -> void:
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		_find_meshes(c, out)


func _no_extras(n: Node) -> bool:
	if n is CollisionObject3D or n is CollisionShape3D or n is AnimationPlayer or n is Camera3D or n is Light3D:
		return false
	for c in n.get_children():
		if not _no_extras(c):
			return false
	return true


func _check(cond: bool, name: String) -> void:
	if cond:
		_passed += 1
		print("  ok   ", name)
	else:
		_failed += 1
		print("  FAIL ", name)
