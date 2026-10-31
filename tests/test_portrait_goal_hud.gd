## Phone-portrait goal readout (PortraitGoalHud):
##   - shown only when the screen is taller than wide: hidden on PC 16:9
##     (1920x1080) and phone landscape (844x390 -> 2337x1080 canvas), shown on
##     phone portrait (390x844 -> 1920x4155 canvas);
##   - live: its goal line and bounty marks follow the run ([ ] open,
##     [?] pending, [x] claimed) and match the bounty cards;
##   - in portrait it replaces the bounty cards (hidden) and carries their
##     feedback: rows pulse for the selection, a CLAIMED stamp on a bank, a
##     red flash for pending rows lost on a bust; the bank / bust banner
##     stays readable (not under the readout). Cards come back off portrait;
##   - readable and out of the way, measured in REAL screen pixels of a
##     390x844 phone: text >= 11 px, >= 80 px clear of the pot row, clear of
##     the hand, inside the screen;
##   - the portrait camera and dice size are untouched (pitch 60, no tilt).
##
## Screen pixels vs canvas pixels: the project stretches a 1920x1080 design
## canvas over the window ("canvas_items", aspect "expand"). A 390x844 window
## is scaled by min(390/1920, 844/1080) = 0.203, so the canvas it shows is
## 390/0.203 x 844/0.203 = 1920 x 4155 canvas px. The scene runs in a
## SubViewport of that canvas size (what the game renders into); every
## distance is multiplied by SCALE to get the phone's real pixels.
##   godot --headless --path . --script res://tests/test_portrait_goal_hud.gd
extends SceneTree

## The phone window (real screen px) and the canvas it shows.
const PHONE := Vector2(390, 844)
const DESIGN := Vector2(1920, 1080)
var SCALE: float = minf(PHONE.x / DESIGN.x, PHONE.y / DESIGN.y)
## Real-pixel targets.
const MIN_TEXT_PX := 11.0
const POT_CLEAR_PX := 80.0
const HAND_CLEAR_PX := 16.0

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	# The sandbox table_1 is a real F1 target table now; this suite tests bounties.
	var sandbox_tuning := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	sandbox_tuning.table_goal = load("res://tests/fixtures/bounty_table_1.tres") as TableGoal
	set_meta(&"sandbox_tuning", sandbox_tuning)  # keep it cached so every load sees the fixture
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


## The Bonfire scene inside a SubViewport of the given canvas size.
func _make(canvas: Vector2i, count: int = 5) -> Array:
	var sv := SubViewport.new()
	sv.size = canvas
	root.add_child(sv)
	var t := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = TableSetup.sandbox(t, count)
	s.setup.nerve_uses = 0  # these checks expect a plain bust (no Nerve rescue pause)
	s.tutorial_override = 0
	s.bonfire_seed = 5
	s.test_speed = 10.0
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
	check(not s.bhud.portrait_goal.visible and not s.bhud.checklist_panel.visible and s.bhud.target_plate.visible, "PC 16:9: Target HUD v2.1 plate replaces the readout and the cards")
	(made[0] as Node).queue_free()
	await process_frame
	# Phone landscape: hidden.
	made = await _make(Vector2i(2337, 1080))
	s = made[1]
	s.fit_phone(Vector2(844, 390))
	s._refresh_hud()
	check(not s.bhud.portrait_goal.visible and not s.bhud.checklist_panel.visible and s.bhud.target_plate.visible, "phone landscape: the plate replaces the readout and the cards")
	(made[0] as Node).queue_free()
	await process_frame
	# Phone portrait: shown, live, out of the way.
	var canvas := Vector2i(int(round(PHONE.x / SCALE)), int(round(PHONE.y / SCALE)))
	made = await _make(canvas)
	var sv: SubViewport = made[0]
	s = made[1]
	s.camera.cam.current = true
	s.fit_phone(PHONE)
	s.camera.snap_home()
	s._refresh_hud()
	await process_frame
	var g := s.bhud.portrait_goal
	check(not g.visible and s.bhud.target_plate.visible, "phone portrait: the plate replaces the old readout")
	check(not s.bhud.checklist_panel.visible, "phone portrait: the old bounty cards are hidden (one list)")
	check(is_equal_approx(s.camera.pitch_deg, 60.0) and is_zero_approx(s.camera.look_up_deg), "portrait camera unchanged (pitch 60, no tilt)")
	_live(s, g)
	_text_size(g)
	await process_frame
	_clearance(sv, s, s.bhud.target_plate)
	await _feedback(s, g)
	# Rotating back to landscape hides it again and brings the cards back.
	sv.size = Vector2i(2337, 1080)
	await process_frame
	s._refresh_hud()
	check(not g.visible and not s.bhud.checklist_panel.visible and s.bhud.target_plate.visible, "back to landscape: the plate stays, old readout and cards stay hidden")
	check(is_equal_approx(s.bhud.result_label.position.y, BonfireHud.RESULT_Y), "back to landscape: banner back at its usual place")
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
	# Back to a fresh table for the rest of the test.
	r.ticks.erase(first.id)
	r.hands_left += 1
	s._refresh_hud()


