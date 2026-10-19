## Headless test: the Blender-built special dice (art/models/dice/, build_special_dice.py) match
## the face convention the 3D table reads (DieVisual.FACE_AXES + DieVisual.PIPS), are centred and
## die-sized, stay on budget, use the toon materials + ink hull, and keep their silhouettes
## distinct (chips, spikes, beads or chamfer). See art/models/dice/SPECIAL_DICE.md.
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
	_check(aabb.get_center().length() < 0.0015, "%s: centred on the origin (%s)" % [die, aabb.get_center()])
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
		if sname.ends_with("_pip"):
			pip_verts = arrays[Mesh.ARRAY_VERTEX]
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
	return false


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
