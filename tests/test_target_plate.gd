## Target HUD v2.1 goal plate (art/concept/hud_target_oct30/v2/HANDOFF_SPEC.md,
## handoff/table_goals_v1_pr1.md §4), on its own (the HUD wiring is the next PR):
##   - number format (12,400 in full, 123,456 -> 123.5k) and the line 3 text;
##   - TableGoalState (stub) follows the real run on table_event;
##   - TARGET + number, bar + banked, to go / PASSED +n / Missed;
##     bar #F0CC72 at 100 %; no empty chips, at most 2; SEALS hides at 0;
##   - a 150 ms hover or a tap opens the chip's name card.
##   godot --headless --path . --script res://tests/test_target_plate.gd
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
	print("test_target_plate: %d passed, %d failed" % [_passed, _failed])
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


## A plate bound to TableGoalState.watch(s.run) on the real scene: the stub
## follows the run, every plate state, chips. (The HUD wiring is the next PR.)
func _check_pc() -> void:
	var m: Array = await _make(Vector2i(1920, 1080))
	var s: Bonfire3D = m[1]
	var p := TargetPlate.new()
	(m[0] as Node).add_child(p)
	var g := TableGoalState.watch(s.run)
	p.bind(g)
	await _frames(1)
	check(p.goal == g, "the plate is bound to the run's TableGoalState")
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
	# Boss: a small brass BOSS tag left of TARGET (no red); hidden otherwise.
	check(not p.boss_tag.visible, "no BOSS tag on a normal table")
	g.set_for_test(123456, 12400, 2, null, 4, true)
	await _frames(1)
	check(p.boss_tag.visible and p.boss_tag.text == "BOSS" and p.boss_tag.label_settings.font_color == Palette.BRASS_HI, "boss: brass BOSS tag")
	check(p.boss_tag.get_index() < p.target_label.get_index() and p.boss_tag.get_parent() == p.target_label.get_parent(), "BOSS sits left of TARGET")
	g.set_for_test(123456, 12400, 2, null, 4)
	# text_scale grows text (not padding or chips): AD PC x1.4.
	p.text_scale = 1.4
	p.restyle()
	await _frames(1)
	check(is_equal_approx(p.target_label.label_settings.font_size, roundi(12 * 1.2 * 1.4)), "text_scale 1.4: TARGET label %d" % p.target_label.label_settings.font_size)
	check(is_equal_approx((p.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_left, 16 * 1.2), "text_scale keeps the padding")
	check(is_equal_approx(p.chip_row.get_child(0).custom_minimum_size.x, 24 * 1.2), "text_scale keeps chips at 24 px")
	check(p.chip_row.get_theme_constant("separation") == roundi(12 * 1.2), "text_scale keeps the 12 px chip gaps")
	p.text_scale = 1.0
	p.restyle()
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
	m[0].queue_free()
	await process_frame
