extends SceneTree
## Shared headless test body for the boss dealers templated on the Pit Boss (tests/test_pit_boss.gd is the
## reference and keeps its own copy). A per-boss test extends this file and fills the config in _setup():
## the Smiles rig + clip contract, tri budgets, toon-noir + ink on every surface in the AD dealer palette with the
## two ambient conditions, HeadTrack + HeadAnchor, accents in their own slots, the hand prop on the chip bone
## (palmed in cheat), swap slots, brazier gap + felt in both game cams every dealer-clip frame, prop clip guard.
## Per-boss extras go in _extra(). Shared low-level checks: tests/support/boss_dealer_checks.gd.

const BD := preload("res://tests/support/boss_dealer_checks.gd")
const SMILES := preload("res://tests/test_smiles.gd")  # rig contract: BONES / PARENTS / LOOPS / REACTIONS
const DEALER_CLIPS: Array[String] = ["idle", "taunt", "grudging", "cheat", "deal"]

var title := ""
var boss := ""          # folder + file stem, e.g. "shuffle"
var parts: Array[String] = []
var slots: Array[String] = []
var no_ink: Array[String] = []
var accents: Array[String] = []
var prop := ""          # hand-prop part on the chip bone
var prop_slots: Array[String] = []
var swap_bone := {}     # part -> the only bone it may ride
var extra_bones := {}   # bone -> parent, beyond the Smiles rig (Ashmouth's firebox_door)
var prop_clip_max := 160
var scripted_ok: Array[String] = []  # node names allowed to carry a script (FX listeners)
var t: BD


func _setup() -> void:
	pass


func _extra(_s: Node3D, _skel: Skeleton3D, _ap: AnimationPlayer, _meshes: Dictionary, _label: String) -> void:
	pass


func dir() -> String:
	return "res://art/models/characters/bosses/%s/" % boss


func _initialize() -> void:
	_setup()
	print("=== Dice of the Damned: %s dealer tests ===" % title)
	t = BD.new(self)
	_run.call_deferred()


func _run() -> void:
	_materials()
	for lod in ["", "_mobile"]:
		await _check(lod)
	t.finish()


func _materials() -> void:
	for s in slots:
		var m := load(dir() + "materials/" + s + ".tres") as Material
		t.ok(m != null, "material %s.tres exists" % s)
		if m:
			t.check_material(m, s, not s in no_ink)
	# self-check: an ambient pushed past the lit value / glow threshold must be caught by the same maths
	var hot := ShaderMaterial.new()
	hot.shader = load(BD.TOON)
	hot.set_shader_parameter("albedo", Color(0.3, 0.3, 0.3))
	hot.set_shader_parameter("shadow_color", Color(1, 1, 1))
	hot.set_shader_parameter("ambient_color", Color(1, 1, 1))
	hot.set_shader_parameter("ambient_energy", 1.0)
	var amb := BD.ambient_term(hot)
	t.ok(amb.x > Color(0.3, 0.3, 0.3).srgb_to_linear().r and amb.x >= BD.GLOW_THRESHOLD, "ambient rule catches an over-bright ambient (%.2f)" % amb.x)


