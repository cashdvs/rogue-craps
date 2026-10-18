## QA: scripted mouse/keyboard input edge cases on scenes/table.tscn.
## Sends real InputEvents through the viewport (root.push_input).
## Run: godot --headless --path . --script res://tests/qa_/qa_input_edges.gd
extends SceneTree
var p := 0
var f := 0
var scene: TableScene
func check(c: bool, what: String) -> void:
	if c: p += 1
	else:
		f += 1
		print("FAIL  ", what)
func _initialize() -> void:
	_run.call_deferred()

var k := Vector2.ONE  # unused
func to_screen(pos: Vector2) -> Vector2:
	return scene.get_viewport().get_final_transform() * (scene.get_canvas_transform() * pos)
func mouse_btn(pos: Vector2, pressed: bool, btn := MOUSE_BUTTON_LEFT) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = btn; e.pressed = pressed; e.position = to_screen(pos); e.global_position = to_screen(pos)
	Input.parse_input_event(e)
	Input.flush_buffered_events()
func motion(pos: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = to_screen(pos); e.global_position = to_screen(pos)
	Input.parse_input_event(e)
	Input.flush_buffered_events()
func key(code: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = code; e.pressed = true
	Input.parse_input_event(e)
	var u := InputEventKey.new(); u.keycode = code; u.pressed = false
	Input.parse_input_event(u)
	Input.flush_buffered_events()
func frames(n: int) -> void:
	for i in n: await process_frame
func msleep(ms: int) -> void:
	await create_timer(ms / 1000.0).timeout

func _run() -> void:
	scene = (load("res://scenes/table.tscn") as PackedScene).instantiate()
	scene.test_speed = 6.0
	scene.rng_seed = 99
	root.add_child(scene)
	await frames(2)
	var poc := scene.poc
	var hand := TableScene.HAND
	var pass_pt := TableScene.PASS_SPOT

	# Grab with no bet: refused, stays BET.
	mouse_btn(hand, true); await frames(1)
	check(scene.phase == TableScene.Phase.BET, "grab without bet refused")
	mouse_btn(hand, false); await frames(1)
	check(poc.rolls_used == 0, "no roll without bet")

	# Click Pass Line to add chips; cap via repeated clicks and keyboard.
	for i in 8:
		mouse_btn(pass_pt, true); mouse_btn(pass_pt, false)
	await frames(1)
	check(poc.table.stake_on(&"pass") == 20 and poc.bankroll.coin == 0, "8 clicks with 20 Coin -> stake 20 (got %d)" % poc.table.stake_on(&"pass"))
	poc.bankroll.add(30)
	for i in 6: key(KEY_UP)
	await frames(1)
	check(poc.table.stake_on(&"pass") == 25 and poc.bankroll.coin == 25, "repeated adds capped at 25 (stake %d coin %d)" % [poc.table.stake_on(&"pass"), poc.bankroll.coin])
	mouse_btn(pass_pt, true, MOUSE_BUTTON_RIGHT); await frames(1)
	check(poc.table.stake_on(&"pass") == 0 and poc.bankroll.coin == 50, "right-click takes down before come-out")
	poc.bankroll.set_coin(20)
	mouse_btn(pass_pt, true); mouse_btn(pass_pt, false); await frames(1)

	# Plain click on dice, no drag: drops back, no roll.
	mouse_btn(hand, true); await frames(1)
	check(scene.phase == TableScene.Phase.HELD, "press on hand grabs (HELD)")
	await msleep(120)
	mouse_btn(hand, false); await frames(1)
	check(scene.phase == TableScene.Phase.BET and poc.rolls_used == 0, "plain click: no roll")

	# Weak flick: slow long drag -> no roll.
	mouse_btn(hand, true)
	for i in 10:
		motion(hand - Vector2(i * 15, i * 8)); await msleep(30)
	mouse_btn(hand - Vector2(150, 80), false); await frames(1)
	check(poc.rolls_used == 0 and scene.phase == TableScene.Phase.BET, "slow drag: no roll")

	# Strong flick via real events.
	scene.rig_next_roll(2, 2)  # point 4
	mouse_btn(hand, true); await frames(1)
	motion(hand + Vector2(-40, -20)); await msleep(16)
	motion(hand + Vector2(-200, -110)); await msleep(16)
	mouse_btn(hand + Vector2(-400, -220), false); await frames(1)
	var rolled := scene.is_busy()
	check(rolled, "fast flick rolls (real-time velocity)")
	if rolled:
		# Double-roll attempts while in motion
		key(KEY_SPACE); mouse_btn(hand, true); mouse_btn(hand, false); key(KEY_UP)
		check(scene.poc.table.stake_on(&"pass") == 5, "no bet change while rolling")
		await scene.sequence_finished
		check(poc.rolls_used == 1, "exactly one roll consumed (got %d)" % poc.rolls_used)
		check(poc.table.craps.point == 4, "point 4 set")
		# Bet lock while point on: click, key, right-click
		mouse_btn(pass_pt, true); mouse_btn(pass_pt, false); key(KEY_UP); key(KEY_DOWN)
		mouse_btn(pass_pt, true, MOUSE_BUTTON_RIGHT); await frames(1)
		check(poc.table.stake_on(&"pass") == 5 and poc.bankroll.coin == 15, "Pass locked during point (all inputs)")

	# Drag off-screen then release off-screen.
	mouse_btn(hand, true); await frames(1)
	motion(Vector2(2500, 1400)); await msleep(200)
	mouse_btn(Vector2(2500, 1400), false); await frames(1)
	check(scene.phase == TableScene.Phase.BET, "off-screen slow release returns to BET (phase %d)" % scene.phase)

	# Space quick throw then RUN OVER at 0 Soul: input blocked.
	poc.soul = 1; scene._soul_shown = 1
	scene.rig_next_roll(3, 4)  # seven-out
	key(KEY_SPACE); await frames(1)
	await scene.table_finished
	await frames(2)
	check(poc.soul == 0 and poc.is_over() and scene.end_title.text == "RUN OVER", "RUN OVER at 0 Soul")
	var used := poc.rolls_used
	if scene.phase != TableScene.Phase.OVER: await scene.sequence_finished
	check(scene.phase == TableScene.Phase.OVER, "phase OVER after run over")
	mouse_btn(pass_pt, true); mouse_btn(pass_pt, false); key(KEY_UP)
	mouse_btn(hand, true); mouse_btn(hand + Vector2(-400, -220), false)
	check(scene.place() != "" and not scene.throw(Vector2(-2500, -1200)), "API refuses bet/throw after run over")
	check(poc.rolls_used == used and poc.table.stake_on(&"pass") == 0, "no rolls/bets after run over")
	check(poc.bankroll.coin >= 0, "bankroll never negative")
	key(KEY_SPACE); await frames(1)
	check(scene.poc.soul == 40 and scene.table_number == 1, "Space on RUN OVER restarts")
	print("=== qa_input_edges: %d passed, %d failed ===" % [p, f])
	scene.queue_free()
	await create_timer(0.5).timeout
	quit(1 if f > 0 else 0)