## Text size in real screen px on the 390 px wide phone.
func _text_size(g: PortraitGoalHud) -> void:
	var smallest := INF
	var labels: Array = [g.title_label, g.progress_label]
	labels.append_array(g.rows.values())
	for l: Label in labels:
		smallest = minf(smallest, l.label_settings.font_size * SCALE)
	print("  portrait readout text: smallest %.1f px on a %d px wide screen (title %.1f, rows %.1f); dice icons %.1f px" % [
		smallest, int(PHONE.x), g.title_label.label_settings.font_size * SCALE, PortraitGoalHud.ROW_PX * SCALE, PortraitGoalHud.ICON_PX * SCALE])
	check(smallest >= MIN_TEXT_PX, "readout text >= %.0f px on screen (%.1f)" % [MIN_TEXT_PX, smallest])


## Target HUD v2.1: run on the goal plate (the old readout is hidden).
func _clearance(sv: SubViewport, s: Bonfire3D, g: Control) -> void:
	var cam := s.camera.cam
	var ds := s.tuning.die_size
	# Everything below in real screen px (canvas px x SCALE).
	var box := _px(g.get_global_rect())
	print("  portrait readout on screen: %s in a %s screen" % [box, PHONE])
	check(Rect2(Vector2.ZERO, PHONE).encloses(box), "readout fits on screen")
	check(box.end.y < PHONE.y * 0.25, "readout sits near the top (bottom at %.0f of %.0f px)" % [box.end.y, PHONE.y])
	# Pot row: every pot slot, from the felt to a die on its pillar.
	var pot: Array[Vector3] = []
	for k in maxi(s.setup.dice.size(), 1):
		pot.append_array(_box(s.pot_slot(k), ds * 0.5, 0.0, Bonfire3D.PILLAR_HEIGHT + ds))
	var pot_r := _px(_screen_rect(cam, pot))
	# In portrait the pot row runs down the right side, so the gap that
	# matters is horizontal (readout right edge -> first pot slot).
	var gap := maxf(pot_r.position.x - box.end.x, pot_r.position.y - box.end.y)
	print("  pot row on screen: %s; readout right edge %.0f px, gap %.0f px" % [pot_r, box.end.x, gap])
	check(not box.grow(POT_CLEAR_PX).intersects(pot_r), "readout >= %.0f screen px clear of the pot row (gap %.0f px)" % [POT_CLEAR_PX, gap])
	# How big the text could get before the 80 px gap runs out (the panel
	# grows with the text from its top-left corner).
	var room := (pot_r.position.x - POT_CLEAR_PX) - box.position.x
	print("  largest readout text that keeps %.0f px clear: ~%.1f px (now %.1f px)" % [POT_CLEAR_PX, PortraitGoalHud.ROW_PX * SCALE * room / box.size.x, PortraitGoalHud.ROW_PX * SCALE])
	# The hand: every die waiting to be thrown.
	var hand: Array[Vector3] = []
	for d in s.dice:
		hand.append_array(_box((d as Node3D).global_position, ds * 0.75, 0.0, ds * 1.5))
	var hand_r := _px(_screen_rect(cam, hand))
	check(not box.grow(HAND_CLEAR_PX).intersects(hand_r), "readout clear of the hand (hand top at %.0f px, readout bottom %.0f px)" % [hand_r.position.y, box.end.y])