func _check(lod: String) -> void:
	var path := dir() + "scenes/%s%s.tscn" % [boss, lod]
	var label := path.get_file()
	var ps := load(path) as PackedScene
	t.ok(ps != null, label + ": loads")
	if ps == null:
		return
	var s := ps.instantiate() as Node3D
	root.add_child(s)
	await process_frame
	var skel := s.find_child("Skeleton3D", true, false) as Skeleton3D
	var ap := s.find_child("AnimationPlayer", true, false) as AnimationPlayer
	t.ok(skel != null and ap != null, label + ": Skeleton3D + AnimationPlayer")
	if skel == null or ap == null:
		return
	var missing: Array[String] = []
	for b in SMILES.BONES:
		if skel.find_bone(b) < 0:
			missing.append(b)
	t.ok(missing.is_empty(), "%s: all %d Smiles rig bones present %s" % [label, SMILES.BONES.size(), missing])
	var bad_par: Array[String] = []
	var pars: Dictionary = SMILES.PARENTS.merged(extra_bones)
	for b: String in pars:
		var i := skel.find_bone(b)
		if i < 0 or skel.get_bone_parent(i) != skel.find_bone(pars[b]):
			bad_par.append(b)
	t.ok(bad_par.is_empty(), "%s: bone hierarchy matches Smiles (+%s) %s" % [label, extra_bones.keys(), bad_par])
	t.ok(skel.get_bone_count() == SMILES.BONES.size() + extra_bones.size(), "%s: no stray bones (%d)" % [label, skel.get_bone_count()])
	t.ok(ap.autoplay == "idle", label + ": autoplays idle")
	for c in SMILES.LOOPS + SMILES.REACTIONS:
		var a := ap.get_animation(c)
		t.ok(a != null, "%s: clip %s" % [label, c])
		if a == null:
			continue
		if c in SMILES.LOOPS:
			t.ok(a.loop_mode == Animation.LOOP_LINEAR and a.length >= 1.999 and a.length <= 4.001, "%s: %s loops, 2-4 s (%.2f)" % [label, c, a.length])
			t.ok(_pose(skel, ap, c, 0.0) == _pose(skel, ap, c, a.length), "%s: %s wraps without a pop" % [label, c])
		else:
			t.ok(a.loop_mode == Animation.LOOP_NONE and a.length >= 0.799 and a.length <= 1.601, "%s: %s one-shot, 0.8-1.6 s (%.2f)" % [label, c, a.length])
		var head := false
		for ti in a.get_track_count():
			head = head or str(a.track_get_path(ti)).ends_with(":head")
		t.ok(head, "%s: %s animates the head" % [label, c])
	var tris := 0
	var meshes := {}
	var unshaded: Array[String] = []
	var used := {}
	for mi: MeshInstance3D in s.find_children("*", "MeshInstance3D", true, false):
		meshes[str(mi.name)] = mi
		for si in mi.mesh.get_surface_count():
			tris += (mi.mesh.surface_get_arrays(si)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
			var m := mi.get_active_material(si) as ShaderMaterial
			var nm := m.resource_path.get_file().get_basename() if m else "?"
			used[nm] = true
			if m == null or not m.resource_path.begins_with(dir() + "materials/") or (m.next_pass == null) != (nm in no_ink):
				unshaded.append("%s/%d %s" % [mi.name, si, nm])
	for p in parts:
		t.ok(meshes.has(p), "%s: separate part %s" % [label, p])
	t.ok(unshaded.is_empty(), "%s: every surface uses the external toon .tres (+ ink unless embedded detail) %s" % [label, unshaded])
	var unused := slots.filter(func(x: String) -> bool: return not used.has(x))
	t.ok(unused.is_empty(), "%s: every slot is on a surface %s" % [label, unused])
	if lod == "":  # budget is a ceiling (the blockout dealers sit at 3-6k; the Pit Boss reference spends ~7k)
		t.ok(tris > 3000 and tris <= 8000, "%s: PC tris 3k-8k (%d)" % [label, tris])
	else:
		t.ok(tris <= 3600, "%s: mobile tris <= ~3.5k (%d)" % [label, tris])
	t.ok(s.find_children("*", "Light3D", true, false).is_empty(), label + ": no lights (art only)")
	var scripted := s.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n.get_script() != null and not str(n.name) in scripted_ok)
	t.ok(scripted.is_empty() and s.get_script() == null, label + ": no scripts (beyond FX listeners %s)" % [scripted_ok])
	var look := s.find_child("HeadTrack", true, false) as LookAtModifier3D
	t.ok(look != null and look.get_parent() == skel and look.bone_name == "head" and look.influence == 0.0 and look.use_angle_limitation,
		label + ": HeadTrack LookAtModifier3D on head (limited, influence 0 until driven)")
	var anc := s.find_child("HeadAnchor", true, false) as BoneAttachment3D
	t.ok(anc != null and anc.get_parent() == skel and anc.bone_name == "head", label + ": HeadAnchor BoneAttachment3D on head")
	# --- hand prop: own part on the chip bone, own materials, palmed in cheat
	if meshes.has(prop):
		var pm: MeshInstance3D = meshes[prop]
		var ms: Array[String] = []
		for si in pm.mesh.get_surface_count():
			ms.append(pm.get_active_material(si).resource_path.get_file().get_basename())
		ms.sort()
		var want := prop_slots.duplicate()
		want.sort()
		t.ok(ms == want, "%s: %s materials %s" % [label, prop, ms])
		t.ok(_binds(pm, skel) == ["chip"], "%s: %s skinned only to the chip bone %s" % [label, prop, _binds(pm, skel)])
	var chip := skel.find_bone("chip")
	ap.play("cheat")
	ap.seek(0.7, true)
	var palmed := skel.get_bone_pose_scale(chip).x
	ap.seek(1.2, true)
	t.ok(palmed < 0.05 and skel.get_bone_pose_scale(chip).x > 0.95, "%s: cheat palms the %s (scale %.2f @0.7, back by 1.2)" % [label, prop, palmed])
	for p: String in swap_bone:
		if meshes.has(p):
			t.ok(_binds(meshes[p], skel) == [swap_bone[p]], "%s: %s rides only the %s bone (swap slot) %s" % [label, p, swap_bone[p], _binds(meshes[p], skel)])
	for a in accents:
		var m := load(dir() + "materials/" + a + ".tres") as ShaderMaterial
		var users := 0
		for k in meshes:
			var mi: MeshInstance3D = meshes[k]
			for si in mi.mesh.get_surface_count():
				if mi.get_active_material(si) == m:
					users += 1
		t.ok(users > 0, "%s: accent %s is its own slot (%d surfaces)" % [label, a, users])
	await _extra(s, skel, ap, meshes, label)
	# --- framing: brazier gap + felt in both game cams, every dealer-clip frame
	s.position = BD.DEALER_POS
	var cams := {"pc": t.game_cam("pc"), "phone": t.game_cam("phone")}
	await process_frame
	var polys := {"pc": t.brazier_poly(cams["pc"]), "phone": t.brazier_poly(cams["phone"])}
	var gap := {"pc": INF, "phone": INF}
	var felt := {"pc": 0.0, "phone": 0.0}
	for c in DEALER_CLIPS:
		var a := ap.get_animation(c)
		var tt := 0.0
		while tt <= a.length + 0.001:
			ap.play(c)
			ap.seek(tt, true)
			var pts := t.skinned(s, skel)
			for k in cams:
				gap[k] = minf(gap[k], t.brazier_px(cams[k], polys[k], pts))
				felt[k] = maxf(felt[k], t.felt_cover(cams[k], pts))
			tt += 0.1
	for k in cams:
		t.ok(gap[k] >= BD.BRAZIER_CLEAR_PX, "%s: >= %d px clear of the brazier, %s cam, every clip (min %.1f px)" % [label, BD.BRAZIER_CLEAR_PX, k, gap[k]])
		t.ok(felt[k] <= BD.FELT_COVER_MAX, "%s: felt left clear, %s cam (worst %.0f%% of the felt grid under the dealer)" % [label, k, felt[k] * 100.0])
	s.position = Vector3(0, 0.0, 0.3)
	ap.play("idle")
	ap.seek(0.0, true)
	t.ok(t.felt_cover(cams["pc"], t.skinned(s, skel)) > 0.1, label + ": felt proxy catches a dealer moved onto the felt")
	s.position = BD.DEALER_POS
	var pc := t.prop_clip_frames(s, skel, ap, SMILES.LOOPS + SMILES.REACTIONS)
	print("  info %s tris %d, gap pc %.1f / phone %.1f px, felt cover pc %.1f%% / phone %.1f%%, prop clip %d" % [label, tris, gap["pc"], gap["phone"], felt["pc"] * 100.0, felt["phone"] * 100.0, pc])
	t.ok(pc <= prop_clip_max, "%s: prop-in-hand clip frames <= %d (%d)" % [label, prop_clip_max, pc])
	s.queue_free()
	await process_frame


