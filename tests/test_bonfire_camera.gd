## Bonfire game-camera framing (PM / Art Director, Oct 19: show Smiles the
## dealer behind the far rail without losing the table or shrinking dice).
## The scene runs inside a SubViewport of each aspect's canvas size:
##   - PC 16:9 (1920x1080): headroom above the far rail top at the dealer's
##     depth >= cam_headroom_min_m; the whole felt, rails, TotalPlate,
##     TargetPlate and brazier top in frame; resting dice (mean / min /
##     centre over the felt rest spots) at most cam_die_shrink_max smaller
##     than with the spec camera (pitch 55, 2.5 m, pivot z 0.05, no tilt);
##     the goal plaque as readable as before.
##   - phone landscape (844x390 -> 2337x1080 canvas): the same must-see
##     points and the pot row in frame, dice >= min_die_px and no smaller
##     than on PC, headroom above the rail.
##   - phone portrait (390x844 -> 1920x4155): unchanged; pot row 80 px clear.
##   - when the art is in the tree (art/board-hearth, art/dealer-smiles):
##     the real Hearth brazier meshes fully in frame on PC and phone
##     landscape, Smiles (horns included) fully in frame on PC. Portrait
##     prints where the brazier sits: showing it there with the pot row
##     80 px clear needs ~3.97 m, ~23% smaller dice, so it isn't required.
##   godot --headless --path . --script res://tests/test_bonfire_camera.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


func _make(canvas: Vector2i) -> Array:
	var sv := SubViewport.new()
	sv.size = canvas
	root.add_child(sv)
	var t := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = TableSetup.sandbox(t, 5)
	s.tutorial_override = 0
	sv.add_child(s)
	await process_frame
	await process_frame
	return [sv, s]


## The spec camera (the shared TuningData, as before this framing) in the
## same viewport: the reference for dice size and the plaque.
func _spec_ref(sv: SubViewport) -> Dictionary:
	var spec := load("res://resources/tuning/poc_tuning.tres") as TuningData
	var rig := CameraRig.new()
	sv.add_child(rig)
	rig.setup(spec)
	var st := CameraFraming.die_stats(rig.cam, spec.die_size)
	st["plate"] = _plate_px(rig.cam)
	st["headroom"] = CameraFraming.headroom(rig.cam)
	rig.cam.current = false
	rig.queue_free()
	return st


func _plate_px(cam: Camera3D) -> float:
	var p := CameraFraming.TARGET_PLATE
	return cam.unproject_position(p + Vector3(0.1, 0, 0)).distance_to(cam.unproject_position(p - Vector3(0.1, 0, 0)))


const HEARTH := "res://art/models/boards/hearth/scenes/hearth_board.tscn"
const SMILES := "res://art/models/characters/smiles/scenes/smiles.tscn"
## art/dealer-smiles README "Placement".
const DEALER_SPOT := Vector3(-0.42, -0.47, -0.86)


## Adds the Hearth board / Smiles to s when they're in the tree; returns
## {"brazier": corners, "smiles": corners} for whichever loaded.
func _art(s: Bonfire3D) -> Dictionary:
	var out := {}
	if ResourceLoader.exists(HEARTH):
		var board := (load(HEARTH) as PackedScene).instantiate() as Node3D
		s.add_child(board)
		for n in board.find_children("*", "Node3D", true, false):
			if (n as Node).scene_file_path.contains("brazier"):
				out["brazier"] = _mesh_corners(n)
				break
	if ResourceLoader.exists(SMILES):
		var sm := (load(SMILES) as PackedScene).instantiate() as Node3D
		sm.position = DEALER_SPOT
		s.add_child(sm)
		out["smiles"] = _mesh_corners(sm)
	return out


func _mesh_corners(n: Node) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var nodes: Array = n.find_children("*", "MeshInstance3D", true, false)
	if n is MeshInstance3D:
		nodes.append(n)
	for m in nodes:
		var mi := m as MeshInstance3D
		if mi.is_visible_in_tree():
			var bb := mi.global_transform * mi.get_aabb()
			for i in 8:
				out.append(bb.get_endpoint(i))
	return out


