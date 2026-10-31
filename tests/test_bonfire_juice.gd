## Headless test: the Bonfire scoring-juice art (design/bonfire_map_events_juice.md section 3) in
## art/vfx/bonfire and art/models/props/bonfire. Checks the 4 fire tiers (GPU + CPU fallback),
## the lit-face glow, the potted-dice lift, Hot Hand ignite and trail, the ash dice, the props
## (wax stamp + shards, Soul flask, ember pile, Mult chip) and the combo banner palette:
## clip lengths inside the score-sequence timing (normal <= 1.2 s, big <= 2.0 s), particle and
## triangle budgets, every animation track resolves, toon materials, Soul cyan only on Soul props,
## and art only (no scripts, lights or physics nodes).
##
## Run:
##   godot --headless --path . --script res://tests/test_bonfire_juice.gd
extends SceneTree

const V := "res://art/vfx/bonfire/"
const P := "res://art/models/props/bonfire/"
const NORMAL_MAX: float = 1.2
const BIG_MAX: float = 2.0
const TIERS := {
	1: ["fire_tier_1_embers", 0.8, 12], 2: ["fire_tier_2_flames", 1.0, 24],
	3: ["fire_tier_3_inferno", 1.2, 48], 4: ["fire_tier_4_pillar", 1.8, 64],  # tier 4: ONE pillar per group
}
const INSTANCE_PARAMS: Array[String] = ["heat", "glow", "ash", "dissolve", "crack", "fill"]
const PROP_TRIS := {"wax_stamp": 1500, "wax_stamp_shards": 1500, "soul_flask": 1500, "ember_pile": 1000, "mult_chip": 600}
const PROP_SLOTS := {
	"wax_stamp": ["wax", "wax_letter"], "wax_stamp_shards": ["wax", "wax_letter"],
	"soul_flask": ["soul_glass", "soul_liquid", "cork", "brass"], "ember_pile": ["coal", "ember_hot"],
	"mult_chip": ["mult_body", "mult_inlay"],
}
## Clips that are a big moment (<= 2.0 s); every other one-shot clip fits a normal sequence (<= 1.2 s).
const BIG_CLIPS: Array[String] = ["fire_tier_4_pillar:burst", "hot_hand_demo:hot_hand", "potted_dice_demo:pot_sequence_big"]

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	print("=== Dice of the Damned: Bonfire juice art tests ===")
	_test_fire_tiers()
	_test_dice()
	_test_props()
	_test_palette()
	_test_all_scenes()
	_test_soul_cyan()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# --- fire tiers --------------------------------------------------------------------------------

func _test_fire_tiers() -> void:
	var amounts := {}
	for n in TIERS:
		var info: Array = TIERS[n]
		for cpu in [false, true]:
			var path: String = V + "scenes/fire/%s%s.tscn" % ["cpu/" if cpu else "", info[0] + ("_cpu" if cpu else "")]
			var root := _load(path)
			if root == null:
				continue
			var tag: String = path.get_file()
			var ap := root.get_node_or_null("AnimationPlayer") as AnimationPlayer
			_check(ap != null and ap.has_animation("ignite") and ap.has_animation("snuff") and ap.has_animation("burst") and ap.has_animation("RESET"),
				tag + ": clips RESET / ignite / snuff / burst")
			if ap:
				_check(is_equal_approx(ap.get_animation("burst").length, info[1]), "%s: burst is %.1f s" % [tag, info[1]])
				_check(ap.get_animation("ignite").length <= 0.15 and ap.get_animation("snuff").length <= 0.25, tag + ": ignite <= 0.15 s, snuff <= 0.25 s")
			var total := 0
			var kinds_ok := true
			var mats_ok := true
			for e in _all(root):
				if e is GPUParticles3D or e is CPUParticles3D:
					kinds_ok = kinds_ok and (e is CPUParticles3D) == cpu
					total += e.amount
					var m: Material = (e.draw_pass_1 as Mesh).surface_get_material(0) if e is GPUParticles3D else (e.mesh as Mesh).surface_get_material(0)
					mats_ok = mats_ok and _is_toon_fire(m)
			_check(kinds_ok, tag + (": CPUParticles3D only (fallback)" if cpu else ": GPUParticles3D only"))
			_check(mats_ok, tag + ": every particle draws with toon_fire (alpha-cut, no blending overdraw)")
			_check(total <= info[2], "%s: %d particles <= %d" % [tag, total, info[2]])
			if cpu:
				_check(total == amounts[n], "%s: same particle counts as the GPU scene" % tag)
			amounts[n] = total
			root.free()
	_check(amounts[1] < amounts[2] and amounts[2] < amounts[3], "tiers escalate: embers < flames < inferno particles")
	var pillar := _load(V + "scenes/fire/fire_tier_4_pillar.tscn")
	if pillar:
		var col := pillar.get_node_or_null("ColumnPivot/Column") as MeshInstance3D
		_check(col != null and (col.mesh as CylinderMesh).height >= 0.5, "pillar: a fire column >= 0.5 m tall")
		_check(col != null and _is_toon_fire(col.material_override), "pillar: column uses toon_fire")
		_check(_tris(col.mesh) <= 64, "pillar: column <= 64 tris")
		var pivot := pillar.get_node_or_null("ColumnPivot") as Node3D
		_check(pivot != null and pivot.position.is_zero_approx(), "pillar: rises from the scene origin (the group centre on the felt)")
		_check(col != null and (col.mesh as CylinderMesh).bottom_radius >= 0.12, "pillar: one central column wide enough for the potted group (not per die)")
		var flames := pillar.get_node_or_null("Flames") as GPUParticles3D
		var box: Vector3 = (flames.process_material as ParticleProcessMaterial).emission_box_extents if flames else Vector3.ZERO
		_check(box.x >= 0.25, "pillar: flame bed spans the 5-dice group (half-width %.2f m)" % box.x)
		pillar.free()


