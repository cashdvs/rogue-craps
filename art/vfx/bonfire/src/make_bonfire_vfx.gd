extends SceneTree
## Generates the Bonfire scoring-juice materials and scenes (art only, no gameplay code).
##   godot --headless --path . --script res://art/vfx/bonfire/src/make_bonfire_vfx.gd -- --materials
##   (then import the prop glbs: python3 art/models/props/bonfire/src/remap_imports.py && godot --import)
##   godot --headless --path . --script res://art/vfx/bonfire/src/make_bonfire_vfx.gd -- --scenes
## Spec: design/bonfire_map_events_juice.md section 3. Every scene is plain nodes, particles and an
## AnimationPlayer; the README lists the clips and the parameters Godot Dev triggers.

const V := "res://art/vfx/bonfire/"
const P := "res://art/models/props/bonfire/"
const TOON := "res://shaders/3d/toon_noir.gdshader"
const OUTLINE := "res://shaders/3d/outline.gdshader"

# Palette (style_guide.md / scripts/table/palette.gd) + Bonfire derivations (README).
const BONE := Color("#E8DCC0")
const BONE_SHADE := Color("#BFAF8E")
const EMBER := Color("#E8622A")
const FLAME_MID := Color("#F6A845")
const FLAME_CORE := Color("#FFE7A8")
const HELLFIRE := Color("#C8281E")
const BURGUNDY := Color("#6E1A24")
const OXBLOOD := Color("#3B0D14")
const PIT_BLACK := Color("#0E1414")
const BRASS := Color("#B08D3C")
const BRASS_HI := Color("#E2C06A")
const SOUL := Color("#4FE6E0")
const SOUL_CORE := Color("#DFFFFD")
const SOUL_DEEP := Color("#1E8F8B")
const ASH := Color("#5A5E62")
const ASH_DARK := Color("#141618")
const WAX := Color("#8E1A20")

## Clip lengths (s). Normal score sequence <= 1.2 s, big <= 2.0 s (section 3 "Timing").
const TIER_BURST := {1: 0.8, 2: 1.0, 3: 1.2, 4: 1.8}
const IGNITE := 0.12
const SNUFF := 0.2
const LIFT := 0.24
const STAGGER_NORMAL := 0.08
const STAGGER_BIG := 0.14

var _stage := "all"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--materials":
			_stage = "materials"
		elif a == "--scenes":
			_stage = "scenes"
	for d in ["materials", "scenes/fire/cpu", "scenes/dice", "palette"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(V + d))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(P + "materials"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(P + "scenes"))
	if _stage != "scenes":
		_materials()
		_palette()
	if _stage != "materials":
		_fire_tiers()
		_dice_scenes()
		_props()
	quit(0)


# --- materials ------------------------------------------------------------------------------

