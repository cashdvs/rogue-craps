## Target HUD v2.1 (art/concept/hud_target_oct30/v2/HANDOFF_SPEC.md,
## handoff/table_goals_v1_pr1.md §4) on the real Bonfire scene:
##   - number format (12,400 in full, 123,456 -> 123.5k) and the line 3 text;
##   - TableGoalState (stub) follows the run on hand_finished / table_event;
##   - the plate: TARGET + number, bar + banked, to go / PASSED +n / Missed;
##     bar brightens at 100 %; no empty chips, at most 2; SEALS hides at 0;
##   - a 150 ms hover or a tap opens the chip's name card;
##   - placement on PC 1920x1080, phone 844x390 and portrait 390x844, and the
##     old bounty cards / portrait readout stay hidden.
##   godot --headless --path . --script res://tests/test_target_hud.gd
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
	s.setup.nerve_uses = 1
	s.tutorial_override = 0
	s.bonfire_seed = 5
	s.test_speed = 10.0
	sv.add_child(s)
	await process_frame
	await process_frame
	return [sv, s]


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	_check_text()
	await _check_pc()
	await _check_phone()
	await _check_portrait()
	print("test_target_hud: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check_text() -> void:
	check(TargetPlate.fmt(12400) == "12,400", "12,400 in full (%s)" % TargetPlate.fmt(12400))
	check(TargetPlate.fmt(123456) == "123.5k", "123,456 -> 123.5k (%s)" % TargetPlate.fmt(123456))
	check(TargetPlate.fmt(99999) == "99,999" and TargetPlate.fmt(100000) == "100.0k", "k only above 99,999")
	check(TargetPlate.fmt(300) == "300" and TargetPlate.fmt(3500) == "3,500", "small numbers")
	check(TargetPlate.status_text(300, 120, 3) == "180 to go · 3 hands left", "goal_to_go (%s)" % TargetPlate.status_text(300, 120, 3))
	check(TargetPlate.status_text(300, 120, 1) == "180 to go · 1 hand left", "goal_to_go_one_hand")
	check(TargetPlate.status_text(300, 300, 2) == "PASSED · 2 hands left", "exactly the target passes")
	check(TargetPlate.status_text(300, 299, 2) != "PASSED · 2 hands left", "target - 1 is not passed")
	check(TargetPlate.status_text(300, 340, 1) == "PASSED · 1 hand left", "goal_passed_one_hand")
	var want := {"goal_target_label": "TARGET", "goal_to_go": "{n} to go · {h} hands left",
		"goal_to_go_one_hand": "{n} to go · 1 hand left", "goal_passed": "PASSED · {h} hands left",
		"goal_passed_one_hand": "PASSED · 1 hand left", "goal_over": "+{n}", "goal_miss": "Missed: -{s} Soul",
		"hud_seals_chip": "SEALS · {n}", "hud_nerve": "Nerve {n}", "goal_hint": "Bank points to reach the target."}
	for id: String in want:
		check(GoalStrings.get_text(id) == want[id], "strings_v1 %s" % id)


## PC: the real HUD, the stub following the run, every plate state, chips.
func _check_pc() -> void:
	var m: Array = await _make(Vector2i(1920, 1080))
	var s: Bonfire3D = m[1]
	s._refresh_hud()
	var h := s.bhud
	var p := h.target_plate
	var g := h.goal_state
	check(g != null and p.goal == g, "the HUD made a TableGoalState for the run and bound the plate")
	check(p.is_visible_in_tree() and not h.checklist_panel.visible and not h.portrait_goal.visible, "plate shown, bounty cards and portrait readout hidden")
	check(not h.hands_label.visible, "the hands line moved onto the plate")
	# Empty PR1 state: no chips, SEALS hidden, target from the stub.
	check(p.target_value.text == "300" and p.target_label.text == "TARGET", "TARGET 300 (%s)" % p.target_value.text)
	check(p.chip_row.get_child_count() == 0, "no bounties: no empty chips")
	check(not p.seals_chip.visible, "0 seals: no SEALS chip")
	# The stub follows the run: a real throw and bank change banked / hands.
	var seen := {"changed": 0, "banked": 0}
	g.changed.connect(func() -> void: seen["changed"] += 1)
	g.banked_changed.connect(func(_v: int) -> void: seen["banked"] += 1)
	for i in 600:
		if s.run.state == BonfireRun.State.AIM and not s.hand_moving():
			break
		await process_frame
	var hands0 := s.run.hands_left
	s.run.set_throw([1, 1, 1, 5, 5] as Array[int])
	s.run.toggle(0); s.run.toggle(1); s.run.toggle(2)
	s.run.bank()
	await _frames(2)
	check(g.banked == s.run.points and s.run.points > 0, "banked follows run.points (%d / %d)" % [g.banked, s.run.points])
	check(g.hands_left == s.run.hands_left and g.hands_left == hands0 - 1, "hands_left follows the run")
	check(seen["banked"] >= 1 and seen["changed"] >= 1, "banked_changed and changed fired")
	check(p.banked_value.text == TargetPlate.fmt(s.run.points), "plate banked number redraws on changed")
	# Stub values: chips (max 2), SEALS, bar, passed, boss, miss.
	g._bounties = [{"icon_id": &"clean_hands", "text": "Clean Hands"}, {"icon_id": &"usurers_ledger", "text": "Usurer's Ledger"},
		{"icon_id": &"pair_up", "text": "Pair Up"}]
	g.set_for_test(270, 120, 3, null, 4)
	await _frames(2)
	var chips := p.chip_row.get_children().filter(func(c: Node) -> bool: return c is GoalIcon)
	check(chips.size() == 2, "at most 2 chips (%d)" % chips.size())
	check(p.line3.text == "150 to go · 3 hands left" and not p.line3_extra.visible, "line 3 to go")
	check(is_equal_approx(p.fill(), 120.0 / 270.0) and p.bar_color() == Palette.BRASS, "bar fill and brass")
	check(p.seals_chip.visible and p.seals_chip.text == "SEALS · 4", "SEALS · 4 (%s)" % p.seals_chip.text)
	var pressed := [0]
	p.seals_pressed.connect(func() -> void: pressed[0] += 1)
	p.seals_chip.pressed.emit()
	check(pressed[0] == 1, "SEALS opens the Seals list (seals_pressed)")
	g.set_for_test(270, 310, 2, null, 4)
	await _frames(1)
	check(p.line3.text == "PASSED · 2 hands left" and p.line3_extra.visible and p.line3_extra.text == "+40", "passed: PASSED + over (%s %s)" % [p.line3.text, p.line3_extra.text])
	check(p.bar_color() == Color("#F0CC72"), "bar is #F0CC72 at 100%")
	g.set_for_test(123456, 12400, 2, null, 4)
	await _frames(1)
	check(p.target_value.text == "123.5k" and p.banked_value.text == "12,400", "plate abbreviates above 99,999")
	p.show_miss(5)
	check(p.line3.text == "Missed:" and p.line3.label_settings.font_color == Palette.DANGER, "miss: 'Missed:' in red")
	check(p.line3_extra.text == "-5 Soul" and p.line3_extra.label_settings.font_color == Palette.SOUL_FLAME and p.line3_extra.visible, "miss: Soul in cyan")
	p.show_miss(-1)
	# Hover 150 ms (not sooner) or tap opens the name card.
	var chip: GoalIcon = p.chip_row.get_child(0)
	chip.mouse_entered.emit()
	await create_timer(0.08).timeout
	check(not p.card.visible, "no card before 150 ms")
	await create_timer(0.15).timeout
	check(p.card.visible and p.card_label.text == "Clean Hands", "card after 150 ms hover (%s)" % p.card_label.text)
	chip.mouse_exited.emit()
	check(not p.card.visible, "card hides on leave")
	var tap := InputEventScreenTouch.new()
	tap.pressed = true
	chip.gui_input.emit(tap)
	check(p.card.visible, "a tap opens the card")
	chip.gui_input.emit(tap)
	check(not p.card.visible, "a second tap closes it")
	# Placement (AD Oct 30): w756 top-centre at y24 of 1600x900 = w907 x506 y29 here.
	var r := p.get_global_rect()
	check(absf(r.size.x - 756 * 1.2) < 1 and absf(r.get_center().x - 960) < 1 and absf(r.position.y - 24 * 1.2) < 1, "PC plate x1.4, top-centre %s" % r)
	_check_sizes(p, 1.2, "PC", 14, 16, 24, 16)
	check(p.seals_chip.position.y >= r.end.y and p.seals_chip.position.y - r.end.y < 8 * 1.2 and absf(p.seals_chip.position.x - r.position.x) < 1, "PC SEALS just under the plate's left end")
	check(not r.grow(23).intersects(h.coin_label.get_global_rect()) and not r.intersects(h.points_label.get_global_rect()), "plate clear of the Embers readout")
	await _check_nerve_clear(s, "PC")
	m[0].queue_free()
	await process_frame


func _check_nerve_clear(s: Bonfire3D, tag: String) -> void:
	for k in 600:  # a real throw, so the Nerve UI shows (it hides at AIM)
		if s.phase == Table3D.Phase.BET and s.run.state == BonfireRun.State.AIM and not s.hand_moving():
			break
		await process_frame
	s.quick_throw()
	await s.sequence_finished
	await _frames(4)
	var h := s.bhud
	check(s.nerve_ui.pip.is_visible_in_tree(), "%s: Nerve pip showing after a throw" % tag)
	_nerve_clear(s, tag)
	check(s.nerve_ui.pip.flat, "%s: borderless Nerve chip" % tag)
	# Same frame: move the plate down onto the pip; no frame passes before the check.
	var p := h.target_plate
	p.global_position.y = s.nerve_ui.pip.get_global_rect().position.y
	_nerve_clear(s, tag + " same frame as the plate moves")
	s._refresh_hud()


func _nerve_clear(s: Bonfire3D, tag: String) -> void:
	var u := s.bhud.target_plate.unit
	var g := TargetPlace.goal_rect(s.bhud)
	var nb := s.nerve_ui.pip.get_global_rect()
	check(not nb.intersects(g.grow(24.0 * u - 1.0)), "%s: Nerve >= 24 px clear of the plate (%s vs %s)" % [tag, nb, g])


## Font sizes in screen px (k = px per spec unit): TARGET label / to-go line,
## banked number, chip size, padding.
func _check_sizes(p: TargetPlate, k: float, tag: String, label_min: float, banked_min: float, chip: float, pad: float) -> void:
	check(p.target_label.label_settings.font_size >= label_min * k - 0.5 and p.line3.label_settings.font_size >= label_min * k - 0.5, "%s: TARGET label and to-go line >= %d (%d / %d)" % [tag, label_min, p.target_label.label_settings.font_size, p.line3.label_settings.font_size])
	check(p.banked_value.label_settings.font_size >= banked_min * k - 0.5, "%s: banked number >= %d (%d)" % [tag, banked_min, p.banked_value.label_settings.font_size])
	check(is_equal_approx((p.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_top, pad * k), "%s: padding %d" % [tag, pad])
	var chips := p.chip_row.get_children().filter(func(c: Node) -> bool: return c is GoalIcon)
	check(chips.is_empty() or absf((chips[0] as Control).custom_minimum_size.x - chip * k) < 1, "%s: chips %d" % [tag, chip])


## The dealer art's screen rect (its mesh boxes projected).
func _dealer_rect(s: Bonfire3D) -> Rect2:
	var r := Rect2()
	var cam := s.get_viewport().get_camera_3d()
	for mi: VisualInstance3D in (s.dealer_art.scene if s.dealer_art.scene != null else s.dealer_art).find_children("*", "VisualInstance3D", true, false):
		if not mi.is_visible_in_tree():
			continue
		var bb := mi.global_transform * mi.get_aabb()
		for i in 8:
			var sp := cam.unproject_position(bb.get_endpoint(i))
			r = Rect2(sp, Vector2.ZERO) if not r.has_area() and r.position == Vector2.ZERO else r.expand(sp)
	return r


func _check_phone() -> void:
	var m: Array = await _make(Vector2i(2337, 1080))
	var s: Bonfire3D = m[1]
	s.fit_phone(Vector2(844, 390))
	s._refresh_hud()
	await _frames(2)
	var h := s.bhud
	var p := h.target_plate
	var u := 1080.0 / 390.0
	check(h.is_phone_land and is_equal_approx(p.unit, h.ui_pt_px), "phone landscape: 1 spec pt = ui_pt_px")
	var r := p.get_global_rect()
	check(absf(r.size.x - 390 * u) < 1.5 and absf(r.end.x - (2337 - 16 * u)) < 1.5 and absf(r.position.y - 40 * u) < 1.5, "phone plate w390 (46%%), right x-16, y40 (%s)" % (r.position / u))
	check(r.size.x / 2337.0 <= 0.47, "phone plate <= ~46% of the width")
	_check_sizes(p, u, "phone", 12, 12, 28, 12)
	check(p.target_value.label_settings.font_size >= 24 * u - 0.5, "phone TARGET number >= 24 pt")
	var dr := _dealer_rect(s)
	check(dr.has_area() and not r.intersects(dr), "phone plate clear of the dealer (%s vs %s)" % [r, dr])
	check(r.end.y <= 138 * u, "phone plate ends above the dice rest zone y138 (%.1f pt)" % (r.end.y / u))
	check(not h.checklist_panel.visible, "phone: no bounty cards")
	h.goal_state.set_for_test(300, 0, h.goal_state.hands_left, null, 2)
	await _frames(2)
	var sc := p.seals_chip.get_global_rect()
	check(p.seals_chip.visible and Rect2(Vector2.ZERO, Vector2(2337, 1080)).encloses(sc) and not sc.intersects(r), "phone SEALS on screen, off the plate")
	await _check_nerve_clear(s, "phone")
	m[0].queue_free()
	await process_frame


func _check_portrait() -> void:
	var m: Array = await _make(Vector2i(1920, 4155))
	var s: Bonfire3D = m[1]
	s.fit_phone(Vector2(390, 844))
	s._refresh_hud()
	await _frames(2)
	var h := s.bhud
	var p := h.target_plate
	var pt := h.ui_pt_px
	var r := p.get_global_rect()
	check(h.is_portrait and not h.portrait_goal.visible and not h.checklist_panel.visible, "portrait: the plate replaces the readout")
	# Not centred: it stops short of the pot row down the right edge (QA readout test).
	check(r.position.is_equal_approx(Vector2(12, 36) * pt) and r.end.x / pt <= 262.5, "portrait plate at (12, 36) pt, <= 250 pt wide (%s)" % (r.position / pt))
	check(is_equal_approx(p.unit, pt * 0.8) and r.position.x >= 0 and r.end.x <= 1920, "portrait scale 0.8, inside the screen")
	check(h.result_label.position.y >= TargetPlace.goal_rect(h).end.y, "bank / bust banner under the plate")
	await _check_nerve_clear(s, "portrait")
	m[0].queue_free()
	await process_frame
