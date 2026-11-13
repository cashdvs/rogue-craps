## Builds one shared beveled chip (AD chips_3d_nov5 SPEC §1): rim by tier,
## face PNG on the top cap, optional RISKY overlay. Also builds the bone
## token used to lift flat mod / Seal / Draught icons (HANDOFF_SPEC §5).
## The shop shelf calls present_for_shop: a larger chip, face toward the
## camera, rarity tint on the rim only. The HUD row does not.
class_name ShopChipBuild
extends RefCounted

const R := 1.0
const H := 0.20
const BEVEL := 0.04
## Face PNG includes brass+accent; leave an outer rim band for tier spots.
const FACE_R := 0.78
const SPOT_R := 0.90  ## Top-band spot centres (SPEC: ~80% of radius).
const RISK_OVERLAY := "res://art/chips/chip_risky_overlay.png"
## Glyph PNG for each token art key (baked under art/chips/token_*.png).
const TOKEN_FACE := {
	&"mod_wild": "spark", &"mod_twin": "twin", &"mod_gilded": "coin",
	&"mod_ember_pip": "ring_dot", &"soul": "bottle",
}
## Tier spot count + shape (SPEC table). Colour is light on clay, dark on brass/bone.
const SPOTS := {
	&"C": {"n": 4, "shape": &"round", "col": Color("#ECE2C8")},
	&"S": {"n": 6, "shape": &"square", "col": Color("#2A221C")},
	&"R": {"n": 8, "shape": &"diamond", "col": Color("#2A221C")},
}
## Shop-shelf rim tints. Keys are the existing ChipLooks tiers (C common,
## S special, R rare). Presentation only: no new tier, and prices and odds
## stay where they are. The face PNG is a separate unshaded disc, so the
## design stays readable while the rim takes the colour.
const RARITY_TINT := {
	## Common: muted bone / grey, quiet on the wood counter.
	&"C": Color("#B7AA96"),
	## Special: green. This is the middle tier (there is no "uncommon" id).
	&"S": Color("#2F8F4E"),
	## Rare: blue, distinct from Special green and Common bone.
	&"R": Color("#3A6FBF"),
}
## Shelf chips are this many times the shared icon fit (1 = the old size).
## Kept inside 1.25–1.4 so the face still sits in the icon, clear of the tag.
const SHOP_CHIP_SCALE := 1.32


## A chip or bone-token Node3D for `id` (chip id or token art key).
static func make(id: StringName) -> Node3D:
	return _chip(id) if ChipLooks.has(id) else _token(id)


## Shelf only, after the rig has fitted the pivot: tint the rim, grow the chip,
## and point the face (+Y) at the shop camera. The face PNG stays on its own
## disc, so the design is not recoloured. Hover (`ShopItem.lift`) and any idle
## slide must move the node, not rotate it: the face normal is this basis Y.
static func present_for_shop(chip: Node3D, id: StringName) -> void:
	_apply_rarity_tint(chip, id)
	_drop_side_stripes(chip)  # Edge boxes were for the old 3/4 view; face-on they stick out.
	_aim(chip, chip.get_parent() as Node3D, _camera_up())


## Copy the rim material and set its albedo to this chip's tier tint.
## Emission stays 0: the rarity read is the colour, not a glow.
static func _apply_rarity_tint(chip: Node3D, id: StringName) -> void:
	var tier: StringName = ChipLooks.look(id).tier
	var tint: Color = RARITY_TINT[tier]
	var rim := _rim_mesh(chip)
	var mat := (rim.material_override as ShaderMaterial).duplicate() as ShaderMaterial
	mat.set_shader_parameter("albedo", tint)
	# Dark band stays in the same hue, so the toon steps don't turn the rim brown.
	mat.set_shader_parameter("shadow_color", tint.darkened(0.55))
	mat.set_shader_parameter("emission_energy", 0.0)
	rim.material_override = mat


## The beveled body (the first toon material). Spots and the face use other materials.
static func _rim_mesh(chip: Node3D) -> MeshInstance3D:
	for c: Node in chip.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).material_override is ShaderMaterial:
			return c
	return null


## Up axis of the shop camera, matching `look_at_from_position` in the rig.
static func _camera_up() -> Vector3:
	var look := Basis.looking_at(-ShopDieRender.CAM_OFFSET.normalized(), Vector3.UP)
	return look.y