func _sm(shader_path: String, params: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(shader_path)
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m


func _save_mat(m: Material, path: String) -> void:
	ResourceSaver.save(m, path)


func _fire(name: String, shape: int, outer: Color, mid: Color, core: Color, extra: Dictionary = {}) -> void:
	var p := {"shape": shape, "outer_color": outer, "mid_color": mid, "core_color": core}
	p.merge(extra, true)
	_save_mat(_sm(V + "shaders/toon_fire.gdshader", p), V + "materials/%s.tres" % name)


func _toon(path: String, albedo: Color, shadow: Color, opts: Dictionary, ink: float = 0.0, ink_mode: int = 0) -> void:
	var p := {"albedo": albedo, "shadow_color": shadow}
	p.merge(opts, true)
	var m := _sm(TOON, p)
	if ink > 0.0:
		m.next_pass = load(P + "materials/prop_ink_mode%d.tres" % ink_mode)
	_save_mat(m, path)


func _materials() -> void:
	# Fire (toon_fire.gdshader).
	_fire("fire_flame", 0, EMBER, FLAME_MID, FLAME_CORE)
	_fire("fire_flame_hell", 0, HELLFIRE, EMBER, FLAME_MID, {"energy": 1.3})
	_fire("fire_spark", 1, EMBER, FLAME_MID, FLAME_CORE, {"ink_width": 0.0, "energy": 1.8})
	_fire("fire_blob", 2, EMBER, FLAME_MID, FLAME_CORE, {"ink_width": 0.0, "energy": 1.2})
	_fire("fire_column", 3, HELLFIRE, EMBER, FLAME_MID, {"billboard": 0, "energy": 1.3, "tongues": 7.0, "ink_width": 0.03})
	_fire("fire_column_core", 3, EMBER, FLAME_MID, FLAME_CORE, {"billboard": 0, "energy": 1.5, "tongues": 5.0, "ink_width": 0.0, "scroll_speed": 2.0})
	_fire("fire_ring", 4, EMBER, FLAME_MID, FLAME_CORE, {"billboard": 0, "ink_width": 0.0, "energy": 2.0})
	_fire("fire_ring_billboard", 4, EMBER, FLAME_MID, FLAME_CORE, {"ink_width": 0.0, "energy": 2.0})
	_fire("ash_smoke", 2, ASH_DARK, Color("#4A4440"), ASH, {"ink_width": 0.14, "energy": 1.0, "mid_at": 0.5, "core_at": 0.85})
	_fire("soul_drip", 2, SOUL_DEEP, SOUL, SOUL_CORE, {"ink_width": 0.18, "energy": 1.3})
	_fire("wax_crumb", 2, WAX, Color("#B0303A"), Color("#D85A50"), {"ink_width": 0.2, "energy": 1.0})
	# Dice.
	_save_mat(_sm(V + "shaders/lit_face_glow.gdshader", {"face_dir": Vector3.UP, "half_size": 0.04}), V + "materials/lit_face_glow.tres")
	_save_mat(_sm(V + "shaders/lit_face_glow.gdshader", {"round_pool": true, "half_size": 0.08, "face_threshold": 0.5, "body_glow": 0.0, "energy": 1.2, "glow_color": Color("#FFE2B0"), "edge_color": Color("#FFB070")}), V + "materials/felt_glow_pool.tres")
	var ink := _sm(V + "shaders/ash_outline.gdshader", {})
	_save_mat(ink, V + "materials/ash_outline.tres")
	var body := _sm(V + "shaders/ash_die.gdshader", {"base_color": BONE, "base_shadow": Color("#8E7A5C"), "ash_color": ASH, "ash_shadow": ASH_DARK})
	body.next_pass = load(V + "materials/ash_outline.tres")
	_save_mat(body, V + "materials/ash_body.tres")
	_save_mat(_sm(V + "shaders/ash_die.gdshader", {"base_color": PIT_BLACK, "base_shadow": PIT_BLACK,
		"ash_color": Color("#2B2826"), "ash_shadow": Color("#0E0D0C"), "light_gain": 0.4}), V + "materials/ash_pip.tres")
	# Props (toon_noir + ink hulls; mode 1 pushes from the prop origin for flat-shaded props).
	for mode in [0, 1]:
		_save_mat(_sm(OUTLINE, {"width": 0.0025 if mode == 0 else 0.0022, "mode": mode}), P + "materials/prop_ink_mode%d.tres" % mode)
	_toon(P + "materials/wax.tres", WAX, Color("#2A0A10"), {"spec_size": 0.97, "spec_strength": 0.35, "wrap": 0.3, "mid_tint": 0.72, "light_gain": 0.85}, 1.0, 1)
	_toon(P + "materials/wax_letter.tres", BRASS_HI, Color("#3A2A10"), {"spec_size": 0.92, "wrap": 0.3, "mid_tint": 0.8})
	_toon(P + "materials/cork.tres", Color("#5A3A24"), Color("#140A06"), {"wrap": 0.3}, 1.0, 0)
	_toon(P + "materials/brass.tres", BRASS, Color("#3A2A10"), {"spec_size": 0.92, "wrap": 0.3}, 1.0, 0)
	_toon(P + "materials/coal.tres", Color("#161212"), Color("#0A0606"), {"rim_color": EMBER, "rim_strength": 0.5, "rim_power": 2.0, "wrap": 0.2}, 1.0, 1)
	_toon(P + "materials/mult_body.tres", HELLFIRE, Color("#3B0D14"), {"chip_mode": true, "chip_radius": 0.0275,
		"notch_color": BONE, "ring_color": BRASS_HI, "spec_size": 0.94, "spec_strength": 0.4, "mid_tint": 0.7, "wrap": 0.3}, 1.0, 1)
	_toon(P + "materials/mult_inlay.tres", OXBLOOD, Color("#140406"), {"wrap": 0.3, "mid_tint": 0.8})
	_save_mat(_sm(V + "shaders/ember_glow.gdshader", {}), P + "materials/ember_hot.tres")
	var glass := _sm(V + "shaders/soul_glass.gdshader", {})
	glass.render_priority = 1
	glass.next_pass = load(P + "materials/prop_ink_mode0.tres")
	_save_mat(glass, P + "materials/soul_glass.tres")
	_save_mat(_sm(V + "shaders/soul_liquid.gdshader", {}), P + "materials/soul_liquid.tres")


## Combo banner colours by rarity tier (section 3), tier order = rarity order.
func _palette() -> void:
	var tiers := ColorPalette.new()
	tiers.colors = PackedColorArray([BONE, EMBER, HELLFIRE, PIT_BLACK])
	ResourceSaver.save(tiers, V + "palette/combo_banner_tiers.tres")
	# Per tier: face, shade, ink/trim, glow.
	var detail := ColorPalette.new()
	detail.colors = PackedColorArray([
		BONE, BONE_SHADE, PIT_BLACK, Color("#FFE2B0"),
		EMBER, Color("#A8401A"), PIT_BLACK, FLAME_MID,
		HELLFIRE, BURGUNDY, PIT_BLACK, EMBER,
		PIT_BLACK, BRASS, BRASS_HI, BRASS_HI,
	])
	ResourceSaver.save(detail, V + "palette/combo_banner_detail.tres")


# --- scene helpers --------------------------------------------------------------------------

func _own(n: Node, root: Node) -> void:
	for c in n.get_children():
		c.owner = root
		if c.scene_file_path == "":
			_own(c, root)


func _save(root: Node, path: String) -> void:
	_own(root, root)
	var ps := PackedScene.new()
	var err := ps.pack(root)
	assert(err == OK)
	ResourceSaver.save(ps, path)
	root.free()


func _ramp(alphas: Array) -> GradientTexture1D:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in alphas.size():
		offs.append(float(i) / float(alphas.size() - 1))
		cols.append(Color(1, 1, 1, alphas[i]))
	g.offsets = offs
	g.colors = cols
	var t := GradientTexture1D.new()
	t.gradient = g
	t.width = 64
	return t


## A GPUParticles3D with a toon_fire quad. o: box (Vector3 extents), at (offset), dir, spread,
## vel (Vector2), gravity (float, +up), damp, scale (Vector2), ramp (alphas), one_shot, expl, local.
func _particles(parent: Node, name: String, mat: String, amount: int, life: float, quad: Vector2, o: Dictionary) -> GPUParticles3D:
	var g := GPUParticles3D.new()
	g.name = name
	g.amount = amount
	g.lifetime = life
	g.emitting = o.get("emitting", false)
	g.one_shot = o.get("one_shot", false)
	g.explosiveness = o.get("expl", 0.0)
	g.local_coords = o.get("local", true)
	g.position = o.get("pos", Vector3.ZERO)
	g.visibility_aabb = o.get("aabb", AABB(Vector3(-0.3, -0.1, -0.3), Vector3(0.6, 0.6, 0.6)))
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = o.get("box", Vector3(0.03, 0.005, 0.03))
	pm.emission_shape_offset = o.get("at", Vector3.ZERO)
	pm.direction = o.get("dir", Vector3.UP)
	pm.spread = o.get("spread", 15.0)
	var vel: Vector2 = o.get("vel", Vector2(0.05, 0.1))
	pm.initial_velocity_min = vel.x
	pm.initial_velocity_max = vel.y
	pm.gravity = Vector3(0, o.get("gravity", 0.0), 0)
	pm.damping_min = o.get("damp", 0.0)
	pm.damping_max = o.get("damp", 0.0)
	var sc: Vector2 = o.get("scale", Vector2(0.8, 1.2))
	pm.scale_min = sc.x
	pm.scale_max = sc.y
	pm.color_ramp = _ramp(o.get("ramp", [0.4, 1.0, 0.8, 0.0]))
	g.process_material = pm
	var q := QuadMesh.new()
	q.size = quad
	q.material = load(V + "materials/%s.tres" % mat)
	g.draw_pass_1 = q
	parent.add_child(g)
	return g


func _quad(parent: Node, name: String, mat: Material, size: Vector2, pos: Vector3, flat: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var q := PlaneMesh.new() if flat else QuadMesh.new()
	q.size = size
	mi.mesh = q
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _player(root: Node, clips: Dictionary, autoplay: String = "") -> AnimationPlayer:
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	var lib := AnimationLibrary.new()
	for k in clips:
		lib.add_animation(k, clips[k])
	ap.add_animation_library("", lib)
	root.add_child(ap)
	ap.autoplay = autoplay
	return ap


func _clip(length: float, loop: bool = false) -> Animation:
	var a := Animation.new()
	a.length = length
	a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	return a


## keys: [[time, value], ...]. Discrete for bools.
func _track(a: Animation, path: String, keys: Array, cubic: bool = false) -> void:
	var t := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(t, NodePath(path))
	if keys.size() > 0 and keys[0][1] is bool:
		a.value_track_set_update_mode(t, Animation.UPDATE_DISCRETE)
	elif cubic:
		a.track_set_interpolation_type(t, Animation.INTERPOLATION_CUBIC)
	for k in keys:
		a.track_insert_key(t, k[0], k[1])


## Plays another AnimationPlayer's clip at time t (animation track).
func _sub(a: Animation, path: String, keys: Array) -> void:
	var t := a.add_track(Animation.TYPE_ANIMATION)
	a.track_set_path(t, NodePath(path))
	for k in keys:
		a.animation_track_insert_key(t, k[0], k[1])


func _to_cpu(n: Node) -> void:
	for c in n.get_children():
		_to_cpu(c)
		if c is GPUParticles3D:
			var g := c as GPUParticles3D
			var cpu := CPUParticles3D.new()
			cpu.convert_from_particles(g)
			cpu.name = g.name
			cpu.transform = g.transform
			cpu.emitting = g.emitting
			cpu.cast_shadow = g.cast_shadow
			var idx := g.get_index()
			n.remove_child(g)
			g.free()
			n.add_child(cpu)
			n.move_child(cpu, idx)


# --- 4 fire tiers ---------------------------------------------------------------------------
# Origin = the die centre (a 0.08 m die resting on the felt: its top face is at y = +0.04, the felt
# at y = -0.04). local_coords = true, so the fire rides along when the die lifts.

const TIER_NAMES := {1: "fire_tier_1_embers", 2: "fire_tier_2_flames", 3: "fire_tier_3_inferno", 4: "fire_tier_4_pillar"}


func _tier(n: int, cpu: bool) -> void:
	var root := Node3D.new()
	root.name = ["", "FireTier1Embers", "FireTier2Flames", "FireTier3Inferno", "FireTier4Pillar"][n]
	var emitters: Array[String] = []
	match n:
		1:
			_particles(root, "Sparks", "fire_spark", 12, 0.7, Vector2(1, 1), {"box": Vector3(0.035, 0.01, 0.035),
				"at": Vector3(0, 0.035, 0), "vel": Vector2(0.10, 0.22), "spread": 30.0, "gravity": 0.08, "damp": 0.1,
				"scale": Vector2(0.014, 0.022), "ramp": [1.0, 1.0, 0.7, 0.0]})
			emitters = ["Sparks"]
		2:
			_particles(root, "Flames", "fire_flame", 10, 0.45, Vector2(0.055, 0.085), {"box": Vector3(0.03, 0.004, 0.03),
				"at": Vector3(0, 0.055, 0), "vel": Vector2(0.04, 0.10), "spread": 10.0, "scale": Vector2(0.8, 1.2),
				"ramp": [0.35, 1.0, 0.85, 0.0]})
			_particles(root, "Sparks", "fire_spark", 8, 0.6, Vector2(1, 1), {"box": Vector3(0.03, 0.01, 0.03),
				"at": Vector3(0, 0.05, 0), "vel": Vector2(0.15, 0.3), "spread": 25.0, "gravity": 0.05,
				"scale": Vector2(0.010, 0.016), "ramp": [1.0, 1.0, 0.6, 0.0]})
			emitters = ["Flames", "Sparks"]
		3:
			_particles(root, "Flames", "fire_flame_hell", 18, 0.5, Vector2(0.08, 0.12), {"box": Vector3(0.045, 0.02, 0.045),
				"at": Vector3(0, 0.05, 0), "vel": Vector2(0.06, 0.16), "spread": 15.0, "scale": Vector2(0.8, 1.25),
				"ramp": [0.35, 1.0, 0.85, 0.0]})
			_particles(root, "Core", "fire_flame", 8, 0.4, Vector2(0.045, 0.075), {"box": Vector3(0.025, 0.005, 0.025),
				"at": Vector3(0, 0.06, 0), "vel": Vector2(0.05, 0.12), "spread": 8.0, "ramp": [0.4, 1.0, 0.8, 0.0]})
			_particles(root, "Sparks", "fire_spark", 14, 0.7, Vector2(1, 1), {"box": Vector3(0.04, 0.02, 0.04),
				"at": Vector3(0, 0.06, 0), "vel": Vector2(0.25, 0.5), "spread": 35.0, "gravity": -0.2,
				"scale": Vector2(0.012, 0.02), "ramp": [1.0, 1.0, 0.6, 0.0]})
			emitters = ["Flames", "Core", "Sparks"]
		4:
			# ONE central pillar for the whole potted group (design section 6). Origin = the group's
			# centre on the felt (y = 0); sized for 5 dice across ~0.66 m. The dice keep tier 3
			# (inferno) per die underneath it.
			for spec in [["Column", "fire_column", 0.15, 0.05, 0.85], ["ColumnCore", "fire_column_core", 0.09, 0.02, 0.7]]:
				var mi := MeshInstance3D.new()
				mi.name = spec[0]
				var cyl := CylinderMesh.new()
				cyl.bottom_radius = spec[2]
				cyl.top_radius = spec[3]
				cyl.height = spec[4]
				cyl.radial_segments = 16
				cyl.rings = 1
				cyl.cap_top = false
				cyl.cap_bottom = false
				mi.mesh = cyl
				mi.material_override = load(V + "materials/%s.tres" % spec[1])
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				var pivot := Node3D.new()  # scales up from the felt
				pivot.name = spec[0] + "Pivot"
				root.add_child(pivot)
				mi.position = Vector3(0, spec[4] * 0.5, 0)
				pivot.add_child(mi)
			var group := AABB(Vector3(-0.8, -0.1, -0.8), Vector3(1.6, 1.8, 1.6))
			_particles(root, "Flames", "fire_flame_hell", 24, 0.55, Vector2(0.12, 0.2), {"box": Vector3(0.3, 0.02, 0.09),
				"at": Vector3(0, 0.06, 0), "vel": Vector2(0.12, 0.3), "spread": 12.0, "scale": Vector2(0.8, 1.3),
				"ramp": [0.35, 1.0, 0.85, 0.0], "aabb": group})
			_particles(root, "Sparks", "fire_spark", 32, 0.9, Vector2(1, 1), {"box": Vector3(0.2, 0.06, 0.08),
				"at": Vector3(0, 0.18, 0), "vel": Vector2(0.6, 1.3), "spread": 20.0, "gravity": -0.6,
				"scale": Vector2(0.018, 0.03), "ramp": [1.0, 1.0, 0.6, 0.0], "aabb": group})
			_quad(root, "ShockRing", load(V + "materials/fire_ring.tres"), Vector2(0.8, 0.8), Vector3(0, 0.002, 0), true)
			emitters = ["Flames", "Sparks"]
	var ign := _clip(IGNITE)
	var snf := _clip(SNUFF)
	var reset := _clip(0.001)
	var burst := _clip(TIER_BURST[n])
	var hold_end: float = TIER_BURST[n] - SNUFF
	for e in emitters:
		var hp := e + ":instance_shader_parameters/heat"
		_track(reset, e + ":emitting", [[0.0, false]])
		_track(reset, hp, [[0.0, 1.0]])
		_track(ign, e + ":emitting", [[0.0, true]])
		_track(ign, hp, [[0.0, 0.3], [IGNITE, 1.0]])
		_track(snf, e + ":emitting", [[0.0, false]])
		_track(snf, hp, [[0.0, 1.0], [SNUFF, 0.0]])
		_track(burst, e + ":emitting", [[0.0, true], [hold_end, false]])
		_track(burst, hp, [[0.0, 0.3], [IGNITE, 1.0], [hold_end, 1.0], [TIER_BURST[n], 0.0]])
	if n == 4:
		for c in ["ColumnPivot", "ColumnCorePivot"]:
			var cp: String = c + ":scale"
			var hp: String = c + "/" + c.replace("Pivot", "") + ":instance_shader_parameters/heat"
			_track(reset, cp, [[0.0, Vector3(1, 0.001, 1)]])
			_track(reset, hp, [[0.0, 1.0]])
			_track(ign, cp, [[0.0, Vector3(0.6, 0.05, 0.6)], [IGNITE, Vector3(1.1, 0.7, 1.1)]])
			_track(snf, cp, [[0.0, Vector3(1, 1, 1)], [SNUFF, Vector3(0.4, 0.15, 0.4)]])
			_track(snf, hp, [[0.0, 1.0], [SNUFF, 0.0]])
			_track(burst, cp, [[0.0, Vector3(0.6, 0.05, 0.6)], [0.22, Vector3(1.15, 1.12, 1.15)], [0.4, Vector3(1, 1, 1)],
				[hold_end, Vector3(1, 1, 1)], [TIER_BURST[n], Vector3(0.4, 0.15, 0.4)]])
			_track(burst, hp, [[0.0, 1.0], [hold_end, 1.0], [TIER_BURST[n], 0.0]])
		_track(reset, "ShockRing:scale", [[0.0, Vector3(0.001, 1, 0.001)]])
		_track(burst, "ShockRing:scale", [[0.0, Vector3(0.2, 1, 0.2)], [0.35, Vector3(1.3, 1, 1.3)], [0.36, Vector3(0.001, 1, 0.001)]])
		_track(burst, "ShockRing:instance_shader_parameters/heat", [[0.0, 1.0], [0.35, 0.0]])
		_track(ign, "ShockRing:scale", [[0.0, Vector3(0.2, 1, 0.2)], [IGNITE, Vector3(0.8, 1, 0.8)]])
		_track(snf, "ShockRing:scale", [[0.0, Vector3(0.001, 1, 0.001)]])
	_player(root, {"RESET": reset, "ignite": ign, "snuff": snf, "burst": burst})
	if cpu:
		_to_cpu(root)
	_save(root, V + "scenes/fire/%s%s.tscn" % ["cpu/" if cpu else "", TIER_NAMES[n] + ("_cpu" if cpu else "")])


func _fire_tiers() -> void:
	for n in [1, 2, 3, 4]:
		_tier(n, false)
		_tier(n, true)


# --- dice: lit face, potted lift, Hot Hand, ash ------------------------------------------------

func _standin(parent: Node, name: String, mat: Material = null) -> MeshInstance3D:
	## Demo-only stand-in die (a plain 0.08 box). Real dice: bone_d6.glb.
	var mi := MeshInstance3D.new()
	mi.name = name
	var b := BoxMesh.new()
	b.size = Vector3(0.08, 0.08, 0.08)
	mi.mesh = b
	if mat == null:
		var m := _sm(TOON, {"albedo": BONE, "shadow_color": Color("#8E7A5C"), "wrap": 0.35, "spec_size": 0.97, "mid_tint": 0.8})
		m.next_pass = _sm(OUTLINE, {"width": 0.0042, "mode": 1})
		mat = m
	mi.material_override = mat
	parent.add_child(mi)
	return mi


## One potted die: lift + light-up. The die goes under Lift/DieSlot (or point Lift/Follow's
## remote_path at it). Origin = the die centre at rest.
func _potted_rig() -> Node3D:
	var root := Node3D.new()
	root.name = "PottedDie"
	var lift := Node3D.new()
	lift.name = "Lift"
	root.add_child(lift)
	var slot := Node3D.new()
	slot.name = "DieSlot"
	lift.add_child(slot)
	var follow := RemoteTransform3D.new()
	follow.name = "Follow"
	follow.update_rotation = false
	lift.add_child(follow)
	var face := _quad(lift, "LitFace", load(V + "materials/lit_face_glow.tres"), Vector2(0.08, 0.08), Vector3(0, 0.0406, 0), true)
	face.set_instance_shader_parameter("glow", 0.0)
	var pool := _quad(root, "FeltGlow", load(V + "materials/felt_glow_pool.tres"), Vector2(0.16, 0.16), Vector3(0, -0.0395, 0), true)
	pool.set_instance_shader_parameter("glow", 0.0)
	var reset := _clip(0.001)
	_track(reset, "Lift:position", [[0.0, Vector3.ZERO]])
	_track(reset, "Lift:scale", [[0.0, Vector3.ONE]])
	_track(reset, "Lift/LitFace:instance_shader_parameters/glow", [[0.0, 0.0]])
	_track(reset, "FeltGlow:instance_shader_parameters/glow", [[0.0, 0.0]])
	var up := _clip(LIFT)
	_track(up, "Lift:position", [[0.0, Vector3.ZERO], [0.14, Vector3(0, 0.078, 0)], [LIFT, Vector3(0, 0.07, 0)]], true)
	_track(up, "Lift:scale", [[0.0, Vector3.ONE], [0.09, Vector3(1.14, 1.14, 1.14)], [LIFT, Vector3.ONE]])
	_track(up, "Lift/LitFace:instance_shader_parameters/glow", [[0.0, 0.0], [0.08, 1.8], [LIFT, 1.0]])
	_track(up, "FeltGlow:instance_shader_parameters/glow", [[0.0, 0.0], [0.1, 1.0], [LIFT, 0.6]])
	var hold := _clip(0.6, true)
	_track(hold, "Lift:position", [[0.0, Vector3(0, 0.07, 0)], [0.3, Vector3(0, 0.074, 0)], [0.6, Vector3(0, 0.07, 0)]], true)
	_track(hold, "Lift/LitFace:instance_shader_parameters/glow", [[0.0, 1.0], [0.3, 0.8], [0.6, 1.0]])
	_track(hold, "FeltGlow:instance_shader_parameters/glow", [[0.0, 0.6], [0.6, 0.6]])
	var drop := _clip(0.15)
	_track(drop, "Lift:position", [[0.0, Vector3(0, 0.07, 0)], [0.15, Vector3.ZERO]])
	_track(drop, "Lift/LitFace:instance_shader_parameters/glow", [[0.0, 1.0], [0.15, 0.0]])
	_track(drop, "FeltGlow:instance_shader_parameters/glow", [[0.0, 0.6], [0.15, 0.0]])
	_player(root, {"RESET": reset, "lift_light": up, "hold": hold, "drop": drop})
	return root


func _ignite_scene() -> void:
	var root := Node3D.new()
	root.name = "HotHandIgnite"
	_particles(root, "Burst", "fire_flame", 12, 0.35, Vector2(0.05, 0.08), {"one_shot": true, "expl": 0.9,
		"box": Vector3(0.04, 0.03, 0.04), "at": Vector3(0, 0.02, 0), "vel": Vector2(0.15, 0.35), "spread": 60.0,
		"ramp": [1.0, 1.0, 0.7, 0.0]})
	_particles(root, "Sparks", "fire_spark", 10, 0.4, Vector2(1, 1), {"one_shot": true, "expl": 1.0,
		"box": Vector3(0.03, 0.03, 0.03), "vel": Vector2(0.4, 0.8), "spread": 90.0, "gravity": -0.8,
		"scale": Vector2(0.012, 0.02), "ramp": [1.0, 1.0, 0.5, 0.0]})
	var ring := _quad(root, "Flash", load(V + "materials/fire_ring_billboard.tres"), Vector2(0.2, 0.2), Vector3.ZERO, false)
	ring.set_instance_shader_parameter("heat", 0.0)
	var reset := _clip(0.001)
	_track(reset, "Flash:instance_shader_parameters/heat", [[0.0, 0.0]])
	var ig := _clip(0.35)
	_track(ig, "Burst:emitting", [[0.0, true]])
	_track(ig, "Sparks:emitting", [[0.0, true]])
	_track(ig, "Flash:scale", [[0.0, Vector3(0.3, 0.3, 0.3)], [0.2, Vector3(1.2, 1.2, 1.2)]])
	_track(ig, "Flash:instance_shader_parameters/heat", [[0.0, 1.0], [0.2, 0.0]])
	_player(root, {"RESET": reset, "ignite": ig})
	_save(root, V + "scenes/dice/hot_hand_ignite.tscn")


func _trail(parent: Node = null) -> Node3D:
	var root := Node3D.new()
	root.name = "FireTrail"
	var world := AABB(Vector3(-2, -1, -2), Vector3(4, 2, 4))
	_particles(root, "Blobs", "fire_blob", 36, 0.25, Vector2(1, 1), {"local": false, "box": Vector3(0.02, 0.02, 0.02),
		"vel": Vector2(0.0, 0.03), "spread": 180.0, "scale": Vector2(0.022, 0.04), "ramp": [1.0, 0.8, 0.4, 0.0], "aabb": world})
	_particles(root, "Head", "fire_flame", 8, 0.3, Vector2(0.05, 0.075), {"box": Vector3(0.03, 0.01, 0.03),
		"at": Vector3(0, 0.045, 0), "vel": Vector2(0.03, 0.08), "spread": 10.0, "ramp": [0.4, 1.0, 0.8, 0.0]})
	_particles(root, "Sparks", "fire_spark", 10, 0.4, Vector2(1, 1), {"local": false, "box": Vector3(0.02, 0.02, 0.02),
		"vel": Vector2(0.05, 0.2), "spread": 180.0, "gravity": -0.4, "scale": Vector2(0.01, 0.016),
		"ramp": [1.0, 1.0, 0.5, 0.0], "aabb": world})
	var reset := _clip(0.001)
	var start := _clip(0.05)
	var stop := _clip(0.05)
	for e in ["Blobs", "Sparks", "Head"]:
		_track(reset, e + ":emitting", [[0.0, false]])
		_track(start, e + ":emitting", [[0.0, true]])
		_track(stop, e + ":emitting", [[0.0, false]])
	_player(root, {"RESET": reset, "start": start, "stop": stop})
	if parent:
		parent.add_child(root)
	return root


const DEMO_SPOTS: Array[Vector3] = [Vector3(-0.32, 0.04, -0.05), Vector3(-0.15, 0.04, 0.08), Vector3(0.0, 0.04, -0.08),
	Vector3(0.16, 0.04, 0.05), Vector3(0.33, 0.04, -0.03)]


func _dice_scenes() -> void:
	_save(_potted_rig(), V + "scenes/dice/potted_die_rig.tscn")
	_ignite_scene()
	_save(_trail(), V + "scenes/dice/fire_trail.tscn")
	# Potted dice demo: 5 rigs, staggered (normal and big pacing).
	var demo := Node3D.new()
	demo.name = "PottedDiceDemo"
	var normal := _clip(4 * STAGGER_NORMAL + LIFT)
	var big := _clip(4 * STAGGER_BIG + LIFT)
	for i in 5:
		var rig := (load(V + "scenes/dice/potted_die_rig.tscn") as PackedScene).instantiate() as Node3D
		rig.name = "Die%d" % i
		rig.position = DEMO_SPOTS[i]
		demo.add_child(rig)
		_standin(rig.get_node("Lift/DieSlot"), "StandIn")
		_sub(normal, "Die%d/AnimationPlayer" % i, [[i * STAGGER_NORMAL, "lift_light"]])
		_sub(big, "Die%d/AnimationPlayer" % i, [[i * STAGGER_BIG, "lift_light"]])
	_player(demo, {"pot_sequence_normal": normal, "pot_sequence_big": big}, "")
	_save_editable(demo, V + "scenes/dice/potted_dice_demo.tscn")
	# Hot Hand demo: all 5 ignite, then fly back to the hand (off the near rail) trailing fire.
	var hh := Node3D.new()
	hh.name = "HotHandDemo"
	var fly := _clip(1.0)
	var hand := Vector3(0.0, 0.3, 0.75)
	for i in 5:
		var d := Node3D.new()
		d.name = "Die%d" % i
		d.position = DEMO_SPOTS[i]
		hh.add_child(d)
		_standin(d, "StandIn")
		var ig := (load(V + "scenes/dice/hot_hand_ignite.tscn") as PackedScene).instantiate()
		d.add_child(ig)
		var tr := (load(V + "scenes/dice/fire_trail.tscn") as PackedScene).instantiate()
		d.add_child(tr)
		var t0 := 0.3 + i * 0.04
		var mid := DEMO_SPOTS[i].lerp(hand, 0.5) + Vector3(0, 0.22, 0)
		_track(fly, "Die%d:position" % i, [[0.0, DEMO_SPOTS[i]], [t0, DEMO_SPOTS[i]], [t0 + 0.25, mid], [t0 + 0.5, hand]], true)
		_track(fly, "Die%d:scale" % i, [[t0 + 0.4, Vector3.ONE], [t0 + 0.5, Vector3(0.6, 0.6, 0.6)]])
		_sub(fly, "Die%d/HotHandIgnite/AnimationPlayer" % i, [[0.0, "ignite"]])
		_sub(fly, "Die%d/FireTrail/AnimationPlayer" % i, [[t0 - 0.02, "start"], [t0 + 0.5, "stop"]])
	_player(hh, {"hot_hand": fly})
	_save(hh, V + "scenes/dice/hot_hand_demo.tscn")
	# Ash demo: one stand-in with the ash material; the clips animate its instance uniforms.
	# bust (default): ash 0 -> 1 -> 0 in 0.5 s, back to bone (the dice stay in the bag).
	var ash := Node3D.new()
	ash.name = "AshDieDemo"
	var die := _standin(ash, "Die", load(V + "materials/ash_body.tres"))
	die.set_instance_shader_parameter("ash", 0.0)
	_particles(ash, "Puff", "ash_smoke", 8, 0.5, Vector2(1, 1), {"one_shot": true, "expl": 0.9,
		"box": Vector3(0.04, 0.01, 0.04), "at": Vector3(0, 0.04, 0), "vel": Vector2(0.05, 0.12), "spread": 40.0,
		"gravity": 0.05, "damp": 0.2, "scale": Vector2(0.03, 0.05), "ramp": [1.0, 1.0, 0.8, 0.0]})
	var reset := _clip(0.001)
	_track(reset, "Die:instance_shader_parameters/ash", [[0.0, 0.0]])
	_track(reset, "Die:instance_shader_parameters/dissolve", [[0.0, 0.0]])
	var back := _clip(0.5)
	_track(back, "Die:instance_shader_parameters/ash", [[0.0, 0.0], [0.12, 1.0], [0.4, 1.0], [0.5, 0.0]])
	_track(back, "Die:instance_shader_parameters/dissolve", [[0.0, 0.0]])
	_track(back, "Puff:emitting", [[0.0, true]])
	# Not a bust: only a Cracked die that shatters crumbles away (design section 6).
	var shatter := _clip(0.5)
	_track(shatter, "Die:instance_shader_parameters/ash", [[0.0, 0.0], [0.12, 1.0]])
	_track(shatter, "Die:instance_shader_parameters/dissolve", [[0.0, 0.0], [0.3, 0.0], [0.5, 1.0]])
	_track(shatter, "Puff:emitting", [[0.0, true]])
	_player(ash, {"RESET": reset, "bust": back, "cracked_shatter": shatter})
	_save(ash, V + "scenes/dice/ash_die_demo.tscn")


func _save_editable(root: Node, path: String) -> void:
	_own_all(root, root)
	var ps := PackedScene.new()
	assert(ps.pack(root) == OK)
	ResourceSaver.save(ps, path)
	root.free()


## Owns nodes added under instanced scenes too (only the ones we created: no owner yet).
func _own_all(n: Node, root: Node) -> void:
	for c in n.get_children():
		if c.owner == null:
			c.owner = root
		_own_all(c, root)


# --- props (art/models/props/bonfire) ---------------------------------------------------------
# Each prop scene: Root (Node3D, origin = bottom centre on the surface) -> Body (the animated node)
# -> Model (the glb). Shader parameters that clips drive are instance uniforms on the glb mesh.

func _prop_root(name: String, glb: String) -> Array:
	var root := Node3D.new()
	root.name = name
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	var model := (load(P + glb + ".glb") as PackedScene).instantiate() as Node3D
	model.name = "Model"
	body.add_child(model)
	return [root, body, model]


func _props() -> void:
	# Wax "CLAIMED" stamp: stamp-down clip.
	var r := _prop_root("WaxStamp", "wax_stamp")
	var root: Node3D = r[0]
	_particles(root, "Crumbs", "wax_crumb", 8, 0.35, Vector2(1, 1), {"one_shot": true, "expl": 1.0,
		"box": Vector3(0.025, 0.002, 0.025), "at": Vector3(0, 0.003, 0), "dir": Vector3(0, 1, 0), "spread": 80.0,
		"vel": Vector2(0.08, 0.18), "gravity": -2.0, "scale": Vector2(0.004, 0.007), "ramp": [1.0, 1.0, 1.0, 0.0]})
	var reset := _clip(0.001)
	_track(reset, "Body:position", [[0.0, Vector3.ZERO]])
	_track(reset, "Body:scale", [[0.0, Vector3.ONE]])
	_track(reset, "Body:rotation", [[0.0, Vector3.ZERO]])
	var stamp := _clip(0.25)
	_track(stamp, "Body:position", [[0.0, Vector3(0, 0.07, 0)], [0.1, Vector3.ZERO]])
	_track(stamp, "Body:scale", [[0.0, Vector3(1.3, 1.3, 1.3)], [0.1, Vector3(1.12, 1.12, 1.12)], [0.13, Vector3(1.18, 0.6, 1.18)], [0.25, Vector3.ONE]])
	_track(stamp, "Body:rotation", [[0.0, Vector3(0, -0.25, 0)], [0.1, Vector3.ZERO]])
	_track(stamp, "Crumbs:emitting", [[0.1, true]])
	_player(root, {"RESET": reset, "stamp": stamp})
	_save(root, P + "scenes/wax_stamp.tscn")
	# Crumble: the shard variant tumbles apart (bust: pending stamps crumble).
	r = _prop_root("WaxStampCrumble", "wax_stamp_shards")
	root = r[0]
	var model: Node3D = r[2]
	_particles(root, "Dust", "wax_crumb", 12, 0.4, Vector2(1, 1), {"one_shot": true, "expl": 0.8,
		"box": Vector3(0.025, 0.003, 0.025), "at": Vector3(0, 0.004, 0), "spread": 90.0,
		"vel": Vector2(0.05, 0.14), "gravity": -1.5, "scale": Vector2(0.003, 0.006), "ramp": [1.0, 1.0, 1.0, 0.0]})
	reset = _clip(0.001)
	var crumble := _clip(0.45)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for c in model.get_children():
		var s := c as Node3D
		var home := s.position
		var out := Vector3(home.x, 0, home.z).normalized()
		var path := "Body/Model/" + String(s.name)
		var spin := Vector3(rng.randf_range(-2.5, 2.5), rng.randf_range(-1.5, 1.5), rng.randf_range(-2.5, 2.5))
		var t0 := rng.randf_range(0.0, 0.08)
		_track(reset, path + ":position", [[0.0, home]])
		_track(reset, path + ":rotation", [[0.0, Vector3.ZERO]])
		_track(reset, path + ":scale", [[0.0, Vector3.ONE]])
		_track(crumble, path + ":position", [[0.0, home], [t0, home], [t0 + 0.12, home + out * 0.006 + Vector3(0, 0.006, 0)],
			[0.45, home + out * 0.02 + Vector3(0, -0.004, 0)]], true)
		_track(crumble, path + ":rotation", [[t0, Vector3.ZERO], [0.45, spin]])
		_track(crumble, path + ":scale", [[0.0, Vector3.ONE], [0.25, Vector3.ONE], [0.45, Vector3(0.01, 0.01, 0.01)]])
	_track(crumble, "Dust:emitting", [[0.02, true]])
	_player(root, {"RESET": reset, "crumble": crumble})
	_save(root, P + "scenes/wax_stamp_crumble.tscn")
	# Soul flask: intact / crack / drip. Instance uniforms on the flask mesh: crack (glass), fill (liquid).
	for cracked in [false, true]:
		r = _prop_root("SoulFlaskCracked" if cracked else "SoulFlask", "soul_flask")
		root = r[0]
		var mesh_path := "Body/Model/SoulFlask"
		_particles(root, "Drips", "soul_drip", 6, 0.6, Vector2(1, 1), {"box": Vector3(0.002, 0.002, 0.002),
			"at": Vector3(0.024, 0.026, 0.024), "dir": Vector3(0.3, -1, 0.3), "spread": 10.0, "vel": Vector2(0.01, 0.03),
			"gravity": -0.25, "scale": Vector2(0.006, 0.009), "ramp": [0.5, 1.0, 1.0, 0.0], "emitting": cracked})
		reset = _clip(0.001)
		_track(reset, mesh_path + ":instance_shader_parameters/crack", [[0.0, 1.0 if cracked else 0.0]])
		_track(reset, mesh_path + ":instance_shader_parameters/fill", [[0.0, 0.85 if cracked else 1.0]])
		_track(reset, "Body:position", [[0.0, Vector3.ZERO]])
		_track(reset, "Drips:emitting", [[0.0, cracked]])
		var crack := _clip(0.35)
		_track(crack, mesh_path + ":instance_shader_parameters/crack", [[0.0, 0.0], [0.05, 0.55], [0.15, 1.0]])
		_track(crack, "Body:position", [[0.0, Vector3.ZERO], [0.03, Vector3(0.004, 0, 0)], [0.06, Vector3(-0.004, 0, 0)],
			[0.09, Vector3(0.003, 0, 0)], [0.12, Vector3(-0.002, 0, 0)], [0.16, Vector3.ZERO]])
		_track(crack, "Drips:emitting", [[0.15, true]])
		var drip := _clip(1.0, true)
		_track(drip, mesh_path + ":instance_shader_parameters/crack", [[0.0, 1.0]])
		_track(drip, "Drips:emitting", [[0.0, true]])
		var clips := {"RESET": reset, "crack": crack, "drip": drip}
		_player(root, clips, "drip" if cracked else "")
		_save(root, P + "scenes/%s.tscn" % ("soul_flask_cracked" if cracked else "soul_flask"))
	# Ember-pile pickup: idle glow, collect (embers arrive), pickup (it goes to the pile).
	r = _prop_root("EmberPile", "ember_pile")
	root = r[0]
	var ep := "Body/Model/EmberPile:instance_shader_parameters/heat"
	_particles(root, "Sparks", "fire_spark", 6, 0.8, Vector2(1, 1), {"box": Vector3(0.02, 0.005, 0.02),
		"at": Vector3(0, 0.02, 0), "vel": Vector2(0.04, 0.1), "spread": 25.0, "gravity": 0.03,
		"scale": Vector2(0.006, 0.01), "ramp": [1.0, 1.0, 0.6, 0.0], "emitting": true})
	_particles(root, "Pop", "fire_spark", 10, 0.35, Vector2(1, 1), {"one_shot": true, "expl": 1.0,
		"box": Vector3(0.02, 0.01, 0.02), "at": Vector3(0, 0.02, 0), "vel": Vector2(0.2, 0.4), "spread": 60.0,
		"gravity": -0.8, "scale": Vector2(0.008, 0.013), "ramp": [1.0, 1.0, 0.5, 0.0]})
	reset = _clip(0.001)
	_track(reset, ep, [[0.0, 1.0]])
	_track(reset, "Body:position", [[0.0, Vector3.ZERO]])
	_track(reset, "Body:scale", [[0.0, Vector3.ONE]])
	var idle := _clip(1.2, true)
	_track(idle, ep, [[0.0, 0.9], [0.6, 1.15], [1.2, 0.9]], true)
	var collect := _clip(0.2)
	_track(collect, "Body:scale", [[0.0, Vector3.ONE], [0.06, Vector3(1.2, 1.25, 1.2)], [0.2, Vector3.ONE]])
	_track(collect, ep, [[0.0, 2.0], [0.2, 1.0]])
	_track(collect, "Pop:emitting", [[0.0, true]])
	var pick := _clip(0.35)
	_track(pick, "Body:position", [[0.0, Vector3.ZERO], [0.12, Vector3(0, 0.04, 0)], [0.35, Vector3(0, 0.06, 0)]], true)
	_track(pick, "Body:scale", [[0.0, Vector3.ONE], [0.12, Vector3(1.2, 1.2, 1.2)], [0.35, Vector3(0.01, 0.01, 0.01)]])
	_track(pick, ep, [[0.0, 1.0], [0.12, 2.0], [0.35, 0.0]])
	_track(pick, "Pop:emitting", [[0.0, true]])
	_track(pick, "Sparks:emitting", [[0.3, false]])
	_player(root, {"RESET": reset, "idle": idle, "collect": collect, "pickup": pick}, "idle")
	_save(root, P + "scenes/ember_pile.tscn")
	# Mult chip: slam in (thud + flare). NumberAnchor on the inlay for the "x2" label.
	r = _prop_root("MultChip", "mult_chip")
	root = r[0]
	var body: Node3D = r[1]
	var na := Marker3D.new()
	na.name = "NumberAnchor"
	na.transform = Transform3D(Basis(Vector3.RIGHT, Vector3(0, 0, -1), Vector3.UP), Vector3(0, 0.006, 0))
	body.add_child(na)
	var flare := _quad(root, "Flare", load(V + "materials/fire_ring.tres"), Vector2(0.13, 0.13), Vector3(0, 0.001, 0), true)
	flare.set_instance_shader_parameter("heat", 0.0)
	_particles(root, "Sparks", "fire_spark", 12, 0.35, Vector2(1, 1), {"one_shot": true, "expl": 1.0,
		"box": Vector3(0.024, 0.002, 0.024), "at": Vector3(0, 0.004, 0), "vel": Vector2(0.3, 0.6), "spread": 75.0,
		"gravity": -1.2, "scale": Vector2(0.01, 0.016), "ramp": [1.0, 1.0, 0.5, 0.0]})
	reset = _clip(0.001)
	_track(reset, "Body:position", [[0.0, Vector3.ZERO]])
	_track(reset, "Body:scale", [[0.0, Vector3.ONE]])
	_track(reset, "Flare:instance_shader_parameters/heat", [[0.0, 0.0]])
	var slam := _clip(0.3)
	_track(slam, "Body:position", [[0.0, Vector3(0, 0.22, 0)], [0.12, Vector3.ZERO]])
	_track(slam, "Body:scale", [[0.0, Vector3(0.85, 1.5, 0.85)], [0.12, Vector3(0.9, 1.3, 0.9)], [0.15, Vector3(1.3, 0.55, 1.3)], [0.21, Vector3(0.94, 1.1, 0.94)], [0.26, Vector3(1.03, 0.97, 1.03)], [0.3, Vector3.ONE]])
	_track(slam, "Flare:scale", [[0.12, Vector3(0.2, 1, 0.2)], [0.3, Vector3(1.6, 1, 1.6)]])
	_track(slam, "Flare:instance_shader_parameters/heat", [[0.0, 0.0], [0.12, 1.0], [0.3, 0.0]])
	_track(slam, "Sparks:emitting", [[0.12, true]])
	_player(root, {"RESET": reset, "slam": slam})
	_save(root, P + "scenes/mult_chip.tscn")
