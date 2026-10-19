## Builds the Hearth board's Godot side: materials, prop scenes (PC + mobile) and the two board
## scenes, with the AnimationPlayer clips. The .glb meshes come from build_hearth.py (Blender).
##
##   godot --headless --path . --script res://art/models/boards/hearth/src/make_hearth.gd -- materials
##   (python3 art/models/boards/hearth/src/write_imports.py; godot --headless --path . --import)
##   godot --headless --path . --script res://art/models/boards/hearth/src/make_hearth.gd -- props
##   godot --headless --path . --script res://art/models/boards/hearth/src/make_hearth.gd -- board
##
## Spec: art/concept/bonfire_table/README.md "LOCKED DIRECTION", board_kit.md sections 1-8,
## art/concept/fire/fire_style.md. The board is Board A (infernal_pit) with the same node tree and
## anchors; only slot contents, two material overrides and a "Hearth" subtree are added.
extends SceneTree

const H := "res://art/models/boards/hearth/"
const A := "res://art/models/boards/infernal_pit/"
const TOON := "res://shaders/3d/toon_noir.gdshader"
const S := H + "shaders/"

const BUTTER := Color("#FFE6A8")
const EMBER := Color("#E8622A")
const HELLFIRE := Color("#C8281E")
const OXBLOOD := Color("#3B0D14")
const CHARCOAL := Color("#1E1B1A")
const PIT_BLACK := Color("#0E1414")
const BRASS_HI := Color("#E2C06A")

## Flame card helpers (same numbers as the fire WIP): the tongue drawing sits 58/512 above the
## frame bottom; visible flame height = 0.8 x card.
const CARD_FOOT := 0.113
const STEP := 1.0 / 12.0

## build_hearth.py numbers (anchor-local).
const BOWL := Vector3(0.0, 0.086, -0.16)    # brazier coal-bed top centre
const NUMBER_ANCHOR := Vector3(0.0, 0.0624, -0.0178)
const CANDLE_TOP := 0.066
const EYE_L := Vector3(-0.0166, 0.0616, 0.0181)   # build_hearth.py eye_pos(-1)
const EYE_SIZE := Vector2(0.0163, 0.0096)          # eye radii x 1.41 = 2x area (Art Director, Oct 18)
const CANDLE_X := 1.135
const CANDLE_Z: Array[float] = [-0.42, -0.24, 0.24, 0.42]
const CANDLE_Y := 0.105
const FACE_OUT := 0.04                        # demon faces pushed out along the corner diagonal


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0] if args.size() > 0 else "all"
	if phase == "materials" or phase == "all":
		_materials()
	# Props and boards run in separate processes so the boards pack against freshly loaded prop scenes.
	if phase == "scenes" or phase == "props" or phase == "all":
		for mobile in [false, true]:
			_props(mobile)
	if phase == "scenes" or phase == "board" or phase == "all":
		for mobile in [false, true]:
			_board(mobile)
	print("make_hearth: done (%s)" % phase)
	quit()


# --- materials -------------------------------------------------------------------------------

