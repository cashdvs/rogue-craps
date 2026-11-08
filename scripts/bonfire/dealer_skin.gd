## CPU skin that uses the engine's posed skeleton and every stored weight.
##
## final = sum(weight * skeleton_global * bone_pose * bind_pose * (vertex + morphs))
## Weights are not divided by their sum. A zero, non-finite, or invalid bind
## fails closed. Morph deltas are Godot blend-shape offsets. Glow meshes are
## named, not dropped and not treated as the opaque head. Outline-shader
## displacement is not applied. This is the engine bone palette plus the skin
## equation, not a Vulkan vertex-buffer readback.
class_name DealerSkin
extends RefCounted


## One posed surface. `part` is head / visor / body / chip / glow / other.
static func surface(mi: MeshInstance3D, skel: Skeleton3D) -> Dictionary:
	if mi == null or mi.mesh == null or skel == null:
		return {"ok": false, "reason": "missing", "tris": [], "part": ""}
	var part := _part(mi)
	var skin := mi.skin
	if skin == null:
		return {"ok": false, "reason": "no_skin", "tris": [], "part": part}
	var mats: Array[Transform3D] = []
	var sx := skel.global_transform
	for b in skin.get_bind_count():
		var bone := skin.get_bind_bone(b)
		if bone < 0:
			bone = skel.find_bone(skin.get_bind_name(b))
		if bone < 0:
			return {"ok": false, "reason": "bad_bind", "tris": [], "part": part}
		mats.append(sx * skel.get_bone_global_pose(bone) * skin.get_bind_pose(b))
	return _all_surfaces(mi, mats, part)


static func _all_surfaces(mi: MeshInstance3D, mats: Array[Transform3D], part: String) -> Dictionary:
	var tris: Array = []
	var wsum_min := INF
	var any := false
	for si in mi.mesh.get_surface_count():
		var morph := _morph_surface(mi, si)
		if not bool(morph["ok"]):
			return morph
		var base: PackedVector3Array = morph["verts"]
		var arr: Array = mi.mesh.surface_get_arrays(si)
		var bones := arr[Mesh.ARRAY_BONES] as PackedInt32Array
		var weights := arr[Mesh.ARRAY_WEIGHTS] as PackedFloat32Array
		var idx := arr[Mesh.ARRAY_INDEX] as PackedInt32Array
		if bones.is_empty() or weights.is_empty() or idx.is_empty() or base.is_empty():
			return {"ok": false, "reason": "empty_skin", "tris": [], "part": part}
		var per := int(weights.size() / base.size())
		if per <= 0 or bones.size() != weights.size():
			return {"ok": false, "reason": "bad_skin_layout", "tris": [], "part": part}
		var posed: Array[Vector3] = []
		posed.resize(base.size())
		for i in base.size():
			var acc := Vector3.ZERO
			var wsum := 0.0
			for j in per:
				var w := weights[i * per + j]
				if not is_finite(w):
					return {"ok": false, "reason": "nonfinite_weight", "tris": [], "part": part}
				if w == 0.0:
					continue
				var bi := bones[i * per + j]
				if bi < 0 or bi >= mats.size():
					return {"ok": false, "reason": "bad_bind", "tris": [], "part": part}
				acc += (mats[bi] * base[i]) * w
				wsum += w
			if wsum <= 0.0 or not is_finite(wsum):
				return {"ok": false, "reason": "zero_weight", "tris": [], "part": part}
			wsum_min = minf(wsum_min, wsum)
			# Stored weights only. Do not divide by wsum.
			posed[i] = acc
		for k in range(0, idx.size() - 2, 3):
			tris.append([posed[idx[k]], posed[idx[k + 1]], posed[idx[k + 2]]])
		any = true
	if not any:
		return {"ok": false, "reason": "no_triangles", "tris": [], "part": part}
	return {"ok": true, "reason": "skinned", "tris": tris, "part": part, "wsum_min": wsum_min}


static func _morph_surface(mi: MeshInstance3D, si: int) -> Dictionary:
	var arr: Array = mi.mesh.surface_get_arrays(si)
	var base := (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate()
	var count: int = mi.mesh.get_blend_shape_count()
	for m in count:
		var shape: Array = mi.mesh.surface_get_blend_shape_arrays(si)[m]
		var delta := shape[Mesh.ARRAY_VERTEX] as PackedVector3Array
		if delta.size() != base.size():
			return {"ok": false, "reason": "bad_morph", "verts": base}
		var value := mi.get_blend_shape_value(m)
		if not is_finite(value):
			return {"ok": false, "reason": "nonfinite_morph", "verts": base}
		if value == 0.0:
			continue
		for i in base.size():
			base[i] += delta[i] * value
	return {"ok": true, "verts": base}


static func _part(mi: MeshInstance3D) -> String:
	var mat := mi.get_active_material(0)
	var mname := ""
	if mat != null:
		mname = mat.resource_path.get_file().get_basename()
	if mname.contains("glow"):
		return "glow"
	var n := String(mi.name).to_lower()
	if n.contains("visor"):
		return "visor"
	if n.contains("head") or n.contains("jaw") or n.contains("horn"):
		return "head"
	if n.contains("chip"):
		return "chip"
	if n.contains("body"):
		return "body"
	return "other"


## Opaque head pieces the oracle must see. Glow is reported beside them.
static func required_head_parts() -> Array[String]:
	return ["head", "visor"]
