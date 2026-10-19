## QA full run pass 1 (qa/full_run_pass_1.md), Godot Dev's Majors:
##   M1: a press-drag-release that starts on any die in the hand is a flick
##       throw, never a THROW / BANK button press, at 16:9 (1920x1080),
##       phone landscape (844x390 -> 2337x1080 canvas) and phone portrait
##       (390x844 -> 1920x4155): the buttons sit clear of the hand, and even
##       a button laid right over a die doesn't eat the grab.
##   M2: the tutorial plays on the run's FIRST table only (RunScreen, where
##       the table is a child of the current scene), and on the sandbox's
##       Table 1; not on later run tables, not in tests / tools.
##   M4: running out of hands uncleared burns the Soul meter by the table's
##       penalty; a cleared table burns nothing.
##   godot --headless --path . --script res://tests/test_bonfire_full_run_fixes.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0
## The fake flick clock (seconds) the gestures run on.
var _clock_t: float = 0.0


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


func _run() -> void:
	await _m1_hand_grabs()
	await _m2_tutorial()
	await _m4_soul_meter()
	print("test_bonfire_full_run_fixes: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# --- M1 -----------------------------------------------------------------------------

## A sandbox table inside a SubViewport of the given canvas size (what the
## window stretches to at that aspect), framed like that screen.
func _table_in(canvas: Vector2i, screen: Vector2) -> Array:
	var sv := SubViewport.new()
	sv.size = canvas
	root.add_child(sv)
	var t := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = TableSetup.sandbox(t, 5)
	s.tutorial_override = 0
	s.test_speed = 10.0
	sv.add_child(s)
	await process_frame
	await process_frame
	s.camera.cam.current = true
	if screen != Vector2(canvas):
		s.fit_phone(screen)
	s.camera.snap_home()
	return [sv, s]


func _wait_in_hand(s: Bonfire3D) -> void:
	for k in 600:
		if s.phase == Table3D.Phase.BET and not s.hand_moving():
			return
		await process_frame


func _click_event(p: Vector2, down: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = p
	e.global_position = p
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	return e


## Real input through the viewport (so the GUI gets its chance first):
## press at p, drag up-left at `speed` px/s for 0.2 s, release.
func _flick_from(sv: SubViewport, s: Bonfire3D, p: Vector2, speed: float) -> void:
	_clock_t = 0.0
	s.flick_clock = func() -> float: return _clock_t
	var dir := Vector2(-0.55, -0.83).normalized()
	sv.push_input(_click_event(p, true), true)
	var t := 0.0
	while t < 0.2:
		t += 0.008
		_clock_t = t
		var mm := InputEventMouseMotion.new()
		mm.position = p + dir * speed * t
		mm.global_position = mm.position
		mm.button_mask = MOUSE_BUTTON_MASK_LEFT
		sv.push_input(mm, true)
	sv.push_input(_click_event(p + dir * speed * t, false), true)
	s.flick_clock = Callable()


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


## Flick from p; it must start a flick throw (launch speed from the drag,
## not the canned quick throw) and press no button. Then a fresh hand.
func _flick_and_check(sv: SubViewport, s: Bonfire3D, p: Vector2, presses: Array, what: String) -> void:
	var before: int = presses[0]
	s.last_launch = {}
	await _flick_from(sv, s, p, 4000.0)
	var thrown := s.phase != Table3D.Phase.BET and s.phase != Table3D.Phase.HELD
	var flick := float(s.last_launch.get("flick", 0.0))
	var want := 4000.0 * s.sensitivity()
	check(thrown and presses[0] == before, "%s: press-drag-release throws (phase %d) and presses no button (%d presses)" % [what, s.phase, presses[0] - before])
	check(absf(flick - want) < want * 0.15, "%s: it's the flick (%.0f px/s, want ~%.0f), not a quick throw" % [what, flick, want])
	if thrown:
		await s.sequence_finished
	s.new_run(11)


# --- M2 -----------------------------------------------------------------------------

## GameSettings with a throwaway file, tutorial on and not seen yet.
func _fresh_settings() -> Dictionary:
	var gs := root.get_node_or_null("GameSettings")
	if gs == null:
		return {}
	var old := {"path": gs.path, "enabled": gs.tutorial_enabled, "seen": gs.tutorial_seen}
	gs.path = "user://test_full_run_fixes_settings.cfg"
	gs.tutorial_enabled = true
	gs.tutorial_seen = false
	return old


func _restore_settings(old: Dictionary) -> void:
	var gs := root.get_node_or_null("GameSettings")
	if gs == null or old.is_empty():
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.path))
	gs.path = old["path"]
	gs.tutorial_enabled = old["enabled"]
	gs.tutorial_seen = old["seen"]


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


# --- M4 -----------------------------------------------------------------------------

func _one_hand_table(goal_required: int) -> Bonfire3D:
	var t := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var setup := TableSetup.sandbox(t, 5)
	var goal := t.table_goal.duplicate() as TableGoal
	goal.hands = 1
	goal.bonus = []
	goal.required = goal.required.slice(0, goal_required)
	setup.goal = goal
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = setup
	s.tutorial_override = 0
	s.test_speed = 10.0
	root.add_child(s)
	return s


func _m4_soul_meter() -> void:
	# Lost: bank one single on the last hand with every bounty unticked.
	var s := _one_hand_table(3)
	await process_frame
	var start := s.run.soul
	s.rig_faces([1, 2, 3, 4, 6] as Array[int])
	s.quick_throw()
	await s.sequence_finished
	s.pick_die(0)
	await s.bank()
	var penalty := int(s.run.table_summary.get("timeout_soul", 0))
	check(s.run.is_over() and s.run.state != BonfireRun.State.CLEARED and penalty == 9, "out of hands uncleared: -9 Soul (got %d)" % penalty)
	check(s.soul_meter.soul == s.run.soul and s.soul_meter.soul == start - penalty, "the Soul meter drops to %d (shows %d)" % [start - penalty, s.soul_meter.soul])
	check(s.bhud.end_body.text.contains("Soul %d" % s.soul_meter.soul), "end panel and meter agree")
	s.queue_free()
	await process_frame
	# Cleared on the last hand: no end-of-table Soul cost, nothing burns.
	s = _one_hand_table(1)
	await process_frame
	start = s.run.soul
	var want: Array[int] = []
	for v in DiceIcons.pattern(s.run.goal.required[0]):
		want.append(int(v))
	while want.size() < 5:
		want.append(6 if not want.has(6) else 2)
	s.rig_faces(want)
	s.quick_throw()
	await s.sequence_finished
	for i in DiceIcons.pattern(s.run.goal.required[0]).size():
		s.pick_die(i)
	await s.bank()
	check(s.run.state == BonfireRun.State.CLEARED, "the one-bounty table clears (%s)" % BonfireRun.State.keys()[s.run.state])
	check(s.run.soul == start and s.soul_meter.soul == start, "cleared: no Soul lost, the meter stays at %d (shows %d)" % [start, s.soul_meter.soul])
	s.queue_free()
	await process_frame