func _is_toon_fire(m: Material) -> bool:
	if not m is ShaderMaterial:
		return false
	var sh := (m as ShaderMaterial).shader
	return sh.resource_path == V + "shaders/toon_fire.gdshader" and not sh.code.contains("blend_add") and sh.code.contains("discard")


# --- dice --------------------------------------------------------------------------------------

func _test_dice() -> void:
	var glow := load(V + "materials/lit_face_glow.tres") as ShaderMaterial
	_check(glow != null and _declares(glow.shader, "glow"), "lit-face glow: instance uniform glow")
	if glow:
		_check(_param(glow, "face_dir") == Vector3.UP, "lit-face glow: lights the +Y (rolled) face in world space")
		_check(is_equal_approx(_param(glow, "half_size"), 0.04), "lit-face glow: half_size 0.04 = bone_d6 / DieVisual edge 0.08 / 2")
	var rig := _load(V + "scenes/dice/potted_die_rig.tscn")
	if rig:
		_check(rig.get_node_or_null("Lift/DieSlot") != null, "potted rig: Lift/DieSlot for the die")
		var f := rig.get_node_or_null("Lift/Follow") as RemoteTransform3D
		_check(f != null and not f.update_rotation, "potted rig: Lift/Follow RemoteTransform3D keeps the die's rotation")
		var face := rig.get_node_or_null("Lift/LitFace") as Node3D
		_check(face != null and absf(face.position.y - 0.0406) < 0.0005, "potted rig: LitFace just above the 0.08 die's top face")
		var ap := rig.get_node("AnimationPlayer") as AnimationPlayer
		_check(ap.has_animation("lift_light") and ap.get_animation("lift_light").length <= 0.3, "potted rig: lift_light <= 0.3 s")
		rig.free()
	var demo := _load(V + "scenes/dice/potted_dice_demo.tscn")
	if demo:
		var ap := demo.get_node("AnimationPlayer") as AnimationPlayer
		_check(ap.get_animation("pot_sequence_normal").length <= NORMAL_MAX * 0.5, "5 dice lift (normal pacing) in <= half the 1.2 s sequence")
		_check(ap.get_animation("pot_sequence_big").length <= BIG_MAX * 0.5, "5 dice lift (big pacing) in <= half the 2.0 s sequence")
		demo.free()
	var trail := _load(V + "scenes/dice/fire_trail.tscn")
	if trail:
		var blobs := trail.get_node_or_null("Blobs") as GPUParticles3D
		_check(blobs != null and not blobs.local_coords, "fire trail: world-space particles (they trail behind a moving die)")
		trail.free()
	for m in ["ash_body", "ash_pip", "ash_outline"]:
		var mat := load(V + "materials/%s.tres" % m) as ShaderMaterial
		_check(mat != null and _declares(mat.shader, "ash") and _declares(mat.shader, "dissolve"), m + ": ash + dissolve instance uniforms")
	var body := load(V + "materials/ash_body.tres") as ShaderMaterial
	_check(_param(body, "base_color").is_equal_approx(Color("#E8DCC0")), "ash_body: starts as Bone (ash = 0 matches the bone die)")
	var ash_c: Color = _param(body, "ash_color")
	_check(ash_c.s < 0.12, "ash_body: ash is grey (saturation %.2f)" % ash_c.s)
	_check(body.next_pass != null and (body.next_pass as ShaderMaterial).shader.resource_path.ends_with("ash_outline.gdshader"), "ash_body: ink hull that crumbles with it")
	var ash := _load(V + "scenes/dice/ash_die_demo.tscn")
	if ash:
		var ap := ash.get_node("AnimationPlayer") as AnimationPlayer
		for c in ["bust", "cracked_shatter"]:
			_check(ap.has_animation(c) and is_equal_approx(ap.get_animation(c).length, 0.5), "ash demo: %s is 0.5 s" % c)
		if ap.has_animation("bust"):
			var b := ap.get_animation("bust")
			var at := b.find_track(NodePath("Die:instance_shader_parameters/ash"), Animation.TYPE_VALUE)
			var dt := b.find_track(NodePath("Die:instance_shader_parameters/dissolve"), Animation.TYPE_VALUE)
			var peak := 0.0
			for k in b.track_get_key_count(at):
				peak = maxf(peak, b.track_get_key_value(at, k))
			_check(peak >= 1.0 and is_zero_approx(b.value_track_interpolate(at, b.length)), "ash demo: bust goes ash 0 -> 1 -> 0 (returns to bone)")
			_check(dt >= 0 and is_zero_approx(b.value_track_interpolate(dt, b.length)), "ash demo: bust never dissolves the die")
		if ap.has_animation("cracked_shatter"):
			var c := ap.get_animation("cracked_shatter")
			var dt := c.find_track(NodePath("Die:instance_shader_parameters/dissolve"), Animation.TYPE_VALUE)
			_check(dt >= 0 and is_equal_approx(c.value_track_interpolate(dt, c.length), 1.0), "ash demo: cracked_shatter dissolves the die away")
		ash.free()


