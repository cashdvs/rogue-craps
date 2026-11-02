## The authored body / pip materials of the special dice
## (res://art/models/dice/materials/<die>_body.tres and <die>_pip.tres) put
## on a table die. Before this, every special die was painted plain Bone.
##   - A toon_noir body (most dice): its values are copied onto the die's
##     own toon material, so the lit / cold glow still works on it.
##   - Any other shader (the Mirror's toon_mirror): that material is used
##     as is (a copy), with the die's ink outline under it.
##   - Dice in EDGE_INK get a wider outline (EDGE_MUL, else 1.5x) in their own colour.
##   - Dice with crack grooves (Cracked) get DieCrackInk's dark seams.
## Called from BonfireTableLook.apply_die_look; reset() first puts back the
## plain look, so one DieVisual can show a different die later.
class_name DieArtMaterial
extends RefCounted

const DIR := "res://art/models/dice/materials/"
const TOON_NOIR := "res://shaders/3d/toon_noir.gdshader"
## Dice whose edge outline is drawn 1.5x wide, in this colour.
## AD proof pass: Extra a brass rim, Beacon and Bellows a cream keyline.
const EDGE_INK := {
	&"mirror": Color("#E8DCC0"), &"cracked": Color("#2A2420"),
	&"wanderer": Color("#16130F"), &"ossuary": Color("#E8DCC0"), &"fortune": Color("#C9A24A"), &"powder_keg": Color("#E8DCC0"), &"usurer": Color("#C9A24A"),
	&"extra": Color("#C9A24A"), &"beacon": Color("#E8DCC0"), &"bellows": Color("#E8DCC0"),
	&"twin_flame": Color("#C9A24A"), &"blood_pact": Color("#C9A24A"), &"coven": Color("#E8DCC0"),
}
## Dice whose outline is a thinner multiple than EDGE_WIDTH_MUL (AD, Nov 1).
## Beacon / Bellows went 1.5x -> 1.3x: the thinner shell stops the jagged slivers.
const EDGE_MUL := {
	&"twin_flame": 1.3, &"blood_pact": 1.3, &"coven": 1.3, &"usurer": 1.3,
	&"beacon": 1.3, &"bellows": 1.3, &"fortune": 1.3,
	## Wanderer: a thin dark ink line (stock width) instead of the cream keyline (AD, Nov 1 10:05 PM).
	&"wanderer": 1.0,
	&"mirror": 1.2, &"ossuary": 1.2, &"powder_keg": 1.2,
}
## Authored rares that still wear the brass bevel RareTrim at full strength (Fortune).
const TRIM_DICE: Array[StringName] = [&"fortune"]
## Dice with unlit bone-cream #E8DCC0 corner caps, 15% of the edge per corner (Ossuary, AD Nov 1).
const CAP_DICE: Array[StringName] = [&"ossuary"]
const CAP_COLOR := Color("#E8DCC0")
## Dice that wear two brass hoop bands round their sides (Barrel).
const HOOP_DICE: Array[StringName] = [&"barrel"]
const HOOP_MAT := DIR + "barrel_hoop.tres"  # flat brass #C9A24A, like the brass keylines
const EDGE_WIDTH_MUL := 1.5


## The die's authored body material path, or "" when it has none (Bone has
## one too, but it is the default look, so it is skipped).
static func body_path(die_id: StringName) -> String:
	var c := DiceIds.canonical(die_id)
	if c == &"" or c == DiceIds.DIE_BONE:
		return ""
	var p := DIR + "%s_body.tres" % c
	return p if ResourceLoader.exists(p) else ""


## Puts back the die's own toon material and its first values (undoes apply).
static func reset(d: DieVisual) -> void:
	var body := d.faces.get_node_or_null("Body") as MeshInstance3D
	if not d.has_meta(&"base_material"):
		# First time: remember the plain material and every value on it.
		var vals := {}
		for u in d.body_material.shader.get_shader_uniform_list():
			vals[u.name] = d.body_material.get_shader_parameter(u.name)
		d.set_meta(&"base_material", d.body_material)
		d.set_meta(&"base_values", vals)
		d.set_meta(&"base_outline", d.body_material.next_pass)
		return
	if not d.has_meta(&"art_material"):
		return
	DieCrackInk.clear(d)
	_set_hoops(d, false)
	_set_caps(d, false)
	var base := d.get_meta(&"base_material") as ShaderMaterial
	var vals: Dictionary = d.get_meta(&"base_values")
	for k in vals:
		base.set_shader_parameter(k, vals[k])
	base.next_pass = d.get_meta(&"base_outline")
	d.body_material = base
	if body != null:
		body.material_override = base
	d.remove_meta(&"art_material")