func _sm(shader: String, params: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(shader)
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m


func _save(res: Resource, path: String) -> void:
	var err := ResourceSaver.save(res, path)
	assert(err == OK, "save " + path)
	res.take_over_path(path)


func _copy_toon(src: String, extra: Dictionary) -> ShaderMaterial:
	var o := load(src) as ShaderMaterial
	var m := _sm(TOON, {})
	for p in o.shader.get_shader_uniform_list():
		var v: Variant = o.get_shader_parameter(p.name)
		if v != null:
			m.set_shader_parameter(p.name, v)
	for k in extra:
		m.set_shader_parameter(k, extra[k])
	return m


func _materials() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(H + "materials"))
	var M := H + "materials/"
	var ink_trim := load(A + "materials/ink_trim.tres")
	var ink_table := load(A + "materials/ink_table.tres")
	var iron := _sm(TOON, {"albedo": Color("#2B2A2E"), "shadow_color": Color("#0E0D10"), "mid_tint": 0.66,
		"spec_size": 0.975, "spec_strength": 0.12, "rim_color": EMBER, "rim_strength": 0.12, "rim_power": 3.0, "wrap": 0.2, "roughness": 0.6})
	iron.next_pass = ink_trim
	_save(iron, M + "hearth_iron.tres")
	var demon := _sm(TOON, {"albedo": Color("#3A3230"), "shadow_color": Color("#120E0D"), "mid_tint": 0.66,
		"spec_size": 0.0, "rim_color": EMBER, "rim_strength": 0.4, "rim_power": 2.5, "wrap": 0.2, "roughness": 0.6})
	demon.next_pass = ink_trim
	_save(demon, M + "demon_iron.tres")
	var wax := _sm(TOON, {"albedo": Color("#E8D6B0"), "shadow_color": Color("#6E4A3A"), "mid_tint": 0.74,
		"spec_size": 0.97, "spec_strength": 0.3, "wrap": 0.3, "light_gain": 0.9, "rim_color": BUTTER, "rim_strength": 0.15})
	# Unlit wax keeps a dim visible silhouette in the dark side rails (Art Director, Oct 18).
	wax.set_shader_parameter("emission_color", Color("#3A2E24"))
	wax.set_shader_parameter("emission_energy", 0.5)
	wax.next_pass = ink_trim
	_save(wax, M + "candle_wax.tres")
	# Lit wax: same wax + a hot emissive rim (Butter) and an ember-warm body.
	var wl := _sm(TOON, {"albedo": Color("#E8D6B0"), "shadow_color": Color("#6E4A3A"), "mid_tint": 0.74,
		"spec_size": 0.97, "spec_strength": 0.3, "wrap": 0.3, "light_gain": 0.9, "rim_color": BUTTER, "rim_strength": 2.2,
		"rim_power": 1.6, "emission_color": Color("#E8A060"), "emission_energy": 0.45})
	wl.next_pass = ink_trim
	_save(wl, M + "candle_wax_lit.tres")
	_save(_sm(S + "hearth_glow.gdshader", {}), M + "candle_glow.tres")
	_save(_sm(S + "hearth_coals.gdshader", {"level_max": 4.6, "scale": 38.0}), M + "hearth_coals.tres")
	_save(_sm(S + "hearth_coals.gdshader", {"level_max": 1.0, "coin_amount": 0.12, "scale": 4.5}), M + "cauldron_coals.tres")
	_save(_sm(S + "demon_eye.gdshader", {"eye_left": EYE_L, "eye_right": EYE_L * Vector3(-1, 1, 1), "eye_size": EYE_SIZE}), M + "demon_eye.tres")
	# Felt: Board A's felt + the ember corner motif overlay (no rules text).
	var felt := _copy_toon(A + "materials/felt.tres", {"use_overlay": true,
		"overlay_tex": load(H + "textures/felt_ember_corners.png"), "overlay_tint": Color(1, 1, 1, 1.0),
		# edge lift (Art Director, Oct 18): the overlay lifts the edge albedo; this is the floor value
		"emission_color": Color("#0C2623"), "emission_energy": 1.0})
	_save(felt, M + "hearth_felt.tres")
	# Rails: Board A's leather + the ember seam pass + the same ink hull.
	var seam := _sm(S + "ember_seam.gdshader", {"band_v": 0.125, "band_half": 0.012})
	seam.next_pass = ink_table
	_save(seam, M + "ember_seam.tres")
	var leather := _copy_toon(A + "materials/leather.tres", {})
	leather.next_pass = load(M + "ember_seam.tres")
	_save(leather, M + "hearth_leather.tres")
	# Toon fire cards (fire_style.md; values from the WIP flame_tongue / inferno / pillar materials).
	var fc := S + "hearth_flame_card.gdshader"
	for lod in ["", "_mobile"]:
		var atlas := load(H + "textures/flame_tongue_4x4%s.png" % lod)
		_save(_sm(fc, {"atlas": atlas, "back_offset": 0.0, "core_energy": 1.35}), M + "fire_tongue%s.tres" % lod)
		_save(_sm(fc, {"atlas": atlas, "back_offset": 0.0, "outline_px": 2.6, "core_energy": 1.4}), M + "fire_inferno%s.tres" % lod)
		_save(_sm(fc, {"atlas": atlas, "back_offset": 0.02, "outline_px": 3.0, "core_energy": 1.5}), M + "fire_pillar%s.tres" % lod)
		_save(_sm(fc, {"atlas": atlas, "back_offset": 0.0, "outline_px": 1.6, "core_energy": 1.35, "flare_grow": 0.9}), M + "candle_flame%s.tres" % lod)
	var curl := load(H + "textures/smoke_curl.png")
	var smoke := {"atlas": curl, "mode": 1, "outer_color": CHARCOAL, "mid_color": Color("#3A3432"), "outline_color": PIT_BLACK,
		"core_energy": 1.0, "erode": 0.3, "min_size": 0.45}
	var big := smoke.duplicate()
	big["rise"] = 0.12
	_save(_sm(fc, big), M + "smoke_wisp.tres")
	var small := smoke.duplicate()
	small["rise"] = 0.05
	small["outline_px"] = 1.6
	_save(_sm(fc, small), M + "smoke_wisp_small.tres")
	var cap := smoke.duplicate()
	_save(_sm(fc, cap), M + "smoke_cap.tres")
	_save(_sm(S + "hearth_sparks.gdshader", {"rise": 0.2, "period": 0.8, "radius": 0.06, "turns": 0.0, "size": 0.012}), M + "sparks_ember.tres")
	_save(_sm(S + "hearth_sparks.gdshader", {"rise": 0.3, "period": 1.5, "radius": 0.11, "turns": 0.2, "size": 0.014, "drift": 0.06}), M + "sparks_drift.tres")
	_save(_sm(S + "hearth_sparks.gdshader", {"fill_color": BRASS_HI, "core_energy": 1.8, "rise": 0.34, "period": 1.0,
		"radius": 0.075, "turns": 1.5, "size": 0.016}), M + "sparks_brass.tres")


