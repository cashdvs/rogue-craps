## Dresses a table die (DieVisual) as a shaped d4 / d8 body: the 3D
## Artist's mesh (caltrop_d4 / lantern_d8, the Gallows and Beacon bodies),
## its numbered faces, and the shape id the table reads. Setting
## DieVisual.shape is what makes the rest of the table treat it as a hull
## die: DiceSim gives it the ConvexPolygonShape3D collider (PolyDie.make_shape),
## and up_slot() / face_rotation() read it from PolyDie's direction table
## (a d4 by its top POINT, a d8 by its top face, so Beacon's 7 and 8 show).
## The collider hull comes from the same PC mesh (pc_hull).
## Only d4 and d8 for now; the other shaped dice stay on the cube until
## their own pass. Body-key art loading (Table3D.apply_art_body) is separate
## and untouched: a shaped die simply keeps its shape's own mesh.
class_name PolyBody
extends RefCounted

## Shapes this file dresses on the table.
const TABLE_SHAPES: Array[StringName] = [&"d4", &"d8"]


## Which shape [param td] gets on the table: d4 / d8 when its mesh is in
## the repo, else &"" (keep the d6 cube).
static func table_shape(td: TableDie) -> StringName:
	var s := PolyDie.body_shape_for(td)
	if TABLE_SHAPES.has(s) and PolyDie.has_mesh(s):
		return s
	return &""


## Extra toon "wrap" light per shape (DieVisual's own is 0.35). A d4 has no
## face pointing up: its three visible faces lean 70 degrees off the felt,
## so the overhead light hits them nearly edge-on and the toon shader puts
## them in its darkest band (the cube's top face catches full light). More
## wrap lifts those sloped faces into the mid/lit bands (it is also scaled
## up to its own 0.065 m cap, see body_scale).
const SHAPE_SHADE: Dictionary = {&"d4": {"wrap": 1.0, "mid_tint": 1.0, "light_gain": 1.6}}


## Collider points per shape, built once from the PC mesh (see pc_hull).
static var _hulls: Dictionary = {}


## The full-detail PC .glb path for a shape (the file next to the mobile
## LOD), or "" if it is not in the repo.
static func pc_path(shape: StringName) -> String:
	var p := PolyDie.mesh_path(shape)
	if p == "":
		return ""
	p = p.replace("_mobile.glb", ".glb")
	return p if ResourceLoader.exists(p) else ""


## The full-detail mesh for a shape (the PC .glb, never the mobile LOD).
static func mesh_for(shape: StringName) -> Mesh:
	var p := pc_path(shape)
	if p == "":
		return null
	var scene := load(p) as PackedScene
	if scene == null:
		return null
	var inst := scene.instantiate()
	var found: Mesh = null
	for n in inst.find_children("*", "MeshInstance3D", true, false):
		found = (n as MeshInstance3D).mesh
		break
	inst.free()
	return found


## How much the art mesh is scaled on the table: 1.0 except for shapes
## with their own cap (PolyDie.SHAPE_HALF_EXTENT), which are grown so their
## farthest point reaches that cap (the d4: 0.065 / 0.050 = about 1.3x).
static func body_scale(shape: StringName) -> float:
	if not PolyDie.SHAPE_HALF_EXTENT.has(shape):
		return 1.0
	var mesh := mesh_for(shape)
	if mesh == null:
		return 1.0
	var ab := mesh.get_aabb()
	var half := maxf(maxf(maxf(-ab.position.x, ab.end.x), maxf(-ab.position.y, ab.end.y)), maxf(-ab.position.z, ab.end.z))
	return PolyDie.cap_for(shape) / half if half > 0.0 else 1.0


## Convex-hull collider points for a table shape, taken from the PC mesh
## the player sees (not the mobile LOD), so the die rests on exactly the
## faces it shows. Empty for shapes this file does not dress.
static func pc_hull(shape: StringName) -> PackedVector3Array:
	if not TABLE_SHAPES.has(shape):
		return PackedVector3Array()
	if not _hulls.has(shape):
		var mesh := mesh_for(shape)
		var pts := PackedVector3Array()
		if mesh != null:
			pts = (mesh.create_convex_shape(true, false) as ConvexPolygonShape3D).points
			# Same scale as the drawn body (body_scale), so it rests on what shows.
			var k := body_scale(shape)
			for i in pts.size():
				pts[i] *= k
		_hulls[shape] = pts
	return _hulls[shape]


