## Headless test: Smiles, the imp croupier dealer (art/models/characters/smiles), follows the locked
## direction (art/concept/bonfire_table/README.md "LOCKED DIRECTION" > Dealer: Smiles) and the rig /
## clip contract Godot Dev drives: bone names, clips present + lengths (idle loop 2-4 s, reactions
## 0.8-1.6 s), the head-track hook (LookAtModifier3D on "head") and head anchor, the swap-friendly
## part split (body / head / visor / chip prop), toon materials with ink hulls (no Soul cyan), the
## tri budgets (~6-8k PC, ~3.5k mobile), and no scripts / lights (art only).
##
## Run:
##   godot --headless --path . --script res://tests/test_smiles.gd
extends SceneTree

const S := "res://art/models/characters/smiles/scenes/"
const TOON := "res://shaders/3d/toon_noir.gdshader"
const OUTLINE := "res://shaders/3d/outline.gdshader"
const BONES: Array[String] = ["root", "spine", "chest", "neck", "head", "jaw", "grin_L", "grin_R", "visor",
	"shoulder_L", "upper_arm_L", "forearm_L", "hand_L", "thumb_L", "index_L", "fingers_L",
	"shoulder_R", "upper_arm_R", "forearm_R", "hand_R", "thumb_R", "index_R", "fingers_R", "chip"]
const PARENTS: Dictionary = {"spine": "root", "chest": "spine", "neck": "chest", "head": "neck", "jaw": "head",
	"grin_L": "head", "grin_R": "head", "visor": "head", "hand_L": "forearm_L", "hand_R": "forearm_R", "chip": "hand_R"}
const LOOPS: Array[String] = ["idle", "mc_idle"]
const REACTIONS: Array[String] = ["taunt", "grudging", "cheat", "deal", "mc_cheer"]
const PARTS: Array[String] = ["Smiles_Body", "Smiles_Head", "Smiles_Visor", "Smiles_Chip"]
## Surfaces that are deliberately not inked (embedded eyes, mouth interior, chip edge stripe).
const NO_INK: Array[String] = ["smiles_eye", "smiles_mouth", "smiles_chip_edge"]
const SOUL_CYAN := Color("#4FE6E0")
## Placement the README documents (Hearth / Board A table): dealer behind the far rail, stage left of the
## brazier; MC outside the left rail facing in. Rail outer edges: far z -0.70, left x -1.20 (+2 cm margin);
## rail top y ~0.13, rail ~0.2 m deep, then the felt (y ~0). Anything that reaches past an outer edge has to be
## up over the rail (y > 0.14), and over the felt it has to stay above the cloth (y > 0.03).
const DEALER_POS := Vector3(-0.42, -0.47, -0.86)
const MC_POS := Vector3(-1.32, -0.42, -0.30)
const RAIL_TOP := 0.14
const FELT_TOP := 0.03
const LIMBS: Array[String] = ["forearm_L", "forearm_R", "hand_L", "hand_R", "index_L", "index_R", "fingers_L", "fingers_R", "thumb_L", "thumb_R", "chip"]

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	print("=== Dice of the Damned: Smiles dealer tests ===")
	_run.call_deferred()


