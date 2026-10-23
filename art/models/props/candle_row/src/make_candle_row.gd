## Builds the candle row's Godot side: materials, the candle + row scenes (PC + mobile flame atlas) and
## the AnimationPlayer clips. Meshes come from build_candle_row.py (Blender).
##   godot --headless --path . --script res://art/models/props/candle_row/src/make_candle_row.gd -- materials
##   python3 art/models/props/candle_row/src/write_imports.py; godot --headless --path . --import
##   godot --headless --path . --script res://art/models/props/candle_row/src/make_candle_row.gd -- scenes
extends SceneTree

const P := "res://art/models/props/candle_row/"
const H := "res://art/models/boards/hearth/"
const TOON := "res://shaders/3d/toon_noir.gdshader"
const BUTTER := Color("#FFE6A8")
const TALLOW := Color("#DCC79F")      # tallow: warmer/darker than the dice bone #E8DCC0
const ASH := Color("#7A7166")         # cold stub: grey-ash tallow
const CARD_FOOT := 0.113
const STEP := 1.0 / 12.0              # on twos
const PITCH := 0.058
const CAP := 8
const BAR_H := 0.009
const PLATE_Y := 0.0012
const ROW_SCALE := {"": 1.0, "_mobile": 1.4}  # v2 AD (3): phone row 1.4x (candles ~20 px, pitch ~27 px)
const TIER := 4                       # v4: front tier = hands 1-4, back tier = 5-8 (offset half a pitch)
const TIER_DZ := 0.040                # back tier this far behind the front one (bar depth 0.034 + gap)
const TIER_RISE := 0.0                # both bars sit flat on the rail top
const PITCH_SCALE := {"": 1.0, "_mobile": 0.87}  # v3 AD: spacing tightened to fit the Bank-Pot gap
                                              # (phone floor 24 px @ 844x390; 0.87 -> 24.1 px)
const BRASS_HI := Color("#E2C06A")    # the Hearth bevel highlight
const BEAD_AT := Vector3(0.005, PLATE_Y, 0.0175)  # bust bead: on the plate lip in front of the candle foot
const DRIP_W := 0.020                 # v2: bigger drip card (v1 0.011 x 0.042)
const DRIP_H := 0.070
const FLAME_H := 0.032                # visible tongue (Hearth progress candles: 0.03; +7 % so the state reads at 48 px)


func _init() -> void:
	var mode := "scenes"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		mode = args[0]
	if mode == "materials":
		_materials()
	else:
		_candle("")
		_candle("_mobile")
		_row("")
		_row("_mobile")
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


func _materials() -> void:
	var M := P + "materials/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(M))
	var ink := load(H + "materials/ink_prop.tres")
	# unlit (snuffed) tallow: the Hearth wax with a dim silhouette emission (reads in the dark near rail)
	var wax := _copy(H + "materials/candle_wax.tres", {"albedo": TALLOW, "emission_color": Color("#33281F"), "emission_energy": 0.5})
	wax.next_pass = ink
	_save(wax, M + "candle_row_wax.tres")
	# lit: hot Butter rim + warm body, a notch under the Hearth progress candles (rim 2.2 -> 1.8)
	var wl := _copy(H + "materials/candle_wax_lit.tres", {"albedo": TALLOW, "rim_strength": 1.8, "emission_color": Color("#C88A52"), "emission_energy": 0.85})
	wl.next_pass = ink
	_save(wl, M + "candle_row_wax_lit.tres")
	# cold stub: ash grey, no rim, faint silhouette
	var wc := _copy(H + "materials/candle_wax.tres", {"albedo": ASH, "shadow_color": Color("#2A2622"), "rim_strength": 0.08,
		"spec_strength": 0.08, "emission_color": Color("#26221E"), "emission_energy": 0.45})
	wc.next_pass = ink
	_save(wc, M + "candle_row_wax_cold.tres")
	for lod in ["", "_mobile"]:
		var fl := _copy(H + "materials/candle_flame%s.tres" % lod, {})
		fl.shader = load(P + "shaders/candle_row_flame.gdshader")
		var src := load(H + "materials/candle_flame%s.tres" % lod) as ShaderMaterial
		for p in src.shader.get_shader_uniform_list():
			var v: Variant = src.get_shader_parameter(p.name)
			if v != null:
				fl.set_shader_parameter(p.name, v)
		_save(fl, M + "candle_row_flame%s.tres" % lod)
	_save(_sm(P + "shaders/candle_row_drip.gdshader", {"wax_color": Color("#F2D9A2")}), M + "candle_row_drip.tres")
	# v2 last-hand gutter: the lit wax at ~half its glow
	var wg := _copy(H + "materials/candle_wax_lit.tres", {"albedo": TALLOW, "rim_strength": 0.95, "emission_color": Color("#C88A52"), "emission_energy": 0.42})
	wg.next_pass = ink
	_save(wg, M + "candle_row_wax_gutter.tres")
	# v2 bust bead: the drip's wax colour as a lit-ish tallow lump
	var bd := _copy(H + "materials/candle_wax.tres", {"albedo": Color("#F2D9A2"), "emission_color": Color("#C88A52"), "emission_energy": 0.9, "rim_strength": 1.4})
	bd.next_pass = ink
	_save(bd, M + "candle_row_bead.tres")
	# v2 AD (1): the gift / cue ring at the bevel-highlight level: BRASS_HI body + BRASS_HI rim, a little glow
	var rg := _copy("res://art/models/boards/infernal_pit/materials/brass.tres", {"albedo": BRASS_HI, "rim_color": BRASS_HI,
		"rim_strength": 1.6, "emission_color": BRASS_HI, "emission_energy": 0.32})
	rg.next_pass = ink
	_save(rg, M + "candle_row_ring.tres")
	# v5 QA (#142): the >8 "more than shown" cue ring: Butter-hot brass, stronger rim + glow, so 10 hands never reads as 8
	var rc := _copy("res://art/models/boards/infernal_pit/materials/brass.tres", {"albedo": Color("#C8902A"), "spec_color": Color("#FFE6A8"), "rim_color": BRASS_HI,
		"rim_strength": 2.0, "emission_color": Color("#E8A93A"), "emission_energy": 0.6})
	rc.next_pass = ink
	_save(rc, M + "candle_row_ring_cue.tres")


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