## Point face +Y at the camera. PlaneMesh puts the texture's top toward local -Z,
## so local +Z is aimed down the screen and the art stays upright. Scale is
## restored because setting `basis` clears it.
static func _aim(chip: Node3D, pivot: Node3D, cam_up: Vector3) -> void:
	var fit := pivot.scale.x
	var origin := pivot.position + pivot.basis * (chip.position * fit)
	var to_cam := (ShopDieRender.CAM_OFFSET - origin).normalized()
	chip.basis = _basis_face(to_cam, -cam_up)
	chip.scale = Vector3.ONE * SHOP_CHIP_SCALE


## Side stripes are the tall boxes. Top spots are flat (height ~0.01).
static func _drop_side_stripes(chip: Node3D) -> void:
	var drop: Array[Node] = []
	for c: Node in chip.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is BoxMesh:
			if ((c as MeshInstance3D).mesh as BoxMesh).size.y > 0.05:
				drop.append(c)
	for n: Node in drop:
		chip.remove_child(n)
		n.free()


## Basis with Y pointing at the camera and Z following `up_hint` in the face plane.
static func _basis_face(toward: Vector3, up_hint: Vector3) -> Basis:
	var y := toward.normalized()
	var z := (up_hint - y * up_hint.dot(y)).normalized()
	var x := y.cross(z).normalized()
	z = x.cross(y).normalized()
	return Basis(x, y, z)


static func face_path(id: StringName) -> String:
	var p := ChipLooks.face_path(id) if ChipLooks.has(id) else ""
	return p if p != "" and ResourceLoader.exists(p) else ""


static func _chip(id: StringName) -> Node3D:
	var look: Dictionary = ChipLooks.look(id)
	var tier: Dictionary = ChipLooks.TIER[look.tier]
	var root := Node3D.new()
	root.name = "Chip_%s" % id
	var body := MeshInstance3D.new()
	body.mesh = _beveled()
	var opts := {"roughness": tier.rough, "emission_energy": 0.0}
	if float(tier.metal) > 0.0:
		opts["spec_size"] = 0.92
		opts["spec_strength"] = minf(float(tier.metal), 0.3)
	# Solid rim colour only — spot textures need cylindrical UVs we don't have,
	# so spots are small child meshes (see _add_spots).
	body.material_override = Toon.inked(tier.rim, tier.rim * 0.35, Toon.INK_CHIP, opts, 1)
	root.add_child(body)
	_add_spots(root, look.tier)
	var face_p := face_path(id)
	if face_p != "":
		root.add_child(_disc(FACE_R, H * 0.5 + 0.002, load(face_p) as Texture2D))
	# This PR: only Double Down ships the RISKY overlay (AD). Others later.
	if id == &"double_down" and ResourceLoader.exists(RISK_OVERLAY):
		root.add_child(_disc(R * 0.98, H * 0.5 + 0.004, load(RISK_OVERLAY) as Texture2D))
	return root


## Bone disc + brass ring + carved mark for mods / Seals / Draught.
static func _token(art_key: StringName) -> Node3D:
	var root := Node3D.new()
	root.name = "Token_%s" % art_key
	var body := MeshInstance3D.new()
	body.mesh = _beveled()
	body.material_override = Toon.inked(Color("#E8DCC0"), Color("#8E7A5C"), Toon.INK_CHIP, {
		"roughness": 0.7, "emission_energy": 0.0,
	}, 1)
	root.add_child(body)
	var ring := MeshInstance3D.new()
	ring.mesh = _annulus(0.92, 0.78)
	ring.position.y = H * 0.5 + 0.001
	ring.material_override = Toon.inked(Color("#C9A24A"), Toon.SHADOW_BRASS, Toon.INK_CHIP * 0.6, {
		"roughness": 0.4, "spec_size": 0.92, "spec_strength": 0.3, "emission_energy": 0.0,
	}, 1)
	root.add_child(ring)
	var glyph: String = "seal" if String(art_key).begins_with("seal_") else str(TOKEN_FACE.get(art_key, "mark"))
	var path := "res://art/chips/token_%s.png" % glyph
	if ResourceLoader.exists(path):
		root.add_child(_disc(0.55, H * 0.5 + 0.003, load(path) as Texture2D))
	return root


## Tier edge spots on the top rim band + a short vertical mark on the side.
static func _add_spots(root: Node3D, tier: StringName) -> void:
	var sp: Dictionary = SPOTS[tier]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = sp.col
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var n: int = sp.n
	for i in n:
		var a := float(i) / float(n) * TAU
		var x := cos(a) * SPOT_R
		var z := sin(a) * SPOT_R
		var top := _spot_mesh(sp.shape)
		top.material_override = mat
		top.position = Vector3(x, H * 0.5 + 0.003, z)
		root.add_child(top)
		# Side stripe on the rim. The shelf turns the whole chip to face the
		# camera, so the top spots read on the tinted rim.
		var side := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.10, H * 0.7, 0.04)
		side.mesh = box
		side.material_override = mat
		side.position = Vector3(x * (R / SPOT_R) * 0.98, 0.0, z * (R / SPOT_R) * 0.98)
		side.rotation.y = -a  # Face the stripe outward on the cylinder.
		root.add_child(side)


