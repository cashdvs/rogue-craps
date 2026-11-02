## Dark crack ink on a die whose art body has crack grooves (the Cracked
## Die: the surface whose material is <die>_crack.tres). The body's
## material_override paints the whole mesh, grooves too, so the cracks were
## lost. This adds a "CrackInk" child of the Body: flat seams just above
## every face, twice the modelled groove width, in the ink colour.
class_name DieCrackInk
extends RefCounted

const NODE := &"CrackInk"
## Seam width as a fraction of the half edge: 2x the modelled groove
## (about 0.0375 of the half edge, 0.0015 on the 0.08 die).
const SEAM := 0.075
## Seams keep this far (half-edge fraction) from any pip rim point.
const PIP_CLEAR := 0.06
## A hair above the face, so the body never covers the ink.
const LIFT := 0.004
const INK := Color("#16130F")

static var _cache := {}


## The index of the crack surface in [param mesh], or -1.
static func crack_surface(mesh: Mesh) -> int:
	if mesh == null:
		return -1
	for s in mesh.get_surface_count():
		var m := mesh.surface_get_material(s)
		if m != null and m.resource_path.ends_with("_crack.tres"):
			return s
	return -1


## Removes the crack ink from die [param d] (any die; no-op without it).
static func clear(d: DieVisual) -> void:
	var body := d.faces.get_node_or_null("Body") as MeshInstance3D
	var old := body.get_node_or_null(NodePath(NODE)) if body != null else null
	if old != null:
		old.free()


## Adds the crack ink when the die's body mesh has a crack surface.
static func apply(d: DieVisual) -> bool:
	clear(d)
	var body := d.faces.get_node_or_null("Body") as MeshInstance3D
	if body == null:
		return false
	var s := crack_surface(body.mesh)
	if s < 0:
		return false
	if not _cache.has(body.mesh):
		_cache[body.mesh] = ink_mesh(body.mesh, s)
	var mi := MeshInstance3D.new()
	mi.name = NODE
	mi.mesh = _cache[body.mesh]
	mi.layers = body.layers
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	## Flat ink: no lighting, so red light or glow never lifts it.
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = INK
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	body.add_child(mi)
	return true


## The ink mesh: on every face a crack walks in from one edge with a
## jagged line, and one branch splits off it. Seeded, so every Cracked Die
## shows the same cracks. Steps that would cross a pip are skipped, so
## pips stay as they were. Sizes are fractions of the half edge.
static func ink_mesh(mesh: Mesh, s: int) -> ArrayMesh:
	var half := mesh.get_aabb().size.x * 0.5
	var pips := _pip_points(mesh, s, half)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7013
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ax in 3:
		for sg: float in [1.0, -1.0]:
			var n := Vector3.ZERO
			n[ax] = sg
			var u := Vector3.ZERO
			u[(ax + 1) % 3] = 1.0
			var v := n.cross(u)
			var side := rng.randi() % 4
			var start := Vector2([0.78, -0.78, 0.0, 0.0][side], [0.0, 0.0, 0.78, -0.78][side])
			start += Vector2(start.y, start.x).abs().normalized() * rng.randf_range(-0.4, 0.4)
			var dir := -start.normalized()
			var line := _walk(rng, start, dir, 6, 0.2)
			var at := line[rng.randi_range(2, 3)]
			var bdir := dir.rotated(rng.randf_range(0.6, 1.0) * (1.0 if rng.randf() < 0.5 else -1.0))
			for path in [line, _walk(rng, at, bdir, 3, 0.17)]:
				for i in path.size() - 1:
					_seam(st, path[i], path[i + 1], n, u, v, half, pips)
	return st.commit()


## A jagged line: [param steps] steps of about [param len] from [param p].
static func _walk(rng: RandomNumberGenerator, p: Vector2, dir: Vector2, steps: int, len: float) -> Array[Vector2]:
	var out: Array[Vector2] = [p]
	for i in steps:
		dir = dir.rotated(rng.randf_range(-0.6, 0.6))
		p = (p + dir * len * rng.randf_range(0.7, 1.2)).clampf(-0.8, 0.8)
		out.append(p)
	return out


## One seam step from a to b (face coords) as a thin quad, unless it
## comes near a pip.
static func _seam(st: SurfaceTool, a: Vector2, b: Vector2, n: Vector3, u: Vector3, v: Vector3, half: float, pips: PackedVector3Array) -> void:
	var to3 := func(q: Vector2) -> Vector3: return (n * (1.0 + LIFT) + u * q.x + v * q.y) * half
	var pa: Vector3 = to3.call(a)
	var pb: Vector3 = to3.call(b)
	for p in pips:
		if p.dot(n) > 0.5 * half and Geometry3D.get_closest_point_to_segment(p, pa, pb).distance_to(p) < PIP_CLEAR * half:
			return
	var side := (pb - pa).cross(n).normalized() * SEAM * half * 0.5
	for q in [pa - side, pa + side, pb + side, pa - side, pb + side, pb - side]:
		st.set_normal(n)
		st.add_vertex(q)


## Points on the pip rims (the pip surface, at the face), to steer around.
static func _pip_points(mesh: Mesh, crack: int, half: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for s in mesh.get_surface_count():
		if s == crack or s == 0:
			continue
		for p: Vector3 in mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			if p.abs()[p.abs().max_axis_index()] > 0.99 * half:
				out.append(p)
	return out


## Crack ink triangles per face (+x, -x, +y, -y, +z, -z), for checks.
static func per_face(mesh: ArrayMesh) -> Dictionary:
	var out := {}
	var v: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for t in range(0, v.size(), 3):
		var c := (v[t] + v[t + 1] + v[t + 2]) / 3.0
		var ax := c.abs().max_axis_index()
		var key := ("+" if c[ax] > 0.0 else "-") + "xyz"[ax]
		out[key] = int(out.get(key, 0)) + 1
	return out
