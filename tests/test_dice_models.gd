## Headless test: the Blender-built Bone d6 (art/models/dice/) matches the face convention the
## 3D table reads (DieVisual.FACE_AXES + DieVisual.PIPS), fits the die size, and stays on budget.
## If the model and DieVisual disagreed, the remapped face shown on top would not be the seeded value.
##
## Run:
##   godot --headless --path . --script res://tests/test_dice_models.gd
extends SceneTree

const BONE_PATH: String = "res://art/models/dice/bone_d6.glb"
## Triangle budget per die (poc_3d.md 3: ~800 body + ~1.2k drilled pips).
const MAX_TRIS: int = 2500

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	print("=== Dice of the Damned: dice model tests ===")
	_check_model(BONE_PATH, [1, 2, 3, 4, 5, 6], TuningData.new().die_size)
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check_model(path: String, labels: Array, edge: float) -> void:
	var scene := load(path) as PackedScene
	_check(scene != null, "%s: loads" % path)
	if scene == null:
		return
	var inst := scene.instantiate()
	var meshes: Array[MeshInstance3D] = []
	_find_meshes(inst, meshes)
	_check(meshes.size() == 1 and inst.get_child_count() == 1, "%s: exactly one mesh node" % path)
	_check(_no_extras(inst), "%s: no physics bodies, animations, cameras or lights" % path)
	if meshes.is_empty():
		inst.free()
		return
	var mi := meshes[0]
	_check(mi.global_transform.is_equal_approx(Transform3D.IDENTITY) if mi.is_inside_tree() else mi.transform.is_equal_approx(Transform3D.IDENTITY),
		"%s: mesh at the origin, scale 1" % path)
	var mesh := mi.mesh
	var aabb := mesh.get_aabb()
	_check(aabb.size.is_equal_approx(Vector3.ONE * edge) and aabb.get_center().is_zero_approx(),
		"%s: %.2f m cube centred on the origin" % [path, edge])
	var tris := 0
	var pip_verts := PackedVector3Array()
	var names: Array[String] = []
	var toon := true
	for s in mesh.get_surface_count():
		var mat := mesh.surface_get_material(s) as ShaderMaterial
		toon = toon and mat != null and mat.shader.resource_path == "res://shaders/3d/toon_noir.gdshader"
		names.append(mesh.surface_get_name(s))
		var arrays := mesh.surface_get_arrays(s)
		tris += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		if mesh.surface_get_name(s).ends_with("_pip"):
			pip_verts = arrays[Mesh.ARRAY_VERTEX]
	_check(names == ["bone_body", "bone_pip"], "%s: two material slots, body + pips (%s)" % [path, names])
	_check(toon, "%s: both slots use the toon shader" % path)
	_check(tris <= MAX_TRIS, "%s: %d tris <= %d" % [path, tris, MAX_TRIS])
	var step := DieVisual.PIP_STEP * edge
	for slot: int in DieVisual.FACE_AXES:
		var n := DieVisual.FACE_AXES[slot] as Vector3
		# Pip cavity vertices on this face, snapped to the pip grid.
		var found := {}
		for v in pip_verts:
			if v.dot(n) > edge * 0.41:
				found[Vector3i(((v - n * v.dot(n)) / step).round())] = true
		# Where DieVisual._add_pips puts the pips for this slot's label.
		var u := Vector3.UP if absf(n.y) < 0.5 else Vector3.RIGHT
		u = (u - n * u.dot(n)).normalized()
		var w := n.cross(u)
		var want := {}
		for spot: Vector2 in DieVisual.PIPS[labels[slot - 1]]:
			want[Vector3i((u * spot.x + w * spot.y).round())] = true
		_check(found.size() == want.size() and found.keys().all(func(k: Vector3i) -> bool: return want.has(k)),
			"%s: slot %d (%s) shows %d pips where DieVisual puts them" % [path, slot, n, labels[slot - 1]])
	var sums_to_7 := true
	for pair: Array in [[1, 6], [2, 5], [3, 4]]:
		sums_to_7 = sums_to_7 and labels[pair[0] - 1] + labels[pair[1] - 1] == 7
	_check(sums_to_7, "%s: opposite faces sum to 7" % path)
	inst.free()


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
