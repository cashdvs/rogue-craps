## Headless test: every dealer's hands mirror each other (Cash playtest: "the hands are all on the same side").
## Smiles and all six boss dealers share Smiles' clips (build_smiles.py). In the idle clip, the pose seen at the
## table almost all the time, both forearms rest on the rail: the left hand must be the mirror image of the right
## (same palm roll, mirrored across the body), with both palms facing down. Before the fix the left palm faced
## down and the right palm up, so both hands read as the same hand. Also checks the chip prop stays on hand_R.
##
## Natural hands (Cash playtest: "the people at the tables still look unnatural ... mostly the hands"):
##  - finger curl: every hand's fingers curl toward the palm in a relaxed arc (not straight rakes, not fists),
##    measured on the skinned mesh in the bind pose (the curl is sculpted, the rig keeps its 29 bones);
##  - wrist angle: forearm -> hand bend stays within a believable range in every dealer clip;
##  - rail: in idle and deal, no hand / finger vertex sinks into the rail top or the felt (dealer spot, far rail).
##
## Run:
##   godot --headless --path . --script res://tests/test_dealer_hands.gd
extends SceneTree

const SCENES := [
	"res://art/models/characters/smiles/scenes/smiles%s.tscn",
	"res://art/models/characters/bosses/pit_boss/scenes/pit_boss%s.tscn",
	"res://art/models/characters/bosses/shuffle/scenes/shuffle%s.tscn",
	"res://art/models/characters/bosses/ashmouth/scenes/ashmouth%s.tscn",
	"res://art/models/characters/bosses/straight_man/scenes/straight_man%s.tscn",
	"res://art/models/characters/bosses/collector/scenes/collector%s.tscn",
	"res://art/models/characters/bosses/bloodletter/scenes/bloodletter%s.tscn",
]
## Mirror across the body's centre plane (model X).
const MX := Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1))
const MIN_MIRROR_DOT := 0.8
const MIN_PALM_DOWN := 0.7
## Finger curl: chord angle knuckle -> fingertip, bent toward the palm (deg). Straight ~0, fist ~90+.
const CURL_MIN := 15.0
const CURL_MAX := 70.0
## Max forearm -> hand bend (deg) in any dealer clip.
const WRIST_MAX := 60.0
const DEALER_CLIPS := ["idle", "taunt", "grudging", "cheat", "deal"]
## Rail / felt in model space at the dealer spot (test_smiles: DEALER_POS y -0.47, RAIL_TOP 0.14, FELT_TOP 0.03,
## rail's outer edge world z -0.72 = model z 0.14, 0.2 m deep).
const RAIL_Y := 0.61
const FELT_Y := 0.50
const RAIL_Z0 := 0.14
const RAIL_DEPTH := 0.2

var _pass := 0
var _fail := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, msg: String) -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL ", msg)


func _run() -> void:
	print("=== Dice of the Damned: dealer hand mirroring ===")
	for path: String in SCENES:
		for lod in ["", "_mobile"]:
			await _check_scene(path % lod)
	print("=== %d passed, %d failed ===" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)


## Palm normal in model space: the palm faces the body at rest, i.e. -X for hand_L and +X for hand_R.
func _palm(sk: Skeleton3D, side: String) -> Vector3:
	var g := sk.get_bone_global_pose(sk.find_bone("hand_" + side))
	var rest := sk.get_bone_global_rest(sk.find_bone("hand_" + side))
	var local := rest.basis.inverse() * Vector3(-1.0 if side == "L" else 1.0, 0, 0)
	return (g.basis * local).normalized()