## Turns die [param d] into the shaped body for [param td] (no-op for a d6,
## coin or any shape without a mesh). Returns true if it changed the die.
static func dress(d: DieVisual, td: TableDie) -> bool:
	var s := table_shape(td)
	if s == &"":
		return false
	var mesh := mesh_for(s)
	if mesh == null:
		return false
	d.shape = s
	var body := d.faces.get_node("Body") as MeshInstance3D
	body.mesh = mesh
	# The art is in metres; a shape with its own cap (the d4) is grown to it.
	var grow := body_scale(s)
	body.scale = Vector3.ONE * grow
	# Keep the die's own toon material (the rare tint and the lit glow live
	# on it) and borrow the art's printed numbers (its overlay texture).
	body.material_override = d.body_material
	var art := mesh.surface_get_material(0) as ShaderMaterial
	if art != null and art.get_shader_parameter("overlay_tex") != null:
		for k in ["use_overlay", "overlay_tex", "overlay_tint"]:
			d.body_material.set_shader_parameter(k, art.get_shader_parameter(k))
	for k in SHAPE_SHADE.get(s, {}):
		d.body_material.set_shader_parameter(k, SHAPE_SHADE[s][k])
	# The cube's pips go (the art prints the numbers). FaceMods marks and a
	# RareTrim child are other systems' nodes: left alone on purpose.
	d.clear_pips()
	if d.hull_outline != null:
		d.hull_outline.mesh = mesh
		d.hull_outline.scale = Vector3.ONE * grow
	# shown_value() reads labels by slot: one label per face (not padded to 6).
	d.labels.assign(td.faces)
	if s == &"d4":
		# AD #198: the lamp's shadow leaves the steep faces near black. An
		# unshaded pass in the body's own colour lifts them (D4FlatPass), and
		# a camera-facing tag shows the value (D4ValueTag).
		D4FlatPass.add(d.body_material)
		if d.get_node_or_null("D4ValueTag") == null:
			D4ValueTag.attach(d)
	return true


## Where a face-mod mark goes on a d4 or d8 face slot, for placing a decal:
## {normal, dist, at, width}. normal = the flat face's outward normal;
## dist = how far that face sits from the centre (the body mesh's farthest
## vertex along it, times its scale), so a decal there is flush; at = the
## mark's centre, an offset in the face plane; width = a square side that
## fits inside the face triangle with room for the bevels.
## A d8 slot is a face (DieHullData dirs are face normals): the mark sits in
## the middle of it. A d4 is read by its top VERTEX (dirs point at the
## corners), so slot k's mark goes on the next slot's opposite face, pulled
## toward corner k, where that face shows the k.
static func face_spot(d: DieVisual, slot: int) -> Dictionary:
	var dirs: Array = DieHullData.SHAPES[d.shape]["dirs"]
	var i := clampi(slot, 1, dirs.size()) - 1
	var n: Vector3 = (dirs[i] as Vector3).normalized()
	# The die's corners: the d4's are its dirs, the d8's the 6 axis tips.
	var corner_dirs: Array = dirs
	var toward := -1
	if d.shape == &"d4":
		toward = i
		n = -(dirs[(i + 1) % 4] as Vector3).normalized()
	else:
		corner_dirs = [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]
	var pts := _body_points(d)
	var dist := _far(pts, n)
	# The face's 3 corners are the die corners that lean most along n,
	# dropped onto the face plane.
	corner_dirs = corner_dirs.duplicate()
	corner_dirs.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.dot(n) > b.dot(n))
	var tri: Array[Vector3] = []
	for c: Vector3 in corner_dirs.slice(0, 3):
		var tip: Vector3 = c.normalized() * _far(pts, c.normalized())
		tri.append(tip - n * (tip.dot(n) - dist))
	var g := (tri[0] + tri[1] + tri[2]) / 3.0
	# Inradius: twice the area over the perimeter.
	var area := (tri[1] - tri[0]).cross(tri[2] - tri[0]).length() * 0.5
	var r := 2.0 * area / (tri[0].distance_to(tri[1]) + tri[1].distance_to(tri[2]) + tri[2].distance_to(tri[0]))
	var at := g
	if toward >= 0:
		var tip: Vector3 = (dirs[toward] as Vector3).normalized()
		for c in tri:
			if c.normalized().dot(tip) > 0.9:
				at = g.lerp(c, D4_PULL)  # edges near the corner come in by (1 - pull)
		r *= 1.0 - D4_PULL
	# A square of side r * sqrt(2) fits in a circle of radius r; BEVEL_FIT
	# keeps it off the rounded edges.
	return {"normal": n, "dist": dist, "at": at - n * at.dot(n), "width": r * sqrt(2.0) * BEVEL_FIT}


## How far a d4 mark slides from the face middle toward its corner (0..1).
const D4_PULL := 0.3
## Share of the ideal (sharp-edged) fit kept, so marks clear the bevels.
const BEVEL_FIT := 0.8


static func _body_points(d: DieVisual) -> PackedVector3Array:
	var out := PackedVector3Array()
	var body := d.faces.get_node_or_null("Body") as MeshInstance3D
	if body != null and body.mesh != null:
		for p: Vector3 in body.mesh.get_faces():
			out.append(body.scale * p)
	return out


static func _far(pts: PackedVector3Array, n: Vector3) -> float:
	var far := -INF
	for p in pts:
		far = maxf(far, p.dot(n))
	return far


## True for the shapes whose face-mod marks sit on real triangle faces.
static func has_face_spots(d: DieVisual) -> bool:
	return d.shape == &"d4" or d.shape == &"d8"
