## The rare dice look on the Bonfire table (Art Director, playtest e1cd912
## bug 1): a warm-tinted body and one mark per rare face mod, each its own
## glyph on a dark plate. Material only: no flame, and the marks glow (at
## most MARK_EMISSION_MAX) only while the die is lit.
class_name RareDieLook
extends RefCounted

## Body tint, multiplied into Bone at BODY_TINT_AMOUNT.
const BODY_TINT := Color("#C8A878")
const BODY_TINT_AMOUNT := 0.55
## Brass edge trim (AD rare-vs-bone): the main rare cue, on the bevels only.
const TRIM := Color("#E6C46A")
## A body normal is flat face (no trim) when it is within the shape's
## threshold of one of its flat-face normals (dot >= SHAPE_FLAT); anything
## rounder is bevel / edge. A d6 uses the 6 axes at TRIM_FLAT (37 deg).
const TRIM_FLAT := 0.80
## Flat-face normals (object space) per shape. d4 / d8 from Godot Dev's
## caltrop_d4 / lantern_d8 meshes (#198), slot order.
const _A := 0.57735
const FACE_NORMALS: Dictionary = {
	&"d6": [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD],
	&"d4": [Vector3(0, 1, 0), Vector3(0, -0.3333, 0.9428), Vector3(-0.8165, -0.3333, -0.4714), Vector3(0.8165, -0.3333, -0.4714)],
	&"d8": [Vector3(_A, -_A, _A), Vector3(-_A, -_A, _A), Vector3(-_A, -_A, -_A), Vector3(_A, -_A, -_A),
		Vector3(-_A, _A, _A), Vector3(_A, _A, _A), Vector3(_A, _A, -_A), Vector3(-_A, _A, -_A)],
}
## d4 / d8 bevels sit ~18 deg off their faces (cos 0.951), so their flat
## cut is 14 deg (0.97): faces bare, the bevel band brass.
const SHAPE_FLAT: Dictionary = {&"d6": TRIM_FLAT, &"d4": 0.97, &"d8": 0.97}
## The trim sits this far (edge units) out along the normal, over the body.
const TRIM_LIFT := 0.002
## AD fallback for a face-up rare: an inset brass frame line on each flat
## face, FRAME_AT of the edge out from the centre (~1 px at 48 px wide). The
## AD asked for ~6% in from the face edge; the flat face ends at 0.34 (bevel
## 0.16) and corner pips reach 0.32, so the line sits in that clear gap.
const FRAME_AT := 0.33
const FRAME_HALF := 0.0105
## Light resistance: share of the trim drawn flat (unshaded albedo, not
## emission) over its lit result, so bonfire light cannot swallow it. Capped
## at TRIM_UNSHADED_MAX.
const TRIM_UNSHADED := 0.7
const TRIM_UNSHADED_MAX := 0.7
## Second pass: the flat albedo blended at TRIM_UNSHADED over the lit pass.
const TRIM_FLAT_SHADER := """shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;
uniform vec4 trim : source_color;
uniform float flat_limit;
uniform float lift;
uniform float mix_amount;
uniform float edge;
uniform float frame_at;
uniform float frame_half;
uniform vec3 face_n[8];
uniform int face_count;
varying vec3 obj_n;
varying vec3 obj_p;
void vertex() {
	obj_n = NORMAL;
	obj_p = VERTEX;
	VERTEX += NORMAL * lift * 1.5;
}
void fragment() {
	vec3 n = normalize(obj_n);
	vec3 a = abs(n);
	bool flat_face = false;
	for (int i = 0; i < 8; i++) {
		if (i < face_count && dot(n, face_n[i]) >= flat_limit) { flat_face = true; }
	}
	if (flat_face) {
		vec3 q = abs(obj_p) / edge;
		float m = a.x > a.y && a.x > a.z ? max(q.y, q.z) : (a.y > a.z ? max(q.x, q.z) : max(q.x, q.y));
		if (abs(m - frame_at) > frame_half) { discard; }
	}
	ALBEDO = trim.rgb;
	ALPHA = mix_amount;
}
"""
const TRIM_SHADER := """shader_type spatial;
render_mode diffuse_toon, specular_disabled;
uniform vec4 trim : source_color;
uniform float flat_limit;
uniform float lift;
uniform float edge;
uniform float frame_at;
uniform float frame_half;
uniform vec3 face_n[8];
uniform int face_count;
varying vec3 obj_n;
varying vec3 obj_p;
void vertex() {
	obj_n = NORMAL;
	obj_p = VERTEX;
	VERTEX += NORMAL * lift;
}
void fragment() {
	vec3 n = normalize(obj_n);
	vec3 a = abs(n);
	bool flat_face = false;
	for (int i = 0; i < 8; i++) {
		if (i < face_count && dot(n, face_n[i]) >= flat_limit) { flat_face = true; }
	}
	if (flat_face) {
		vec3 q = abs(obj_p) / edge;
		float m = a.x > a.y && a.x > a.z ? max(q.y, q.z) : (a.y > a.z ? max(q.x, q.z) : max(q.x, q.y));
		if (abs(m - frame_at) > frame_half) { discard; }
	}
	ALBEDO = trim.rgb;
	ROUGHNESS = 0.55;
}
"""
const FUSE_MARK := Color("#FFA13A")
const JACKPOT_MARK := Color("#FFF1B8")
const HEX_MARK := Color("#8FA8D8")
const GILDED_MARK := Color("#E8B84A")
const STEP_MARK := Color("#F5EBD8")
## The plate each mark sits on (its "face" for the contrast check).
const PLATE := Color("#1E1712")
const MARK_EMISSION_MAX := 0.3
const MIN_CONTRAST := 3.0
## mod id -> mark colour. Glyphs: fuse spark, coin, cracked x, bitten coin, up arrow.
const MARKS: Dictionary = {
	&"fuse": FUSE_MARK, &"jackpot": JACKPOT_MARK, &"hex": HEX_MARK,
	&"gilded": GILDED_MARK, &"step": STEP_MARK,
}
## Plate diameter as a fraction of the die edge: as big as the pips allow
## (readable at table zoom), up to PLATE_MAX. A five or six only has room
## for about a quarter of the edge between its pips.
const PLATE_MAX := 0.44
## Glyph size / stroke as fractions of the plate diameter (thick enough to
## read at table zoom).
const GLYPH := 0.78
const STROKE := 0.20
## A rim of the mark's own colour around the plate; it is the ink, so it
## glows (MARK_EMISSION_MAX) only when the die is lit or landed.
const RIM := 0.10
## Pip radius / face margin (edge units) the plate keeps clear of.
const PIP_CLEAR := 0.09 + 0.012
const FACE_MARGIN := 0.40


