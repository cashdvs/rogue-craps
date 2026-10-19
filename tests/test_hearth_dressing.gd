## Headless test: the Hearth set dressing + ambient motion (detail pass, Oct 19;
## art/concept/bonfire_table/hearth_detail_pass.md). Art only: Hearth/Dressing (hearth_dressing.gd) under the
## Hearth hub. The image / resource-level looks (felt wear, inks, colours, the unlit-light ceiling) are in
## test_hearth_dressing_looks.gd. Checks, for PC and mobile:
##   budget     drawn tris with the dressing on (tail out: the worst frame) <= 15k / 8k; off = the pre-pass board;
##              trinkets are PC only (mobile LOD).
##   clearance  no dressing vertex over the felt / inside the rail centrelines (at rest and at every sampled
##              frame of the tail / chain / bell clips), nothing above 0.25 m but the motes and the backdrop
##              card (which stands far behind Smiles); motes, tail, chain and bell never project over the
##              felt from the game camera (PC 16:9 and phone landscape), and the bell never covers Smiles' face.
##   toggle     Hearth.dressing off -> exactly Board A's looks (hearth_felt / hearth_leather, Visual/Trim shown,
##              Dressing hidden); on -> worn felt, carved rails, worn studs; ambient off -> motes hidden, clips stop.
##   motion     clip lengths, peek interval 8-15 s, clips key only the pose params, the tail peeks on schedule
##              and whips back + stays in while scoring, rail_hit sways the chain, eyes 3 rattles the bell.
##
## Run:
##   godot --headless --path . --script res://tests/test_hearth_dressing.gd
extends SceneTree

const H := "res://art/models/boards/hearth/"
const FELT_HALF := Vector2(1.02, 0.52)
const RAIL_R := 0.09
const EPS := 0.0015
const DEALER_FACE := Vector3(-0.42, 0.2, -0.86)
const DEALER_FACE_R := 0.11
const POSE_PARAMS: Array[String] = ["tail_out", "tail_sway", "tail_curl", "chain_swing", "bell_shake"]

var _passed := 0
var _failed := 0


func _initialize() -> void:
	print("=== Dice of the Damned: Hearth set dressing tests ===")
	_run.call_deferred()


func _run() -> void:
	for mobile in [false, true]:
		await _check_board(mobile)
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# --- cameras -----------------------------------------------------------------------------------------

## The game cameras, read from the game's own camera code rather than hardcoded: a CameraRig set up like
## Bonfire3D (TuningData + BonfireTuning "Game camera"), PC 16:9 at the home framing and phone landscape
## (844x390) at cam_phone_landscape_distance / _pivot. [name, camera transform, aspect, fov]
var _cam_cache: Array = []


func _cams() -> Array:
	if not _cam_cache.is_empty():
		return _cam_cache
	var bt := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var t := (load("res://resources/tuning/poc_tuning.tres") as TuningData).duplicate() as TuningData
	t.cam_pitch_deg = bt.cam_pitch_deg
	t.cam_distance = bt.cam_distance
	t.cam_pivot = bt.cam_pivot
	t.cam_look_up_deg = bt.cam_look_up_deg
	for spec in [["pc", Vector2(1920, 1080)], ["phone", Vector2(844, 390)]]:
		var rig := CameraRig.new()
		root.add_child(rig)
		rig.setup(t)
		if spec[0] == "phone":
			rig.fit_viewport(spec[1])
			rig.home_distance = bt.cam_phone_landscape_distance
			rig.distance = rig.home_distance
			rig.home_pivot = bt.cam_phone_landscape_pivot
			rig.position = rig.home_pivot
			rig._apply()
		var size: Vector2 = spec[1]
		_cam_cache.append([spec[0], rig.cam.global_transform, size.x / size.y, rig.cam.fov])
		root.remove_child(rig)
		rig.free()
	return _cam_cache


## True when p is above the felt plane and the camera ray through it lands on the felt (p is drawn over
## the play area). Points below the felt plane that project inside it are hidden by the table.
func _over_felt(cam: Transform3D, p: Vector3) -> bool:
	if p.y <= 0.0:
		return false
	var o := cam.origin
	var dir := p - o
	if dir.y >= -1e-6:
		return false
	var t := -o.y / dir.y
	var hit := o + dir * t
	return absf(hit.x) < FELT_HALF.x and absf(hit.z) < FELT_HALF.y


func _ndc(c: Array, p: Vector3) -> Vector2:
	var tn := tan(deg_to_rad(float(c[3])) * 0.5)
	var v := (c[1] as Transform3D).affine_inverse() * p
	var aspect: float = c[2]
	return Vector2(v.x / (-v.z * tn * aspect), v.y / (-v.z * tn))


