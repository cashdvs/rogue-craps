## The one seat a dealer stands on during play, and a fail-closed rail query.
##
## Greybox, Board A and the Hearth board all crown near y = 0.11. Play uses
## one origin, 0.46 m below that design crown and 0.25 m behind the far-rail
## centre: world (-0.42, -0.35, -0.86). That is the old documented anchor
## plus the existing 0.12 m lift. The lift stays. Straight Man's head clears
## the boss framing gate by about 1.5 cm, so a lower actor hides boss heads.
##
## The anchor (-0.42, -0.47, -0.86) is a legacy test fixture. It is not a
## second seat the idle has to satisfy. Planting fingers on the real leather
## at the play seat drops those vertices through the old y = 0.14 slab when
## the same clip is played on the fixture. That conflict is reported; the
## legacy tests are not rewritten here.
class_name DealerPlacement
extends RefCounted

## Table3DBuilder far-rail crown: tube centre 0.02 plus radius 0.09.
const DESIGN_CROWN_Y := 0.11
## Far-rail centre line (Table3DBuilder RailFar).
const RAIL_CENTER_Z := -0.61
## Legacy art/test anchor. Not the play seat.
const DOCUMENTED_FIXTURE := Vector3(-0.42, -0.47, -0.86)
## Kept. A smaller lift fails the boss head gate on Straight Man.
const LIFT_Y := 0.12


## World origin of every dealer Bonfire actually instances.
static func production_origin() -> Vector3:
	return DOCUMENTED_FIXTURE + Vector3(0.0, LIFT_Y, 0.0)


## How far the play seat sits below the design crown (metres).
static func below_design_crown() -> float:
	return DESIGN_CROWN_Y - production_origin().y


## How far the play seat sits behind the far-rail centre (metres, negative).
static func behind_rail_center() -> float:
	return production_origin().z - RAIL_CENTER_Z


## Highest leather Y under (x, z). `ok` is false when the mesh is missing,
## has no triangles, or the ray misses. A miss is not a clearance of -INF
## and must not be treated as "supported".
static func surface_y(mesh_root: Node, x: float, z: float) -> Dictionary:
	if mesh_root == null:
		return {"ok": false, "y": 0.0, "reason": "missing"}
	var tris := _triangles(mesh_root)
	if tris.is_empty():
		return {"ok": false, "y": 0.0, "reason": "no_triangles"}
	var best := -1.0e9
	var origin := Vector3(x, 5.0, z)
	var dir := Vector3(0.0, -1.0, 0.0)
	for tri in tris:
		var hit := _ray(origin, dir, tri[0], tri[1], tri[2])
		if hit >= 0.0:
			best = maxf(best, origin.y + dir.y * hit)
	if best < -1.0e8:
		return {"ok": false, "y": 0.0, "reason": "no_hit"}
	return {"ok": true, "y": best, "reason": "hit"}


static func _triangles(root: Node) -> Array:
	var tris: Array = []
	var meshes: Array = []
	if root is MeshInstance3D:
		meshes.append(root)
	meshes.append_array(root.find_children("*", "MeshInstance3D", true, false))
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
				continue
			for i in range(0, idx.size() - 2, 3):
				tris.append([xf * vs[idx[i]], xf * vs[idx[i + 1]], xf * vs[idx[i + 2]]])
	return tris


## Möller–Trumbore. Ray distance, or -1 on a miss.
static func _ray(orig: Vector3, dir: Vector3, v0: Vector3, v1: Vector3, v2: Vector3) -> float:
	var e1 := v1 - v0
	var e2 := v2 - v0
	var pvec := dir.cross(e2)
	var det := e1.dot(pvec)
	if absf(det) < 1.0e-8:
		return -1.0
	var inv := 1.0 / det
	var tvec := orig - v0
	var u := tvec.dot(pvec) * inv
	if u < 0.0 or u > 1.0:
		return -1.0
	var qvec := tvec.cross(e1)
	var v := dir.dot(qvec) * inv
	if v < 0.0 or u + v > 1.0:
		return -1.0
	var t := e2.dot(qvec) * inv
	return t if t >= 0.0 else -1.0
