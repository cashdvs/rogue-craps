## Additive finite-solid rail oracle. Does not edit legacy suites and does not
## accept a skin-contact band.  Samples are not continuous motion, not blends,
## not taunt-to-idle, and not a Vulkan readback.
##
## Frozen V194 (61619e9) and the V188 checkpoint are not in this remote. Their
## head meshes are not substituted. Published witness POINTS are tested against
## this tree's Hearth rails only when the rail triangle count matches QA.
##
##   godot --headless --path . --script res://tests/test_dealer_rail_oracle.gd
extends SceneTree

const Hearth := "res://art/models/boards/hearth/scenes/hearth_board.tscn"
const SMILES := "res://art/models/characters/smiles/scenes/smiles.tscn"

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
	print("=== dealer rail oracle (additive, not accepted) ===")
	print("--- section: collision-oracle tool (synthetic boxes only; not V188/V194) ---")
	_synthetics()
	print("--- section: production-seat naming ---")
	_preconditions()
	print("--- section: integration-policy proposal (not accepted) ---")
	_legacy_map()
	print("--- section: this-tree Smiles sample (not frozen V194) ---")
	await _rails_and_original_smiles()
	print("--- section: frozen-asset gaps (unavailable is a failure) ---")
	_frozen_art_gap()
	print("=== %d passed, %d failed ===" % [_pass, _fail])
	print("COVERAGE sampled key times only; not 60 Hz, not swept, not blend/reset/autoplay.")
	quit(0 if _fail == 0 else 1)


func _box(at: Vector3) -> Dictionary:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1, 1, 1)
	mi.mesh = mesh
	mi.position = at
	root.add_child(mi)
	return DealerRailSolid.from_mesh_root(mi)


func _synthetics() -> void:
	var solid := _box(Vector3.ZERO)
	_check(bool(solid["ok"]), "unit box is a closed solid (%s)" % solid.get("reason", ""))
	_check(DealerRailSolid.point_vs_solid(Vector3.ZERO, solid) == "inside", "box centre is inside")
	_check(DealerRailSolid.point_vs_solid(Vector3(0, -1.2, 0), solid) == "outside", "below the bottom is not a collision")
	_check(DealerRailSolid.point_vs_solid(Vector3(0, 0.2, 3), solid) == "outside", "outside the footprint is not a collision")
	var open := DealerRailSolid.from_triangles([[Vector3.ZERO, Vector3(1, 0, 0), Vector3(0, 1, 0)]])
	_check(not bool(open["ok"]) and open["reason"] == "open_or_nonmanifold", "one triangle is not a solid")
	var bad := DealerRailSolid.from_triangles([[Vector3(INF, 0, 0), Vector3(1, 0, 0), Vector3(0, 1, 0)]])
	_check(not bool(bad["ok"]) and bad["reason"] == "nonfinite", "non-finite vertex fails closed")
	_check(not bool(DealerRailSolid.from_mesh_root(null)["ok"]), "missing mesh fails closed")
	var other := _box(Vector3(0.25, 0, 0))
	var hit := DealerRailSolid.compare(solid["tris"], other, {}, false)
	_check(hit["status"] == "hit" and int(hit["inside_skin"]) > 0, "overlap contains a corner of the other box (%s)" % str(hit))
	var stab: Array = [Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(0.15, 0.12, 1)]
	var stabbed := false
	for tri in solid["tris"]:
		if DealerRailSolid.triangle_relation(stab[0], stab[1], stab[2], tri[0], tri[1], tri[2]) == "transverse":
			stabbed = true
			break
	_check(stabbed, "a triangle through the box centre is a transverse crossing")
	var far := _box(Vector3(4, 0, 0))
	var clear := DealerRailSolid.compare(solid["tris"], far, {}, false)
	_check(clear["status"] == "clear", "separated boxes are clear (%s)" % clear)
	# Strict interior with no skin triangle at all: the point query itself.
	_check(DealerRailSolid.point_vs_solid(Vector3(0.1, 0.1, 0.1), solid) == "inside", "a contained point fails even without a crossing query")
	var both := Transform3D(Basis.IDENTITY, Vector3(5, 1, -2))
	var moved_rail := DealerRailSolid.from_triangles(_apply(other["tris"], both))
	var moved_hit := DealerRailSolid.compare(_apply(solid["tris"], both), moved_rail, {}, false)
	var one_only := DealerRailSolid.compare(_apply(solid["tris"], both), other, {}, false)
	_check(moved_hit["status"] == "hit", "moving actor and rail together keeps the hit")
	_check(one_only["status"] == "clear", "moving only the actor must not keep the hit")
	var rev := DealerRailSolid.compare(solid["tris"], other, solid, true)
	_check(rev["reverse"] == "certified" and int(rev["inside_rail"]) > 0, "reverse containment catches a rail vertex inside the skin solid")
	var no_head := DealerSkin.required_head_parts()
	_check(_gate([], "clear") == "incomplete", "body-only clear is incomplete when Head/Visor are absent")
	_check(_gate(no_head, "clear") == "clear", "named Head and Visor can complete a clear report")