func _pose(skel: Skeleton3D, ap: AnimationPlayer, c: String, at: float) -> String:
	ap.play(c)
	ap.seek(at, true)
	var out := ""
	for i in skel.get_bone_count():
		out += "%.2f%.2f%.2f%.2f" % _q(skel.get_bone_pose_rotation(i)) + str(skel.get_bone_pose_position(i).snapped(Vector3.ONE * 0.001))
	return out


func _binds(mi: MeshInstance3D, skel: Skeleton3D) -> Array:
	# bones that actually carry weight on this mesh
	var used := {}
	for si in mi.mesh.get_surface_count():
		var arr := mi.mesh.surface_get_arrays(si)
		var bs: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var ws: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		for i in bs.size():
			if ws[i] > 0.01:
				var b := mi.skin.get_bind_name(bs[i])
				used[str(b) if b != "" else skel.get_bone_name(mi.skin.get_bind_bone(bs[i]))] = true
	return used.keys()


func _surf(mi: MeshInstance3D, slot: String) -> int:
	for si in mi.mesh.get_surface_count():
		if mi.get_active_material(si).resource_path.get_file().get_basename() == slot:
			return si
	return 0


func _q(q: Quaternion) -> Array:
	if q.w < 0.0:
		q = -q
	return [q.x, q.y, q.z, q.w]
