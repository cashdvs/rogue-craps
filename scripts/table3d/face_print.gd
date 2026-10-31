## Reads the art printed on a die face (its overlay texture: alpha = ink),
## so marks can be placed around it. Used by the bake tool
## (tools/gen_face_print_spots.gd) and by tests; the game itself only reads
## the baked spots in FacePrintSpots, so nothing here runs in a shipped build.
class_name FacePrint
extends RefCounted

## Ink alpha above this counts as printed.
const INK := 0.15


## The overlay image on [param d]'s body, read straight from the source PNG
## (tests and tools run from the project folder). null if there is none.
static func image_of(d: DieVisual) -> Image:
	var body := d.faces.get_node_or_null("Body") as MeshInstance3D
	var mat := body.get_active_material(0) as ShaderMaterial if body != null else null
	if mat == null or mat.get_shader_parameter("overlay_tex") == null:
		return null
	var path: String = (mat.get_shader_parameter("overlay_tex") as Texture2D).resource_path
	return Image.load_from_file(ProjectSettings.globalize_path(path))


## The body mesh's flat triangles facing along [param n] (scaled like the
## drawn body), each [p0, p1, p2, uv0, uv1, uv2].
static func face_tris(d: DieVisual, n: Vector3) -> Array:
	var body := d.faces.get_node("Body") as MeshInstance3D
	var a: Array = body.mesh.surface_get_arrays(0)
	var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	if idx.is_empty():
		idx = PackedInt32Array(range(vs.size()))
	var out := []
	for t in range(0, idx.size(), 3):
		var p := [body.scale * vs[idx[t]], body.scale * vs[idx[t + 1]], body.scale * vs[idx[t + 2]]]
		var cr: Vector3 = (p[1] - p[0]).cross(p[2] - p[0])
		if cr.length() > 1e-12 and absf(cr.normalized().dot(n)) > 0.999:
			out.append([p[0], p[1], p[2], uvs[idx[t]], uvs[idx[t + 1]], uvs[idx[t + 2]]])
	return out


## Ink alpha printed at face point [param p] (0 when off the flat face).
static func ink_at(tris: Array, img: Image, p: Vector3) -> float:
	for t: Array in tris:
		var w := _bary(t[0], t[1], t[2], p)
		if w.x >= -0.001 and w.y >= -0.001 and w.z >= -0.001:
			var uv: Vector2 = t[3] * w.x + t[4] * w.y + t[5] * w.z
			var x := clampi(int(uv.x * img.get_width()), 0, img.get_width() - 1)
			var y := clampi(int(uv.y * img.get_height()), 0, img.get_height() - 1)
			return img.get_pixel(x, y).a
	return 0.0


## Every inked point on face [param f] (PolyBody.face_tri), sampled on a
## [param steps] x [param steps] lattice across the triangle.
static func ink_points(d: DieVisual, f: Dictionary, img: Image, steps: int = 72) -> PackedVector3Array:
	var tris := face_tris(d, f.normal)
	var tri: Array = f.tri
	var out := PackedVector3Array()
	for i in steps + 1:
		for j in steps + 1 - i:
			var p: Vector3 = tri[0] + (tri[1] - tri[0]) * (float(i) / steps) + (tri[2] - tri[0]) * (float(j) / steps)
			if ink_at(tris, img, p) > INK:
				out.append(p)
	return out


## Barycentric weights of [param p] in triangle a, b, c (in its plane).
static func _bary(a: Vector3, b: Vector3, c: Vector3, p: Vector3) -> Vector3:
	var v0 := b - a
	var v1 := c - a
	var v2 := p - a
	var d00 := v0.dot(v0)
	var d01 := v0.dot(v1)
	var d11 := v1.dot(v1)
	var den := d00 * d11 - d01 * d01
	if absf(den) < 1e-18:
		return Vector3(-1, -1, -1)
	var v := (d11 * v2.dot(v0) - d01 * v2.dot(v1)) / den
	var w := (d00 * v2.dot(v1) - d01 * v2.dot(v0)) / den
	return Vector3(1.0 - v - w, v, w)


## The printed numeral on a face: the biggest connected blob of [param ink]
## points (stray edge trim is dropped), as its tightest box in the face
## plane: {centre, a, b, ha, hb} (a, b = the box axes, ha, hb = half sizes).
## [param gap] = the lattice spacing, so neighbours count as connected.
static func numeral_box(ink: PackedVector3Array, n: Vector3, gap: float) -> Dictionary:
	var blob := _biggest_blob(ink, gap * 1.6)
	var best := {}
	var e0 := (n.cross(Vector3.UP) if absf(n.y) < 0.9 else n.cross(Vector3.RIGHT)).normalized()
	for step in 36:  # every 5 degrees: keep the smallest box
		var a := e0.rotated(n, deg_to_rad(5.0 * step))
		var b := n.cross(a)
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for p in blob:
			var q := Vector2(p.dot(a), p.dot(b))
			lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
			hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
		var size := hi - lo + Vector2(gap, gap)  # each sample covers one cell
		if best.is_empty() or size.x * size.y < best.area:
			var c := (lo + hi) * 0.5
			var on_plane: Vector3 = blob[0] - a * blob[0].dot(a) - b * blob[0].dot(b)
			best = {"centre": on_plane + a * c.x + b * c.y, "a": a, "b": b, "ha": size.x * 0.5, "hb": size.y * 0.5, "area": size.x * size.y}
	return best


