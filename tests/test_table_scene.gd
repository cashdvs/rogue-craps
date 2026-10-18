## Headless smoke test for the POC table scene (scenes/table.tscn) and the
## throw-gesture threshold logic. No mouse needed: it uses the public API
## (place / take_down / throw / rig_next_roll) that the mouse input calls.
##
## Run:
##   godot --headless --path /workspace/dice/game --script res://tests/test_table_scene.gd
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


func _run() -> void:
	_test_gesture()
	await _test_scene()
	print("test_table_scene: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# --- ThrowGesture (pure logic) ---------------------------------------------------

func _test_gesture() -> void:
	var t := TuningData.new()
	var g := ThrowGesture.new(t)
	# A plain click-release: no movement, not a throw.
	g.press(Vector2(1780, 870), 0.0)
	var v := g.release(Vector2(1780, 870), 0.15)
	check(not ThrowGesture.is_throw(v, g.drag_distance(), t), "click-release is not a throw")
	# A slow drag: moves far but slowly.
	g.press(Vector2(1780, 870), 0.0)
	for i in 20:
		g.move(Vector2(1780 - i * 10, 870 - i * 5), i * 0.05)
	v = g.release(Vector2(1580, 770), 1.0)
	check(v.length() < t.min_throw_speed, "slow drag speed below threshold (%.0f)" % v.length())
	check(not ThrowGesture.is_throw(v, g.drag_distance(), t), "slow drag is not a throw")
	# A quick flick: 300 px in 0.1 s.
	g.press(Vector2(1780, 870), 0.0)
	g.move(Vector2(1740, 850), 0.02)
	g.move(Vector2(1640, 800), 0.06)
	v = g.release(Vector2(1500, 730), 0.1)
	check(v.length() >= t.min_throw_speed, "flick speed above threshold (%.0f)" % v.length())
	check(v.x < 0.0 and v.y < 0.0, "flick direction kept (up-left)")
	check(ThrowGesture.is_throw(v, g.drag_distance(), t), "quick flick is a throw")
	# Fast but tiny (a twitch): not a throw.
	check(not ThrowGesture.is_throw(Vector2(-3000, 0), 10.0, t), "fast but tiny drag is not a throw")
	# Release without a press does nothing.
	check(g.release(Vector2.ZERO, 2.0) == Vector2.ZERO, "release without press -> zero")

	# Paths: always end in the rest rect; a hard flick bounces off the rim.
	var bounds := TablePainter.FELT_RECT.grow(-70.0)
	var rest := TableScene.REST_RECT
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var bounced := 0
	for i in 200:
		var vel := Vector2.from_angle(rng.randf_range(PI, TAU)) * rng.randf_range(t.min_throw_speed, t.max_throw_speed)
		var path := ThrowGesture.plan_path(TableScene.HAND, vel, bounds, rest, t)
		var end := path[path.size() - 1]
		if not rest.grow(0.5).has_point(end):
			check(false, "path end %s outside rest rect" % end)
		if path.size() > 2:
			bounced += 1
	check(bounced > 20, "some throws bounce off the rim (%d/200)" % bounced)
	var hard := ThrowGesture.plan_path(TableScene.HAND, Vector2(-4000, -2200), bounds, rest, t)
	check(hard.size() > 2, "a hard flick hits the rim")
	check(hard[1].x <= bounds.position.x + 1.0 or hard[1].y <= bounds.position.y + 1.0, "...the back/left rim")


# --- Scene ----------------------------------------------------------------------------

func _test_scene() -> void:
	var packed := load("res://scenes/table.tscn") as PackedScene
	var scene := packed.instantiate() as TableScene
	scene.test_speed = 6.0
	scene.rng_seed = 2026
	root.add_child(scene)
	await process_frame
	var poc := scene.poc
	var t := scene.tuning
	check(poc.bankroll.coin == 20 and poc.soul == 40 and poc.rolls_left() == 12, "starts at doc v0.3 numbers")
	check(scene.rolls_label.text == "12" and scene.target_label.text == "40", "HUD shows rolls and target")

	# Can't throw without a bet (ROLL disabled below 5).
	check(not scene.throw(Vector2(-2500, -1200)), "no throw without a Pass bet")
	check(poc.rolls_used == 0, "...and no roll used")

	# Click-to-stack: 4 chips spend the whole 20 stake; a 5th is refused.
	for i in 4:
		check(scene.place() == "", "chip %d accepted" % (i + 1))
	check(poc.table.stake_on(&"pass") == 20 and poc.bankroll.coin == 0, "stake 20 after 4 chips")
	check(scene.place() != "", "chip with no Coin left refused")
	# The 25 cap (give the bankroll room for this check only).
	poc.bankroll.add(20)
	check(scene.place() == "", "5th chip accepted with Coin")
	check(poc.table.stake_on(&"pass") == 25, "stake 25 after 5 chips")
	check(scene.place() != "", "chip past 25 refused")
	check(poc.table.stake_on(&"pass") == 25 and poc.bankroll.coin == 15, "refusal changed nothing")
	check(scene.take_down() == "", "take down before come-out")
	check(poc.bankroll.coin == 40 and poc.table.stake_on(&"pass") == 0, "take down returned the Coin")
	poc.bankroll.spend(20)
	check(scene.place() == "", "bet 5 again")

	# Weak throws drop back: no roll consumed.
	var drops := [0]
	scene.dropped_back.connect(func() -> void: drops[0] += 1)
	check(not scene.throw(Vector2(-200, -100)), "weak flick does not roll")
	check(not scene.throw(Vector2(-2500, -1200), TableScene.HAND, 5.0), "tiny drag does not roll")
	check(poc.rolls_used == 0 and drops[0] == 2, "weak throws used no roll and dropped back")
	check(not scene.is_busy(), "not busy after a drop")

	# Strong throw rolls: a rigged Natural (3+4) pays 1:1.
	scene.rig_next_roll(3, 4)
	var landed: Array = []
	scene.dice_landed.connect(func(v: Array[int]) -> void: landed.append(v))
	check(scene.throw(Vector2(-2500, -1200)), "strong flick rolls")
	check(scene.is_busy(), "busy while rolling")
	check(not scene.throw(Vector2(-2500, -1200)), "can't throw again mid-roll")
	await scene.sequence_finished
	check(poc.rolls_used == 1, "strong throw consumed a roll")
	check(landed.size() == 1 and landed[0] == [3, 4], "dice landed showing the predetermined faces")
	check(scene._dice[0].shown_value == 3 and scene._dice[1].shown_value == 4, "die views show 3 and 4")
	check(poc.bankroll.coin == 25, "natural paid 5 -> 25 (got %d)" % poc.bankroll.coin)
	await create_timer(0.2).timeout
	check(int(round(scene.stack.displayed)) == poc.bankroll.coin, "bankroll stack shows coin")
	check(scene.rolls_label.text == "11", "rolls left 11")
	check(scene._felt_chips.is_empty(), "felt cleared after collect")

	# Point 8, then locked betting, then seven-out with Hot Seven.
	check(scene.place() == "", "bet 5 for the next come-out")
	scene.rig_next_roll(6, 2)
	check(scene.throw(Vector2(-2000, -1500)), "throw for point")
	await scene.sequence_finished
	check(poc.table.craps.point == 8, "point is 8")
	check(scene.puck.is_on and scene.puck.number == 8, "puck ON 8")
	check(scene.puck.position.distance_to(TablePainter.point_box_center(8)) < 2.0, "puck on the 8 box")
	check(scene.place() != "", "Pass Line locked during the point")
	check(scene.take_down() != "", "can't take down during the point")
	scene.rig_next_roll(3, 3)
	check(scene.throw(Vector2(-2000, -900)), "throw during point (bet locked, still allowed)")
	await scene.sequence_finished
	scene.rig_next_roll(4, 3)
	var soul_before := poc.soul
	check(scene.throw(Vector2(-2600, -1300)), "throw seven")
	await scene.sequence_finished
	var expected := PocTable.soul_damage_for(RollResult.Outcome.SEVEN_OUT, 5, t, poc.rule)
	check(expected == 3, "seven-out on 5 (no table rule in the POC) = 2+1 = 3")
	check(not scene.plaque.visible, "no rule plaque (doc v0.4: table rules out of POC scope)")
	check(poc.soul == soul_before - expected, "Soul burned by the seven-out")
	check(scene.soul_meter.soul == poc.soul, "Soul meter matches (%d vs %d)" % [scene.soul_meter.soul, poc.soul])
	check(not scene.puck.is_on, "puck OFF after seven-out")
	check(poc.bankroll.coin == 20, "lost the 5")

	# Craps also costs Soul (PM: every Pass loss costs Soul).
	check(scene.place() == "", "bet before craps")
	scene.rig_next_roll(1, 1)
	soul_before = poc.soul
	scene.throw(Vector2(-2500, -1200))
	await scene.sequence_finished
	check(poc.soul == soul_before - 2, "craps on 5: 1 + ceil(5/10) = 2 Soul")

	# Taunts fire from the lines file.
	var taunts: Array = []
	scene.taunted.connect(func(e: StringName, l: String) -> void: taunts.append([e, l]))
	check(scene.place() == "", "bet before taunt check")
	scene.rig_next_roll(5, 6)
	scene.throw(Vector2(-2500, -1200))
	await scene.sequence_finished
	check(taunts.size() >= 1 and taunts[0][0] == &"natural" and taunts[0][1] != "", "dealer taunts on a natural")

	# Skip: a click during the reveal fast-forwards.
	check(scene.place() == "", "bet before skip test")
	scene.rig_next_roll(2, 2)
	scene.throw(Vector2(-2500, -1200))
	await scene.dice_landed
	scene.skip()
	check(scene._skip and Engine.time_scale >= 6.0 * t.fast_roll_speed - 0.01, "skip speeds up the reveal")
	await scene.sequence_finished
	check(Engine.time_scale == 1.0, "time scale restored after the roll")

	# Play the table out with real (seeded) rolls until it ends.
	var guard := 0
	while not poc.is_over() and guard < 40:
		guard += 1
		if not poc.table.craps.has_point() and poc.table.stake_on(&"pass") == 0:
			if scene.place() != "":
				break
		if not scene.quick_throw():
			break
		await scene.sequence_finished
	check(poc.is_over(), "table ended (status %d)" % poc.status)
	check(scene.end_layer.visible, "end screen shown")
	check(scene.end_body.text.contains("Soul lost: %d" % poc.soul_lost()), "end screen shows Soul lost")
	check(scene.end_body.text.contains("Coin surplus"), "end screen shows Coin surplus")
	var soul_left := poc.soul
	if soul_left > 0:
		check(scene.end_button.text == "NEXT TABLE", "end button is NEXT TABLE")
		scene.next_table()
		check(scene.table_number == 2 and scene.poc.soul == soul_left and scene.poc.rolls_used == 0 and scene.poc.bankroll.coin == 20,
			"next table: same stake/rolls, Soul carries over (%d)" % scene.poc.soul)
		check(scene.table_label.text == "TABLE 2", "HUD shows table 2")
	scene.restart(7)
	check(not scene.end_layer.visible and scene.table_number == 1 and scene.poc.rolls_used == 0 and scene.poc.soul == 40, "restart resets the run")
	# Run over at 0 Soul: RESTART.
	scene.poc.soul = 1
	scene._soul_shown = 1
	check(scene.place() == "", "bet before the last seven")
	scene.rig_next_roll(1, 1)
	scene.throw(Vector2(-2500, -1200))
	await scene.table_finished
	check(scene.poc.soul == 0 and scene.end_title.text == "RUN OVER" and scene.end_button.text == "RESTART", "0 Soul -> run over + RESTART")
	scene.next_table()
	check(scene.table_number == 1 and scene.poc.soul == 40, "RESTART from run over starts a new run")

	# Reduced motion still plays a full roll.
	scene.set_reduced_motion(true)
	check(scene.place() == "", "bet in reduced motion")
	scene.rig_next_roll(6, 5)
	scene.throw(Vector2(-2500, -1200))
	await scene.sequence_finished
	check(scene.poc.rolls_used == 1 and scene.poc.bankroll.coin == 25, "reduced-motion roll resolves")
	scene.queue_free()
	await create_timer(1.0).timeout