func _preconditions() -> void:
	var play := DealerPlacement.production_origin()
	_check(DealerContext.production_frame_ok(play, 1) == "ok", "play seat, one lift")
	_check(DealerContext.production_frame_ok(DealerPlacement.DOCUMENTED_FIXTURE, 1) == "not_production_seat", "-.47 labeled production fails")
	_check(DealerContext.production_frame_ok(play + Vector3(0, 0.12, 0), 1) == "not_production_seat", "a second +0.12 is not the play seat")
	_check(DealerContext.production_frame_ok(play, 2) == "lift_count", "lift count 2 fails")
	var parent := Transform3D(Basis.IDENTITY, Vector3(1, 2, 3))
	var world := DealerContext.actor_world(parent, play, 0.0)
	_check(world.origin.is_equal_approx(parent * play), "actor world uses the full parent, not a bare world constant")
	var mc := DealerContext.actor_world(Transform3D.IDENTITY, DealerContext.MC_LOCAL, DealerContext.MC_YAW_DEG)
	_check(mc.origin.is_equal_approx(DealerContext.MC_LOCAL) and is_equal_approx(mc.basis.get_euler().y, deg_to_rad(90.0)), "MC anchor constant only; not a collision measurement")


func _legacy_map() -> void:
	var hands := FileAccess.get_file_as_string("res://tests/test_dealer_hands.gd")
	var smiles := FileAccess.get_file_as_string("res://tests/test_smiles.gd")
	var hearth := FileAccess.get_file_as_string("res://tests/test_hearth_dealer_clear.gd")
	_check(hands.contains("worst_clear >= 0.0"), "legacy hand clearance is still >= 0")
	_check(smiles.contains("const RAIL_TOP := 0.14") and smiles.contains("const DEALER_POS := Vector3(-0.42, -0.47, -0.86)"), "legacy limb envelope and -.47 seat remain")
	_check(smiles.contains("const MC_POS := Vector3(-1.32, -0.42, -0.30)"), "legacy MC seat remains")
	_check(hearth.contains("const PAD := 0.004") and hearth.contains("const MIN_VISIBLE := 0.85") and hearth.contains("const DEALER_Y := -0.47"), "Hearth pad, bell threshold and -.47 fixture remain")
	for row in DealerContext.successor_map():
		var status := String(row["status"])
		_check(status == "legacy_unchanged" or status == "proposed_not_accepted", "%s has an explicit unaccepted-or-legacy status" % row["property"])
	var saw_future := false
	var saw_fixture := false
	for ctx in DealerContext.contexts():
		if ctx["id"] == "future_hearth_at_play_seat":
			saw_future = not bool(ctx["live"])
		if ctx["id"] == "documented_hearth_fixture":
			saw_fixture = not bool(ctx["live"]) and (ctx["actor_local"] as Vector3).is_equal_approx(DealerPlacement.DOCUMENTED_FIXTURE)
	_check(saw_future and saw_fixture, "future Hearth-at-play-seat is labeled not live; -.47 fixture remains")


