## Dresses a table die (DieVisual) as a shaped d4 / d8 body: the 3D
## Artist's mesh (caltrop_d4 / lantern_d8, the Gallows and Beacon bodies),
## its numbered faces, and the shape id the table reads. Setting
## DieVisual.shape is what makes the rest of the table treat it as a hull
## die: DiceSim gives it the ConvexPolygonShape3D collider (PolyDie.make_shape),
## and up_slot() / face_rotation() read it from PolyDie's direction table
## (a d4 by its top POINT, a d8 by its top face, so Beacon's 7 and 8 show).
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


## The full-detail mesh for a shape: the PC .glb next to the mobile one the
## hull was built from (falls back to the mobile mesh).
static func mesh_for(shape: StringName) -> Mesh:
	var p := PolyDie.mesh_path(shape)
	if p == "":
		return null
	var pc := p.replace("_mobile.glb", ".glb")
	if ResourceLoader.exists(pc):
		p = pc
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
	body.scale = Vector3.ONE  # the art is already in metres, capped at 0.05
	# The art's own material carries the printed numbers, so drop the
	# bone-cube toon override and the cube's pips / mod decals.
	body.material_override = null
	d.clear_pips()
	var decals := d.faces.get_node_or_null("FaceMods")
	if decals != null:
		decals.free()
	if d.hull_outline != null:
		d.hull_outline.mesh = mesh
		d.hull_outline.scale = Vector3.ONE
	# shown_value() reads labels by slot: one label per face (not padded to 6).
	d.labels.assign(td.faces)
	return true
