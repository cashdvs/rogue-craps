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
	return true


## The d4's four face normals (object space), in face-slot order 1..4.
const D4_FACE_NORMALS: Array[Vector3] = [
	Vector3(0, 1, 0), Vector3(0, -0.3333, 0.9428),
	Vector3(-0.8165, -0.3333, -0.4714), Vector3(0.8165, -0.3333, -0.4714)]


## Where a d4 face is, for placing a decal on it: {normal, dist, width}.
## dist = how far the flat face sits from the centre (the body mesh's
## farthest vertex along the normal, times its scale), so a decal there is
## flush. width = a square that fits inside the triangle: a regular
## tetrahedron's face incircle has radius sqrt(2) * dist, so a square of
## side 2 * dist fits; 0.9 leaves room for the bevels.
static func d4_face(d: DieVisual, slot: int) -> Dictionary:
	var n: Vector3 = D4_FACE_NORMALS[clampi(slot, 1, 4) - 1].normalized()
	var dist := d.edge * 0.5
	var body := d.faces.get_node_or_null("Body") as MeshInstance3D
	if body != null and body.mesh != null:
		var far := -INF
		for p: Vector3 in body.mesh.get_faces():
			far = maxf(far, (body.scale * p).dot(n))
		dist = far
	return {"normal": n, "dist": dist, "width": 2.0 * dist * 0.9}