func _rails_and_original_smiles() -> void:
	var board := (load(Hearth) as PackedScene).instantiate() as Node3D
	root.add_child(board)
	await process_frame
	var rails := DealerRailSolid.from_mesh_root(board.get_node_or_null("Visual/Rails"))
	_check(bool(rails["ok"]), "Hearth PC rails form a closed solid (%s, tris %d)" % [rails.get("reason", ""), (rails["tris"] as Array).size() if rails.has("tris") else 0])
	if not bool(rails["ok"]):
		board.queue_free()
		return
	# QA's published points, this tree's rails. Not a V194 head mesh.
	var jaw := Vector3(-0.419990689, 0.021211118, -0.610123754)
	var outside_foot := Vector3(-0.420674, 0.018086, -0.802405)
	var above_surface := Vector3(-0.42, 0.108872, -0.592908)
	_check(DealerRailSolid.point_vs_solid(jaw, rails) == "inside", "published interior jaw point is inside this Hearth solid")
	_check(DealerRailSolid.point_vs_solid(outside_foot, rails) == "outside", "below-crown point outside the footprint is not inside")
	_check(DealerRailSolid.point_vs_solid(above_surface, rails) == "outside", "point under y=0.11 but above the real surface is not inside")
	var chest: Array = [Vector3(-0.42, -0.142534, -0.741972), Vector3(-0.482, 0.031723, -0.685763), Vector3(-0.358, 0.031723, -0.685763)]
	var chest_hit := false
	for tri in rails["tris"]:
		if DealerRailSolid.triangle_relation(chest[0], chest[1], chest[2], tri[0], tri[1], tri[2]) == "transverse":
			chest_hit = true
			break
	_check(chest_hit, "original chest triangle still crosses this Hearth rail (separate from head)")
	var smiles := (load(SMILES) as PackedScene).instantiate() as Node3D
	root.add_child(smiles)
	await process_frame
	var skel := smiles.find_child("Skeleton3D", true, false) as Skeleton3D
	var ap := smiles.find_child("AnimationPlayer", true, false) as AnimationPlayer
	ap.play("idle")
	ap.seek(0.0, true)
	await process_frame
	await process_frame
	var parts := _skinned_parts(smiles, skel)
	_check(parts.has("head") and parts.has("visor") and parts.has("body"), "opaque Head, Visor and Body skinned (%s)" % str(parts.keys()))
	if parts.has("head"):
		_check(float(parts["head"]["wsum_min"]) > 0.999, "head weights are not renormalized; min sum %.6f" % parts["head"]["wsum_min"])
		smiles.position = DealerPlacement.production_origin()
		await process_frame
		var at_play := _skinned_parts(smiles, skel)
		var head_play := DealerRailSolid.compare(at_play["head"]["tris"], rails, {}, false)
		_check(head_play["status"] == "clear", "original idle t=0 head vs Hearth at play seat, rail-containment only (%s)" % head_play)
		_check(false, "UNVERIFIED open-head reverse containment (reverse=%s); not coverage" % str(head_play.get("reverse", "")))
		smiles.position = DealerPlacement.DOCUMENTED_FIXTURE
		await process_frame
		var at_fix := _skinned_parts(smiles, skel)
		var head_fix := DealerRailSolid.compare(at_fix["head"]["tris"], rails, {}, false)
		_check(head_fix["status"] == "clear", "original idle t=0 head vs Hearth at -.47 is clear (%s)" % head_fix)
		var body_play_pos := DealerPlacement.production_origin()
		smiles.position = body_play_pos
		await process_frame
		var body := _skinned_parts(smiles, skel)
		var body_hit := DealerRailSolid.compare(body["body"]["tris"], rails, {}, false)
		_check(body_hit["status"] == "hit", "original idle body/chest is a positive rail hit, not a head failure (%s)" % body_hit)
	board.queue_free()
	smiles.queue_free()


func _frozen_art_gap() -> void:
	# Hard failure: do not grade a later GLB as this commit.
	_check(false, "GAP V194 head mesh %s is not in this remote; jaw MESH witness not run" % DealerContext.FROZEN_V194)
	_check(false, "GAP V188 checkpoint %s is not in this remote; taunt 0.500s and mc_cheer witnesses not run" % DealerContext.FROZEN_V188_CHECKPOINT)


func _skinned_parts(smiles: Node3D, skel: Skeleton3D) -> Dictionary:
	var out := {}
	for mi in smiles.find_children("*", "MeshInstance3D", true, false):
		var mesh := mi as MeshInstance3D
		if mesh.skin == null:
			continue
		var skin := DealerSkin.surface(mesh, skel)
		if not bool(skin["ok"]):
			out[String(mesh.name)] = skin
			continue
		var part := String(skin["part"])
		if not out.has(part):
			out[part] = {"tris": [], "wsum_min": INF}
		(out[part]["tris"] as Array).append_array(skin["tris"])
		out[part]["wsum_min"] = minf(float(out[part]["wsum_min"]), float(skin["wsum_min"]))
	return out


func _gate(parts: Array, status: String) -> String:
	for need in DealerSkin.required_head_parts():
		if not parts.has(need):
			return "incomplete"
	return status


func _apply(tris: Array, xf: Transform3D) -> Array:
	var out: Array = []
	for tri in tris:
		out.append([xf * tri[0], xf * tri[1], xf * tri[2]])
	return out
