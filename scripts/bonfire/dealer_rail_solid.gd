## Finite closed-mesh collision against a rail solid. Not an infinite y = 0.11 plane.
##
## A hit is a transverse triangle crossing or a point strictly inside the solid.
## Coplanar contact is not penetration. A point below the crown but outside the
## mesh, or below the solid's bottom, is not inside. Grazing an edge, an open
## mesh, or a non-finite coordinate is indeterminate and must fail closed.
## There is no penetration allowance.
##
## Numbers: positions are Godot floats. EDGE_EPS and INTERIOR_MARGIN are 1 µm.
## COPLANAR_AREA is 1e-10 m². Vertices closer than 1e-8 m weld before the
## watertight edge count. This is not a swept/continuous test.
class_name DealerRailSolid
extends RefCounted

const EDGE_EPS := 1.0e-6
const INTERIOR_MARGIN := 1.0e-6
const COPLANAR_AREA := 1.0e-10
const WELD_M := 1.0e-8


## `tris` is an Array of [Vector3, Vector3, Vector3].
static func from_triangles(tris: Array) -> Dictionary:
	if tris.is_empty():
		return {"ok": false, "reason": "no_triangles", "tris": [], "verts": []}
	var verts: Array[Vector3] = []
	var keys := {}
	var faces: Array = []
	for tri in tris:
		var a := tri[0] as Vector3
		var b := tri[1] as Vector3
		var c := tri[2] as Vector3
		if not _finite(a) or not _finite(b) or not _finite(c):
			return {"ok": false, "reason": "nonfinite", "tris": [], "verts": []}
		var ia := _weld(verts, keys, a)
		var ib := _weld(verts, keys, b)
		var ic := _weld(verts, keys, c)
		if ia == ib or ib == ic or ic == ia:
			continue
		faces.append([ia, ib, ic])
	if faces.is_empty():
		return {"ok": false, "reason": "no_triangles", "tris": [], "verts": []}
	var edges := {}
	for f in faces:
		for e in [[f[0], f[1]], [f[1], f[2]], [f[2], f[0]]]:
			var lo: int = mini(e[0], e[1])
			var hi: int = maxi(e[0], e[1])
			var k := "%d:%d" % [lo, hi]
			edges[k] = int(edges.get(k, 0)) + 1
	for k in edges:
		if int(edges[k]) != 2:
			return {"ok": false, "reason": "open_or_nonmanifold", "tris": [], "verts": []}
	var out: Array = []
	var mn := verts[0]
	var mx := verts[0]
	for f in faces:
		var p0 := verts[f[0]]
		var p1 := verts[f[1]]
		var p2 := verts[f[2]]
		out.append([p0, p1, p2])
		mn = mn.min(p0).min(p1).min(p2)
		mx = mx.max(p0).max(p1).max(p2)
	return {"ok": true, "reason": "closed", "tris": out, "verts": verts, "min": mn, "max": mx}


static func from_mesh_root(root: Node) -> Dictionary:
	if root == null:
		return {"ok": false, "reason": "missing", "tris": [], "verts": []}
	var raw: Array = []
	var meshes: Array = []
	if root is MeshInstance3D:
		meshes.append(root)
	meshes.append_array(root.find_children("*", "MeshInstance3D", true, false))
	if meshes.is_empty():
		return {"ok": false, "reason": "no_triangles", "tris": [], "verts": []}
	for item in meshes:
		var mi := item as MeshInstance3D
		if mi.mesh == null:
			continue
		var xf := mi.global_transform
		for si in mi.mesh.get_surface_count():
			var arr: Array = mi.mesh.surface_get_arrays(si)
			var vs := arr[Mesh.ARRAY_VERTEX] as PackedVector3Array
			var idx := arr[Mesh.ARRAY_INDEX] as PackedInt32Array
			if idx.is_empty():
				return {"ok": false, "reason": "no_triangles", "tris": [], "verts": []}
			for i in range(0, idx.size() - 2, 3):
				raw.append([xf * vs[idx[i]], xf * vs[idx[i + 1]], xf * vs[idx[i + 2]]])
	return from_triangles(raw)


