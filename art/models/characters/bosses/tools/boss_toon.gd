extends RefCounted
## Shared toon-noir builder for the boss dealers (template for all six). Use from a per-boss make_<boss>.gd:
##   const BT := preload("res://art/models/characters/bosses/tools/boss_toon.gd")
##   BT.materials(R, {"slot": BT.brass(), ...})   # writes R/materials/<slot>.tres (+ ink_<boss>.tres / _thin)
##   BT.scene(R, "pit_boss", "PitBoss")           # writes R/scenes/<boss>(_mobile).tscn like smiles.tscn
## Mirrors smiles/src/make_smiles.gd (toon_noir + outline ink hull, HeadTrack + HeadAnchor) with the AD dealer
## palette: brass, bone, greys and pewter only - no red / cyan / violet, and no emission on any surface.

const TOON := "res://shaders/3d/toon_noir.gdshader"
const OUTLINE := "res://shaders/3d/outline.gdshader"
const PIT_BLACK := Color("#0E1414")  # ink (same as Smiles)
const BRASS := Color("#B08D3C")
const BONE := Color("#E8DCC0")
const PEWTER := Color("#8A8D8F")
## Neutral warm-grey room ambient (v2: lifted from #141416 so shade sides read against the far wall). The shader
## default ambient is oxblood-tinted. This is the shade-band ambient term, not emission_energy (which stays 0).
const AMBIENT := Color("#3A3732")
const AMBIENT_ENERGY := 0.40
## Bone rim (AD 2026-10-24): every dealer gets a low bone-tinted fresnel rim so its silhouette reads against the
## far wall. Lit-side only (toon_noir light()), so it adds no emission; emission_energy stays 0.
const RIM_BONE := Color("#E8DCC0")
const RIM_STRENGTH := 0.30
const RIM_POWER := 2.0
## One value step for dealer greys (cloth / grey() helpers): the v1 greys read too dark at game zoom.
const GREY_STEP := 0.08
const INK_W := 0.0048
const INK_THIN_W := 0.0018
## Every colour parameter the toon shader takes; all are written explicitly so no red/teal shader default leaks in.
const COLOR_KEYS: Array[String] = ["albedo", "shadow_color", "ambient_color", "spec_color", "rim_color", "emission_color"]


static func grey(v: float) -> Color:
	return Color(v, v, v)


## Base params for a dealer surface: neutral ambient + a soft pewter rim, emission hard off.
static func base(albedo: Color, shadow: Color, extra: Dictionary = {}) -> Dictionary:
	var d := {"albedo": albedo, "shadow_color": shadow, "mid_tint": 0.7, "wrap": 0.25, "roughness": 0.75,
		"ambient_color": AMBIENT, "ambient_energy": AMBIENT_ENERGY, "spec_color": Color("#F4ECD8"), "spec_size": 0.0, "spec_strength": 0.0,
		"rim_color": RIM_BONE, "rim_strength": RIM_STRENGTH, "rim_power": RIM_POWER,
		"emission_color": Color.BLACK, "emission_energy": 0.0}
	return d.merged(extra, true)


static func brass(extra: Dictionary = {}) -> Dictionary:
	return base(BRASS, Color("#4A3A1A"), {"spec_size": 0.92, "spec_strength": 0.55}.merged(extra, true))


static func bone(extra: Dictionary = {}) -> Dictionary:
	return base(BONE, Color("#5E584C"), {"spec_size": 0.97, "spec_strength": 0.3}.merged(extra, true))


static func pewter(extra: Dictionary = {}) -> Dictionary:
	return base(PEWTER, Color("#2E3032"), {"spec_size": 0.9, "spec_strength": 0.4}.merged(extra, true))


## Grey cloth at v + GREY_STEP (callers pass the v1 value, so all bosses shift together).
static func cloth(v: float, extra: Dictionary = {}) -> Dictionary:
	var g := v + GREY_STEP
	return base(grey(g), grey(g * 0.38), extra)


static func ink(dir: String, name: String, width: float) -> Material:
	var m := ShaderMaterial.new()
	m.shader = load(OUTLINE)
	m.set_shader_parameter("color", PIT_BLACK)
	m.set_shader_parameter("width", width)
	m.set_shader_parameter("mode", 0)
	var p := dir + "materials/%s.tres" % name
	ResourceSaver.save(m, p)
	return load(p)


static func toon(dir: String, name: String, params: Dictionary, ink_mat: Material) -> void:
	var m := ShaderMaterial.new()
	m.shader = load(TOON)
	for k in params:
		m.set_shader_parameter(k, params[k])
	if ink_mat != null:
		m.next_pass = ink_mat
	ResourceSaver.save(m, dir + "materials/%s.tres" % name)


## slots: {slot_name: params}; ink: "thick" (default) | "thin" | "none" per slot via `inks`.
static func materials(dir: String, boss: String, slots: Dictionary, inks: Dictionary = {}) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir + "materials"))
	var thick := ink(dir, "ink_" + boss, INK_W)
	var thin := ink(dir, "ink_%s_thin" % boss, INK_THIN_W)
	for s: String in slots:
		var k: String = inks.get(s, "thick")
		toon(dir, s, slots[s], thick if k == "thick" else (thin if k == "thin" else null))


## Wrapper scene, same layout as smiles.tscn: Model (editable glb instance, idle autoplay) + HeadTrack
## (LookAtModifier3D on "head", influence 0 until Godot Dev targets it) + HeadAnchor (BoneAttachment3D on "head").
static func scene(dir: String, boss: String, root_name: String) -> void:
	for lod in ["", "_mobile"]:
		var glb := load(dir + "%s%s.glb" % [boss, lod]) as PackedScene
		var root := Node3D.new()
		root.name = root_name
		var model := glb.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
		model.name = "Model"
		root.add_child(model)
		model.owner = root
		root.set_editable_instance(model, true)
		var ap := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		ap.autoplay = "idle"
		var skel := model.find_child("Skeleton3D", true, false) as Skeleton3D
		var look := LookAtModifier3D.new()
		look.name = "HeadTrack"
		look.bone_name = "head"
		look.forward_axis = SkeletonModifier3D.BONE_AXIS_PLUS_Z
		look.primary_rotation_axis = Vector3.AXIS_Y
		look.use_secondary_rotation = true
		look.use_angle_limitation = true
		look.symmetry_limitation = true
		look.primary_limit_angle = deg_to_rad(120.0)  # yaw +-60
		look.secondary_limit_angle = deg_to_rad(40.0)  # pitch +-20
		look.duration = 0.25
		look.transition_type = Tween.TRANS_SINE
		look.ease_type = Tween.EASE_OUT
		look.influence = 0.0
		skel.add_child(look)
		look.owner = root
		var anchor := BoneAttachment3D.new()
		anchor.name = "HeadAnchor"
		anchor.bone_name = "head"
		skel.add_child(anchor)
		anchor.owner = root
		var ps := PackedScene.new()
		ps.pack(root)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir + "scenes"))
		ResourceSaver.save(ps, dir + "scenes/%s%s.tscn" % [boss, lod])
		root.free()
