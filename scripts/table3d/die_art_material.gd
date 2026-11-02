## The authored body / pip materials of the special dice
## (res://art/models/dice/materials/<die>_body.tres and <die>_pip.tres) put
## on a table die. Before this, every special die was painted plain Bone.
##   - A toon_noir body (most dice): its values are copied onto the die's
##     own toon material, so the lit / cold glow still works on it.
##   - Any other shader (the Mirror's toon_mirror): that material is used
##     as is (a copy), with the die's ink outline under it.
##   - Mirror and Cracked also get a 1.5x outline in their own edge colour.
## Called from BonfireTableLook.apply_die_look; reset() first puts back the
## plain look, so one DieVisual can show a different die later.
class_name DieArtMaterial
extends RefCounted

const DIR := "res://art/models/dice/materials/"
const TOON_NOIR := "res://shaders/3d/toon_noir.gdshader"
## Dice whose edge outline is drawn 1.5x wide, in this colour.
const EDGE_INK := {&"mirror": Color("#3A4148"), &"cracked": Color("#2A2420")}
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
		o.set_shader_parameter("width", float(o.get_shader_parameter("width")) * EDGE_WIDTH_MUL)
		o.set_shader_parameter("color", EDGE_INK[c])
		d.body_material.next_pass = o
	d.set_meta(&"art_material", c)
	return true