# --- props -------------------------------------------------------------------------------------

func _test_props() -> void:
	for name in PROP_TRIS:
		var root := _load(P + name + ".glb")
		if root == null:
			continue
		var tris := 0
		var ok_mats := true
		var aabb := AABB()
		var first := true
		for mi in _all(root):
			if not mi is MeshInstance3D:
				continue
			var m := mi as MeshInstance3D
			tris += _tris(m.mesh)
			var box: AABB = m.transform * m.mesh.get_aabb()
			aabb = box if first else aabb.merge(box)
			first = false
			for s in m.mesh.get_surface_count():
				var mat := m.get_active_material(s)
				var slot: String = m.mesh.surface_get_name(s)
				ok_mats = ok_mats and PROP_SLOTS[name].has(slot) and mat != null and mat.resource_path == P + "materials/%s.tres" % slot
				ok_mats = ok_mats and mat is ShaderMaterial and ((mat as ShaderMaterial).shader.resource_path == "res://shaders/3d/toon_noir.gdshader"
					or (mat as ShaderMaterial).shader.resource_path.begins_with(V + "shaders/"))
		_check(tris <= PROP_TRIS[name], "%s.glb: %d tris <= %d" % [name, tris, PROP_TRIS[name]])
		_check(ok_mats, name + ".glb: every slot maps to materials/<slot>.tres (toon)")
		_check(absf(aabb.position.y) < 0.0005, name + ".glb: rests on y = 0 (origin = bottom centre)")
		match name:
			"wax_stamp":
				_check(aabb.size.x > 0.05 and aabb.size.x < 0.066 and aabb.size.y < 0.008, "wax stamp: ~0.056 m seal, < 8 mm thick")
			"wax_stamp_shards":
				_check(root.get_child_count() == 7, "wax stamp shards: 7 shards")
				var centred := true
				for c in root.get_children():
					centred = centred and (c as Node3D).position.length() > 0.005
				_check(centred, "wax stamp shards: each shard's origin at its own centre (tumbles in place)")
			"soul_flask":
				_check(aabb.size.y <= 0.1, "soul flask: <= 0.10 m tall (%.3f)" % aabb.size.y)
			"mult_chip":
				_check(absf(aabb.size.x - 0.055) < 0.001 and absf(aabb.size.y - 0.006) < 0.0005, "mult chip: 0.055 x 0.006 m (in-game chip size)")
			"ember_pile":
				_check(aabb.size.x < 0.07 and aabb.size.y < 0.04, "ember pile: fits a 0.07 m footprint")
		root.free()
	var clips := {"wax_stamp": ["stamp", 0.3], "wax_stamp_crumble": ["crumble", 0.5], "soul_flask": ["crack", 0.4],
		"ember_pile": ["collect", 0.25], "mult_chip": ["slam", 0.35]}
	for s in clips:
		var root := _load(P + "scenes/%s.tscn" % s)
		if root == null:
			continue
		var ap := root.get_node("AnimationPlayer") as AnimationPlayer
		_check(ap.has_animation(clips[s][0]) and ap.get_animation(clips[s][0]).length <= clips[s][1],
			"%s: %s <= %.2f s" % [s, clips[s][0], clips[s][1]])
		if s == "mult_chip":
			var na := root.get_node_or_null("Body/NumberAnchor") as Node3D
			_check(na != null and na.basis.z.is_equal_approx(Vector3.UP) and na.position.y >= 0.0055 and na.position.y <= 0.0065, "mult chip: NumberAnchor on the top, facing up")
		root.free()
	var cracked := _load(P + "scenes/soul_flask_cracked.tscn")
	if cracked:
		_check((cracked.get_node("AnimationPlayer") as AnimationPlayer).autoplay == "drip", "cracked flask: autoplays the cracked + drip state")
		cracked.free()


