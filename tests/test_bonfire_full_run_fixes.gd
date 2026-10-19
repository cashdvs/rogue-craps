## QA full run pass 1 (qa/full_run_pass_1.md), Godot Dev's Majors:
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
	await _m2_tutorial()
	await _m4_soul_meter()
	print("test_bonfire_full_run_fixes: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


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