# --- scene helpers ----------------------------------------------------------------------------

func _own(n: Node, root: Node) -> void:
	for c in n.get_children():
		c.owner = root
		if c.scene_file_path == "":
			_own(c, root)


func _pack(root: Node, path: String) -> void:
	_own(root, root)
	var ps := PackedScene.new()
	var err := ps.pack(root)
	assert(err == OK, "pack " + path)
	_save(ps, path)
	root.free()


func _inst(path: String, name: String, parent: Node) -> Node3D:
	var n := (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	n.name = name
	parent.add_child(n)
	return n


## One flame / smoke card: a QuadMesh with its base at the node origin (the shader Y-billboards it).
## h = visible flame height; the card is h / 0.8 and is sunk by CARD_FOOT so the drawing stands at y.
func _card(parent: Node, name: String, mat: String, h: float, base: Vector3, square: bool = true) -> MeshInstance3D:
	var size := h / 0.8
	var mi := MeshInstance3D.new()
	mi.name = name
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.center_offset = Vector3(0, size * 0.5, 0)
	mi.mesh = q
	mi.material_override = load(H + "materials/%s.tres" % mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = size + 0.1
	mi.position = base - Vector3(0, size * CARD_FOOT, 0)
	parent.add_child(mi)
	return mi


## Self-animated diamond sparks: n quads in one mesh, COLOR.r = per-spark seed (hearth_sparks.gdshader).
func _sparks(parent: Node, name: String, mat: String, n: int, pos: Vector3) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 + n
	for i in n:
		var c := Color(rng.randf(), 0, 0, 1)
		var corners := [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)]
		for k in [0, 1, 2, 0, 2, 3]:
			var p: Vector2 = corners[k]
			st.set_color(c)
			st.set_uv(Vector2(p.x + 0.5, 0.5 - p.y))
			st.add_vertex(Vector3(p.x, p.y, 0))
	var mesh := st.commit()
	mesh.custom_aabb = AABB(Vector3(-0.15, -0.05, -0.15), Vector3(0.3, 0.5, 0.3))
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = mesh
	mi.material_override = load(H + "materials/%s.tres" % mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	parent.add_child(mi)
	return mi


func _scripted(name: String, script: String) -> Node3D:
	var n := Node3D.new()
	n.name = name
	n.set_script(load(H + "scripts/%s.gd" % script))
	return n


# --- props ------------------------------------------------------------------------------------

func _props(mobile: bool) -> void:
	var lod := "_mobile" if mobile else ""
	var D := H + "scenes/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(D))
	# Brazier pot = goal_plaque_scene.
	var bz := _scripted("Brazier", "hearth_brazier")
	_inst(H + "brazier%s.glb" % lod, "Model", bz)
	var na := Marker3D.new()
	na.name = "NumberAnchor"
	na.transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-30.0)), NUMBER_ANCHOR)
	bz.add_child(na)
	var fire := Node3D.new()
	fire.name = "Fire"
	bz.add_child(fire)
	var steps := [
		[[0.0, 0.07]],
		[[-0.04, 0.08], [0.0, 0.11], [0.04, 0.085]],
		[[-0.07, 0.09], [-0.035, 0.13], [0.0, 0.17], [0.035, 0.135], [0.07, 0.095]],
	]
	for i in 3:
		var g := Node3D.new()
		g.name = "Step%d" % (i + 1)
		g.position = BOWL
		fire.add_child(g)
		var mat := "fire_inferno" if i == 2 else "fire_tongue"
		for j in steps[i].size():
			var sp: Array = steps[i][j]
			# alternate tiny depth offsets so neighbouring cards never z-fight
			_card(g, "Tongue%d" % j, mat + lod, sp[1], Vector3(sp[0], -0.004, 0.006 * ((j % 2) * 2 - 1) * (1 if j > 0 else 0)))
		if i == 2:
			_sparks(g, "Sparks", "sparks_ember", 4 if mobile else 6, Vector3(0, 0.02, 0))
	var s4 := Node3D.new()
	s4.name = "Step4"
	s4.position = BOWL
	fire.add_child(s4)
	var twist := Node3D.new()
	twist.name = "Twist"
	s4.add_child(twist)
	# The column (Art Director, Oct 18): capped at ~0.3 m with a wider flare: 5 tongues across the
	# bowl, 3 above, round a twisting pivot (stepped at 12 fps by the script): [x, base y, visible h, z].
	var col := [[-0.085, 0.0, 0.15, 0.01], [0.085, 0.0, 0.14, -0.01], [-0.04, 0.0, 0.2, -0.012], [0.04, 0.0, 0.19, 0.012],
		[0.0, 0.0, 0.24, 0.0], [-0.05, 0.1, 0.15, 0.0], [0.05, 0.11, 0.14, 0.0], [0.0, 0.16, 0.14, 0.0]]
	for i in col.size():
		_card(twist, "Tongue%d" % i, "fire_pillar" + lod, col[i][2], Vector3(col[i][0], col[i][1] - 0.004, col[i][3]))
	# diamond sparks drifting up out of the column top and fading
	_sparks(s4, "DriftSparks", "sparks_drift", 6 if mobile else 10, Vector3(0, 0.25, 0))
	_sparks(s4, "BrassSparks", "sparks_brass", 8 if mobile else 12, Vector3(0, 0.03, 0))
	_card(s4, "Curl", "smoke_cap", 0.045, Vector3(0.01, 0.29, 0))
	var wisp := _card(bz, "Wisp", "smoke_wisp", 0.07, BOWL + Vector3(0, 0.01, 0))
	wisp.visible = false
	_pack(bz, D + "brazier%s.tscn" % lod)
	# Demon face (corner_props FL / FR).
	var face := _scripted("DemonFace", "hearth_demon_face")
	_inst(H + "demon_face%s.glb" % lod, "Model", face)
	_pack(face, D + "demon_face%s.tscn" % lod)
	# Ember cauldron (chip tray slot).
	var caul := _scripted("Cauldron", "hearth_cauldron")
	_inst(H + "cauldron%s.glb" % lod, "Model", caul)
	_inst(H + "cauldron_fill%s.glb" % lod, "Fill", caul)
	var cw := _card(caul, "Wisp", "smoke_wisp_small", 0.05, Vector3(0.106, 0.1, 0))
	cw.visible = false
	caul.set("fill", 0.5)  # bakes the default mound transform into the scene
	_pack(caul, D + "cauldron%s.tscn" % lod)
	# Progress candle (all 8 share this scene, mesh and materials).
	var cd := _scripted("Candle", "hearth_candle")
	_inst(H + "candle%s.glb" % lod, "Model", cd)
	var glow := MeshInstance3D.new()
	glow.name = "Glow"
	var gq := PlaneMesh.new()
	gq.size = Vector2(0.07, 0.12)
	glow.mesh = gq
	glow.material_override = load(H + "materials/candle_glow.tres")
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.position = Vector3(0, 0.0028, 0)
	glow.visible = false
	cd.add_child(glow)
	# tier-1 tongue at 0.75 scale (Art Director, Oct 18; was 0.5): 0.03 m visible
	var fl := _card(cd, "Flame", "candle_flame" + lod, 0.03, Vector3(0, CANDLE_TOP - 0.0015, 0))
	fl.visible = false
	var w2 := _card(cd, "Wisp", "smoke_wisp_small", 0.026, Vector3(0, CANDLE_TOP + 0.002, 0))
	w2.visible = false
	_pack(cd, D + "candle%s.tscn" % lod)