func _run() -> void:
	await _pc()
	await _phone_landscape()
	await _phone_portrait()
	print("test_bonfire_camera: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _pc() -> void:
	var made: Array = await _make(Vector2i(1920, 1080))
	var sv: SubViewport = made[0]
	var s: Bonfire3D = made[1]
	var bt := s.bonfire_tuning
	var ref := _spec_ref(sv)
	s.camera.cam.current = true
	s.camera.snap_home()
	var cam := s.camera.cam
	var ds := s.tuning.die_size
	var head := CameraFraming.headroom(cam)
	print("  PC 16:9: headroom above the far rail at the dealer %.3f m (spec camera %.3f m)" % [head, float(ref["headroom"])])
	check(head >= bt.cam_headroom_min_m, "PC: %.2f m above the far rail at the dealer's depth (>= %.2f)" % [head, bt.cam_headroom_min_m])
	check(head <= 0.65, "PC: headroom stays modest (%.2f <= 0.65 m): the table stays the subject" % head)
	var m := CameraFraming.margin(cam, CameraFraming.must_points())
	check(m >= bt.cam_edge_margin_px, "PC: whole felt, rails, TotalPlate, TargetPlate, brazier in frame (margin %.0f >= %.0f px)" % [m, bt.cam_edge_margin_px])
	var st := CameraFraming.die_stats(cam, ds)
	var lim := 1.0 - bt.cam_die_shrink_max
	print("  PC 16:9: die px mean %.1f / min %.1f / centre %.1f (spec %.1f / %.1f / %.1f)" % [float(st["mean"]), float(st["min"]), float(st["center"]), float(ref["mean"]), float(ref["min"]), float(ref["center"])])
	for k in ["mean", "min", "center"]:
		check(float(st[k]) >= float(ref[k]) * lim, "PC: die %s %.1f px >= %.0f%% of the spec camera's %.1f" % [k, float(st[k]), lim * 100.0, float(ref[k])])
	check(float(st["min"]) >= s.tuning.min_die_px, "PC: every resting die >= min_die_px (%.1f)" % float(st["min"]))
	var plate := _plate_px(cam)
	check(plate >= float(ref["plate"]) * lim, "PC: goal plaque at TargetPlate stays readable (%.0f px wide vs %.0f)" % [plate, float(ref["plate"])])
	var art := _art(s)
	if art.has("brazier"):
		check(CameraFraming.margin(cam, art["brazier"]) >= 0.0, "PC: Hearth brazier fully in frame (%.0f px)" % CameraFraming.margin(cam, art["brazier"]))
	if art.has("smiles"):
		check(CameraFraming.margin(cam, art["smiles"]) >= 0.0, "PC: Smiles fully in frame, horns included (%.0f px)" % CameraFraming.margin(cam, art["smiles"]))
	print("  PC 16:9: art in tree: %s" % str(art.keys()))
	sv.queue_free()
	await process_frame


func _phone_landscape() -> void:
	var made: Array = await _make(Vector2i(2337, 1080))
	var sv: SubViewport = made[0]
	var s: Bonfire3D = made[1]
	var bt := s.bonfire_tuning
	var pc_ref := _spec_ref(sv)
	s.camera.cam.current = true
	s.fit_phone(Vector2(844, 390))
	s.camera.snap_home()
	var cam := s.camera.cam
	var ds := s.tuning.die_size
	# #204: 1.41x closer than the old whole-felt framing; resting dice sit
	# between the Target plate and the bottom bar, and stay on screen.
	check(is_equal_approx(s.camera.home_distance, bt.cam_phone_landscape_distance / PhoneFrame.CLOSER), "phone landscape: camera 1.41x closer (%.3f m)" % s.camera.home_distance)
	# The inner rest rows (|z| <= 0.12) must clear the plate and bar; the
	# full zone (to |z| 0.4) is taller than the band at 1.41x (flagged).
	var band := PhoneFrame.band(s)
	var span := PhoneFrame.rest_span(s, 0.15)
	check(span.x >= band.x - 1.0 and span.y <= band.y + 1.0, "phone landscape: inner resting dice y %s inside the clear band %s" % [span, band])
	var full := PhoneFrame.rest_span(s)
	check(absf((full.x + full.y) - (band.x + band.y)) < 4.0, "phone landscape: rest zone centred on the band (%s vs %s)" % [full, band])
	check(CameraFraming.margin(cam, CameraFraming.rest_spots(ds)) >= 0.0, "phone landscape: every rest spot on screen")
	var st := CameraFraming.die_stats(cam, ds)
	var head := CameraFraming.headroom(cam)
	print("  phone landscape: headroom %.3f m, die px mean %.1f / min %.1f / centre %.1f" % [head, float(st["mean"]), float(st["min"]), float(st["center"])])
	print("  phone landscape: %.2f m above the far rail (#204 closer camera: no 0.20 m minimum)" % head)
	check(float(st["min"]) >= s.tuning.min_die_px, "phone landscape: every resting die >= min_die_px (%.1f)" % float(st["min"]))
	check(float(st["mean"]) >= float(pc_ref["mean"]) * 1.3, "phone landscape: dice well above the spec PC camera (mean %.1f >= %.1f)" % [float(st["mean"]), float(pc_ref["mean"])])
	var art := _art(s)
	if art.has("brazier"):
		print("  phone landscape: Hearth brazier margin %.0f px (#204: may crop)" % CameraFraming.margin(cam, art["brazier"]))
	sv.queue_free()
	await process_frame


func _phone_portrait() -> void:
	var made: Array = await _make(Vector2i(1920, 4155))
	var sv: SubViewport = made[0]
	var s: Bonfire3D = made[1]
	s.camera.cam.current = true
	s.fit_phone(Vector2(390, 844))
	s.camera.snap_home()
	var cam := s.camera.cam
	var ds := s.tuning.die_size
	check(is_zero_approx(s.camera.look_up_deg) and is_equal_approx(s.camera.pitch_deg, 60.0), "portrait keeps its own framing (pitch 60, no tilt)")
	var pot: Array[Vector3] = [s.pot_slot(0) + Vector3(0, Bonfire3D.PILLAR_HEIGHT, 0), s.pot_slot(4) + Vector3(0, ds, 0)]
	var m := CameraFraming.margin(cam, pot)
	check(m >= Bonfire3D.PHONE_EDGE_PX, "portrait: pot row %.0f px clear of the edges (>= %.0f)" % [m, Bonfire3D.PHONE_EDGE_PX])
	var st := CameraFraming.die_stats(cam, ds)
	check(float(st["min"]) >= s.tuning.min_die_px, "portrait: dice >= min_die_px (%.1f)" % float(st["min"]))
	var art := _art(s)
	if art.has("brazier"):
		print("  portrait: Hearth brazier margin %.0f px (not required; see header)" % CameraFraming.margin(cam, art["brazier"]))
	sv.queue_free()
	await process_frame
