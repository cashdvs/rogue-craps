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
	s.fit_phone(Vector2(844, 390))
	check(s.reliquary_kind() == SoulReliquaryHookup.PHONE, "phone screen uses the phone layout")

	print("reliquary hookup: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