# --- board ------------------------------------------------------------------------------------

func _replace(parent: Node, name: String, scene: String) -> Node3D:
	var old := parent.get_node(name) as Node3D
	var xf := old.transform
	var idx := old.get_index()
	parent.remove_child(old)
	old.free()
	var n := _inst(scene, name, parent)
	parent.move_child(n, idx)
	n.transform = xf
	return n


func _clip(length: float) -> Animation:
	var a := Animation.new()
	a.length = length
	return a


## Discrete (drawn, on twos) value track.
func _dtrack(a: Animation, path: String, keys: Array) -> void:
	var t := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(t, NodePath(path))
	a.value_track_set_update_mode(t, Animation.UPDATE_DISCRETE)
	for k in keys:
		a.track_insert_key(t, k[0], k[1])


func _board(mobile: bool) -> void:
	var lod := "_mobile" if mobile else ""
	var D := H + "scenes/"
	var board := (load(A + "scenes/board_a_infernal_pit%s.tscn" % lod) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	board.scene_file_path = ""
	board.name = "Board"
	# Felt and rail overrides (editable children of the Board A glbs; the meshes are unchanged).
	var floor := board.get_node("Visual/Floor")
	board.set_editable_instance(floor, true)
	(_mesh(floor)).set_surface_override_material(0, load(H + "materials/hearth_felt.tres"))
	var rails := board.get_node("Visual/Rails")
	board.set_editable_instance(rails, true)
	(_mesh(rails)).set_surface_override_material(0, load(H + "materials/hearth_leather.tres"))
	# Slots.
	var an := board.get_node("Anchors")
	_replace(an.get_node("TargetPlate"), "Plate", D + "brazier%s.tscn" % lod)
	for side in [["Corner_FL", -1.0], ["Corner_FR", 1.0]]:
		var sx: float = side[1]
		var cap := _replace(an.get_node(side[0]), "Cap", D + "demon_face%s.tscn" % lod)
		# Authored facing +Z: yaw toward the felt centre, pushed out along the corner diagonal.
		cap.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(-45.0 * sx)), Vector3(sx, 0, -1).normalized() * FACE_OUT)
	var tray := _inst(D + "cauldron%s.tscn" % lod, "Tray", an.get_node("ChipTray"))
	tray.set("fill", 0.5)
	# Hearth subtree: candles, the FX hub and its clips.
	var hearth := _scripted("Hearth", "hearth_fx")
	board.add_child(hearth)
	var candles := Node3D.new()
	candles.name = "Candles"
	hearth.add_child(candles)
	var heights := [1.0, 1.12, 0.92, 1.06, 1.1, 0.95, 1.04, 0.9]
	var rows := {}
	for side in ["RailLeft", "RailRight"]:
		var r := Node3D.new()
		r.name = side
		candles.add_child(r)
		rows[side] = r
	# Lighting order: alternate left / right from the far end to the player: 1 = L far ... 8 = R near.
	for i in 8:
		var left := i % 2 == 0
		var z: float = CANDLE_Z[i / 2]
		var c := _inst(D + "candle%s.tscn" % lod, "Candle%d" % (i + 1), rows["RailLeft" if left else "RailRight"])
		c.position = Vector3(-CANDLE_X if left else CANDLE_X, CANDLE_Y, z)
		c.set("spin", 0.7 * i)
		c.set("glow_tilt", 16.0 if left else -16.0)
		c.set("height", heights[i])
	_animations(hearth)
	_pack(board, D + "hearth_board%s.tscn" % lod)