## True when a circle (centre [param p], radius [param r]) touches the box.
static func circle_hits_box(p: Vector3, r: float, box: Dictionary) -> bool:
	var d: Vector3 = p - box.centre
	var x := clampf(d.dot(box.a), -box.ha, box.ha)
	var y := clampf(d.dot(box.b), -box.hb, box.hb)
	return Vector2(d.dot(box.a) - x, d.dot(box.b) - y).length() < r


## The largest group of points chained by links shorter than [param link].
static func _biggest_blob(pts: PackedVector3Array, link: float) -> PackedVector3Array:
	var group := PackedInt32Array()
	group.resize(pts.size())
	group.fill(-1)
	var best := PackedVector3Array()
	for s in pts.size():
		if group[s] >= 0:
			continue
		var todo: Array[int] = [s]
		group[s] = s
		var mine := PackedVector3Array()
		while not todo.is_empty():
			var i: int = todo.pop_back()
			mine.append(pts[i])
			for j in pts.size():
				if group[j] < 0 and pts[i].distance_to(pts[j]) < link:
					group[j] = s
					todo.append(j)
		if mine.size() > best.size():
			best = mine
	return best


## The Twin diamond's axes on face [param f]: a points at the face's first
## corner (the d4 corner it reads), b across. Its tips lie along a and b.
static func diamond_axes(f: Dictionary) -> Array[Vector3]:
	var a: Vector3 = (f.tri[0] - f.g).normalized()
	return [a, (f.normal as Vector3).cross(a)]


## Clearance of a diamond (centre [param p], half-diagonal [param q]) from
## the ink: the smallest L1 distance (in the diamond's axes) of any inked
## point, minus q. Below 0 means it covers ink.
static func diamond_clear(p: Vector3, q: float, ax: Array[Vector3], ink: PackedVector3Array) -> float:
	var c := INF
	for s in ink:
		c = minf(c, absf((s - p).dot(ax[0])) + absf((s - p).dot(ax[1])) - q)
	return c


## How far point [param p] is inside triangle [param tri] (its smallest
## distance to an edge; negative when outside).
static func inside_by(p: Vector3, tri: Array, n: Vector3) -> float:
	var m := INF
	var g: Vector3 = (tri[0] + tri[1] + tri[2]) / 3.0
	for i in 3:
		var e: Vector3 = tri[(i + 1) % 3] - tri[i]
		var inward := n.cross(e).normalized()
		if (g - tri[i]).dot(inward) < 0.0:
			inward = -inward  # either corner order (winding) works
		m = minf(m, (p - tri[i]).dot(inward))
	return m


## Bake: the best Twin diamond centre on face [param f], as weights of its
## corners. Of the spots where the whole diamond (half-diagonal q) is
## inside the face by [param margin] and clear of ink by [param pad], take
## the clearest one, pulled toward the face middle.
static func best_diamond(f: Dictionary, ink: PackedVector3Array, q: float, margin: float, pad: float) -> Vector3:
	var ax := diamond_axes(f)
	var tri: Array = f.tri
	var best := Vector3(1, 1, 1) / 3.0
	var best_score := -INF
	var steps := 60
	for i in steps + 1:
		for j in steps + 1 - i:
			var w := Vector3(1.0 - float(i + j) / steps, float(i) / steps, float(j) / steps)
			var p: Vector3 = tri[0] * w.x + tri[1] * w.y + tri[2] * w.z
			var fits := true
			for t: Vector3 in [ax[0], -ax[0], ax[1], -ax[1]]:
				fits = fits and inside_by(p + t * q, tri, f.normal) >= margin
			var c := diamond_clear(p, q, ax, ink)
			if not fits or c < pad:
				continue
			var score := minf(c, pad * 3.0) - 0.25 * p.distance_to(f.g)
			if score > best_score:
				best_score = score
				best = w
	return best


## Bake: the Step badge centre (radius [param r]) on face [param f], as
## weights of its corners: tucked into the corner farthest from the
## numeral [param box], inside the face by [param margin]. Vector3.ZERO if
## no corner keeps it off the numeral box.
static func best_badge(f: Dictionary, box: Dictionary, r: float, margin: float) -> Vector3:
	var tri: Array = f.tri
	var best := Vector3.ZERO
	var far := -INF
	for k in 3:
		var c: Vector3 = tri[k]
		# In a 60-degree corner a circle touching both edges at margin sits
		# 2 (r + margin) from the corner.
		var p: Vector3 = c + (f.g - c).normalized() * 2.0 * (r + margin)
		if circle_hits_box(p, r, box) or c.distance_to(box.centre) <= far:
			continue
		far = c.distance_to(box.centre)
		var w := _bary(tri[0], tri[1], tri[2], p)
		best = w
	return best