static func _spot_mesh(shape: StringName) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if shape == &"round":
		var c := CylinderMesh.new()
		c.top_radius = 0.08; c.bottom_radius = 0.08; c.height = 0.01; c.radial_segments = 10
		mi.mesh = c
	elif shape == &"diamond":
		# Thin box rotated 45° reads as a diamond at 48 px.
		var b := BoxMesh.new(); b.size = Vector3(0.14, 0.01, 0.14)
		mi.mesh = b
		mi.rotation_degrees.y = 45
	else:
		var b2 := BoxMesh.new(); b2.size = Vector3(0.12, 0.01, 0.12)
		mi.mesh = b2
	return mi


## One shared beveled cylinder (radius 1, height 0.20, bevel 0.04).
static func _beveled() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 32
	var rings: Array = [
		{"y": -H * 0.5, "r": R - BEVEL}, {"y": -H * 0.5 + BEVEL, "r": R},
		{"y": H * 0.5 - BEVEL, "r": R}, {"y": H * 0.5, "r": R - BEVEL},
	]
	for i in sides:
		var a0 := float(i) / sides * TAU
		var a1 := float(i + 1) / sides * TAU
		var u0 := Vector2(cos(a0), sin(a0))
		var u1 := Vector2(cos(a1), sin(a1))
		for r in range(rings.size() - 1):
			var ra: Dictionary = rings[r]
			var rb: Dictionary = rings[r + 1]
			_quad(st, Vector3(u0.x * ra.r, ra.y, u0.y * ra.r), Vector3(u1.x * ra.r, ra.y, u1.y * ra.r),
				Vector3(u1.x * rb.r, rb.y, u1.y * rb.r), Vector3(u0.x * rb.r, rb.y, u0.y * rb.r))
		_cap(st, u0, u1, H * 0.5, R - BEVEL, true)
		_cap(st, u0, u1, -H * 0.5, R - BEVEL, false)
	st.generate_normals()
	return st.commit()


static func _annulus(outer: float, inner: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 32:
		var a0 := float(i) / 32.0 * TAU
		var a1 := float(i + 1) / 32.0 * TAU
		_quad(st,
			Vector3(cos(a0) * inner, 0, sin(a0) * inner), Vector3(cos(a1) * inner, 0, sin(a1) * inner),
			Vector3(cos(a1) * outer, 0, sin(a1) * outer), Vector3(cos(a0) * outer, 0, sin(a0) * outer))
	st.generate_normals()
	return st.commit()


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	# UVs required: _cap also sets them, so every vertex needs one.
	st.set_uv(Vector2(0, 0)); st.add_vertex(a)
	st.set_uv(Vector2(1, 0)); st.add_vertex(b)
	st.set_uv(Vector2(1, 1)); st.add_vertex(c)
	st.set_uv(Vector2(0, 0)); st.add_vertex(a)
	st.set_uv(Vector2(1, 1)); st.add_vertex(c)
	st.set_uv(Vector2(0, 1)); st.add_vertex(d)


static func _cap(st: SurfaceTool, u0: Vector2, u1: Vector2, y: float, r: float, up: bool) -> void:
	var c := Vector3(0, y, 0)
	var a := Vector3(u0.x * r, y, u0.y * r)
	var b := Vector3(u1.x * r, y, u1.y * r)
	st.set_uv(Vector2(0.5, 0.5)); st.add_vertex(c)
	if up:
		st.set_uv(u0 * 0.5 + Vector2(0.5, 0.5)); st.add_vertex(a)
		st.set_uv(u1 * 0.5 + Vector2(0.5, 0.5)); st.add_vertex(b)
	else:
		st.set_uv(u1 * 0.5 + Vector2(0.5, 0.5)); st.add_vertex(b)
		st.set_uv(u0 * 0.5 + Vector2(0.5, 0.5)); st.add_vertex(a)


static func _disc(radius: float, y: float, tex: Texture2D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	# PlaneMesh already lies on XZ facing +Y (Godot 4).
	var m := PlaneMesh.new()
	m.size = Vector2(radius * 2.0, radius * 2.0)
	mi.mesh = m
	mi.position.y = y
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	return mi