## Canvas px -> the phone's real screen px.
func _px(r: Rect2) -> Rect2:
	return Rect2(r.position * SCALE, r.size * SCALE)


## The cards' feedback, played on the readout with real throws.
func _feedback(s: Bonfire3D, g: PortraitGoalHud) -> void:
	var r := s.run
	await create_timer(0.2).timeout
	# Hand 1: 4-4-4 lights; nothing picked yet, the Triple row pulses.
	await _throw(s, [4, 4, 4, 5, 2] as Array[int])
	check(g.pulsing.has(&"triple"), "a throw that could claim the Triple pulses its row (%s)" % str(g.pulsing))
	s.pick_die(0); s.pick_die(1); s.pick_die(2)
	s._refresh_hud()
	check(g.pulsing == [&"triple"], "selected 4-4-4 pulses the Triple row (%s)" % str(g.pulsing))
	var b: Dictionary = await s.bank()
	await process_frame
	check(r.is_ticked(r.goal.required[0]) or (b["ticked"] as Array).has(&"triple"), "bank claims the Triple")
	check(g.stamped.has(&"triple") and g.has_stamp(&"triple"), "a CLAIMED stamp lands on the Triple row")
	check((g.rows[&"triple"] as Label).text.begins_with("[x]"), "Triple row shows [x]")
	check(g.pulsing.is_empty(), "pulse stops after the bank")
	_banner_clear(s, g, "Banked")
	await create_timer(1.8).timeout
	check(not g.has_stamp(&"triple") and (g.rows[&"triple"] as Label).text.begins_with("[x]"), "the stamp fades; the row stays claimed")
	# Hand 2: a pending row, then a bust. Only a Hot Hand throws again, and
	# 5 plain dice always light something, so the bust runs on a 3-die
	# portrait table: pot 1-2-3 (Run of 3 pending), throw 2-4-6.
	var made: Array = await _make(Vector2i(int(round(PHONE.x / SCALE)), int(round(PHONE.y / SCALE))), 3)
	var s3: Bonfire3D = made[1]
	s3.camera.cam.current = true
	s3.fit_phone(PHONE)
	s3.camera.snap_home()
	await process_frame
	var g3 := s3.bhud.portrait_goal
	await _throw(s3, [1, 2, 3] as Array[int])
	for i in 3:
		s3.pick_die(i)
	check(s3.throw_again(), "Hot Hand: throw all 3 dice")
	s3._refresh_hud()
	check((g3.rows[&"run3"] as Label).text.begins_with("[?]"), "Run of 3 row pending (%s)" % (g3.rows[&"run3"] as Label).text)
	await create_timer(0.3).timeout
	await _throw(s3, [2, 4, 6] as Array[int])
	await process_frame
	check(g3.lost_flashed.has(&"run3"), "bust: the pending Run of 3 row flashes as lost")
	check((g3.rows[&"run3"] as Label).text.begins_with("[ ]"), "bust: Run of 3 back to [ ]")
	_banner_clear(s3, g3, "BUST")
	(made[0] as Node).queue_free()
	await process_frame


## The bank / bust banner reads: showing, the right text, not under the readout.
func _banner_clear(s: Bonfire3D, g: PortraitGoalHud, word: String) -> void:
	var res := s.bhud.result_label
	check(res.text.begins_with(word), "%s banner shows (%s)" % [word, res.text])
	check(not res.get_global_rect().intersects(g.get_global_rect()), "%s banner not under the readout" % word)
	check(not res.get_global_rect().intersects(s.bhud.target_plate.get_global_rect()), "%s banner not under the goal plate" % word)


func _throw(s: Bonfire3D, faces: Array[int]) -> void:
	s.rig_faces(faces)
	if not s.quick_throw():
		check(false, "throw %s starts" % str(faces))
		return
	await s.throw_resolved
	await s.sequence_finished