func _card(parent: Node, name: String, mat: Material, h: float) -> MeshInstance3D:
	var size := h / 0.8
	var mi := MeshInstance3D.new()
	mi.name = name
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.center_offset = Vector3(0, size * 0.5, 0)
	mi.mesh = q
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = size + 0.1
	mi.visible = false
	parent.add_child(mi)
	return mi


func _track(a: Animation, prop: String, keys: Array) -> void:
	var t := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(t, NodePath(".:" + prop))
	a.value_track_set_update_mode(t, Animation.UPDATE_DISCRETE)
	for k in keys:
		a.track_insert_key(t, k[0], k[1])


func _clips(ap: AnimationPlayer) -> void:
	var lib := AnimationLibrary.new()
	var reset := Animation.new()
	reset.length = STEP
	for kv in [["heat", 1.0], ["wisp", 0.0], ["gutter", 0.0], ["drip", 0.0], ["bead", 0.0], ["rise", 1.0], ["flare", 0.0]]:
		_track(reset, kv[0], [[0.0, kv[1]]])
	lib.add_animation(&"RESET", reset)
	# snuff 0.6 s: flame dips and is out by 2 drawings (0.17 s); smoke curl 0.08 -> 0.5 s
	var sn := Animation.new()
	sn.length = 0.6
	_track(sn, "heat", [[0.0, 1.0], [STEP, 0.45], [2 * STEP, 0.0]])
	_track(sn, "wisp", [[0.0, 0.0], [STEP, 0.05], [2 * STEP, 0.2], [3 * STEP, 0.35], [4 * STEP, 0.5], [5 * STEP, 0.65], [6 * STEP, 0.8], [7 * STEP, 1.0]])
	lib.add_animation(&"snuff", sn)
	# snuff_bust 1.25 s (v2): the flame gutters (leans, shrinks); a bigger wax drip runs slowly down the
	# wax over 0.42 s (5 drawings on twos) and drops a bead on the holder at 0.5 s; then the snuff above
	var sb := Animation.new()
	sb.length = 1.25
	_track(sb, "gutter", [[0.0, 1.0]])
	_track(sb, "drip", [[0.0, 0.0], [STEP, 0.2], [2 * STEP, 0.4], [3 * STEP, 0.6], [4 * STEP, 0.8], [5 * STEP, 1.0]])
	_track(sb, "bead", [[0.0, 0.0], [6 * STEP, 1.0]])
	var o := 6 * STEP
	_track(sb, "heat", [[0.0, 1.0], [o, 0.7], [o + STEP, 0.4], [o + 2 * STEP, 0.0]])
	_track(sb, "wisp", [[0.0, 0.0], [o + STEP, 0.05], [o + 2 * STEP, 0.2], [o + 3 * STEP, 0.4], [o + 4 * STEP, 0.6], [o + 5 * STEP, 0.8], [o + 6 * STEP, 1.0]])
	lib.add_animation(&"snuff_bust", sb)
	# gutter 1.5 s loop (v2, last hand): a thin smoke thread keeps lifting off the low flame, irregular beats
	var gt := Animation.new()
	gt.length = 1.5
	gt.loop_mode = Animation.LOOP_LINEAR
	_track(gt, "wisp", [[0.0, 0.12], [STEP, 0.2], [2 * STEP, 0.28], [4 * STEP, 0.36], [5 * STEP, 0.44], [7 * STEP, 0.3],
		[8 * STEP, 0.18], [10 * STEP, 0.26], [11 * STEP, 0.34], [13 * STEP, 0.42], [14 * STEP, 0.5], [16 * STEP, 0.16]])
	lib.add_animation(&"gutter", gt)
	# rise_in 0.5 s: the gift candle pushes up out of its socket (overshoot 1 drawing), then lights
	var ri := Animation.new()
	ri.length = 0.5
	_track(ri, "rise", [[0.0, 0.0], [STEP, 0.35], [2 * STEP, 0.75], [3 * STEP, 1.08], [4 * STEP, 1.0]])
	_track(ri, "heat", [[0.0, 0.0], [4 * STEP, 0.35], [5 * STEP, 0.8], [6 * STEP, 1.0]])
	_track(ri, "flare", [[0.0, 0.0], [5 * STEP, 0.8], [6 * STEP, 0.0]])
	lib.add_animation(&"rise_in", ri)
	ap.add_animation_library(&"", lib)