func _mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var m := _mesh(c)
		if m != null:
			return m
	return null


func _animations(hearth: Node) -> void:
	var reset := _clip(0.001)
	for p in ["snuff", "wisp", "flare"]:
		_dtrack(reset, ".:" + p, [[0.0, 0.0]])
	# Bust: snuff in 3 drawings, a charcoal smoke wisp for ~0.4 s, relight in 3 drawings. Only
	# snuff / wisp are keyed, so every prop comes back to the state it had (candles keep progress).
	var snuff := _clip(0.75)
	_dtrack(snuff, ".:snuff", [[0.0, 0.4], [STEP, 0.7], [2 * STEP, 1.0], [0.5, 1.0], [6 * STEP, 0.6], [7 * STEP, 0.3], [8 * STEP, 0.0]])
	var wk := [[0.0, 0.0]]
	for k in range(1, 7):
		wk.append([k * STEP, (k - 1) / 5.0 * 0.98 + 0.01])
	wk.append([7 * STEP, 0.0])
	_dtrack(snuff, ".:wisp", wk)
	# Flare: all 8 lit -> the candle tongues jump up and the cores boost, settling in 6 drawings.
	var flare := _clip(0.6)
	_dtrack(flare, ".:flare", [[0.0, 1.0], [STEP, 0.8], [2 * STEP, 0.65], [3 * STEP, 0.5], [4 * STEP, 0.35], [5 * STEP, 0.15], [6 * STEP, 0.0]])
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	var lib := AnimationLibrary.new()
	lib.add_animation("RESET", reset)
	lib.add_animation("snuff", snuff)
	lib.add_animation("flare", flare)
	ap.add_animation_library("", lib)
	hearth.add_child(ap)
	# Seam pulse on its own player so it can overlap the bust / flare (0.15 s, on twos).
	var pulse := _clip(0.15)
	_dtrack(pulse, ".:pulse", [[0.0, 1.0], [STEP, 0.5], [0.15, 0.0]])
	var preset := _clip(0.001)
	_dtrack(preset, ".:pulse", [[0.0, 0.0]])
	var sp := AnimationPlayer.new()
	sp.name = "SeamPlayer"
	var lib2 := AnimationLibrary.new()
	lib2.add_animation("RESET", preset)
	lib2.add_animation("seam_pulse", pulse)
	sp.add_animation_library("", lib2)
	hearth.add_child(sp)