func _run() -> void:
	for lod in ["", "_mobile"]:
		await _check(lod)
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _ok(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  ok   " + what)
	else:
		_failed += 1
		print("  FAIL " + what)


func _check(lod: String) -> void:
	var path := S + "smiles%s.tscn" % lod
	var label := path.get_file()
	var ps := load(path) as PackedScene
	_ok(ps != null, label + ": loads")
	if ps == null:
		return
	var s := ps.instantiate() as Node3D
	root.add_child(s)
	await process_frame
	var skel := s.find_child("Skeleton3D", true, false) as Skeleton3D
	_ok(skel != null, label + ": has a Skeleton3D")
	var missing: Array[String] = []
	for b in BONES:
		if skel.find_bone(b) < 0:
			missing.append(b)
	_ok(missing.is_empty(), "%s: all %d rig bones present %s" % [label, BONES.size(), missing])
	var bad_par: Array[String] = []
	for b: String in PARENTS:
		var i := skel.find_bone(b)
		if i < 0 or skel.get_bone_parent(i) != skel.find_bone(PARENTS[b]):
			bad_par.append(b)
	_ok(bad_par.is_empty(), "%s: bone hierarchy (head under neck, jaw / grin / visor under head, chip under hand_R) %s" % [label, bad_par])
	var h := skel.find_bone("head")
	var hb := skel.get_bone_global_rest(h).basis
	_ok(hb.z.dot(Vector3(0, 0, 1)) > 0.99 and hb.y.dot(Vector3.UP) > 0.99, label + ": head bone rest faces +Z (LookAt forward axis +Z), up +Y")
	# --- parts / budget / materials ---
	var tris := 0
	var names: Array[String] = []
	var bad_mat: Array[String] = []
	var cyan := false
	for mi: MeshInstance3D in s.find_children("*", "MeshInstance3D", true, false):
		names.append(String(mi.name))
		_ok(mi.skin != null or mi.get_skin() != null, "%s: %s is skinned to the rig" % [label, mi.name])
		for si in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(si)
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			tris += (idx.size() if idx.size() > 0 else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
			var m := mi.get_active_material(si) as ShaderMaterial
			var mname := m.resource_path.get_file().get_basename() if m != null else "?"
			if m == null or m.shader.resource_path != TOON:
				bad_mat.append("%s:%s not toon_noir" % [mi.name, mname])
				continue
			var ink := m.next_pass as ShaderMaterial
			if not (mname in NO_INK) and (ink == null or ink.shader.resource_path != OUTLINE):
				bad_mat.append("%s:%s no ink hull" % [mi.name, mname])
			for k in ["albedo", "emission_color", "rim_color"]:
				var c: Variant = m.get_shader_parameter(k)
				if c is Color and _near(c, SOUL_CYAN):
					cyan = true
	for p in PARTS:
		_ok(p in names, "%s: swappable part %s present" % [label, p])
	if lod == "":
		_ok(tris >= 5000 and tris <= 8000, "%s: PC tris within ~6-8k (%d)" % [label, tris])
	else:
		_ok(tris <= 3600, "%s: mobile tris <= ~3.5k (%d)" % [label, tris])
	print("  info %s total tris %d" % [label, tris])
	_ok(bad_mat.is_empty(), "%s: toon_noir + ink hull on every surface (eyes / mouth / chip edge un-inked) %s" % [label, bad_mat])
	_ok(not cyan, label + ": no Soul cyan (reserved for the player)")
	_ok(s.find_children("*", "Light3D", true, false).is_empty(), label + ": no lights")
	var scripted: Array[String] = []
	for n in s.find_children("*", "", true, false) + [s]:
		if n.get_script() != null:
			scripted.append(String(n.name))
	_ok(scripted.is_empty(), "%s: no scripts (art only) %s" % [label, scripted])
	# --- hooks ---
	var look := s.find_child("HeadTrack", true, false) as LookAtModifier3D
	_ok(look != null and look.bone_name == "head" and look.get_parent() == skel, label + ": HeadTrack = LookAtModifier3D on bone head")
	_ok(look != null and is_zero_approx(look.influence) and look.forward_axis == SkeletonModifier3D.BONE_AXIS_PLUS_Z and look.use_angle_limitation,
		label + ": HeadTrack off by default (influence 0), forward +Z, angle-limited")
	var anchor := s.find_child("HeadAnchor", true, false) as BoneAttachment3D
	_ok(anchor != null and anchor.bone_name == "head", label + ": HeadAnchor = BoneAttachment3D on head (speech bubble)")
	# --- clips ---
	var ap := s.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_ok(ap != null and ap.autoplay == "idle", label + ": AnimationPlayer autoplays idle")
	for c in LOOPS + REACTIONS:
		var a := ap.get_animation(c) if ap.has_animation(c) else null
		_ok(a != null, "%s: clip %s present" % [label, c])
		if a == null:
			continue
		if c in LOOPS:
			_ok(a.loop_mode == Animation.LOOP_LINEAR and a.length >= 2.0 - 0.001 and a.length <= 4.0 + 0.001, "%s: %s loops, 2-4 s (%.2f)" % [label, c, a.length])
		else:
			_ok(a.loop_mode == Animation.LOOP_NONE and a.length >= 0.8 - 0.001 and a.length <= 1.6 + 0.001, "%s: %s one-shot, 0.8-1.6 s (%.2f)" % [label, c, a.length])
		var heads := 0
		for t in a.get_track_count():
			var tp := String(a.track_get_path(t))
			if tp.ends_with(":head") or tp.ends_with(":jaw"):
				heads += 1
		_ok(heads >= 2, "%s: %s animates head + jaw" % [label, c])
	# loops close: first and last pose match (no pop at the wrap)
	for c in LOOPS:
		_ok(_same(_pose_at(ap, skel, c, 0.0), _pose_at(ap, skel, c, ap.get_animation(c).length)), "%s: %s loop wraps without a pop" % [label, c])
	# a few beats the art direction asks for
	var gi := skel.find_bone("grin_L")
	ap.play("grudging")
	ap.seek(1.0, true)
	var crack := skel.get_bone_pose_rotation(gi).get_euler()
	ap.play("idle")
	ap.seek(0.0, true)
	var calm := skel.get_bone_pose_rotation(gi).get_euler()
	_ok(absf(rad_to_deg(crack.z - calm.z)) > 10.0, label + ": grudging cracks the grin (grin_L droops > 10 deg)")
	var ci := skel.find_bone("chip")
	ap.play("cheat")
	ap.seek(0.7, true)
	var hidden := skel.get_bone_pose_scale(ci).x
	ap.seek(1.2, true)
	_ok(hidden < 0.05 and skel.get_bone_pose_scale(ci).x > 0.95, label + ": cheat palms the chip (hidden mid-clip, back by the end)")
	ap.play("taunt")
	ap.seek(0.5, true)
	_ok(rad_to_deg(skel.get_bone_pose_rotation(skel.find_bone("jaw")).get_euler().x) > 15.0, label + ": taunt cackles (jaw open > 15 deg)")
	# rail clearance at the documented spots (arms never sink into the rail / table)
	for spot in [[DEALER_POS, 0.0, false], [MC_POS, 90.0, true]]:
		s.position = spot[0]
		s.rotation_degrees = Vector3(0, spot[1], 0)
		var worst := ""
		for c in (["mc_idle", "mc_cheer"] if spot[2] else ["idle", "taunt", "grudging", "cheat", "deal"]):
			var a := ap.get_animation(c)
			var t := 0.0
			while t <= a.length + 0.001:
				ap.play(c)
				ap.seek(t, true)
				for b in LIMBS:
					if b == "chip" and skel.get_bone_pose_scale(skel.find_bone(b)).x < 0.05:
						continue  # palmed / thrown: not drawn
					var g := skel.global_transform * skel.get_bone_global_pose(skel.find_bone(b))
					for q in [g.origin, g * Vector3(0, -0.1, 0) if b.begins_with("index") or b.begins_with("fingers") else g.origin]:
						# depth past the rail's outer edge: 0..0.2 m = over the rail (clear its top), beyond = over the felt
						var depth: float = (q.x + 1.22) if spot[2] else (q.z + 0.72)
						var floor_y: float = -INF if depth <= 0.0 else (RAIL_TOP if depth < 0.2 else FELT_TOP)
						if q.y < floor_y and worst == "":
							worst = "%s %s @%.1f %s" % [c, b, t, q.snapped(Vector3.ONE * 0.01)]
				t += 0.1
		_ok(worst == "", "%s: %s arms stay behind the rail or reach over it %s" % [label, "MC (left rail)" if spot[2] else "dealer (far rail)", worst])
	s.queue_free()
	await process_frame


func _pose_at(ap: AnimationPlayer, skel: Skeleton3D, clip: String, t: float) -> PackedFloat32Array:
	ap.play(clip)
	ap.seek(t, true)
	var out := PackedFloat32Array()
	for i in skel.get_bone_count():
		var q := skel.get_bone_pose_rotation(i)
		var o := skel.get_bone_pose_position(i)
		out.append_array([q.x * signf(q.w + 1e-6), q.y * signf(q.w + 1e-6), q.z * signf(q.w + 1e-6), o.x, o.y, o.z])
	return out


func _same(a: PackedFloat32Array, b: PackedFloat32Array) -> bool:
	for i in a.size():
		if absf(a[i] - b[i]) > 0.01:
			return false
	return true


func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < 0.2