## The rare body colour: Bone multiplied by BODY_TINT at BODY_TINT_AMOUNT.
static func body_color() -> Color:
	return Palette.BONE.lerp(Palette.BONE * BODY_TINT, BODY_TINT_AMOUNT)


## True when a flat-face point [param p] (object space, edge [param e])
## lies on the inset frame line.
static func is_frame_point(p: Vector3, n: Vector3, e: float) -> bool:
	var a := n.abs()
	var q := p.abs() / e
	var m := maxf(q.y, q.z) if a.x > a.y and a.x > a.z else (maxf(q.x, q.z) if a.y > a.z else maxf(q.x, q.y))
	return absf(m - FRAME_AT) <= FRAME_HALF


## True when a body normal [param n] (object space) is bevel, so takes the trim.
static func is_trim_normal(n: Vector3, shape: StringName = &"d6") -> bool:
	var u := n.normalized()
	for f: Vector3 in face_normals(shape):
		if u.dot(f.normalized()) >= flat_for(shape):
			return false
	return true


## A shape's flat-face normals (unit); unknown shapes use the d6's.
static func face_normals(shape: StringName) -> Array:
	var out: Array = []
	for f: Vector3 in FACE_NORMALS.get(shape, FACE_NORMALS[&"d6"]):
		out.append(f.normalized())
	return out


static func flat_for(shape: StringName) -> float:
	return float(SHAPE_FLAT.get(shape, TRIM_FLAT))


