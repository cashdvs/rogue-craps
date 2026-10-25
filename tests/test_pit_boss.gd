## Headless test: the Pit Boss (art/models/characters/bosses/pit_boss), reference boss dealer for the other five.
## Modelled on tests/test_smiles.gd: the Smiles rig + clip contract (bones, hierarchy, clip lengths, loops),
## tri budgets, toon-noir + ink on every surface in the AD dealer palette (brass / bone / greys / pewter only,
## no red / cyan / violet, no emission), HeadTrack + HeadAnchor, brazier gap in both game cams every clip
## frame, felt left clear, the flip-plaque prop ("4" front / "2" back on the chip bone, palmed in cheat) and the
## swap-friendly part split. Shared checks: tests/support/boss_dealer_checks.gd.
##
## Run:
##   godot --headless --path . --script res://tests/test_pit_boss.gd
extends SceneTree

const BD := preload("res://tests/support/boss_dealer_checks.gd")
const SMILES := preload("res://tests/test_smiles.gd")  # rig contract: BONES / PARENTS / LOOPS / REACTIONS
const S := "res://art/models/characters/bosses/pit_boss/scenes/"
const M := "res://art/models/characters/bosses/pit_boss/materials/"
const PARTS: Array[String] = ["PitBoss_Body", "PitBoss_Head", "PitBoss_Cap", "PitBoss_Plaque"]
const SLOTS: Array[String] = ["pitboss_skin", "pitboss_shirt", "pitboss_vest", "pitboss_black", "pitboss_brass",
	"pitboss_bone", "pitboss_cap", "pitboss_eye", "pitboss_cigar", "pitboss_ash"]
const NO_INK: Array[String] = ["pitboss_eye"]
## Accent slots that must stay their own material (AD: accents in separate slots so a palette pass is one file).
const ACCENTS: Array[String] = ["pitboss_brass", "pitboss_bone"]
const PLAQUE_SLOTS: Array[String] = ["pitboss_brass", "pitboss_black", "pitboss_bone"]
const SWAP_BONE := {"PitBoss_Cap": "visor", "PitBoss_Plaque": "chip"}
## Clips played at the dealer spot (mc_* play at the MC spot, framed by test_smiles.gd).
const DEALER_CLIPS: Array[String] = ["idle", "taunt", "grudging", "cheat", "deal"]
## Regression guard on the coarse in-engine prop check (nearest-triangle, 30 mm band, 0.05 s, all 7 clips): 150
## frames at v2b, from the shared Smiles hand sweeps (README Known issues; the per-shell Blender check reads 35).
const PROP_CLIP_MAX := 160

var t: BD


func _initialize() -> void:
	print("=== Dice of the Damned: Pit Boss dealer tests ===")
	t = BD.new(self)
	_run.call_deferred()


func _run() -> void:
	_materials()
	for lod in ["", "_mobile"]:
		await _check(lod)
	t.finish()


func _materials() -> void:
	for s in SLOTS:
		var m := load(M + s + ".tres") as Material
		t.ok(m != null, "material %s.tres exists" % s)
		if m:
			t.check_material(m, s, not s in NO_INK)
	# the palette rule itself must reject the colours the AD banned
	for c in [Color("#6A1A22"), Color("#2A0A10"), Color("#4FE6E0"), Color("#7A3FB0")]:
		t.ok(BD.palette_fail(c) != "", "palette rule rejects %s" % c.to_html(false))
	for c in [Color("#B08D3C"), Color("#E8DCC0"), Color("#8A8D8F"), Color("#0E1414")]:
		t.ok(BD.palette_fail(c) == "", "palette rule accepts %s" % c.to_html(false))