func _check_board(mobile: bool) -> void:
	var label := "hearth_board%s" % ("_mobile" if mobile else "")
	var budget := 8000 if mobile else 15000
	var board := (load(H + "scenes/%s.tscn" % label) as PackedScene).instantiate() as Node3D
	var fx := board.get_node("Hearth")
	var d := board.get_node_or_null("Hearth/Dressing") as Node3D
	_check(d != null, label + ": Hearth/Dressing present")
	if d == null:
		board.free()
		return
	for h in ["dressing", "ambient", "scoring"]:
		_check(h in fx, "%s: hook Hearth.%s" % [label, h])
	_check(fx.has_method("rail_hit") and fx.has_method("bell_ring"), label + ": hooks Hearth.rail_hit() / bell_ring()")
	_check((d.get_node_or_null("Trinkets") != null) == (not mobile), label + (": trinkets LOD (mobile drops them)" if mobile else ": PC trinkets present"))
	for n in ["Corners", "Under", "Studs", "Bell/Model", "Chain/Model", "Tail/Root/Model", "Tail/Root/Joint/Tip/Model", "Ambient/EmbersBrazier", "Ambient/EmbersCauldron", "Ambient/LampDust", "Backdrop", "TailPlayer", "ChainPlayer", "BellPlayer"]:
		_check(d.get_node_or_null(n) != null, "%s: Dressing/%s" % [label, n])
	# clips (resource level)
	var tp := d.get_node("TailPlayer") as AnimationPlayer
	var cp := d.get_node("ChainPlayer") as AnimationPlayer
	var bp := d.get_node("BellPlayer") as AnimationPlayer
	_check(tp.has_animation("tail_peek") and absf(tp.get_animation("tail_peek").length - 1.8) < 0.01 and tp.has_animation("tail_whip") and tp.has_animation("RESET"), label + ": TailPlayer tail_peek 1.8 s / tail_whip / RESET")
	_check(cp.has_animation("chain_sway") and absf(cp.get_animation("chain_sway").length - 0.4) < 0.01, label + ": ChainPlayer chain_sway 0.4 s")
	_check(bp.has_animation("bell_rattle") and absf(bp.get_animation("bell_rattle").length - 0.5) < 0.01, label + ": BellPlayer bell_rattle 0.5 s")
	_check(float(d.get("peek_min")) == 8.0 and float(d.get("peek_max")) == 15.0, label + ": tail peeks every 8-15 s")
	var keys_ok := true
	var twos_ok := true
	var keyed := ""
	for ap: AnimationPlayer in [tp, cp, bp]:
		for clip in ap.get_animation_list():
			var an := ap.get_animation(clip)
			for t in an.get_track_count():
				var path := str(an.track_get_path(t))
				keyed += path + " "
				if not path.begins_with(".:") or not POSE_PARAMS.has(path.substr(2)):
					keys_ok = false
				if an.value_track_get_update_mode(t) != Animation.UPDATE_DISCRETE:
					twos_ok = false
	_check(keys_ok, label + ": dressing clips key only the pose params (" + keyed.strip_edges() + ")")
	_check(twos_ok, label + ": dressing clips are drawn on twos (discrete keys)")
	_check(not d.get_node("Tail").visible, label + ": the tail rests folded away (hidden) under the table")
	# --- in the tree ---
	root.add_child(board)
	await process_frame
	# budget: worst frame = tail out
	d.set("tail_out", 1.0)
	var on := _drawn_tris(board)
	d.set("tail_out", 0.0)
	_check(on <= budget, "%s: dressing on, tail out: %d tris <= %d" % [label, on, budget])
	print("  info %s tris dressing on %d (tail out), dressing %d" % [label, on, _drawn_tris(d)])
	# clearance at rest and over every sampled clip frame
	var res := {"keep": true, "height": true, "felt": true, "face": true, "bad": "", "fbad": ""}
	_scan(board, d, res)
	for spec in [[tp, "tail_peek"], [tp, "tail_whip"], [cp, "chain_sway"], [bp, "bell_rattle"]]:
		var ap: AnimationPlayer = spec[0]
		ap.play(spec[1])
		var ln := ap.get_animation(spec[1]).length
		var t := 0.0
		while t <= ln + 0.001:
			ap.seek(t, true)
			_scan(board, d, res, true)
			t += 1.0 / 24.0
		ap.stop()
	d.set("tail_out", 0.0)
	d.set("chain_swing", 0.0)
	d.set("bell_shake", 0.0)
	# extreme poses (beyond the clip values)
	for pose in [{"tail_out": 1.0, "tail_sway": 1.0, "tail_curl": 1.0}, {"tail_out": 1.0, "tail_sway": -1.0, "tail_curl": -1.0}, {"chain_swing": 1.0}, {"chain_swing": -1.0}, {"bell_shake": 1.0}, {"bell_shake": -1.0}]:
		for k in pose:
			d.set(k, pose[k])
		_scan(board, d, res, true)
		for k in pose:
			d.set(k, 0.0)
	_check(res.keep, "%s: no dressing geometry over the felt / inside the rail centrelines, at rest or animated %s" % [label, res.bad])
	_check(res.height, "%s: dressing geometry under 0.25 m (motes + backdrop card excepted) %s" % [label, res.bad])
	_check(res.felt, "%s: motes, dust, tail, chain and bell never project over the felt from the game camera (PC + phone) %s" % [label, res.fbad])
	_check(res.face, label + ": the service bell never covers Smiles' face from the game camera")
	_check_motes(label, board, d)
	# toggle
	fx.set("dressing", false)
	var off := _drawn_tris(board)
	var felt := _mesh(board.get_node("Visual/Floor"))
	var rails := _mesh(board.get_node("Visual/Rails"))
	var trim := board.get_node("Visual/Trim") as Node3D
	_check(not d.visible and trim.visible and _mat(felt).ends_with("hearth_felt.tres") and _mat(rails).ends_with("hearth_leather.tres"),
		label + ": dressing off -> Board A looks (hearth_felt, hearth_leather, Trim shown, Dressing hidden)")
	var pre := _prepass_tris(label)
	_check(off == pre, "%s: dressing off draws exactly the pre-pass board (%d tris = %d)" % [label, off, pre])
	print("  info %s tris dressing off %d" % [label, off])
	d.rail_hit(1.0)
	_check(not cp.is_playing(), label + ": dressing off: rail_hit does nothing")
	fx.set("dressing", true)
	_check(d.visible and not trim.visible and _mat(felt).ends_with("hearth_felt_worn.tres") and _mat(rails).ends_with("hearth_leather_carved.tres") and (d.get_node("Studs") as Node3D).visible,
		label + ": dressing on -> worn felt, carved rails, worn studs (Board A trim hidden)")
	# motion behaviour
	d.call("set_next_peek", 0.01)
	for i in 3:
		await process_frame
	_check(tp.is_playing() and tp.current_animation == "tail_peek", label + ": the tail peeks when its timer runs out")
	tp.seek(0.6, true)
	_check(d.get_node("Tail").visible and float(d.get("tail_out")) > 0.9, label + ": mid-peek the tail is out (tail_out 1)")
	fx.set("scoring", true)
	_check(tp.current_animation == "tail_whip", label + ": scoring starts -> the tail whips back")
	tp.seek(tp.get_animation("tail_whip").length, true)
	tp.stop(true)
	_check(not d.get_node("Tail").visible, label + ": after the whip the tail is hidden")
	d.call("set_next_peek", 0.01)
	for i in 3:
		await process_frame
	_check(not tp.is_playing(), label + ": no tail peek while scoring")
	fx.set("scoring", false)
	fx.rail_hit(1.0)
	_check(cp.is_playing() and cp.current_animation == "chain_sway", label + ": Hearth.rail_hit() sways the chain")
	cp.seek(0.0, true)
	_check(absf((d.get_node("Chain") as Node3D).rotation_degrees.x) > 3.0, label + ": the chain swings on the hit")
	cp.stop()
	fx.set("eyes", 3)
	_check(bp.is_playing() and bp.current_animation == "bell_rattle", label + ": Hot Hand (eyes 3) rattles Smiles' bell")
	bp.stop()
	fx.set("eyes", 0)
	fx.set("ambient", false)
	fx.rail_hit(1.0)
	_check(not (d.get_node("Ambient") as Node3D).visible and not cp.is_playing() and d.visible, label + ": ambient off -> motes hidden, no clips, dressing stays")
	fx.set("ambient", true)
	root.remove_child(board)
	board.free()