func _candle(lod: String) -> void:
	var cd := Node3D.new()
	cd.name = "Candle"
	cd.set_script(load(P + "scripts/candle_row_candle.gd"))
	_inst(P + "candle_row_socket.glb", "Plate", cd)
	var m := _inst(P + "candle_row_candle.glb", "Model", cd)
	m.position.y = PLATE_Y
	var fl := _card(cd, "Flame", load(P + "materials/candle_row_flame%s.tres" % lod), FLAME_H)
	fl.visible = true
	_card(cd, "Wisp", load(H + "materials/smoke_wisp_small.tres"), 0.024)
	var dr := MeshInstance3D.new()
	dr.name = "Drip"
	var q := QuadMesh.new()
	q.size = Vector2(DRIP_W, DRIP_H)
	q.center_offset = Vector3(0, -DRIP_H * 0.5, 0)
	dr.mesh = q
	dr.material_override = load(P + "materials/candle_row_drip.tres")
	dr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dr.extra_cull_margin = 0.1
	dr.visible = false
	cd.add_child(dr)
	var bd := _inst(P + "candle_row_bead.glb", "Bead", cd)
	bd.position = BEAD_AT
	bd.visible = false
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	cd.add_child(ap)
	_clips(ap)
	_pack(cd, P + "scenes/candle_row_candle%s.tscn" % lod)


func _row(lod: String) -> void:
	var row := Node3D.new()
	row.name = "CandleRow"
	row.set_script(load(P + "scripts/candle_row.gd"))
	var k := float(ROW_SCALE[lod])
	var ps := float(PITCH_SCALE[lod])
	var pp := PITCH * ps
	for t in 2:  # Holder = front tier, HolderBack = back tier
		var hd := _inst(P + "candle_row_holder.glb", "Holder" if t == 0 else "HolderBack", row)
		hd.scale = Vector3(k * ps, k, k)
		hd.position = Vector3(0.5 * pp * t, TIER_RISE * t, -TIER_DZ * t) * k
	var socks := Node3D.new()
	socks.name = "Sockets"
	row.add_child(socks)
	for i in CAP:
		var t := i / TIER
		var s := Marker3D.new()
		s.name = "Socket%d" % (i + 1)
		s.position = Vector3((i % TIER - (TIER - 1) * 0.5 + 0.5 * t) * pp, BAR_H + TIER_RISE * t, -TIER_DZ * t) * k
		s.scale = Vector3.ONE * k
		socks.add_child(s)
		_inst(P + "scenes/candle_row_candle%s.tscn" % lod, "Candle", s)
	for g in 2:
		var r := _inst(P + "candle_row_ring.glb", "GiftRing%d" % (g + 1), row)
		r.position.y = (BAR_H + PLATE_Y) * k
		r.scale = Vector3.ONE * k
		r.visible = false
	var la := Marker3D.new()
	la.name = "LightAnchor"   # bounce light belongs to the lighting rig (lighting_layers_spec), not the prop
	la.position = Vector3(0, 0.12, 0.03) * k
	row.add_child(la)
	_pack(row, P + "scenes/candle_row%s.tscn" % lod)