func _check(lod: String) -> void:
	var path := S + "pit_boss%s.tscn" % lod
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
	# --- bones
	var missing: Array[String] = []
	for b in SMILES.BONES:
		if skel.find_bone(b) < 0:
			missing.append(b)
	t.ok(missing.is_empty(), "%s: all %d Smiles rig bones present %s" % [label, SMILES.BONES.size(), missing])
	var bad_par: Array[String] = []
	for b: String in SMILES.PARENTS:
		var i := skel.find_bone(b)
		if i < 0 or skel.get_bone_parent(i) != skel.find_bone(SMILES.PARENTS[b]):
			bad_par.append(b)
	t.ok(bad_par.is_empty(), "%s: bone hierarchy matches Smiles %s" % [label, bad_par])
	# --- clips
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
	# --- parts, budgets, materials on the meshes
	var tris := 0
	var meshes := {}
	var unshaded: Array[String] = []
	for mi: MeshInstance3D in s.find_children("*", "MeshInstance3D", true, false):
		meshes[str(mi.name)] = mi
		for si in mi.mesh.get_surface_count():
			tris += (mi.mesh.surface_get_arrays(si)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
			var m := mi.get_active_material(si) as ShaderMaterial
			var nm := m.resource_path.get_file().get_basename() if m else "?"
			if m == null or not m.resource_path.begins_with(M) or (m.next_pass == null) != (nm in NO_INK):
				unshaded.append("%s/%d %s" % [mi.name, si, nm])
	for p in PARTS:
		t.ok(meshes.has(p), "%s: separate part %s" % [label, p])
	t.ok(unshaded.is_empty(), "%s: every surface uses the external toon .tres (+ ink unless eye) %s" % [label, unshaded])
	if lod == "":
		t.ok(tris >= 5000 and tris <= 8000, "%s: PC tris within ~6-8k (%d)" % [label, tris])
	else:
		t.ok(tris <= 3600, "%s: mobile tris <= ~3.5k (%d)" % [label, tris])
	t.ok(s.find_children("*", "Light3D", true, false).is_empty(), label + ": no lights (art only)")
	var scripted := s.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n.get_script() != null)
	t.ok(scripted.is_empty() and s.get_script() == null, label + ": no scripts")
	# --- hooks
	var look := s.find_child("HeadTrack", true, false) as LookAtModifier3D
	t.ok(look != null and look.get_parent() == skel and look.bone_name == "head" and look.influence == 0.0 and look.use_angle_limitation,
		label + ": HeadTrack LookAtModifier3D on head (limited, influence 0 until driven)")
	var anc := s.find_child("HeadAnchor", true, false) as BoneAttachment3D
	t.ok(anc != null and anc.get_parent() == skel and anc.bone_name == "head", label + ": HeadAnchor BoneAttachment3D on head")
	# --- plaque: brass plate on the chip bone, black numerals + bone bar, palmed in cheat
	if meshes.has("PitBoss_Plaque"):
		var pm: MeshInstance3D = meshes["PitBoss_Plaque"]
		var ms: Array[String] = []
		for si in pm.mesh.get_surface_count():
			ms.append(pm.get_active_material(si).resource_path.get_file().get_basename())
		ms.sort()
		var want := PLAQUE_SLOTS.duplicate()
		want.sort()
		t.ok(ms == want, "%s: plaque = brass plate, black numerals, bone bar %s" % [label, ms])
		t.ok(_binds(pm, skel) == ["chip"], "%s: plaque skinned only to the chip bone %s" % [label, _binds(pm, skel)])
		var vs: PackedVector3Array = pm.mesh.surface_get_arrays(_surf(pm, "pitboss_black"))[Mesh.ARRAY_VERTEX]
		var xs := {-1: 0, 1: 0}
		var cx := pm.mesh.get_aabb().get_center().x
		for v in vs:
			xs[1 if v.x > cx else -1] += 1
		t.ok(xs[-1] > 0 and xs[1] > 0 and xs[-1] != xs[1], "%s: numerals on both faces, different digits (4 front / 2 back: %d / %d verts)" % [label, xs[-1], xs[1]])
	var chip := skel.find_bone("chip")
	ap.play("cheat")
	ap.seek(0.7, true)
	var palmed := skel.get_bone_pose_scale(chip).x
	ap.seek(1.2, true)
	t.ok(palmed < 0.05 and skel.get_bone_pose_scale(chip).x > 0.95, "%s: cheat palms the plaque (scale %.2f @0.7, back by 1.2)" % [label, palmed])
	# --- slot swap: cap + plaque are self-contained (own bone, own materials) and can be swapped/hidden
	for p: String in SWAP_BONE:
		if meshes.has(p):
			t.ok(_binds(meshes[p], skel) == [SWAP_BONE[p]], "%s: %s rides only the %s bone (swap slot) %s" % [label, p, SWAP_BONE[p], _binds(meshes[p], skel)])
	for a in ACCENTS:
		var m := load(M + a + ".tres") as ShaderMaterial
		var users := 0
		for k in meshes:
			var mi: MeshInstance3D = meshes[k]
			for si in mi.mesh.get_surface_count():
				if mi.get_active_material(si) == m:
					users += 1
		t.ok(users > 0, "%s: accent %s is its own slot (%d surfaces)" % [label, a, users])
	var swap := ShaderMaterial.new()
	swap.shader = load(BD.TOON)
	if meshes.has("PitBoss_Cap"):
		var cap: MeshInstance3D = meshes["PitBoss_Cap"]
		var si := _surf(cap, "pitboss_cap")
		cap.set_surface_override_material(si, swap)
		t.ok(cap.get_active_material(si) == swap and (meshes["PitBoss_Head"] as MeshInstance3D).get_active_material(0) != swap,
			label + ": swapping the cap material leaves the head untouched")
		cap.set_surface_override_material(si, null)
		cap.visible = false
		t.ok((meshes["PitBoss_Head"] as MeshInstance3D).visible, label + ": hiding the cap slot keeps the head")
		cap.visible = true
	# --- framing: brazier gap + felt in both game cams, every clip frame
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
	s.position = Vector3(0, 0.0, 0.3)  # self-check: a dealer standing on the felt must trip the felt proxy
	ap.play("idle")
	ap.seek(0.0, true)
	t.ok(t.felt_cover(cams["pc"], t.skinned(s, skel)) > 0.1, label + ": felt proxy catches a dealer moved onto the felt")
	s.position = BD.DEALER_POS
	var pc := t.prop_clip_frames(s, skel, ap, SMILES.LOOPS + SMILES.REACTIONS)
	print("  info %s gap pc %.1f / phone %.1f px, felt cover pc %.1f%% / phone %.1f%%, prop clip %d" % [label, gap["pc"], gap["phone"], felt["pc"] * 100.0, felt["phone"] * 100.0, pc])
	t.ok(pc <= PROP_CLIP_MAX, "%s: plaque-in-hand clip frames <= %d (%d)" % [label, PROP_CLIP_MAX, pc])
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