## Gives die [param d] (showing [param td]) its authored materials.
## Returns false (and changes nothing) when the die has none.
static func apply(d: DieVisual, td: TableDie) -> bool:
	reset(d)
	var p := body_path(td.id)
	if p == "":
		return false
	var art := load(p) as ShaderMaterial
	if art == null:
		return false
	var c := DiceIds.canonical(td.id)
	var pip := Palette.PIT_BLACK
	var pp := DIR + "%s_pip.tres" % c
	if ResourceLoader.exists(pp):
		var pm := load(pp) as ShaderMaterial
		if pm != null and pm.get_shader_parameter("albedo") != null:
			pip = pm.get_shader_parameter("albedo")
	var col: Variant = art.get_shader_parameter("albedo")
	# set_look sets the body colour and rebuilds the pips in the pip colour.
	d.set_look(col if col != null else Palette.BONE, pip, td.faces)
	if art.shader != null and art.shader.resource_path == TOON_NOIR:
		for u in art.shader.get_shader_uniform_list():
			var v: Variant = art.get_shader_parameter(u.name)
			# The printed-number overlay is left to PolyBody.dress, which only
			# adds it on the matching shaped body (on a cube it would be wrong).
			if v != null and not String(u.name).begins_with("overlay") and u.name != "use_overlay":
				d.body_material.set_shader_parameter(u.name, v)
	else:
		var m := art.duplicate() as ShaderMaterial
		m.next_pass = d.body_material.next_pass
		d.body_material = m
		var body := d.faces.get_node_or_null("Body") as MeshInstance3D
		if body != null:
			body.material_override = m
	if EDGE_INK.has(c) and d.body_material.next_pass is ShaderMaterial:
		var o := (d.body_material.next_pass as ShaderMaterial).duplicate() as ShaderMaterial
		o.set_shader_parameter("width", float(o.get_shader_parameter("width")) * float(EDGE_MUL.get(c, EDGE_WIDTH_MUL)))
		o.set_shader_parameter("color", EDGE_INK[c])
		d.body_material.next_pass = o
	DieCrackInk.apply(d)  # Cracked: its seams in dark ink
	_set_hoops(d, c in HOOP_DICE)
	_set_caps(d, c in CAP_DICE)
	RareDieLook.set_trim(d, c in TRIM_DICE)  ## the same trim the plain rares wear
	d.set_meta(&"art_material", c)
	return true


## Adds (or removes) two thin brass bands round the die's four side faces,
## near the top and bottom edges, clear of the pips (like barrel hoops).
## QA PR 250: box bands stuck out at the rounded corners (bars when the die
## lay on its side), so each band is now a 1.5%-bigger copy of the body mesh
## that only draws a thin strip: it follows the body's own curves, flush.
static func _set_hoops(d: DieVisual, on: bool) -> void:
	var body := d.faces.get_node_or_null("Body") as MeshInstance3D
	var old := body.get_node_or_null("HoopBands") if body != null else null
	if old != null:
		old.free()
	if not on or body == null or body.mesh == null:
		return
	var root := Node3D.new()
	root.name = "HoopBands"
	var brass: Color = (load(HOOP_MAT) as StandardMaterial3D).albedo_color
	var h := body.mesh.get_aabb().size.y  # the body's height, in its own units
	for y in [-0.38, 0.38]:
		var band := MeshInstance3D.new()
		band.mesh = body.mesh
		band.scale = Vector3.ONE * 1.015
		var m := ShaderMaterial.new()
		m.shader = _hoop_shader()
		m.set_shader_parameter("color", brass)
		m.set_shader_parameter("y_at", y * h)
		m.set_shader_parameter("half_h", 0.07 * h)  # 0.14 of the height tall
		band.material_override = m
		band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(band)
	body.add_child(root)


static var _hoop_sh: Shader
## Flat brass (unshaded, no emission), drawn only where the body point's
## height is within half_h of y_at: a band on the side faces.
static func _hoop_shader() -> Shader:
	if _hoop_sh == null:
		_hoop_sh = Shader.new()
		_hoop_sh.code = """shader_type spatial;
render_mode unshaded;
uniform vec4 color : source_color;
uniform float y_at;
uniform float half_h;
varying float ly;
void vertex() { ly = VERTEX.y; }
void fragment() {
	if (abs(ly - y_at) > half_h) { discard; }
	ALBEDO = color.rgb;
}"""
	return _hoop_sh


## Adds (or removes) the corner caps: a 1.5%-bigger copy of the body mesh
## that only draws where a point is near a corner on all three axes
## (within 15% of the edge of it), in flat unlit cream. Cheap: one mesh.
static func _set_caps(d: DieVisual, on: bool) -> void:
	var body := d.faces.get_node_or_null("Body") as MeshInstance3D
	var old := body.get_node_or_null("CornerCaps") if body != null else null
	if old != null:
		old.free()
	if not on or body == null or body.mesh == null:
		return
	var box := body.mesh.get_aabb()
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded;
uniform vec4 color : source_color;
uniform vec3 mid;
uniform vec3 half_size;
uniform float cap;
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	vec3 q = abs(lp - mid) / half_size;  // 1.0 = on the face
	if (min(q.x, min(q.y, q.z)) < 1.0 - cap) { discard; }
	ALBEDO = color.rgb;
}"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("color", CAP_COLOR)
	m.set_shader_parameter("mid", box.get_center())
	m.set_shader_parameter("half_size", box.size * 0.5)
	m.set_shader_parameter("cap", 0.30)  # 15% of the edge = 30% of the half edge
	var mi := MeshInstance3D.new()
	mi.name = "CornerCaps"
	mi.mesh = body.mesh
	mi.scale = Vector3.ONE * 1.015
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mi)