## Fits RareTrim to the body as it is now: its mesh, its shape's face
## normals and cut, and the square frame line only on a d6 (d4 / d8 faces
## are triangles: bevel brass only). set_trim calls this right away and once
## more deferred, after PolyBody.dress has swapped in a d4 / d8 mesh.
static func fit_trim(d: DieVisual) -> void:
	if not is_instance_valid(d):
		return
	var body := d.faces.get_node_or_null("Body") as MeshInstance3D
	var mi := body.get_node_or_null("RareTrim") as MeshInstance3D if body != null else null
	if mi == null:
		return
	mi.mesh = body.mesh
	var shape: StringName = d.shape if FACE_NORMALS.has(d.shape) else &"d6"
	var ns := PackedVector3Array(face_normals(shape))
	ns.resize(8)
	var m := mi.material_override as ShaderMaterial
	for mat: ShaderMaterial in [m, m.next_pass as ShaderMaterial]:
		mat.set_shader_parameter("face_n", ns)
		mat.set_shader_parameter("face_count", face_normals(shape).size())
		mat.set_shader_parameter("flat_limit", flat_for(shape))
		mat.set_shader_parameter("edge", body.mesh.get_aabb().size.x)
		mat.set_shader_parameter("frame_half", FRAME_HALF if shape == &"d6" else -1.0)


## Adds (on) or removes (off) the brass bevel trim: a copy of the body mesh
## that keeps only bevel fragments. Separate from the #162 hull outline.
static func set_trim(d: DieVisual, on: bool) -> void:
	var body := d.faces.get_node_or_null("Body") as MeshInstance3D
	if body == null:
		return
	var old := body.get_node_or_null("RareTrim")
	if old != null:
		old.free()
	if not on:
		return
	var sh := Shader.new()
	sh.code = TRIM_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("trim", TRIM)
	m.set_shader_parameter("flat_limit", TRIM_FLAT)
	m.set_shader_parameter("lift", TRIM_LIFT * d.edge)
	var fs := Shader.new()
	fs.code = TRIM_FLAT_SHADER
	var f := ShaderMaterial.new()
	f.shader = fs
	f.set_shader_parameter("trim", TRIM)
	f.set_shader_parameter("flat_limit", TRIM_FLAT)
	f.set_shader_parameter("lift", TRIM_LIFT * d.edge)
	f.set_shader_parameter("mix_amount", minf(TRIM_UNSHADED, TRIM_UNSHADED_MAX))
	for mat: ShaderMaterial in [m, f]:
		mat.set_shader_parameter("frame_at", FRAME_AT)
	m.next_pass = f
	var mi := MeshInstance3D.new()
	mi.name = "RareTrim"
	mi.mesh = body.mesh
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mi)
	fit_trim(d)
	_fit_later.call_deferred(d)


## Deferred fit_trim: the die may be gone by then.
static func _fit_later(d: Variant) -> void:
	if is_instance_valid(d) and d is DieVisual:
		fit_trim(d)


## True when [param die_id] is a rare die (its shape data's rarity).
static func is_rare(die_id: StringName) -> bool:
	var p := "res://resources/dice/shapes/%s.tres" % die_id
	if die_id == &"" or not ResourceLoader.exists(p):
		return false
	var sh := load(p) as SpecialDieData
	return sh != null and sh.is_rare()


## WCAG contrast ratio between two colours (1..21).
static func contrast(a: Color, b: Color) -> float:
	var la := _rel_lum(a)
	var lb := _rel_lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _rel_lum(c: Color) -> float:
	var l := c.srgb_to_linear()
	return 0.2126 * l.r + 0.7152 * l.g + 0.0722 * l.b


