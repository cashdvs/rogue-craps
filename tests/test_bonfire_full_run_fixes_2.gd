## QA full run pass 1 (qa/full_run_pass_1.md), Godot Dev's Majors, part 2
## (part 1: test_bonfire_full_run_fixes.gd):
##   M4: running out of hands uncleared burns the Soul meter by the table's
##       penalty; a cleared table burns nothing.
##   Minor 9: volumetric fog (FogVolume + Environment) and SSAO only on
##       Forward+; Mobile / Compatibility get the fallback cone instead
##       (built for each renderer via Table3D.render_method; also checked for
##       real under xvfb with --rendering-method gl_compatibility).
##   #103 N6: a table that ends mid-tutorial hides the hint panel.
##   godot --headless --path . --script res://tests/test_bonfire_full_run_fixes_2.gd
extends "res://tests/full_run_fixes_base.gd"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _m4_soul_meter()
	await _fog_compat()
	await _n6_tutorial_hidden_at_end()
	print("test_bonfire_full_run_fixes_2: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


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