# --- palette -----------------------------------------------------------------------------------

func _test_palette() -> void:
	var tiers := load(V + "palette/combo_banner_tiers.tres") as ColorPalette
	_check(tiers != null and tiers.colors.size() == 4, "combo banners: 4 rarity tiers")
	if tiers:
		var want := [Palette.BONE, Palette.EMBER, Color("#C8281E"), Palette.PIT_BLACK]
		var ok := true
		for i in 4:
			ok = ok and tiers.colors[i].is_equal_approx(want[i])
		_check(ok, "combo banners: bone #E8DCC0, ember #E8622A (style guide), hellfire #C8281E, black-gold = Pit Black #0E1414")
	var detail := load(V + "palette/combo_banner_detail.tres") as ColorPalette
	_check(detail != null and detail.colors.size() == 16, "combo banner detail: face / shade / ink / glow per tier")
	if detail:
		_check(detail.colors[14].is_equal_approx(Color("#E2C06A")) and detail.colors[13].is_equal_approx(Palette.BRASS), "black-gold: brass #B08D3C / #E2C06A trim")
		_check(not detail.colors.has(Palette.DANGER), "banners never use DANGER red (loss only)")


# --- every scene -------------------------------------------------------------------------------

func _test_all_scenes() -> void:
	var count := 0
	for dir in [V + "scenes/fire/", V + "scenes/fire/cpu/", V + "scenes/dice/", P + "scenes/"]:
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".tscn"):
				continue
			var root := _load(dir + f)
			if root == null:
				continue
			count += 1
			var clean := true
			for n in _all(root):
				if n is Light3D or n is CollisionObject3D or n is CollisionShape3D or n is WorldEnvironment or n.get_script() != null:
					clean = false
			_check(clean, f + ": art only (no scripts, lights or physics)")
			var ap := root.get_node_or_null("AnimationPlayer") as AnimationPlayer
			if ap:
				var bad := _bad_tracks(root, ap)
				_check(bad == "", f + ": every animation track resolves " + bad)
				var over := _scale_overshoot(ap)
				_check(over == "", f + ": scale tracks never flip or overshoot their keys " + over)
				for a in ap.get_animation_list():
					var anim := ap.get_animation(a)
					if a == "RESET" or anim.loop_mode != Animation.LOOP_NONE:
						continue
					var key: String = f.get_basename().replace("_cpu", "") + ":" + a
					var limit := BIG_MAX if BIG_CLIPS.has(key) else NORMAL_MAX
					_check(anim.length <= limit, "%s: %.2f s <= %.1f s" % [key, anim.length, limit])
			root.free()
	_check(count >= 20, "%d juice scenes load" % count)


func _bad_tracks(root: Node, ap: AnimationPlayer) -> String:
	for a in ap.get_animation_list():
		var anim := ap.get_animation(a)
		for t in anim.get_track_count():
			var np := anim.track_get_path(t)
			var node := root.get_node_or_null(NodePath(String(np).split(":")[0]))
			if node == null:
				return "(%s: %s missing)" % [a, np]
			if anim.track_get_type(t) == Animation.TYPE_ANIMATION:
				for k in anim.track_get_key_count(t):
					if not (node as AnimationPlayer).has_animation(anim.animation_track_get_key_animation(t, k)):
						return "(%s: %s has no clip)" % [a, np]
				continue
			var prop := String(np.get_concatenated_subnames())
			if prop.begins_with("instance_shader_parameters/"):
				var pname := prop.get_slice("/", 1)
				if not INSTANCE_PARAMS.has(pname) or not _instance_declared(node, pname):
					return "(%s: %s not declared)" % [a, np]
			elif node.get_indexed(NodePath(prop)) == null:
				return "(%s: %s no property)" % [a, np]
	return ""


