## The 3D Soul Reliquary on the real Bonfire table (#149 / #167): it replaces
## the 2D Soul bar, its plate and fill follow run.soul through real throws
## (pot, then a bust), lethal / frost / heal show, the layout picks the
## right prop, and the crack overlay + onboarding arrow point at its plate.
##   godot --headless --path . --script res://tests/test_reliquary_hookup.gd
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


func throw_faces(s: Bonfire3D, faces: Array[int]) -> Array:
	s.rig_faces(faces)
	if not s.quick_throw():
		check(false, "throw %s starts" % str(faces))
		return []
	var res: Array = await s.throw_resolved
	return res


func deltas(r: SoulReliquaryHookup) -> Array[String]:
	var out: Array[String] = []
	for n in r.find_children("SoulDelta*", "Label3D", true, false):
		out.append((n as Label3D).text)
	return out


func _run() -> void:
	var t := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = TableSetup.sandbox(t, 5)
	s.setup.nerve_uses = 0  # a plain bust, no Nerve rescue pause
	s.test_speed = 10.0
	root.add_child(s)
	await process_frame
	await process_frame
	var r := s.reliquary
	check(r != null and r.prop != null, "the Reliquary is on the table")
	check(not s.soul_meter.visible, "the old 2D Soul bar is hidden")
	var run := s.run
	check(r.prop.label_text() == "%d/%d" % [run.soul, run.max_soul], "plate shows cur/max (%s)" % r.prop.label_text())
	check(r.shown_soul == run.soul, "fill tracks run.soul at the start")
	check(r.layout_kind == s.reliquary_kind(), "placed for this screen (%s)" % r.layout_kind)
	var plate := s.reliquary_rect()
	check(plate.size.x > 4.0 and plate.size.y > 2.0, "plate is on screen (%s)" % plate)
	check(s.onboarding == null or s.onboarding.anchor_rect(&"soul", {}) == plate, "onboarding 'soul' arrow points at the plate")

	# Real path: pot trips, then a bust loses Soul.
	await create_timer(0.3).timeout
	await throw_faces(s, [4, 4, 4, 5, 2] as Array[int])
	await s.sequence_finished
	s.pick_die(0); s.pick_die(1); s.pick_die(2)
	check(s.throw_again(), "pot the 4-4-4 and throw again")
	await s.bhud.countup.finished
	await create_timer(0.3).timeout
	var before := run.soul
	await throw_faces(s, [2, 6] as Array[int])
	await s.sequence_finished
	await process_frame
	check(run.soul < before, "the bust cost Soul (%d -> %d)" % [before, run.soul])
	check(r.shown_soul == run.soul and r.prop.label_text() == "%d/%d" % [run.soul, run.max_soul], "plate follows the bust (%s)" % r.prop.label_text())
	check(r.last_loss_was_bust, "the drop played as a bust (sharp shudder)")
	check(r.last_delta == "-%d" % (before - run.soul), "a floating -N rose (%s)" % r.last_delta)

	# Low Soul: lethal crack when the next bust kills, frost at 5 or less.
	run.soul = run.soul_cost(run.tuning.bust_soul_loss, &"bust")
	s._refresh_hud()
	check(r.prop.lethal, "lethal crack when the next bust would end the run")
	check(r.prop.frosted(), "frost at low Soul")
	var low := run.soul
	run.soul = run.max_soul
	s._refresh_hud()
	check(not r.prop.lethal and not r.prop.frosted(), "no crack / frost when full")
	check(r.last_delta == "+%d" % (run.max_soul - low) and deltas(r).size() > 0, "heal shows +N (%s)" % r.last_delta)

	# Layouts: portrait gets the stacked phone prop, PC the PC prop.
	r.layout(SoulReliquaryHookup.PORTRAIT)
	check(r.prop.scene_file_path == SoulReliquaryHookup.PHONE_SCENE and r.prop.plate_layout == "stacked", "portrait: phone prop, stacked plate")
	check(r.prop.get_parent().transform.is_equal_approx(SoulReliquaryHookup.marker_for(SoulReliquaryHookup.PORTRAIT)), "portrait marker matches the Hearth board")
	r.layout(SoulReliquaryHookup.PC)
	check(r.prop.scene_file_path == SoulReliquaryHookup.PC_SCENE and r.prop.plate_layout == "row", "PC: PC prop, row plate")
	check(r.prop.label_text() == "%d/%d" % [run.soul, run.max_soul], "swapped prop keeps the Soul")

	await _motion_tests(s)
	await _layout_tests(s)
	await _portrait_tests(t)
	print("reliquary hookup: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func ghost_alpha(r: SoulReliquaryHookup) -> float:
	return float((r.prop.call("_mat") as ShaderMaterial).get_shader_parameter("ghost_alpha"))


## Projected screen box of one plate mesh (for the union check).
func mesh_rect(r: SoulReliquaryHookup, path: String, cam: Camera3D) -> Rect2:
	var mi := r.prop.get_node(path) as VisualInstance3D
	var box := mi.get_aabb()
	var out := Rect2(cam.unproject_position(mi.global_transform * box.get_endpoint(0)), Vector2.ZERO)
	for i in 8:
		out = out.expand(cam.unproject_position(mi.global_transform * box.get_endpoint(i)))
	return out


## A Soul loss starts the red ghost, fades it, and shakes the Rig.
func _motion_tests(s: Bonfire3D) -> void:
	var r := s.reliquary
	r.reduced_motion = false
	s.reduced_motion = false
	s._refresh_hud()  # settle the layout first (an earlier check swapped props)
	await create_timer(1.0).timeout  # earlier tweens done
	var rig := r.prop.get_node("Rig") as Node3D
	var home := rig.position
	check(ghost_alpha(r) < 0.05, "no ghost before the loss (%s)" % ghost_alpha(r))
	s.run.soul -= 3
	s._refresh_hud()
	check(ghost_alpha(r) > 0.5, "loss: the red ghost starts lit (%s)" % ghost_alpha(r))
	var moved := false
	for i in 6:
		await process_frame
		moved = moved or rig.position.distance_to(home) > 0.0005
	check(moved, "loss: the Rig shudders")
	await create_timer(1.0).timeout
	check(ghost_alpha(r) < 0.05, "loss: the ghost fades out (%s)" % ghost_alpha(r))
	check(rig.position.is_equal_approx(home), "the shudder settles back home")


## Short windows and phone landscape get the phone prop; tall ones PC.
func _layout_tests(s: Bonfire3D) -> void:
	var r := s.reliquary
	s.fit_phone(Vector2.ZERO)
	s.phone_screen = Vector2.ZERO
	s.window_px_override = Vector2i(1920, 1080)
	s._refresh_hud()
	check(s.reliquary_kind() == SoulReliquaryHookup.PC and r.prop.scene_file_path == SoulReliquaryHookup.PC_SCENE, "1920x1080 window: PC prop (%s)" % s.reliquary_kind())
	var cam := s.camera.cam
	var plate := r.plate_rect(cam)
	var want := mesh_rect(r, "Rig/Plate", cam).merge(mesh_rect(r, "Rig/Frame", cam))
	check(plate.position.is_equal_approx(want.position) and plate.size.is_equal_approx(want.size), "plate rect = Plate + Frame (%s vs %s)" % [plate, want])
	s.window_px_override = Vector2i(1280, 600)
	s._refresh_hud()
	check(s.reliquary_kind() == SoulReliquaryHookup.PHONE and r.prop.scene_file_path == SoulReliquaryHookup.PHONE_SCENE, "1280x600 window (under 720 px): phone prop")
	s.window_px_override = Vector2i(1920, 1080)
	s.fit_phone(Vector2(844, 390))
	s._refresh_hud()
	check(s.reliquary_kind() == SoulReliquaryHookup.PHONE and r.prop.scene_file_path == SoulReliquaryHookup.PHONE_SCENE and r.prop.plate_layout == "row", "phone landscape 844x390: phone prop, row plate")


## A real portrait canvas (390x844 phone -> 1920x4155): stacked plate, on
## screen, clear of Throw / Bank, and the overlays use it.
func _portrait_tests(t: BonfireTuning) -> void:
	var sv := SubViewport.new()
	sv.size = Vector2i(1920, 4155)
	root.add_child(sv)
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = TableSetup.sandbox(t, 5)
	s.tutorial_override = 0
	sv.add_child(s)
	await process_frame
	await process_frame
	var r := s.reliquary
	var cam := s.camera.cam
	check(s.reliquary_kind() == SoulReliquaryHookup.PORTRAIT and r.layout_kind == SoulReliquaryHookup.PORTRAIT, "portrait canvas: portrait layout (%s)" % s.reliquary_kind())
	check(r.prop.scene_file_path == SoulReliquaryHookup.PHONE_SCENE and r.prop.plate_layout == "stacked", "portrait: phone prop, stacked plate")
	var plate := s.reliquary_rect()
	var want := mesh_rect(r, "Rig/Stacked/Plate", cam).merge(mesh_rect(r, "Rig/Stacked/Frame", cam))
	check(plate.size.x > 20.0 and plate.size.y > 20.0 and plate.position.x > 1.0, "portrait plate rect is real, not the corner (%s)" % plate)
	check(plate.position.is_equal_approx(want.position) and plate.size.is_equal_approx(want.size), "portrait rect = stacked Plate + Frame")
	check(not plate.intersects(s.button_column_rect()), "portrait plate clear of Throw / Bank (%s vs %s)" % [plate, s.button_column_rect()])
	check(s.onboarding == null or s.onboarding.anchor_rect(&"soul", {}) == plate, "portrait onboarding arrow at the plate")
	# Pretend the buttons cover the plate: the nudge must slide it clear.
	r._clear_key = []
	var at := r.clear_of(plate.grow(4.0), cam)
	check(at != Vector3.ZERO and not r.plate_rect(cam).intersects(plate.grow(4.0)), "clear_of slides the plate out from under a covering rect (%s)" % at)
	sv.queue_free()
