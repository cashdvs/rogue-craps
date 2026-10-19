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
	"shoulder_R", "upper_arm_R", "forearm_R", "hand_R", "thumb_R", "index_R", "fingers_R", "chip",
	"glow_head", "glow_jaw", "glow_grin_L", "glow_grin_R", "glow_visor"]
const PARENTS: Dictionary = {"glow_head": "head", "glow_jaw": "jaw", "glow_grin_L": "grin_L", "glow_grin_R": "grin_R", "glow_visor": "visor",
	"spine": "root", "chest": "spine", "neck": "chest", "head": "neck", "jaw": "head",
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
## Key gesture frames that must read above the far rail in the game camera: [clip, time, hands].
const GESTURES: Array = [["grudging", 0.5, ["L", "R"]], ["grudging", 1.0, ["L", "R"]],
	["taunt", 0.5, ["R"]], ["cheat", 0.45, ["R"]]]
## Game camera from feat/bonfire-sandbox a153087: rig at the pivot pitched -55, camera dolly d, look-up 7.5, fov 36.
const GAME_CAMS: Dictionary = {"pc": [Vector2i(1920, 1080), 2.40, Vector3(0, 0, 0.26)], "phone": [Vector2i(844, 390), 2.04, Vector3(0, 0, 0.34)]}
const CAM_RAIL_TOP := 0.11  # RAIL_TOP_Y in the sandbox: the band is measured from here
const VISOR_MIN_PX := 2
const HORN_TIP_PX := 4
const IDLE_HANDS_MAX := 0.10
## Brazier bowl + goal plaque (Hearth board, art/board-hearth f25a745: Anchors/TargetPlate/Plate/Model/brazier),
## world-space hull points (support points in 600 directions). Smiles keeps >= BRAZIER_CLEAR_PX of clear dark from
## it on screen in both game cameras, every dealer clip.
const BRAZIER_HULL: Array[Vector3] = [
	Vector3(-0.134, 0.213, -0.77), Vector3(-0.134, 0.22, -0.77), Vector3(-0.129, 0.213, -0.805), Vector3(-0.129, 0.213, -0.735), Vector3(-0.129, 0.22, -0.805), Vector3(-0.129, 0.22, -0.735),
	Vector3(-0.128, 0.17, -0.773), Vector3(-0.128, 0.17, -0.767), Vector3(-0.116, 0.213, -0.837), Vector3(-0.116, 0.22, -0.837), Vector3(-0.116, 0.22, -0.703), Vector3(-0.115, 0.165, -0.801),
	Vector3(-0.107, 0.173, -0.832), Vector3(-0.103, 0.165, -0.83), Vector3(-0.095, 0.213, -0.865), Vector3(-0.095, 0.22, -0.865), Vector3(-0.095, 0.22, -0.675), Vector3(-0.087, 0.173, -0.857),
	Vector3(-0.084, 0.165, -0.854), Vector3(-0.078, 0.137, -0.617), Vector3(-0.078, 0.141, -0.611), Vector3(-0.078, 0.203, -0.647), Vector3(-0.077, 0.174, -0.627), Vector3(-0.074, 0.174, -0.625),
	Vector3(-0.067, 0.213, -0.886), Vector3(-0.067, 0.22, -0.886), Vector3(-0.067, 0.22, -0.654), Vector3(-0.066, 0.17, -0.879), Vector3(-0.061, 0.17, -0.882), Vector3(-0.045, 0.09, -0.77),
	Vector3(-0.043, 0.09, -0.782), Vector3(-0.043, 0.09, -0.758), Vector3(-0.039, 0.09, -0.793), Vector3(-0.039, 0.09, -0.748), Vector3(-0.035, 0.213, -0.899), Vector3(-0.035, 0.22, -0.899),
	Vector3(-0.035, 0.22, -0.641), Vector3(-0.032, 0.09, -0.802), Vector3(-0.032, 0.09, -0.738), Vector3(-0.031, 0.165, -0.885), Vector3(-0.023, 0.09, -0.809), Vector3(-0.012, 0.09, -0.813),
	Vector3(-0.012, 0.09, -0.727), Vector3(-0, 0.09, -0.815), Vector3(-0, 0.09, -0.725), Vector3(-0, 0.165, -0.889), Vector3(-0, 0.173, -0.893), Vector3(-0, 0.213, -0.904),
	Vector3(-0, 0.22, -0.904), Vector3(-0, 0.22, -0.636), Vector3(0.012, 0.09, -0.813), Vector3(0.012, 0.09, -0.727), Vector3(0.022, 0.09, -0.809), Vector3(0.031, 0.165, -0.885),
	Vector3(0.032, 0.09, -0.802), Vector3(0.032, 0.09, -0.738), Vector3(0.035, 0.213, -0.899), Vector3(0.035, 0.22, -0.899), Vector3(0.035, 0.22, -0.641), Vector3(0.039, 0.09, -0.793),
	Vector3(0.039, 0.09, -0.748), Vector3(0.043, 0.09, -0.782), Vector3(0.043, 0.09, -0.758), Vector3(0.045, 0.09, -0.77), Vector3(0.061, 0.17, -0.882), Vector3(0.066, 0.17, -0.879),
	Vector3(0.067, 0.213, -0.886), Vector3(0.067, 0.22, -0.886), Vector3(0.067, 0.22, -0.654), Vector3(0.074, 0.174, -0.625), Vector3(0.077, 0.174, -0.627), Vector3(0.078, 0.137, -0.617),
	Vector3(0.078, 0.141, -0.611), Vector3(0.078, 0.203, -0.647), Vector3(0.084, 0.165, -0.854), Vector3(0.095, 0.213, -0.865), Vector3(0.095, 0.22, -0.865), Vector3(0.095, 0.22, -0.675),
	Vector3(0.103, 0.165, -0.83), Vector3(0.107, 0.173, -0.832), Vector3(0.115, 0.165, -0.801), Vector3(0.116, 0.213, -0.837), Vector3(0.116, 0.22, -0.837), Vector3(0.116, 0.22, -0.703),
	Vector3(0.128, 0.17, -0.773), Vector3(0.128, 0.17, -0.767), Vector3(0.129, 0.213, -0.805), Vector3(0.129, 0.213, -0.735), Vector3(0.129, 0.22, -0.805), Vector3(0.129, 0.22, -0.735),
	Vector3(0.134, 0.213, -0.77), Vector3(0.134, 0.22, -0.77),
]
const BRAZIER_CLEAR_PX := 20.0
## The pale-green visor rim has to read to the phone camera on every clip: rim area on screen (px^2) that faces the
## camera and sits in the lamp's lit band.
const RIM_MIN_PX2 := 55.0
## Grudging clap: wrist (hand bone) x-gap below which the palms touch, the held-apart keys and their minimum gap.
const CLAP_TOUCH := 0.05
const CLAP_HELD: Array[float] = [0.3, 0.44, 0.6, 0.8, 0.94, 1.1, 1.25]
const CLAP_HELD_GAP := 0.08
const CLAP_PALM_GAP := 0.05  # clear air between the two hand meshes when held (about a palm-width)
const CLAP_SCREEN_GAP := 8.0  # ... and as seen by the game camera, px (PC; the phone gets half)
## Table lamp (the spot the captures use, over the felt centre). RIM_LIT is tuned on the captures: at the dealer spot the
## lamp's cone falloff means the rim only renders pale green where N.L >= ~0.75 (the dark-rim frames measured 31-41 px^2,
## the reading ones 64-75).
const LAMP_POS := Vector3(0, 1.35, -0.05)
const RIM_LIT := 0.75
## Beats where the rim is also ray-tested against the brim / head (camera line of sight + lamp shadow).
const RIM_BEATS: Array = [["idle", 0.0], ["idle", 1.4], ["taunt", 0.5], ["taunt", 1.0], ["grudging", 0.5], ["grudging", 1.0],
	["cheat", 0.45], ["cheat", 0.85], ["deal", 0.42], ["deal", 0.7]]
const GLOW: Array[String] = ["glow_head", "glow_jaw", "glow_grin_L", "glow_grin_R", "glow_visor"]
const FELT_TOP := 0.03
const LIMBS: Array[String] = ["forearm_L", "forearm_R", "hand_L", "hand_R", "index_L", "index_R", "fingers_L", "fingers_R", "thumb_L", "thumb_R", "chip"]

var _passed: int = 0
var _failed: int = 0
var _closest := Vector3.ZERO


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
	# as dealer he is lamp-lit only: the visible grin / visor / pale-green rim carry no emission
	var lit_bad: Array[String] = []
	for n in ["smiles_gold", "smiles_visor", "smiles_visor_rim"]:
		var mm := load("res://art/models/characters/smiles/materials/%s.tres" % n) as ShaderMaterial
		var e: Variant = mm.get_shader_parameter("emission_energy")
		if e != null and float(e) > 0.0:
			lit_bad.append(n)
	_ok(lit_bad.is_empty(), "%s: dealer grin / visor / rim are non-emissive %s" % [label, lit_bad])
	# MC-only glow: the glow_* shells are collapsed in every dealer clip and shown in the MC clips
	var glow_bad: Array[String] = []
	for c in ap.get_animation_list():
		if c == "RESET":
			continue
		var want := 1.0 if String(c).begins_with("mc_") else 0.0
		for t in [0.0, ap.get_animation(c).length * 0.5]:
			ap.play(c)
			ap.seek(t, true)
			for g in GLOW:
				if absf(skel.get_bone_pose_scale(skel.find_bone(g)).x - want) > 0.01:
					glow_bad.append("%s %s @%.1f" % [c, g, t])
	_ok(glow_bad.is_empty(), "%s: grin + visor-rim glow only in the MC clips %s" % [label, glow_bad.slice(0, 3)])
	# --- Godot Dev's game camera (feat/bonfire-sandbox a153087): the band above the far rail is ~0.22 m on
	# phone landscape and ~0.44 m on PC, so everything that has to read is authored for the phone band ---
	s.position = DEALER_POS
	s.rotation_degrees = Vector3.ZERO
	var cams := {"pc": _game_cam("pc"), "phone": _game_cam("phone")}
	await process_frame
	var phone: Camera3D = cams["phone"]
	var band := _headroom(phone)
	print("  info %s band above the rail at the dealer: phone %.3f m, pc %.3f m" % [label, band, _headroom(cams["pc"])])
	var band_bad: Array[String] = []
	var horn_bad: Array[String] = []
	var visor_bad: Array[String] = []
	var over_head: Array[String] = []
	var polys := {"pc": _brazier_poly(cams["pc"]), "phone": _brazier_poly(phone)}
	var clear := {}
	var near_at := {}
	var rim_min := {}
	for c in ["idle", "taunt", "grudging", "cheat", "deal"]:
		var a := ap.get_animation(c)
		var mx := {}
		var px := {}
		var t := 0.0
		while t <= a.length + 0.001:
			ap.play(c)
			ap.seek(t, true)
			var pts := _skinned(s, skel)
			for ck in cams:
				var bp := _brazier_px(cams[ck], polys[ck], pts["all"])
				if bp < clear.get(ck + " " + c, INF):
					clear[ck + " " + c] = bp
					near_at[ck + " " + c] = "@%.2f %s" % [t, _closest.snapped(Vector3.ONE * 0.01)]
			var fm := {}
			for cat: String in pts:
				for q: Vector3 in pts[cat]:
					fm[cat] = maxf(fm.get(cat, -INF), q.y - CAM_RAIL_TOP)
					px[cat] = minf(px.get(cat, INF), phone.unproject_position(q).y)
			for cat: String in fm:
				mx[cat] = maxf(mx.get(cat, -INF), fm[cat])
			if c in ["taunt", "cheat"] and fm.get("hands", -INF) > fm.get("head", INF) + 0.002 and over_head.size() < 3:
				over_head.append("%s@%.2f hands %.3f > head %.3f" % [c, t, fm["hands"], fm["head"]])
			t += 0.05
		print("  info %s %s max height above the rail (m): visor %.3f grin %.3f hands %.3f horns %.3f | phone top px: visor %.0f horns %.0f hands %.0f" % [
			label, c, mx["visor"], mx["grin"], mx["hands"], mx["horn"], px["visor"], px["horn"], px["hands"]])
		if mx["visor"] > band or mx["grin"] > band:
			band_bad.append("%s visor %.3f grin %.3f" % [c, mx["visor"], mx["grin"]])
		if px["visor"] < VISOR_MIN_PX:
			visor_bad.append("%s %.0f px" % [c, px["visor"]])
		if px["horn"] < -HORN_TIP_PX:
			horn_bad.append("%s %.0f px" % [c, px["horn"]])
		if c == "idle" and mx["hands"] > IDLE_HANDS_MAX:
			band_bad.append("idle hands %.3f (lean low on the rail)" % mx["hands"])
	var clear_bad: Array[String] = []
	for key: String in clear:
		print("  info %s brazier + plaque clearance %s: %.1f px (closest %s)" % [label, key, clear[key], near_at[key]])
		if clear[key] < BRAZIER_CLEAR_PX:
			clear_bad.append("%s %.1f px" % [key, clear[key]])
	_ok(clear_bad.is_empty(), "%s: >= %d px of clear dark between Smiles and the brazier / goal plaque (PC + phone, every clip) %s" % [label, BRAZIER_CLEAR_PX, clear_bad])
	for kb in RIM_BEATS:
		ap.play(kb[0])
		ap.seek(kb[1], true)
		var occ_a := _rim_px2(phone, _skinned(s, skel), true)
		print("  info %s visor rim %s@%.2f phone: %.1f px^2 lit, front-facing and unoccluded" % [label, kb[0], kb[1], occ_a])
		rim_min[kb[0]] = minf(rim_min.get(kb[0], INF), occ_a)
	var rim_bad: Array[String] = []
	for c: String in rim_min:
		if rim_min[c] < RIM_MIN_PX2:
			rim_bad.append("%s %.1f" % [c, rim_min[c]])
	_ok(rim_bad.is_empty(), "%s: pale-green visor rim reads to the phone camera on every clip (lit, front-facing, unoccluded >= %.0f px^2 at each beat) %s" % [label, RIM_MIN_PX2, rim_bad])
	_ok(band_bad.is_empty(), "%s: grin + visor stay inside the phone band (<= %.2f m above the rail) in every clip, idle hands low %s" % [label, band, band_bad])
	_ok(visor_bad.is_empty(), "%s: visor never clips the phone frame (>= %d px inside) %s" % [label, VISOR_MIN_PX, visor_bad])
	_ok(horn_bad.is_empty(), "%s: horns swept back - at most the tips clip the phone frame (<= %d px) %s" % [label, HORN_TIP_PX, horn_bad])
	_ok(over_head.is_empty(), "%s: taunt point + cheat tell at or below head height (nothing above the head) %s" % [label, over_head])
	# key gesture hands read over the far rail and inside the phone frame (PC has twice the headroom)
	var low: Array[String] = []
	for gst in GESTURES:
		ap.play(gst[0])
		ap.seek(gst[1], true)
		var pts := _skinned(s, skel)
		for sd: String in gst[2]:
			var hv: PackedVector3Array = pts["hand_" + sd]
			var vis := 0
			var top := INF
			for ck in ["phone", "pc"]:
				var cam: Camera3D = cams[ck]
				vis = 0
				for q: Vector3 in hv:
					var sy := cam.unproject_position(q).y
					top = minf(top, sy) if ck == "phone" else top
					if q.z > -0.72 or sy < cam.unproject_position(Vector3(q.x, RAIL_TOP, -0.72)).y:
						vis += 1
				var frac := float(vis) / maxf(hv.size(), 1.0)
				if ck == "phone":
					print("  info %s %s@%.2f hand_%s: %.0f%% over the rail line on phone, top %.0f px" % [label, gst[0], gst[1], sd, frac * 100.0, top])
				if frac < 0.6 or top < 0.0:
					low.append("%s %s@%.2f hand_%s %.2f top %.0f" % [ck, gst[0], gst[1], sd, frac, top])
		if gst[0] == "grudging":
			var gy := 0.0
			for q: Vector3 in pts["grin"]:
				gy += phone.unproject_position(q).y
			gy /= maxf(pts["grin"].size(), 1.0)
			var hy := INF
			for q: Vector3 in pts["hand_L"] + pts["hand_R"]:
				hy = minf(hy, phone.unproject_position(q).y)
			print("  info %s grudging@%.2f phone: grin centre %.0f px, clapping hands top %.0f px" % [label, gst[1], gy, hy])
			if gy >= hy:
				low.append("grudging@%.2f grin %.0f not above hands %.0f" % [gst[1], gy, hy])
	_ok(low.is_empty(), "%s: key gestures (clap / point / cheat) read over the rail inside the phone + PC frames, grin above the clap %s" % [label, low.slice(0, 3)])
	for ck in cams:
		(cams[ck] as Camera3D).get_viewport().queue_free()
	# grudging clap (AD final): held keys a palm-width apart, palms facing, fingers up, wrists never crossing, and the
	# palms only meet for 2-3 frames (30 fps) per clap
	var clap_bad: Array[String] = []
	var runs: Array[int] = []
	var run := 0
	var ga := ap.get_animation("grudging")
	for fi in int(round(ga.length * 30.0)) + 1:
		var t := fi / 30.0
		ap.play("grudging")
		ap.seek(t, true)
		var gl := skel.get_bone_global_pose(skel.find_bone("hand_L"))
		var gr := skel.get_bone_global_pose(skel.find_bone("hand_R"))
		var gap := gl.origin.x - gr.origin.x
		if gap <= 0.0:
			clap_bad.append("wrists cross @%.2f" % t)
		if gap < CLAP_TOUCH:
			run += 1
		elif run > 0:
			runs.append(run)
			run = 0
	if run > 0:
		runs.append(run)
	for ht in CLAP_HELD:
		ap.play("grudging")
		ap.seek(ht, true)
		var gl := skel.get_bone_global_pose(skel.find_bone("hand_L"))
		var gr := skel.get_bone_global_pose(skel.find_bone("hand_R"))
		var across := (gr.origin - gl.origin).normalized()
		var palm_l := (-gl.basis.x).normalized()  # curl() closes the fingers toward local -X on the left hand, +X on the right
		var palm_r := gr.basis.x.normalized()
		var up_l := (-gl.basis.y).normalized().y
		var up_r := (-gr.basis.y).normalized().y
		var gap := gl.origin.x - gr.origin.x
		var hp := _skinned(s, skel)
		var l_min := INF
		var r_max := -INF
		var sgap := {}
		for q: Vector3 in hp["hand_L"]:
			l_min = minf(l_min, q.x)
		for q: Vector3 in hp["hand_R"]:
			r_max = maxf(r_max, q.x)
		for ck: String in cams:
			var c: Camera3D = cams[ck]
			var sl := INF
			var sr := -INF
			for q: Vector3 in hp["hand_L"]:
				sl = minf(sl, c.unproject_position(q).x)
			for q: Vector3 in hp["hand_R"]:
				sr = maxf(sr, c.unproject_position(q).x)
			sgap[ck] = sl - sr
		print("  info %s grudging held @%.2f: wrist gap %.3f m, mesh gap %.3f m, screen gap pc %.1f / phone %.1f px, palms facing %.2f / %.2f, fingers up %.2f / %.2f" % [label, ht, gap, l_min - r_max, sgap["pc"], sgap["phone"], palm_l.dot(across), palm_r.dot(-across), up_l, up_r])
		if l_min - r_max < CLAP_PALM_GAP or sgap["pc"] < CLAP_SCREEN_GAP or sgap["phone"] < CLAP_SCREEN_GAP * 0.5:
			clap_bad.append("held @%.2f hands only %.3f m / %.1f px apart" % [ht, l_min - r_max, sgap["pc"]])
		if gap < CLAP_HELD_GAP or palm_l.dot(across) < 0.8 or palm_r.dot(-across) < 0.8 or up_l < 0.6 or up_r < 0.6:
			clap_bad.append("held @%.2f gap %.3f palms %.2f/%.2f up %.2f/%.2f" % [ht, gap, palm_l.dot(across), palm_r.dot(-across), up_l, up_r])
	print("  info %s grudging palms-touching runs (frames at 30 fps): %s" % [label, runs])
	if runs.size() != 2 or runs.any(func(r: int) -> bool: return r < 2 or r > 3):
		clap_bad.append("touch runs %s (want 2 claps x 2-3 frames)" % [runs])
	_ok(clap_bad.is_empty(), "%s: grudging claps: held a palm-width apart, palms facing, fingers up, wrists never cross, palms meet 2-3 frames per clap %s" % [label, clap_bad.slice(0, 3)])
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


func _game_cam(kind: String) -> Camera3D:
	var c: Array = GAME_CAMS[kind]
	var vp := SubViewport.new()
	vp.size = c[0]
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(vp)
	var rig := Node3D.new()
	vp.add_child(rig)
	rig.position = c[2]
	rig.rotation_degrees = Vector3(-55, 0, 0)
	var cam := Camera3D.new()
	rig.add_child(cam)
	cam.fov = 36.0
	cam.position = Vector3(0, 0, c[1])
	cam.rotation_degrees = Vector3(7.5, 0, 0)
	cam.current = true
	return cam


## Height above CAM_RAIL_TOP at the dealer's spot where the frame's top edge cuts.
func _headroom(cam: Camera3D) -> float:
	var lo := -1.0
	var hi := 6.0
	for i in 50:
		var mid := (lo + hi) * 0.5
		if cam.unproject_position(Vector3(DEALER_POS.x, mid, DEALER_POS.z)).y < 0.0:
			hi = mid
		else:
			lo = mid
	return lo - CAM_RAIL_TOP


## CPU-skinned world positions of the drawn vertices, by what has to read (glow shells and the chip skipped).
func _skinned(s: Node3D, skel: Skeleton3D) -> Dictionary:
	var out := {"horn": PackedVector3Array(), "visor": PackedVector3Array(), "grin": PackedVector3Array(), "hands": PackedVector3Array(),
		"hand_L": PackedVector3Array(), "hand_R": PackedVector3Array(), "head": PackedVector3Array(),
		"all": PackedVector3Array(), "rim": PackedVector3Array(), "rim_n": PackedVector3Array(), "occ": PackedVector3Array()}
	for mi: MeshInstance3D in s.find_children("*", "MeshInstance3D", true, false):
		var skin := mi.skin
		var mats: Array[Transform3D] = []
		var bnames: Array[String] = []
		for i in skin.get_bind_count():
			var bn := skin.get_bind_name(i)
			var bi := skel.find_bone(bn) if bn != "" else skin.get_bind_bone(i)
			bnames.append(skel.get_bone_name(bi))
			mats.append(skel.global_transform * skel.get_bone_global_pose(bi) * skin.get_bind_pose(i))
		for si in mi.mesh.get_surface_count():
			var m := mi.get_active_material(si)
			var mname := m.resource_path.get_file().get_basename() if m != null else "?"
			if mname.begins_with("smiles_chip") and skel.get_bone_pose_scale(skel.find_bone("chip")).x < 0.05:
				continue  # palmed / thrown: not drawn
			var arr := mi.mesh.surface_get_arrays(si)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bs: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var ws: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			var k := ws.size() / maxi(vs.size(), 1)
			var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var rim := mname == "smiles_visor_rim"
			var occ := (mi.name == "Smiles_Head" or mi.name == "Smiles_Visor") and not rim
			var rim_p := PackedVector3Array()
			var rim_n := PackedVector3Array()
			if rim or occ:
				rim_p.resize(vs.size())
				rim_n.resize(vs.size())
			for vi in vs.size():
				var q := Vector3.ZERO
				var wsum := 0.0
				var top := ""
				var topw := 0.0
				for j in k:
					var w := ws[vi * k + j]
					if w <= 0.0:
						continue
					q += (mats[bs[vi * k + j]] * vs[vi]) * w
					wsum += w
					if w > topw:
						topw = w
						top = bnames[bs[vi * k + j]]
				if wsum <= 0.0 or top.begins_with("glow_"):
					continue
				q /= wsum
				out["all"].append(q)
				if rim or occ:
					rim_p[vi] = q
					rim_n[vi] = (mats[bs[vi * k]].basis * ns[vi]).normalized()
				if mname == "smiles_horn":
					out["horn"].append(q)
				if mi.name == "Smiles_Visor":
					out["visor"].append(q)
				if mname == "smiles_gold" and mi.name == "Smiles_Head":
					out["grin"].append(q)
				if (mi.name == "Smiles_Head" and mname != "smiles_horn") or mi.name == "Smiles_Visor":
					out["head"].append(q)
				for sd in ["L", "R"]:
					if top in ["hand_" + sd, "index_" + sd, "fingers_" + sd, "thumb_" + sd]:
						out["hand_" + sd].append(q)
						out["hands"].append(q)
			if occ:
				var oidx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
				for ti in oidx.size():
					out["occ"].append(rim_p[oidx[ti]])
			if rim:
				var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
				for ti in idx.size():
					out["rim"].append(rim_p[idx[ti]])
					out["rim_n"].append(rim_n[idx[ti]])
	return out


## Lit, front-facing area (px^2) of the visor rim triangles inside the frame and over the far rail line.
func _rim_px2(cam: Camera3D, pts: Dictionary, occlude: bool = false) -> float:
	var tri: PackedVector3Array = pts["rim"]
	var nn: PackedVector3Array = pts["rim_n"]
	var eye := cam.global_position
	var vs := Vector2(cam.get_viewport().size)
	var area := 0.0
	for i in range(0, tri.size(), 3):
		var c := (tri[i] + tri[i + 1] + tri[i + 2]) / 3.0
		var n := (nn[i] + nn[i + 1] + nn[i + 2]).normalized()
		if n.dot(eye - c) <= 0.0 or n.dot((LAMP_POS - c).normalized()) < RIM_LIT:
			continue  # back-facing, or not in toon_noir's lit band (pale green only reads when the lamp hits it)
		var a := cam.unproject_position(tri[i])
		var b := cam.unproject_position(tri[i + 1])
		var d := cam.unproject_position(tri[i + 2])
		var m := (a + b + d) / 3.0
		if occlude and (_blocked(c + n * 0.001, eye, pts["occ"]) or _blocked(c + n * 0.001, LAMP_POS, pts["occ"])):
			continue  # hidden behind the brim / head, or in their shadow from the lamp
		if m.x < 0.0 or m.y < 0.0 or m.x > vs.x or m.y > vs.y:
			continue
		area += absf((b - a).cross(d - a)) * 0.5
	return area


## Screen-space convex hull of the brazier + plaque (monotone chain), counter-clockwise.
func _brazier_poly(cam: Camera3D) -> PackedVector2Array:
	var p: Array[Vector2] = []
	for v in BRAZIER_HULL:
		p.append(cam.unproject_position(v))
	p.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	var h: Array[Vector2] = []
	for pass_i in 2:
		var start := h.size()
		var seq := p if pass_i == 0 else p.duplicate()
		if pass_i == 1:
			seq.reverse()
		for q in seq:
			while h.size() >= start + 2 and (h[-1] - h[-2]).cross(q - h[-2]) <= 0.0:
				h.pop_back()
			h.append(q)
		h.pop_back()
	return PackedVector2Array(h)


## Smallest on-screen distance (px) from any of `pts` to the brazier polygon (0 = touching / overlapping).
func _brazier_px(cam: Camera3D, poly: PackedVector2Array, pts: PackedVector3Array) -> float:
	var lo := INF
	for v in poly:
		lo = minf(lo, v.x)
	var best := INF
	for q in pts:
		var sp := cam.unproject_position(q)
		if sp.x < lo - best:
			continue
		if q.z < -0.72 and sp.y > cam.unproject_position(Vector3(q.x, RAIL_TOP, -0.72)).y:
			continue  # below the far rail's sight line: the rail hides it
		if Geometry2D.is_point_in_polygon(sp, poly):
			_closest = q
			return 0.0
		for i in poly.size():
			var c := Geometry2D.get_closest_point_to_segment(sp, poly[i], poly[(i + 1) % poly.size()])
			if sp.distance_to(c) < best:
				best = sp.distance_to(c)
				_closest = q
	return best


## True when the segment from `p` to `to` passes through any of the triangles in `tris`.
func _blocked(p: Vector3, to: Vector3, tris: PackedVector3Array) -> bool:
	var dir := (to - p).normalized()
	for i in range(0, tris.size(), 3):
		if Geometry3D.ray_intersects_triangle(p, dir, tris[i], tris[i + 1], tris[i + 2]) != null:
			return true
	return false
