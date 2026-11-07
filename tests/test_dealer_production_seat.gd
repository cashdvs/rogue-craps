## The one play seat (DealerPlacement) and the startup camera that frames it.
##
## Legacy suites stay on their own constants: documented anchor y = -0.47,
## rectangular rail y = 0.14, skin clearance >= 0. This file does not retarget
## them and does not claim the idle's fingers touch the leather. A planted
## idle at the play seat fails that old slab; the proposed replacement is in
## the QA artifact, not in those tests.
##
##   godot --headless --path . --script res://tests/test_dealer_production_seat.gd
extends SceneTree

const BOARD_A := "res://art/models/boards/infernal_pit/scenes/board_a_infernal_pit.tscn"
const HEARTH := "res://art/models/boards/hearth/scenes/hearth_board.tscn"

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
	print("=== production dealer seat ===")
	_contract()
	_legacy_files_unchanged()
	await _live_actor_and_crowns()
	await _startup_cameras()
	print("=== %d passed, %d failed ===" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)


func _contract() -> void:
	var play := DealerPlacement.production_origin()
	_check(play.is_equal_approx(Vector3(-0.42, -0.35, -0.86)), "play seat is (-0.42, -0.35, -0.86), got %s" % play)
	_check(is_equal_approx(DealerPlacement.below_design_crown(), 0.46), "seat is 0.46 m below the design crown")
	_check(is_equal_approx(DealerPlacement.behind_rail_center(), -0.25), "seat is 0.25 m behind the far-rail centre")
	_check(play.is_equal_approx(BonfireDealerArt.DEALER_SPOT + BonfireDealerArt.GREYBOX_RAIL_LIFT), "BonfireDealerArt lift still adds to the legacy anchor")
	_check(is_equal_approx(BonfireDealerArt.GREYBOX_RAIL_LIFT.y, 0.12), "lift stays +0.12 (boss head gate)")
	_check(BonfireDealerArt.DEALER_SPOT.is_equal_approx(DealerPlacement.DOCUMENTED_FIXTURE), "legacy anchor stays (-0.42, -0.47, -0.86)")
	var empty := Node3D.new()
	root.add_child(empty)
	var missing := DealerPlacement.surface_y(null, -0.42, -0.61)
	var bare := DealerPlacement.surface_y(empty, -0.42, -0.61)
	_check(missing["ok"] == false and missing["reason"] == "missing", "a missing rail fails closed (%s)" % missing)
	_check(bare["ok"] == false and bare["reason"] == "no_triangles", "a rail with no triangles fails closed (%s)" % bare)
	empty.queue_free()


## The old suites still say what they said. This does not grade their pixels.
func _legacy_files_unchanged() -> void:
	var hands := FileAccess.get_file_as_string("res://tests/test_dealer_hands.gd")
	var smiles := FileAccess.get_file_as_string("res://tests/test_smiles.gd")
	var bosses := FileAccess.get_file_as_string("res://tests/test_boss_dealer_swap.gd")
	_check(hands.contains("worst_clear >= 0.0"), "dealer hands still require skin clearance >= 0, not -0.005")
	_check(smiles.contains("const DEALER_POS := Vector3(-0.42, -0.47, -0.86)"), "smiles framing still uses the documented anchor")
	_check(smiles.contains("const RAIL_TOP := 0.14"), "smiles still uses the 0.14 rail envelope")
	_check(bosses.contains("top - CameraFraming.RAIL_TOP_Y > 0.18"), "boss head gate is still > 0.18 m above the rail")


func _live_actor_and_crowns() -> void:
	var made := await _boot(Vector2i(1920, 1080))
	var table: Bonfire3D = made[1]
	var dealer := table.dealer_art.scene
	_check(dealer.global_position.is_equal_approx(DealerPlacement.production_origin()), "live actor at the play seat %s" % dealer.global_position)
	_check(dealer.global_transform.basis.is_equal_approx(Basis.IDENTITY), "live actor basis is identity")
	_check(dealer.get_parent() == table, "dealer is parented to the table, one lift, no extra node")
	var rail := table.get_node_or_null("Table/RailFar")
	_crown(rail, "greybox RailFar")
	var off := DealerPlacement.surface_y(rail, 50.0, 50.0)
	_check(off["ok"] == false and off["reason"] == "no_hit", "a ray that misses the rail fails closed (%s)" % off)
	for pair in [[BOARD_A, "Board A"], [HEARTH, "Hearth"]]:
		var board := (load(pair[0]) as PackedScene).instantiate() as Node3D
		root.add_child(board)
		_crown(board.get_node_or_null("Visual/Rails"), pair[1])
		board.queue_free()
	made[0].queue_free()
	await process_frame


func _crown(node: Node, label: String) -> void:
	var hit := DealerPlacement.surface_y(node, -0.42, -0.61)
	_check(hit["ok"] == true, "%s crown ray hits (%s)" % [label, hit])
	if hit["ok"] == true:
		_check(absf(float(hit["y"]) - 0.11) < 0.001, "%s crown %.5f is within 1 mm of 0.11" % [label, hit["y"]])


## Phone fit matches startup: HUD not built yet, so PhoneFrame uses its
## fallback plate. A later fit_phone once the plate is visible is a different
## pivot and is not the camera the player gets.
func _startup_cameras() -> void:
	var pc := await _boot(Vector2i(1920, 1080))
	var pc_table: Bonfire3D = pc[1]
	pc_table.camera.snap_home()
	_rig(pc_table, "PC", 2.40, 0.26, Vector3(0.0, 1.965965, 1.636584))
	pc[0].queue_free()
	var phone := await _boot(Vector2i(2337, 1080))
	var phone_table: Bonfire3D = phone[1]
	phone_table.bhud.visible = false
	phone_table.fit_phone(Vector2(844, 390))
	_rig(phone_table, "phone startup", 1.70, 0.101052, Vector3(0.0, 1.392559, 1.076132))
	var frozen := phone_table.camera.position
	phone_table.bhud.visible = true
	await process_frame
	await process_frame
	_check(phone_table.camera.position.is_equal_approx(frozen), "showing the HUD does not refit the phone camera")
	phone[0].queue_free()


func _rig(table: Bonfire3D, label: String, distance: float, pivot_z: float, origin: Vector3) -> void:
	var rig := table.camera
	var gt := rig.cam.global_transform
	_check(is_equal_approx(rig.distance, distance), "%s dolly %.3f" % [label, rig.distance])
	_check(is_equal_approx(rig.position.z, pivot_z), "%s pivot z %.6f" % [label, rig.position.z])
	_check(gt.origin.is_equal_approx(origin), "%s origin %s" % [label, gt.origin])
	_check(gt.basis.x.is_equal_approx(Vector3(1, 0, 0)), "%s basis X" % label)
	_check(is_equal_approx(gt.basis.y.y, 0.675590) and is_equal_approx(gt.basis.z.z, 0.675590), "%s pitch basis" % label)


func _boot(canvas: Vector2i) -> Array:
	var sv := SubViewport.new()
	sv.size = canvas
	root.add_child(sv)
	var tuning := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var table := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	table.setup = TableSetup.sandbox(tuning, 5)
	table.tutorial_override = 0
	table.bonfire_seed = 5
	sv.add_child(table)
	for _i in 6:
		await process_frame
	return [sv, table]