## "transverse", "coplanar", "separate", "graze", "degenerate", or "nonfinite".
static func triangle_relation(a0: Vector3, a1: Vector3, a2: Vector3, b0: Vector3, b1: Vector3, b2: Vector3) -> String:
	if not _finite(a0) or not _finite(a1) or not _finite(a2) or not _finite(b0) or not _finite(b1) or not _finite(b2):
		return "nonfinite"
	var na := (a1 - a0).cross(a2 - a0)
	var nb := (b1 - b0).cross(b2 - b0)
	if na.length_squared() < COPLANAR_AREA * COPLANAR_AREA or nb.length_squared() < COPLANAR_AREA * COPLANAR_AREA:
		return "degenerate"
	var graze := false
	for edge in [[a0, a1], [a1, a2], [a2, a0]]:
		var hit := _edge_tri(edge[0], edge[1], b0, b1, b2, nb)
		if hit == "transverse":
			return "transverse"
		if hit == "graze":
			graze = true
	for edge in [[b0, b1], [b1, b2], [b2, b0]]:
		var hit := _edge_tri(edge[0], edge[1], a0, a1, a2, na)
		if hit == "transverse":
			return "transverse"
		if hit == "graze":
			graze = true
	if graze:
		return "graze"
	if absf(na.normalized().dot(nb.normalized())) > 0.999999 and absf(na.normalized().dot(b0 - a0)) < INTERIOR_MARGIN:
		return "coplanar"
	return "separate"


## "inside", "outside", or "indeterminate". Odd ray parity. Several directions
## are tried because a ray along a shared triangle edge is indeterminate, not
## a miss. Directions that disagree fail closed.
static func point_vs_solid(p: Vector3, solid: Dictionary) -> String:
	if not bool(solid.get("ok", false)):
		return "indeterminate"
	if not _finite(p):
		return "indeterminate"
	var mn: Vector3 = solid["min"]
	var mx: Vector3 = solid["max"]
	if p.x < mn.x - INTERIOR_MARGIN or p.x > mx.x + INTERIOR_MARGIN:
		return "outside"
	if p.y < mn.y - INTERIOR_MARGIN or p.y > mx.y + INTERIOR_MARGIN:
		return "outside"
	if p.z < mn.z - INTERIOR_MARGIN or p.z > mx.z + INTERIOR_MARGIN:
		return "outside"
	var saw_in := false
	var saw_out := false
	for dir in [Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0.31, 0.83, 0.46)]:
		var kind := _parity(p, dir.normalized(), solid)
		if kind == "inside":
			saw_in = true
		elif kind == "outside":
			saw_out = true
	if saw_in and saw_out:
		return "indeterminate"
	if saw_in:
		return "inside"
	if saw_out:
		return "outside"
	return "indeterminate"


static func _parity(p: Vector3, dir: Vector3, solid: Dictionary) -> String:
	var count := 0
	for tri in solid["tris"]:
		var kind := _ray_tri(p, dir, tri[0], tri[1], tri[2])
		if kind == "graze" or kind == "degenerate":
			return "indeterminate"
		if kind == "hit":
			count += 1
	return "inside" if count % 2 == 1 else "outside"


## Skin triangles against a closed rail. `require_reverse` also demands a closed
## skin solid so a rail vertex inside that solid counts. An open head must not
## take a reverse-containment pass; the caller leaves require_reverse false and
## says so. Every skin corner is tested, not only tri[0].
static func compare(skin_tris: Array, rail: Dictionary, skin_solid: Dictionary, require_reverse: bool) -> Dictionary:
	if not bool(rail.get("ok", false)):
		return {"status": "indeterminate", "reason": str(rail.get("reason", "bad_rail")), "crossing": false}
	var crossing := false
	var graze := false
	var inside_skin := 0
	var seen := {}
	for tri in skin_tris:
		for corner in [tri[0], tri[1], tri[2]]:
			var p := corner as Vector3
			var pk := "%d,%d,%d" % [int(round(p.x / WELD_M)), int(round(p.y / WELD_M)), int(round(p.z / WELD_M))]
			if seen.has(pk):
				continue
			seen[pk] = true
			var rel_point := point_vs_solid(p, rail)
			if rel_point == "indeterminate":
				return {"status": "indeterminate", "reason": "point_graze", "crossing": crossing}
			if rel_point == "inside":
				inside_skin += 1
		for other in rail["tris"]:
			if not _aabb_overlap(tri[0], tri[1], tri[2], other[0], other[1], other[2]):
				continue
			var rel := triangle_relation(tri[0], tri[1], tri[2], other[0], other[1], other[2])
			if rel == "transverse":
				crossing = true
			elif rel == "degenerate" or rel == "nonfinite":
				return {"status": "indeterminate", "reason": rel, "crossing": crossing, "inside_skin": inside_skin}
			elif rel == "graze":
				graze = true
	if graze and not crossing and inside_skin == 0:
		return {"status": "indeterminate", "reason": "graze", "crossing": false, "inside_skin": 0}
	var inside_rail := 0
	var reverse := "not_certified"
	if require_reverse:
		if not bool(skin_solid.get("ok", false)):
			return {"status": "indeterminate", "reason": "skin_not_closed", "crossing": crossing, "inside_skin": inside_skin}
		reverse = "certified"
		for v in rail["verts"]:
			var rel_v := point_vs_solid(v, skin_solid)
			if rel_v == "indeterminate":
				return {"status": "indeterminate", "reason": "reverse_graze", "crossing": crossing}
			if rel_v == "inside":
				inside_rail += 1
	var bad := crossing or inside_skin > 0 or inside_rail > 0
	return {"status": "hit" if bad else "clear", "reason": "hit" if bad else "clear",
		"crossing": crossing, "inside_skin": inside_skin, "inside_rail": inside_rail, "reverse": reverse}


