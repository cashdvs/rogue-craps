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
##   Minor 9: volumetric fog (FogVolume + Environment) and SSAO only on
##       Forward+; Mobile / Compatibility get the fallback cone instead
##       (built for each renderer via Table3D.render_method; also checked for
##       real under xvfb with --rendering-method gl_compatibility).
##   #103 F1: while picking, a click on a thrown die under THROW / BANK pots
##       the die (or shakes it if unlit) and presses no button.
##   #103 N6: a table that ends mid-tutorial hides the hint panel.
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
	await _fog_compat()
	await _f1_pick_under_buttons()
	await _n6_tutorial_hidden_at_end()
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

## tutorial: Bonfire3D.tutorial_override (0 = off, 1 = on).
func _one_hand_table(goal_required: int, tutorial: int = 0) -> Bonfire3D:
	var t := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var setup := TableSetup.sandbox(t, 5)
	var goal := t.table_goal.duplicate() as TableGoal
	goal.hands = 1
	goal.bonus = []
	goal.required = goal.required.slice(0, goal_required)
	setup.goal = goal
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = setup
	s.tutorial_override = tutorial
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


# --- Minor 9 ------------------------------------------------------------------------

func _fog_compat() -> void:
	for method in ["gl_compatibility", "mobile", "forward_plus"]:
		var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
		s.tutorial_override = 0
		s.render_method = method
		root.add_child(s)
		await process_frame
		var plus: bool = method == "forward_plus"
		var env: Environment = s.world_env.environment
		check((s.find_child("LampHaze", true, false) != null) == plus, "%s: FogVolume (fog shader) %s" % [method, "built" if plus else "not built"])
		check((s.find_child("LampConeFallback", true, false) != null) == (not plus), "%s: fallback light cone %s" % [method, "absent" if plus else "built"])
		check(env.volumetric_fog_enabled == plus and env.ssao_enabled == plus, "%s: volumetric fog and SSAO %s" % [method, "on" if plus else "off"])
		s.queue_free()
		await process_frame


# --- #103 F1 ------------------------------------------------------------------------

## Lays the button column so `button`'s centre sits on screen point p.
func _button_over(s: Bonfire3D, button: Button, p: Vector2) -> void:
	var col := button.get_parent() as Control
	col.position += p - button.get_global_rect().get_center()


func _click(sv: SubViewport, p: Vector2) -> void:
	sv.push_input(_click_event(p, true), true)
	sv.push_input(_click_event(p, false), true)


func _idle(s: Bonfire3D) -> void:
	for k in 600:
		if s.phase == Table3D.Phase.BET and not s.bhud.countup.is_playing():
			break
		await process_frame
	for k in 12:
		await process_frame


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
	check(s.run.state == BonfireRun.State.PICK and s.run.can_continue() and not s.bhud.bank_button.disabled and not s.bhud.throw_button.disabled,
		"F1 setup: a pair of 5s potted, THROW and BANK live")
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


# --- #103 N6 ------------------------------------------------------------------------

func _n6_tutorial_hidden_at_end() -> void:
	var s := _one_hand_table(3, 1)
	await process_frame
	s.quick_throw()
	await s.sequence_finished
	# Pot the first burning die that makes a legal pot on its own.
	for i in s.throw_dice.size():
		if s.is_lit(s.throw_dice[i]) and s.pick_die(i):
			if s.run.can_continue():
				break
			s.pick_die(i)
	if not s.run.can_continue():
		# No single die scores alone: pot the pair the tutorial throw lands.
		for i in s.throw_dice.size():
			if s.is_lit(s.throw_dice[i]) and not s.run.can_continue():
				s.pick_die(i)
	check(s.bhud.tutorial.active and s.bhud.tutorial.visible, "N6 setup: a tutorial hint is showing mid-table")
	await s.bank()
	check(s.bhud.end_panel.visible and s.run.is_over(), "N6: the one-hand table ends (end panel up)")
	check(not s.bhud.tutorial.visible and not s.bhud.tutorial.active, "N6: the hint panel is hidden under the end panel, no more hints")
	s.queue_free()
	await process_frame