## Adds the mark for mod [param mod_id] to the face with normal [param n]
## (in-plane axes u, v), on a free spot between the pips. Returns false when
## the mod has no mark.
static func add_mark(root: Node3D, d: DieVisual, n: Vector3, u: Vector3, v: Vector3, lift: float, mod_id: StringName) -> bool:
	if not MARKS.has(mod_id):
		return false
	var e := d.edge
	var col: Color = MARKS[mod_id]
	var mark := Node3D.new()
	mark.name = "RareMark_%s" % mod_id
	mark.set_meta("mod", mod_id)
	var spot := _free_spot(d, n, u, v)
	var c: Vector2 = spot["at"] * e
	var size: float = spot["size"]
	mark.set_meta("size", size)
	mark.transform = Transform3D(Basis(u, v, n), n * lift + u * c.x + v * c.y)
	root.add_child(mark)
	var plate := _material(PLATE)
	var ink := _material(col)
	ink.emission_enabled = true
	ink.emission = col
	ink.emission_energy_multiplier = 0.0
	mark.set_meta("ink", ink)
	var pr := e * size * 0.5
	_disc(mark, Vector2.ZERO, pr, 0.0, ink)
	_disc(mark, Vector2.ZERO, pr * (1.0 - RIM), 0.0002, plate)
	var g := pr * 2.0 * GLYPH
	var w := g * STROKE
	match mod_id:
		&"fuse":
			# A spark: a short fuse tail and a four-point star.
			_bar(mark, Vector2(-0.30, -0.30) * g, g * 0.45, w, PI * 0.25, ink)
			for k in 4:
				_bar(mark, Vector2(0.10, 0.10) * g, g * (0.70 if k % 2 == 0 else 0.45), w, PI * 0.25 * k, ink)
		&"jackpot":
			# A coin: a disc with a dark centre hole.
			_disc(mark, Vector2.ZERO, g * 0.45, 0.0006, ink)
			_disc(mark, Vector2.ZERO, w, 0.001, plate)
		&"hex":
			# A cracked x: two crossing bars, one broken with a jog.
			_bar(mark, Vector2.ZERO, g * 0.95, w, PI * 0.25, ink)
			_bar(mark, Vector2(-0.30, 0.18) * g, g * 0.36, w, -PI * 0.25, ink)
			_bar(mark, Vector2(0.18, -0.30) * g, g * 0.36, w, -PI * 0.25, ink)
		&"gilded":
			# A coin with a bite out of its rim.
			_disc(mark, Vector2.ZERO, g * 0.45, 0.0006, ink)
			_disc(mark, Vector2(0.36, 0.30) * g, g * 0.22, 0.001, plate)
		&"step":
			# An up arrow.
			_bar(mark, Vector2(0, -0.10) * g, g * 0.70, w, PI * 0.5, ink)
			_bar(mark, Vector2(-0.14, 0.20) * g, g * 0.42, w, PI * 0.25, ink)
			_bar(mark, Vector2(0.14, 0.20) * g, g * 0.42, w, PI * 0.75, ink)
	return true


## Lights (or dims) every mark on [param d]: emission MARK_EMISSION_MAX only while lit.
static func set_marks_lit(d: DieVisual, on: bool) -> void:
	var root := d.faces.get_node_or_null("FaceMods")
	if root == null:
		return
	for m in root.get_children():
		if m.has_meta("ink"):
			(m.get_meta("ink") as StandardMaterial3D).emission_energy_multiplier = MARK_EMISSION_MAX if on else 0.0


## The roomiest spot on the face clear of the pips: {"at": Vector2 (edge
## units, u/v plane), "size": plate diameter / edge}.
static func _free_spot(d: DieVisual, n: Vector3, u: Vector3, v: Vector3) -> Dictionary:
	var taken: Array[Vector2] = []
	var pips := d.faces.get_node_or_null("Pips")
	if pips != null:
		for p in pips.get_children():
			if p is Node3D and (p as Node3D).position.dot(n) > d.edge * 0.3:
				var q := (p as Node3D).position / d.edge
				taken.append(Vector2(q.dot(u), q.dot(v)))
	var spots: Array[Vector2] = [Vector2.ZERO, Vector2(0.2, 0.2), Vector2(-0.2, -0.2),
		Vector2(0.2, -0.2), Vector2(-0.2, 0.2), Vector2(0, 0.2), Vector2(0.2, 0),
		Vector2(0, -0.2), Vector2(-0.2, 0), Vector2(0.25, 0), Vector2(-0.25, 0),
		Vector2(0, 0.25), Vector2(0, -0.25)]
	var best := spots[0]
	var best_r := -1.0
	for s in spots:
		var r := FACE_MARGIN - maxf(absf(s.x), absf(s.y))
		for t in taken:
			r = minf(r, s.distance_to(t) - PIP_CLEAR)
		if r > best_r + 0.0001:
			best_r = r
			best = s
	return {"at": best, "size": minf(best_r * 2.0, PLATE_MAX)}


static func _material(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.8
	return m


static func _disc(parent: Node3D, at: Vector2, r: float, up: float, mat: Material) -> void:
	var cyl := CylinderMesh.new()
	cyl.top_radius = r
	cyl.bottom_radius = r
	cyl.height = 0.0001
	cyl.radial_segments = 20
	cyl.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = cyl
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Cylinder axis is +Y; lay it along the face normal (+Z here).
	mi.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(at.x, at.y, up))
	parent.add_child(mi)


static func _bar(parent: Node3D, at: Vector2, length: float, thick: float, angle: float, mat: Material) -> void:
	var q := QuadMesh.new()
	q.size = Vector2(length, thick)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.transform = Transform3D(Basis(Vector3.BACK, angle), Vector3(at.x, at.y, 0.0006))
	parent.add_child(mi)