static func _edge_tri(p0: Vector3, p1: Vector3, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> String:
	var dir := p1 - p0
	var denom := n.dot(dir)
	if absf(denom) < 1.0e-12:
		return "none"
	var t := n.dot(a - p0) / denom
	if t <= 0.0 or t >= 1.0:
		return "none"
	var hit := p0 + dir * t
	if hit.distance_to(p0) < EDGE_EPS or hit.distance_to(p1) < EDGE_EPS:
		return "graze"
	var kind := _bary(hit, a, b, c, n)
	return kind


static func _bary(p: Vector3, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> String:
	var area := n.length()
	if area < 1.0e-12:
		return "degenerate"
	var u := (b - p).cross(c - p).dot(n) / (area * area)
	var v := (c - p).cross(a - p).dot(n) / (area * area)
	var w := 1.0 - u - v
	if u < -1.0e-6 or v < -1.0e-6 or w < -1.0e-6:
		return "none"
	if u < 1.0e-5 or v < 1.0e-5 or w < 1.0e-5:
		return "graze"
	return "transverse"


static func _ray_tri(orig: Vector3, dir: Vector3, a: Vector3, b: Vector3, c: Vector3) -> String:
	var e1 := b - a
	var e2 := c - a
	var pvec := dir.cross(e2)
	var det := e1.dot(pvec)
	if absf(det) < 1.0e-12:
		return "none"
	var inv := 1.0 / det
	var tvec := orig - a
	var u := tvec.dot(pvec) * inv
	if u < -1.0e-8 or u > 1.0 + 1.0e-8:
		return "none"
	var qvec := tvec.cross(e1)
	var v := dir.dot(qvec) * inv
	if v < -1.0e-8 or u + v > 1.0 + 1.0e-8:
		return "none"
	var t := e2.dot(qvec) * inv
	if t <= INTERIOR_MARGIN:
		return "none"
	if u < 1.0e-5 or v < 1.0e-5 or (1.0 - u - v) < 1.0e-5:
		return "graze"
	return "hit"


static func _aabb_overlap(a0: Vector3, a1: Vector3, a2: Vector3, b0: Vector3, b1: Vector3, b2: Vector3) -> bool:
	var amn := a0.min(a1).min(a2)
	var amx := a0.max(a1).max(a2)
	var bmn := b0.min(b1).min(b2)
	var bmx := b0.max(b1).max(b2)
	return amn.x <= bmx.x and amx.x >= bmn.x and amn.y <= bmx.y and amx.y >= bmn.y and amn.z <= bmx.z and amx.z >= bmn.z


static func _weld(verts: Array[Vector3], keys: Dictionary, p: Vector3) -> int:
	var k := "%d,%d,%d" % [int(round(p.x / WELD_M)), int(round(p.y / WELD_M)), int(round(p.z / WELD_M))]
	if keys.has(k):
		return int(keys[k])
	var i := verts.size()
	verts.append(p)
	keys[k] = i
	return i


static func _finite(p: Vector3) -> bool:
	return is_finite(p.x) and is_finite(p.y) and is_finite(p.z)
