## Phone-portrait goal readout (PortraitGoalHud):
##   - shown only when the screen is taller than wide: hidden on PC 16:9
##     (1920x1080) and phone landscape (844x390 -> 2337x1080 canvas), shown on
##     phone portrait (390x844 -> 1920x4155 canvas);
##   - live: its goal line and bounty marks follow the run ([ ] open,
##     [?] pending, [x] claimed) and match the bounty cards;
##   - out of the way: >= 80 px (Bonfire3D.PHONE_EDGE_PX) clear of the pot
##     row, clear of the dice in the hand, and inside the screen;
##   - the portrait camera and dice size are untouched (pitch 60, no tilt).
##   godot --headless --path . --script res://tests/test_portrait_goal_hud.gd
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


## The Bonfire scene inside a SubViewport of the given canvas size.
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


## Screen rect (viewport px) around world points.
func _screen_rect(cam: Camera3D, pts: Array[Vector3]) -> Rect2:
	var r := Rect2(cam.unproject_position(pts[0]), Vector2.ZERO)
	for p in pts:
		r = r.expand(cam.unproject_position(p))
	return r


## The 8 corners of a die-sized box at p (rests on the felt / pot).
func _box(p: Vector3, half: float, bottom: float, top: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for x in [-half, half]:
		for z in [-half, half]:
			out.append(Vector3(p.x + x, bottom, p.z + z))
			out.append(Vector3(p.x + x, top, p.z + z))
	return out


func _run() -> void:
	# PC 16:9: hidden.
	var made: Array = await _make(Vector2i(1920, 1080))
	var s: Bonfire3D = made[1]
	s._refresh_hud()
	check(not s.bhud.portrait_goal.visible, "PC 16:9: goal readout hidden")
	(made[0] as Node).queue_free()
	await process_frame
	# Phone landscape: hidden.
	made = await _make(Vector2i(2337, 1080))
	s = made[1]
	s.fit_phone(Vector2(844, 390))
	s._refresh_hud()
	check(not s.bhud.portrait_goal.visible, "phone landscape: goal readout hidden")
	(made[0] as Node).queue_free()
	await process_frame
	# Phone portrait: shown, live, out of the way.
	made = await _make(Vector2i(1920, 4155))
	var sv: SubViewport = made[0]
	s = made[1]
	s.camera.cam.current = true
	s.fit_phone(Vector2(390, 844))
	s.camera.snap_home()
	s._refresh_hud()
	await process_frame
	var g := s.bhud.portrait_goal
	check(g.visible, "phone portrait: goal readout shown")
	check(is_equal_approx(s.camera.pitch_deg, 60.0) and is_zero_approx(s.camera.look_up_deg), "portrait camera unchanged (pitch 60, no tilt)")
	_live(s, g)
	await process_frame
	_clearance(sv, s, g)
	# Rotating back to landscape hides it again.
	sv.size = Vector2i(2337, 1080)
	await process_frame
	s._refresh_hud()
	check(not g.visible, "back to landscape: hidden again")
	print("test_portrait_goal_hud: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _live(s: Bonfire3D, g: PortraitGoalHud) -> void:
	var r := s.run
	var req: Array = r.goal.required
	var first: BountyData = req[0]
	check(g.rows.size() == r.all_bounties().size(), "one row per bounty (%d)" % g.rows.size())
	check(g.title_label.text == "%s GOAL" % r.goal.display_name.to_upper(), "goal title (%s)" % g.title_label.text)
	check(g.progress_label.text.begins_with("0/%d claimed" % req.size()) and g.progress_label.text.contains("%d hands left" % r.hands_left), "fresh goal line (%s)" % g.progress_label.text)
	check((g.rows[first.id] as Label).text.begins_with("[ ]"), "fresh: %s open" % first.display_name)
	# Landed this hand, not banked yet: pending.
	r.pending[first.id] = first.count_needed
	s._refresh_hud()
	check((g.rows[first.id] as Label).text.begins_with("[?]"), "pending shows [?] (%s)" % (g.rows[first.id] as Label).text)
	check((g.rows[first.id] as Label).text.substr(0, 3) == (s.bhud.bounty_rows[first.id] as Label).text.substr(0, 3), "matches the bounty card")
	# Banked: claimed.
	r.pending.erase(first.id)
	r.ticks[first.id] = first.count_needed
	r.hands_left -= 1
	s._refresh_hud()
	check((g.rows[first.id] as Label).text.begins_with("[x]"), "claimed shows [x] (%s)" % (g.rows[first.id] as Label).text)
	check(g.progress_label.text.begins_with("1/%d claimed" % req.size()) and g.progress_label.text.contains("%d hands left" % r.hands_left), "goal line counts it (%s)" % g.progress_label.text)
	check((g.rows[first.id] as Label).label_settings.font_color == PortraitGoalHud.CLAIMED_COLOR, "claimed row turns green")


func _clearance(sv: SubViewport, s: Bonfire3D, g: PortraitGoalHud) -> void:
	var cam := s.camera.cam
	var ds := s.tuning.die_size
	var vs := Vector2(sv.size)
	var box := g.get_global_rect()
	print("  portrait readout rect %s in %s" % [box, vs])
	check(Rect2(Vector2.ZERO, vs).encloses(box), "readout fits on screen")
	check(box.end.y < vs.y * 0.25, "readout sits near the top (bottom at %.0f of %.0f px)" % [box.end.y, vs.y])
	# Pot row: every pot slot, from the felt to a die on its pillar.
	var pot: Array[Vector3] = []
	var n := maxi(s.setup.dice.size(), 1)
	for k in n:
		pot.append_array(_box(s.pot_slot(k), ds * 0.5, 0.0, Bonfire3D.PILLAR_HEIGHT + ds))
	var pot_r := _screen_rect(cam, pot)
	var gap := pot_r.position.y - box.end.y
	check(not box.grow(Bonfire3D.PHONE_EDGE_PX).intersects(pot_r), "readout >= 80 px clear of the pot row (gap %.0f px)" % gap)
	# The hand: every die waiting to be thrown.
	var hand: Array[Vector3] = []
	for d in s.dice:
		hand.append_array(_box((d as Node3D).global_position, ds * 0.75, 0.0, ds * 1.5))
	var hand_r := _screen_rect(cam, hand)
	check(not box.grow(Bonfire3D.PHONE_EDGE_PX).intersects(hand_r), "readout clear of the hand (hand top at %.0f px)" % hand_r.position.y)