## Motes: 6-10 embers on screen (PC), the motion volumes (from the shader params) stay off the felt.
func _check_motes(label: String, board: Node3D, d: Node3D) -> void:
	var n := 0
	for k in ["EmbersBrazier", "EmbersCauldron"]:
		var mi := d.get_node("Ambient/" + k) as MeshInstance3D
		n += (mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 6
	_check(n >= 6 and n <= 10, "%s: %d ember motes (6-10)" % [label, n])
	var ok := true
	var bad := ""
	for k in ["EmbersBrazier", "EmbersCauldron", "LampDust"]:
		var mi := d.get_node("Ambient/" + k) as MeshInstance3D
		var m := mi.material_override as ShaderMaterial
		var o := mi.global_transform.origin
		var pts: Array[Vector3] = []
		if k == "LampDust":
			var box: Vector3 = m.get_shader_parameter("box")
			var hb := box * 0.5
			for sx in [-1, 1]:
				for sy in [-1, 1]:
					for sz in [-1, 1]:
						pts.append(o + Vector3(sx * hb.x, sy * hb.y, sz * hb.z))
		else:
			var r := _param(m, "radius") + _param(m, "drift")
			var rise := _param(m, "rise")
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					for y in [0.0, rise * 0.5, rise]:
						pts.append(o + Vector3(sx * r, y, sz * _param(m, "radius")))
		for cam in _cams():
			for p in pts:
				if _over_felt(cam[1], p):
					ok = false
					bad = "%s %s (%s)" % [k, p, cam[0]]
	_check(ok, "%s: ember + dust motion volumes never project over the felt (PC + phone) %s" % [label, bad])


func _scan(board: Node3D, d: Node3D, res: Dictionary, moving_only: bool = false) -> void:
	var meshes: Array[MeshInstance3D] = []
	if moving_only:
		for n in ["Tail", "Chain", "Bell"]:
			_collect(d.get_node(n), meshes)
	else:
		_collect(d, meshes)
	var cams := _cams()
	for mi in meshes:
		if not mi.is_visible_in_tree():
			continue
		var path := str(d.get_path_to(mi))
		if path.begins_with("Ambient") or path == "Backdrop":
			continue
		var moving := path.begins_with("Tail") or path.begins_with("Chain") or path.begins_with("Bell")
		var xf := mi.global_transform
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for s in mi.mesh.get_surface_count():
			var verts := mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array
			for i in verts.size():
				var w := xf * verts[i]
				if w.y > 0.25 + EPS:
					res.height = false
					res.bad = "%s %s" % [path, w]
				if w.y > EPS and _inside_rail_line(w):
					res.keep = false
					res.bad = "%s %s" % [path, w]
				if moving and i % 3 == 0:
					for c in cams:
						if _over_felt(c[1], w):
							res.felt = false
							res.fbad = "%s %s (%s)" % [path, w, c[0]]
					if path.begins_with("Bell"):
						var q := _ndc(cams[0], w)
						lo = lo.min(q)
						hi = hi.max(q)
		if path.begins_with("Bell"):
			var c0: Array = cams[0]
			var f0 := _ndc(c0, DEALER_FACE + Vector3(-DEALER_FACE_R, -DEALER_FACE_R, 0))
			var f1 := _ndc(c0, DEALER_FACE + Vector3(DEALER_FACE_R, DEALER_FACE_R, 0))
			var face := Rect2(f0.min(f1), (f1 - f0).abs())
			if Rect2(lo, hi - lo).intersects(face):
				res.face = false


## The same board without the dressing at all (Dressing removed, Board A trim shown), in the tree.
func _prepass_tris(label: String) -> int:
	var b := (load(H + "scenes/%s.tscn" % label) as PackedScene).instantiate() as Node3D
	var dn := b.get_node("Hearth/Dressing")
	dn.get_parent().remove_child(dn)
	dn.free()
	(b.get_node("Visual/Trim") as Node3D).visible = true
	root.add_child(b)
	var t := _drawn_tris(b)
	root.remove_child(b)
	b.free()
	return t


func _drawn_tris(n: Node) -> int:
	var meshes: Array[MeshInstance3D] = []
	_collect(n, meshes)
	var t := 0
	for mi in meshes:
		if not mi.is_visible_in_tree():
			continue
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var idx: Variant = arr[Mesh.ARRAY_INDEX]
			t += ((idx as PackedInt32Array).size() if idx != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return t


func _mat(mi: MeshInstance3D) -> String:
	var m := mi.get_active_material(0)
	return m.resource_path if m != null else ""


func _param(m: ShaderMaterial, n: String) -> float:
	if m == null:
		return 0.0
	var v: Variant = m.get_shader_parameter(n)
	if v == null:
		var re := RegEx.create_from_string("uniform float " + n + "[^=;]*=\\s*([0-9.]+)")
		var r := re.search(m.shader.code)
		return 0.0 if r == null else float(r.get_string(1))
	return float(v)


func _inside_rail_line(p: Vector3) -> bool:
	var ax := absf(p.x)
	var az := absf(p.z)
	if ax >= FELT_HALF.x + RAIL_R - EPS or az >= FELT_HALF.y + RAIL_R - EPS:
		return false
	if ax > FELT_HALF.x and az > FELT_HALF.y:
		return Vector2(ax - FELT_HALF.x, az - FELT_HALF.y).length() < RAIL_R - EPS
	return true


func _collect(n: Node, out: Array[MeshInstance3D]) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out.append(n)
	for c in n.get_children():
		_collect(c, out)


func _mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var m := _mesh(c)
		if m != null:
			return m
	return null


func _check(cond: bool, name: String) -> void:
	if cond:
		_passed += 1
		print("  ok   ", name)
	else:
		_failed += 1
		print("  FAIL ", name)
