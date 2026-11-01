## Face-mod marks drawn around the printed art of the d4 / d8 faces, at
## the spots baked in FacePrintSpots (see tools/gen_face_print_spots.gd):
##   - the Gallows d4 Twin: a solid brass diamond with a thin dark outline,
##     in the clearest spot between the printed circles;
##   - a rare glyph on a d8: a badge in the corner farthest from the
##     numeral, or, when no corner has room, the numeral itself tinted brass
##     (no disc) so the number stays readable.
class_name PolyFaceMarks
extends RefCounted

const BRASS := Color("#C9A24A")
const OUTLINE := Color("#1E1712")
## The diamond's dark outline, as a share of the face height (about 1 px on
## the phone table, where a d4 face is about 30 px tall).
const OUTLINE_SHARE := 0.03


## Where a baked spot sits on face [param f] (the face middle if none).
static func spot_point(f: Dictionary, w: Vector3) -> Vector3:
	if w == Vector3.ZERO:
		return f.g
	return f.tri[0] * w.x + f.tri[1] * w.y + f.tri[2] * w.z


## The d4 Twin mark on [param slot]'s face: two flat squares turned 45
## degrees (the dark one under, the brass one on top, so a rim shows).
static func twin_diamond(root: Node3D, d: DieVisual, slot: int) -> void:
	var f := PolyBody.face_tri(d, slot)
	var h: float = f.h
	var n: Vector3 = f.normal
	var p := spot_point(f, FacePrintSpots.spot(&"d4", slot))
	var ax := FacePrint.diamond_axes(f)
	# Diagonals along ax, so the square's sides run between them.
	var s1 := (ax[0] + ax[1]).normalized()
	var s2 := n.cross(s1)
	var side := h * FacePrintSpots.TWIN_SIZE / sqrt(2.0)
	var lift := 0.002 * d.edge
	_flat(root, "TwinDiamondEdge", Basis(s1, s2, n), p + n * lift, side, OUTLINE)
	_flat(root, "TwinDiamond", Basis(s1, s2, n), p + n * (lift + 0.0002), side - 2.0 * h * OUTLINE_SHARE, BRASS)


## A rare glyph [param mod_id] on a d8 [param slot]. Returns false if the
## mod has no glyph (the caller draws the plain mark instead).
static func rare_on_d8(root: Node3D, d: DieVisual, slot: int, mod_id: StringName) -> bool:
	if not RareDieLook.MARKS.has(mod_id):
		return false
	var f := PolyBody.face_tri(d, slot)
	var n: Vector3 = f.normal
	var w := FacePrintSpots.spot(&"d8", slot)
	var lift := 0.002 * d.edge
	if w == Vector3.ZERO:
		_tint_numeral(root, d, f, mod_id, lift)
		return true
	var u := Vector3.UP if absf(n.y) < 0.5 else Vector3.RIGHT
	u = (u - n * u.dot(n)).normalized()
	RareDieLook.add_mark(root, d, n, u, n.cross(u), f.dist + lift, mod_id)
	var mark := root.get_child(-1) as Node3D
	# Resize the cube-sized badge to its share of the face, into the corner.
	var k: float = f.h * FacePrintSpots.BADGE_SIZE / (d.edge * float(mark.get_meta("size", 1.0)))
	mark.transform = Transform3D(mark.transform.basis.scaled_local(Vector3(k, k, 1)), spot_point(f, w) + n * lift)
	return true


## No room for a badge: a copy of the face's printed art, tinted brass,
## laid a hair over it (the art's white goes brass, its dark outline stays).
static func _tint_numeral(root: Node3D, d: DieVisual, f: Dictionary, mod_id: StringName, lift: float) -> void:
	var body := d.faces.get_node("Body") as MeshInstance3D
	var src := body.get_active_material(0) as ShaderMaterial
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n: Vector3 = f.normal
	for t: Array in FacePrint.face_tris(d, n):
		if (t[0] as Vector3).dot(n) <= 0.0:
			continue  # the parallel face on the far side
		for c in 3:
			# Snapped onto the face plane, then lifted a hair off it.
			var p: Vector3 = t[c]
			st.set_uv(t[3 + c])
			st.add_vertex(p + n * (f.dist + lift - p.dot(n)))
	var mat := StandardMaterial3D.new()
	mat.albedo_color = BRASS
	mat.albedo_texture = src.get_shader_parameter("overlay_tex") if src != null else null
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED  # whichever way the art mesh winds
	mat.emission_enabled = true
	mat.emission = RareDieLook.MARKS[mod_id]
	mat.emission_texture = mat.albedo_texture
	mat.emission_energy_multiplier = 0.0
	var mark := Node3D.new()
	mark.name = "RareMark_%s" % mod_id
	mark.set_meta("mod", mod_id)
	mark.set_meta("ink", mat)  # RareDieLook lights it like any glyph
	mark.set_meta("tint", true)
	root.add_child(mark)
	var mi := MeshInstance3D.new()
	mi.name = "NumeralTint"
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mark.add_child(mi)


static func _flat(root: Node3D, name: String, b: Basis, at: Vector3, side: float, col: Color) -> void:
	var q := QuadMesh.new()
	q.size = Vector2(side, side)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = q
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.transform = Transform3D(b, at)
	root.add_child(mi)
