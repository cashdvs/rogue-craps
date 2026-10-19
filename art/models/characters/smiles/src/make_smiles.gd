extends SceneTree
## Smiles generator (run from the repo root, in this order; see rebuild_smiles.sh):
##   godot --headless --path . --script res://art/models/characters/smiles/src/make_smiles.gd -- materials
##   (write_imports.py, --import)
##   godot --headless --path . --script res://art/models/characters/smiles/src/make_smiles.gd -- scenes
## materials: toon_noir .tres per glTF slot, each with an ink hull next pass (shaders/3d/outline.gdshader).
## scenes: scenes/smiles.tscn + smiles_mobile.tscn = the glb (editable instance) + autoplay idle +
## HeadTrack (LookAtModifier3D on "head", off until Godot Dev gives it a target) + HeadAnchor
## (BoneAttachment3D on "head", for the speech bubble). No gameplay code.

const R := "res://art/models/characters/smiles/"
const TOON := "res://shaders/3d/toon_noir.gdshader"
const OUTLINE := "res://shaders/3d/outline.gdshader"
const PIT_BLACK := Color("#0E1414")
const OXBLOOD := Color("#3B0D14")
const BURGUNDY := Color("#6E1A24")
const EMBER := Color("#E8622A")
const BONE := Color("#E8DCC0")
const BRASS := Color("#B08D3C")


func _initialize() -> void:
	var phase: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "materials"
	if phase == "materials":
		_materials()
	else:
		_scene("")
		_scene("_mobile")
	print("make_smiles: done (%s)" % phase)
	quit()


func _ink(width: float, name: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(OUTLINE)
	m.set_shader_parameter("color", PIT_BLACK)
	m.set_shader_parameter("width", width)
	m.set_shader_parameter("mode", 0)
	ResourceSaver.save(m, R + "materials/%s.tres" % name)
	return load(R + "materials/%s.tres" % name)


func _toon(name: String, params: Dictionary, ink: Material) -> void:
	var m := ShaderMaterial.new()
	m.shader = load(TOON)
	for k in params:
		m.set_shader_parameter(k, params[k])
	if ink != null:
		m.next_pass = ink
	ResourceSaver.save(m, R + "materials/%s.tres" % name)


func _materials() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(R + "materials"))
	# Ink: chunky on the silhouette (body / head / visor), thin on the teeth + buttons so each tooth reads.
	var ink := _ink(0.0048, "ink_smiles")
	var ink_thin := _ink(0.0018, "ink_smiles_thin")
	var rim := {"rim_color": EMBER, "rim_strength": 0.55, "rim_power": 2.2, "wrap": 0.25, "roughness": 0.7}
	_toon("smiles_skin", rim.merged({"albedo": Color("#B02A2E"), "shadow_color": OXBLOOD, "mid_tint": 0.7,
		"emission_color": Color("#3B0D14"), "emission_energy": 0.6}), ink)
	_toon("smiles_horn", rim.merged({"albedo": Color("#5A1418"), "shadow_color": Color("#1E0508"), "spec_size": 0.94, "spec_strength": 0.3,
		"emission_color": Color("#2A080C"), "emission_energy": 0.5}), ink)
	_toon("smiles_shirt", rim.merged({"albedo": BONE, "shadow_color": Color("#5A464A"), "mid_tint": 0.72,
		"emission_color": Color("#3A3030"), "emission_energy": 0.6}), ink)
	_toon("smiles_vest", rim.merged({"albedo": Color("#9E1E2A"), "shadow_color": OXBLOOD, "mid_tint": 0.68,
		"emission_color": Color("#2E0A10"), "emission_energy": 0.6}), ink)
	_toon("smiles_black", rim.merged({"albedo": Color("#1C1616"), "shadow_color": Color("#0A0808"), "rim_color": BURGUNDY, "rim_strength": 0.7}), ink)
	# The grin and the visor are the 48 px read. As the dealer they are lit by the lamp only (no emission);
	# the MC clips switch on the glow shells (smiles_glow_*) via the glow_* bones.
	_toon("smiles_gold", {"albedo": Color("#F2C04A"), "shadow_color": Color("#7A5418"), "spec_size": 0.9, "spec_color": Color("#FFF0C0"),
		"spec_strength": 0.6, "rim_color": Color("#FFE6A8"), "rim_strength": 0.5, "emission_energy": 0.0}, ink_thin)
	_toon("smiles_visor", {"albedo": Color("#3CBC5C"), "shadow_color": Color("#14502A"), "mid_tint": 0.75, "wrap": 0.5, "light_gain": 1.6, "spec_size": 0.92, "spec_strength": 0.4,
		"rim_color": Color("#8CF0A0"), "rim_strength": 0.6, "emission_energy": 0.0}, ink)
	_toon("smiles_visor_rim", {"albedo": Color("#C8F8D2"), "shadow_color": Color("#6AAE7C"), "mid_tint": 0.85, "wrap": 0.6, "light_gain": 2.0, "rim_color": Color("#E6FFEC"),
		"rim_strength": 0.4, "emission_energy": 0.0}, ink_thin)
	# MC-only glow shells: faint, they sit just over the teeth / rim and replace them while shown.
	_toon("smiles_glow_gold", {"albedo": Color("#F2C04A"), "shadow_color": Color("#9A6E22"), "spec_size": 0.9, "spec_color": Color("#FFF0C0"),
		"spec_strength": 0.6, "emission_color": Color("#FFC850"), "emission_energy": 0.9}, ink_thin)
	_toon("smiles_glow_rim", {"albedo": Color("#C8FFD2"), "shadow_color": Color("#7AC48C"), "light_gain": 0.4,
		"emission_color": Color("#9CFFB0"), "emission_energy": 1.3}, ink_thin)
	_toon("smiles_eye", {"albedo": Color("#FFC23A"), "shadow_color": Color("#FFC23A"), "light_gain": 0.0,
		"emission_color": Color("#FFC23A"), "emission_energy": 2.2}, null)
	_toon("smiles_mouth", {"albedo": Color("#1A0608"), "shadow_color": Color("#0A0204"), "rim_strength": 0.0}, null)
	_toon("smiles_chip", rim.merged({"albedo": BURGUNDY, "shadow_color": OXBLOOD, "emission_color": Color("#2E0A10"), "emission_energy": 0.6}), ink_thin)
	_toon("smiles_chip_edge", {"albedo": BONE, "shadow_color": Color("#5A464A"), "emission_color": Color("#3A3030"), "emission_energy": 0.6}, null)


func _scene(lod: String) -> void:
	var glb := load(R + "smiles%s.glb" % lod) as PackedScene
	var root := Node3D.new()
	root.name = "Smiles"
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
	# yaw +-60 deg, pitch +-20 deg: he watches the dice without dropping the visor over his face
	look.primary_limit_angle = deg_to_rad(120.0)
	look.secondary_limit_angle = deg_to_rad(40.0)
	look.duration = 0.25
	look.transition_type = Tween.TRANS_SINE
	look.ease_type = Tween.EASE_OUT
	look.influence = 0.0  # off until Godot Dev sets target_node + influence (see README)
	skel.add_child(look)
	look.owner = root
	var anchor := BoneAttachment3D.new()
	anchor.name = "HeadAnchor"
	anchor.bone_name = "head"
	skel.add_child(anchor)
	anchor.owner = root
	var ps := PackedScene.new()
	ps.pack(root)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(R + "scenes"))
	ResourceSaver.save(ps, R + "scenes/smiles%s.tscn" % lod)
	root.free()
