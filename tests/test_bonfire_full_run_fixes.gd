## QA full run pass 1 (qa/full_run_pass_1.md), Godot Dev's Majors, part 1
## (part 2: test_bonfire_full_run_fixes_2.gd):
##   M1: a press-drag-release that starts on any die in the hand is a flick
##       throw, never a THROW / BANK button press, at 16:9 (1920x1080),
##       phone landscape (844x390 -> 2337x1080 canvas) and phone portrait
##       (390x844 -> 1920x4155): the buttons sit clear of the hand, and even
##       a button laid right over a die doesn't eat the grab.
##   M2: the tutorial plays on the run's FIRST table only (RunScreen, where
##       the table is a child of the current scene), and on the sandbox's
##       Table 1; not on later run tables, not in tests / tools.
##   #103 F1: while picking, a click on a thrown die under THROW / BANK pots
##       the die (or shakes it if unlit) and presses no button.
##   godot --headless --path . --script res://tests/test_bonfire_full_run_fixes.gd
extends "res://tests/full_run_fixes_base.gd"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _m1_hand_grabs()
	await _m2_tutorial()
	await _f1_pick_under_buttons()
	print("test_bonfire_full_run_fixes: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _m1_hand_grabs() -> void:
	var cases := [["16:9 1920x1080", Vector2i(1920, 1080), Vector2(1920, 1080)],
		["phone landscape 844x390", Vector2i(2337, 1080), Vector2(844, 390)],
		["phone portrait 390x844", Vector2i(1920, 4155), Vector2(390, 844)]]
	for c in cases:
		var made: Array = await _table_in(c[1], c[2])
		var sv: SubViewport = made[0]
		var s: Bonfire3D = made[1]
		var presses := [0]
		s.bhud.throw_pressed.connect(func() -> void: presses[0] += 1)
		s.bhud.bank_pressed.connect(func() -> void: presses[0] += 1)
		await _wait_in_hand(s)
		var buttons := [s.bhud.throw_button.get_global_rect(), s.bhud.bank_button.get_global_rect()]
		var n := s.dice.size()
		for i in n:
			await _wait_in_hand(s)
			var p := s.camera.cam.unproject_position(s.dice[i].global_position)
			# The die's screen footprint (~half a die across) is clear of both buttons.
			var die_box := Rect2(p - Vector2(30, 30), Vector2(60, 60))
			check(not buttons.any(func(r: Rect2) -> bool: return r.intersects(die_box)),
				"%s: die %d at %s is clear of THROW / BANK" % [c[0], i, p.round()])
			await _flick_and_check(sv, s, p, presses, "%s: die %d" % [c[0], i])
		# Even with THROW laid right over a die, pressing that die grabs.
		await _wait_in_hand(s)
		var p0 := s.camera.cam.unproject_position(s.dice[0].global_position)
		var col := s.bhud.throw_button.get_parent() as Control
		var home := col.position
		col.position = p0 - Vector2(40, 40)
		await process_frame
		check(s.bhud.throw_button.get_global_rect().has_point(p0), "%s: THROW moved over die 0 for the overlap check" % c[0])
		await _flick_and_check(sv, s, p0, presses, "%s: die 0 under THROW" % c[0])
		col.position = home
		sv.queue_free()
		await process_frame


func _m2_tutorial() -> void:
	var old := _fresh_settings()
	check(not old.is_empty(), "GameSettings autoload present")
	var gs := root.get_node_or_null("GameSettings")
	# Sandbox Table 1 as the current scene: plays.
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	root.add_child(s)
	current_scene = s
	# (current_scene can only be set once it's in the tree; deal again.)
	s.new_run(5)
	await process_frame
	check(s.bhud.tutorial.active, "sandbox Table 1 (current scene): tutorial plays")
	current_scene = null
	s.queue_free()
	await process_frame
	# Not the current scene (tests / tools): never.
	gs.tutorial_seen = false
	s = (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	root.add_child(s)
	await process_frame
	check(not s.bhud.tutorial.active, "a table outside the current scene (tests / tools): no tutorial")
	s.queue_free()
	await process_frame
	# The run: the table is a child of RunScreen (the current scene).
	gs.tutorial_seen = false
	var scene: RunScreen = (load("res://scenes/run.tscn") as PackedScene).instantiate()
	scene.run_seed = 4242
	root.add_child(scene)
	current_scene = scene
	await process_frame
	var run := scene.run
	check(run.table_setup().to_table_setup(scene.bonfire_tuning).first_table, "run setup: the first table is flagged first_table")
	var played := 0
	for step in 60:
		if played >= 2:
			break
		match run.screen:
			MapRun.Screen.MAP:
				# Head for a table (Table / Elite node) when one is reachable.
				var to: int = run.map.reachable()[0]
				for id in run.map.reachable():
					if run.map.node(id).type in [MapGenData.NodeType.TABLE, MapGenData.NodeType.ELITE]:
						to = id
						break
				run.choose_node(to)
			MapRun.Screen.TABLE:
				if played == 1:
					# Seen or not, a later table never gets it.
					gs.tutorial_seen = false
				scene._play_table()
				var t: Bonfire3D = scene._table
				await process_frame
				if played == 0:
					check(t.setup.first_table and t.bhud.tutorial.active, "run: the first table plays the tutorial (child of RunScreen)")
				else:
					check(not t.setup.first_table and not t.bhud.tutorial.active, "run: the second table has no tutorial (first_table %s)" % t.setup.first_table)
				played += 1
				t.forfeit()
				t.bhud.continue_pressed.emit()
				await process_frame
			MapRun.Screen.REWARD:
				run.take_seal(-1)
			MapRun.Screen.EVENT:
				for i in run.event.choices.size():
					if run.screen == MapRun.Screen.EVENT and EventApplier.can_choose(run.event.choices[i], run.progress) \
							and EventApplier.picks_needed(run.event.choices[i]) == 0:
						run.choose_event(i)
			_:
				# Shop / rest: back to the map.
				run.leave()
		await process_frame
	check(played == 2, "run: reached two tables (%d)" % played)
	current_scene = null
	scene.queue_free()
	await process_frame
	_restore_settings(old)


func _f1_pick_under_buttons() -> void:
	var made: Array = await _table_in(Vector2i(1920, 1080), Vector2(1920, 1080))
	var sv: SubViewport = made[0]
	var s: Bonfire3D = made[1]
	var presses := [0]
	s.bhud.throw_pressed.connect(func() -> void: presses[0] += 1)
	s.bhud.bank_pressed.connect(func() -> void: presses[0] += 1)
	await _wait_in_hand(s)
	# Three 5s burn (trips), the 6 doesn't.
	s.rig_faces([5, 5, 5, 2, 6] as Array[int])
	s.quick_throw()
	await s.sequence_finished
	s.pick_die(0)
	s.pick_die(1)
	await _idle(s)
	var hands: int = s.run.hands_left
	check(s.run.state == BonfireRun.State.PICK and s.run.can_continue() and not s.bhud.bank_button.disabled,
		"F1 setup: a pair of 5s potted, BANK live")
	# A burning die under THROW: the click pots it (trips now).
	var p := s.camera.cam.unproject_position(s.throw_dice[2].global_position)
	_button_over(s, s.bhud.throw_button, p)
	await process_frame
	check(s.bhud.throw_button.get_global_rect().has_point(p), "F1: THROW laid over the third 5")
	_click(sv, p)
	await _idle(s)
	check(s.run.potted.has(2) and s.run.potted.size() == 3, "F1: the click under THROW pots the die (potted %s)" % str(s.run.potted))
	check(presses[0] == 0 and s.run.hands_left == hands and s.run.state == BonfireRun.State.PICK, "F1: ...and presses nothing (no rethrow, hands %d)" % s.run.hands_left)
	# The unlit 6 under BANK: the click is refused (shake), nothing banks.
	p = s.camera.cam.unproject_position(s.throw_dice[4].global_position)
	check(not s.is_lit(s.throw_dice[4]), "F1: the 6 doesn't burn")
	_button_over(s, s.bhud.bank_button, p)
	await process_frame
	check(s.bhud.bank_button.get_global_rect().has_point(p), "F1: BANK laid over the 6")
	_click(sv, p)
	await _idle(s)
	check(not s.run.potted.has(4) and s.run.potted.size() == 3, "F1: the click under BANK on an unlit die is refused (potted %s)" % str(s.run.potted))
	check(presses[0] == 0 and s.run.hands_left == hands and s.run.state == BonfireRun.State.PICK, "F1: ...and doesn't bank the hand (hands %d)" % s.run.hands_left)
	sv.queue_free()
	await process_frame