func _check_scene(path: String) -> void:
	var name := path.get_file().get_basename()
	var b := (load(path) as PackedScene).instantiate() as Node3D
	root.add_child(b)
	await process_frame
	var ap := b.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var sk := b.find_child("Skeleton3D", true, false) as Skeleton3D
	_check(ap != null and sk != null, "%s: AnimationPlayer + Skeleton3D" % name)
	if ap == null or sk == null:
		b.queue_free()
		return
	var chip := sk.find_bone("chip")
	_check(chip >= 0 and sk.get_bone_name(sk.get_bone_parent(chip)) == "hand_R", "%s: chip prop bone on hand_R" % name)
	var length := ap.get_animation("idle").length
	var worst_mirror := 1.0
	var worst_down := 1.0
	for k in 7:
		ap.play("idle")
		ap.seek(length * k / 6.0, true)
		ap.pause()
		var hl := sk.get_bone_global_pose(sk.find_bone("hand_L")).basis
		var hr := MX * sk.get_bone_global_pose(sk.find_bone("hand_R")).basis * MX
		for ax in 3:
			worst_mirror = minf(worst_mirror, hl[ax].normalized().dot(hr[ax].normalized()))
		var up := sk.get_bone_global_pose(sk.find_bone("chest")).basis.y.normalized()
		for s in ["L", "R"]:
			worst_down = minf(worst_down, -_palm(sk, s).dot(up))
	_check(worst_mirror >= MIN_MIRROR_DOT, "%s idle: left hand mirrors right (worst axis dot %.2f >= %.2f)" % [name, worst_mirror, MIN_MIRROR_DOT])
	_check(worst_down >= MIN_PALM_DOWN, "%s idle: both palms face down on the rail (worst %.2f >= %.2f)" % [name, worst_down, MIN_PALM_DOWN])
	print("  %s idle: mirror dot %.2f, palm-down %.2f" % [name, worst_mirror, worst_down])
	var hv := _hand_verts(b, sk)
	for side in ["L", "R"]:
		for f in ["index_", "fingers_"]:
			var c := _curl(sk, hv, f + side, side)
			_check(c >= CURL_MIN and c <= CURL_MAX, "%s %s%s: relaxed finger curl %.0f deg in [%.0f, %.0f]" % [name, f, side, c, CURL_MIN, CURL_MAX])
	var worst_wrist := 0.0
	var worst_wrist_at := ""
	for clip in DEALER_CLIPS:
		var a := ap.get_animation(clip)
		var t := 0.0
		while t <= a.length + 0.001:
			ap.play(clip)
			ap.seek(t, true)
			for side in ["L", "R"]:
				var fa := sk.get_bone_global_pose(sk.find_bone("forearm_" + side)).basis.y.normalized()
				var hd := sk.get_bone_global_pose(sk.find_bone("hand_" + side)).basis.y.normalized()
				var ang := rad_to_deg(fa.angle_to(hd))
				if ang > worst_wrist:
					worst_wrist = ang
					worst_wrist_at = "%s %s @%.1f" % [clip, side, t]
			t += 0.1
	_check(worst_wrist <= WRIST_MAX, "%s: wrist bend <= %.0f deg in every dealer clip (worst %.1f %s)" % [name, WRIST_MAX, worst_wrist, worst_wrist_at])
	var worst_clear := INF
	var worst_clear_at := ""
	for clip in ["idle", "deal"]:
		var a := ap.get_animation(clip)
		var t := 0.0
		while t <= a.length + 0.001:
			ap.play(clip)
			ap.seek(t, true)
			for bn: String in hv:
				var g := sk.get_bone_global_pose(sk.find_bone(bn))
				for v: Vector3 in hv[bn]:
					var q := g * v
					var depth := q.z - RAIL_Z0
					if depth <= 0.0:
						continue
					var gap := q.y - (RAIL_Y if depth < RAIL_DEPTH else FELT_Y)
					if gap < worst_clear:
						worst_clear = gap
						worst_clear_at = "%s %s @%.1f" % [clip, bn, t]
			t += 0.1
	_check(worst_clear >= 0.0, "%s: idle / deal hands + fingers never sink into the rail or felt (min clearance %.3f m %s)" % [name, worst_clear, worst_clear_at])
	print("  %s: wrist max %.1f deg (%s), rail clearance %.3f m (%s)" % [name, worst_wrist, worst_wrist_at, worst_clear, worst_clear_at])
	b.queue_free()
	await process_frame


## Hand + finger vertices per bone, in each bone's rest (bind) space: {bone: PackedVector3Array}. The dealers are
## rigid-skinned, so each vertex follows its heaviest bone.
func _hand_verts(b: Node3D, sk: Skeleton3D) -> Dictionary:
	var out := {}
	for mi: MeshInstance3D in b.find_children("*", "MeshInstance3D", true, false):
		if mi.skin == null or mi.mesh == null:
			continue
		var names := {}
		for i in mi.skin.get_bind_count():
			var nm := String(mi.skin.get_bind_name(i))
			if nm == "":
				nm = sk.get_bone_name(mi.skin.get_bind_bone(i))
			names[i] = nm
		for si in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(si)
			var vs := arr[Mesh.ARRAY_VERTEX] as PackedVector3Array
			var bo = arr[Mesh.ARRAY_BONES]
			var we = arr[Mesh.ARRAY_WEIGHTS]
			if bo == null or we == null:
				continue
			var per := (bo.size() / vs.size()) as int
			for vi in vs.size():
				var best := 0
				for k in per:
					if we[vi * per + k] > we[vi * per + best]:
						best = k
				var nm: String = names.get(int(bo[vi * per + best]), "")
				if nm.begins_with("hand_") or nm.begins_with("index_") or nm.begins_with("fingers_") or nm.begins_with("thumb_"):
					if not out.has(nm):
						out[nm] = PackedVector3Array()
					out[nm].append(mi.skin.get_bind_pose(int(bo[vi * per + best])) * vs[vi])
	return out


## Chord curl of a finger bone's mesh, in the hand's rest frame: angle from the hand's long axis toward the palm.
func _curl(sk: Skeleton3D, hv: Dictionary, bone: String, side: String) -> float:
	if not hv.has(bone):
		return -1.0
	var hr := sk.get_bone_global_rest(sk.find_bone("hand_" + side))
	var fr := sk.get_bone_global_rest(sk.find_bone(bone))
	var to_hand := hr.affine_inverse() * fr
	var ax := (to_hand.origin).normalized()  # wrist -> knuckle: the hand's long axis (bone rests are unrotated)
	var palm := hr.basis.inverse() * Vector3(-1.0 if side == "L" else 1.0, 0, 0)
	palm = (palm - ax * palm.dot(ax)).normalized()
	var pts: Array[Vector3] = []
	for v: Vector3 in hv[bone]:
		pts.append(to_hand * v)
	pts.sort_custom(func(p: Vector3, q: Vector3) -> bool: return p.dot(ax) < q.dot(ax))
	var n := maxi(1, pts.size() / 10)
	var base := Vector3.ZERO
	for i in n:
		base += pts[i]
	base /= n
	var tip := pts[0]
	for p in pts:  # fingertip: farthest from the knuckle ring
		if p.distance_to(base) > tip.distance_to(base):
			tip = p
	var d := tip - base
	return rad_to_deg(atan2(d.dot(palm), d.dot(ax)))
