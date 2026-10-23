## Builds the Nerve token's Godot side: materials and the PC + mobile scenes (meshes from build_nerve_token.py).
##   godot --headless --path . --script res://art/models/props/nerve_token/src/make_nerve_token.gd -- materials
##   python3 art/models/props/nerve_token/src/write_imports.py; godot --headless --path . --import
##   godot --headless --path . --script res://art/models/props/nerve_token/src/make_nerve_token.gd -- scenes
extends SceneTree

const P := "res://art/models/props/nerve_token/"
const H := "res://art/models/boards/hearth/"
const TAB_T := 0.016
const TAB_H := 0.088
const RIG_SCALE := {"": 1.8, "_mobile": 1.8}  # 48 px rule: the token reads at least as big as a tray die in the real camera
const TRACK_LEN := 0.5                 # default slide track (m); Godot Dev sets Rig/Track scale.x to the rail run
const BONE := Color("#D8C49C")         # warm bone: between the aged dressing bone #C9B48A and the dice bone #E8DCC0
const BONE_SPENT := Color("#5C564E")   # spent: grey, chalky; dark because it lies face-up in the lamp pool (v1 QA)
const CHEV := Color("#5E1118")         # oxblood inlay: crisp dark mark on the bone
const CHEV_SPENT := Color("#3A3531")   # dulled: sinks into the grey bone


func _init() -> void:
	var mode := "scenes"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		mode = args[0]
	if mode == "materials":
		_materials()
	else:
		_token("")
		_token("_mobile")
	quit()


func _sm(shader: String, params: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(shader)
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m


func _copy(src: String, extra: Dictionary) -> ShaderMaterial:
	var o := load(src) as ShaderMaterial
	var m := _sm(o.shader.resource_path, {})
	for p in o.shader.get_shader_uniform_list():
		var v: Variant = o.get_shader_parameter(p.name)
		if v != null:
			m.set_shader_parameter(p.name, v)
	for k in extra:
		m.set_shader_parameter(k, extra[k])
	return m


func _save(res: Resource, path: String) -> void:
	assert(ResourceSaver.save(res, path) == OK, "save " + path)
	res.take_over_path(path)


func _own(n: Node, root: Node) -> void:
	for c in n.get_children():
		if c.owner == null:
			c.owner = root
		if c.scene_file_path == "":
			_own(c, root)


func _pack(root: Node, path: String) -> void:
	_own(root, root)
	var ps := PackedScene.new()
	assert(ps.pack(root) == OK, "pack " + path)
	_save(ps, path)
	root.free()


func _inst(path: String, name: String, parent: Node) -> Node3D:
	var n := (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	n.name = name
	parent.add_child(n)
	return n


func _materials() -> void:
	var M := P + "materials/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(M))
	var ink := load(H + "materials/ink_prop.tres")
	# bone family (dressing bone base), no glow: the ember rim emission is off, only the shared dim fill floor
	var specs := {
		"nerve_bone": [H + "materials/dressing_bone.tres", {"albedo": BONE, "emission_color": BONE, "emission_energy": 0.14, "rim_emit": 0.0}],
		"nerve_bone_spent": [H + "materials/dressing_bone.tres", {"albedo": BONE_SPENT, "shadow_color": Color("#2E2A26"), "emission_color": BONE_SPENT, "emission_energy": 0.04, "rim_emit": 0.0, "spec_strength": 0.0}],
		"nerve_chevron": [H + "materials/dressing_seal.tres", {"albedo": CHEV, "emission_color": CHEV, "emission_energy": 0.12, "rim_emit": 0.0, "rim_strength": 0.0}],
		"nerve_chevron_spent": [H + "materials/dressing_seal.tres", {"albedo": CHEV_SPENT, "shadow_color": Color("#2A2622"), "emission_color": CHEV_SPENT, "emission_energy": 0.06, "rim_emit": 0.0, "rim_strength": 0.0, "spec_strength": 0.0}],
		"nerve_iron": [H + "materials/dressing_iron.tres", {"rim_emit": 0.0}],
		"nerve_brass": [H + "materials/dressing_brass.tres", {"rim_emit": 0.0}],
	}
	for k in specs:
		var m := _copy(specs[k][0], specs[k][1])
		m.next_pass = ink
		_save(m, M + k + ".tres")


func _token(lod: String) -> void:
	var root := Node3D.new()
	root.name = "NerveToken"
	root.set_script(load(P + "scripts/nerve_token.gd"))
	var k := float(RIG_SCALE[lod])
	var rig := Node3D.new()
	rig.name = "Rig"
	rig.scale = Vector3.ONE * k
	root.add_child(rig)
	var tr := _inst(P + "nerve_token_track.glb", "Track", rig)
	tr.scale.x = TRACK_LEN / k
	_inst(P + "nerve_token_cradle.glb", "Cradle", rig)
	var slide := Node3D.new()
	slide.name = "Slide"
	rig.add_child(slide)
	var bob := Node3D.new()
	bob.name = "Bob"
	slide.add_child(bob)
	var lift := Node3D.new()
	lift.name = "Lift"
	lift.position.y = 0.008
	bob.add_child(lift)
	var pv := Node3D.new()
	pv.name = "Pivot"                  # back-bottom edge of the tablet: tips / falls toward the felt (-z)
	pv.position.z = -TAB_T / 2
	lift.add_child(pv)
	for part in [["Tablet", "nerve_token_tablet" + lod], ["Chevron", "nerve_token_chevron"], ["Notch", "nerve_token_notch"]]:
		var n := _inst(P + part[1] + ".glb", part[0], pv)
		n.position.z = TAB_T / 2
	var tip := Marker3D.new()
	tip.name = "TooltipAnchor"          # nerve_* line / tooltip hangs here (moves with the token)
	tip.position = Vector3(0, TAB_H + 0.012, TAB_T / 2)
	pv.add_child(tip)
	for m in [["Home", 0.0], ["TrackStart", -TRACK_LEN / 2 / k], ["TrackEnd", TRACK_LEN / 2 / k]]:
		var mk := Marker3D.new()
		mk.name = m[0]
		mk.position.x = m[1]
		rig.add_child(mk)
	var tap := Marker3D.new()
	tap.name = "TapCenter"              # centre of the tablet face at rest: hit-test / DRAG_PX origin
	tap.position = Vector3(0, 0.008 + TAB_H * 0.5, 0)
	rig.add_child(tap)
	_pack(root, P + "scenes/nerve_token%s.tscn" % lod)