## Cubic value tracks overshoot between unevenly spaced keys (a squash can flip the mesh inside
## out). Sample every Vector3 scale track at 240 Hz: each axis stays > 0 and within 10% of its keys.
func _scale_overshoot(ap: AnimationPlayer) -> String:
	for a in ap.get_animation_list():
		var anim := ap.get_animation(a)
		for t in anim.get_track_count():
			if anim.track_get_type(t) != Animation.TYPE_VALUE or not String(anim.track_get_path(t)).ends_with(":scale"):
				continue
			var lo := Vector3(INF, INF, INF)
			var hi := -lo
			for k in anim.track_get_key_count(t):
				var v: Vector3 = anim.track_get_key_value(t, k)
				lo = lo.min(v)
				hi = hi.max(v)
			var steps := int(ceil(anim.length * 240.0))
			for i in steps + 1:
				var v: Vector3 = anim.value_track_interpolate(t, anim.length * i / maxf(steps, 1))
				for ax in 3:
					if v[ax] <= 0.0 or v[ax] > hi[ax] * 1.1 + 0.001 or v[ax] < lo[ax] * 0.9 - 0.001:
						return "(%s: %s = %s)" % [a, anim.track_get_path(t), v]
	return ""


func _instance_declared(node: Node, pname: String) -> bool:
	var mats: Array[Material] = []
	if node is GPUParticles3D:
		mats.append((node.draw_pass_1 as Mesh).surface_get_material(0))
	elif node is CPUParticles3D:
		mats.append((node.mesh as Mesh).surface_get_material(0))
	elif node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.material_override:
			mats.append(mi.material_override)
		for s in mi.mesh.get_surface_count():
			mats.append(mi.get_active_material(s))
	for m in mats:
		if m is ShaderMaterial and _declares((m as ShaderMaterial).shader, pname):
			return true
	return false


# --- Soul cyan is the player's colour: only the Soul flask / drips may use it ------------------

func _test_soul_cyan() -> void:
	var offenders: Array[String] = []
	for dir in [V + "materials/", P + "materials/", V + "palette/"]:
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".tres") or f.begins_with("soul_"):
				continue
			var mat := load(dir + f)
			if mat is ShaderMaterial:
				for u in (mat as ShaderMaterial).shader.get_shader_uniform_list():
					var v = mat.get_shader_parameter(u.name)
					if v is Color and _is_soul(v):
						offenders.append(f + ":" + u.name)
			elif mat is ColorPalette:
				for c in (mat as ColorPalette).colors:
					if _is_soul(c):
						offenders.append(f)
	_check(offenders.is_empty(), "Soul cyan only on soul_* materials %s" % [offenders])


func _is_soul(c: Color) -> bool:
	return c.h > 0.45 and c.h < 0.53 and c.s > 0.4 and c.v > 0.4


# --- helpers -----------------------------------------------------------------------------------

func _load(path: String) -> Node:
	var ps := load(path) as PackedScene
	_check(ps != null, "loads " + path.get_file())
	return ps.instantiate() if ps else null


func _all(n: Node) -> Array[Node]:
	var out: Array[Node] = [n]
	for c in n.get_children():
		out.append_array(_all(c))
	return out


func _tris(m: Mesh) -> int:
	var t := 0
	for s in m.get_surface_count():
		var arr := m.surface_get_arrays(s)
		var idx = arr[Mesh.ARRAY_INDEX]
		t += (idx.size() if idx != null and idx.size() > 0 else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return t


func _declares(sh: Shader, pname: String) -> bool:
	var code := sh.code
	if code.contains("bonfire_instance.gdshaderinc"):
		code += FileAccess.get_file_as_string(V + "shaders/bonfire_instance.gdshaderinc")
	return code.contains("instance uniform float " + pname + " ")


func _param(m: ShaderMaterial, pname: String) -> Variant:
	var v = m.get_shader_parameter(pname)
	if v == null:
		v = RenderingServer.shader_get_parameter_default(m.shader.get_rid(), pname)
	return v


func _check(cond: bool, name: String) -> void:
	if cond:
		_passed += 1
		print("  ok   ", name)
	else:
		_failed += 1
		print("  FAIL ", name)
