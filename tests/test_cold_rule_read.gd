## P1 (0.1.6 playtest): a die a table rule keeps dark (Cold Sixes) must read
## as frozen, and the why line must name the rule: "Cold Sixes: 6s can't score."
##   godot --headless --path . --script res://tests/test_cold_rule_read.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


func _initialize() -> void:
	var tuning := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	tuning.table_goal = preload("res://tests/bounty_fixture.gd").goal(self)
	if tuning.table_goal == null:
		return
	set_meta(&"sandbox_tuning", tuning)
	_run.call_deferred(tuning)


func _run(t: BonfireTuning) -> void:
	_pure(t)
	await _scene(t, [1, 1, 3, 3, 6])  # Two Pair with a cold 6 (Cash's first case)
	await _scene(t, [3, 4, 5, 6, 1])  # Run of 4 that stops at the 6 (his second)
	print("test_cold_rule_read: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _pure(t: BonfireTuning) -> void:
	check(ColdRuleText.note("Cold Sixes", 6) == "Cold Sixes: 6s can't score.", "note text (%s)" % ColdRuleText.note("Cold Sixes", 6))
	check(ColdRuleText.get_text("nope") == "", "unknown id is empty")
	var r := BonfireRun.new(t)
	r.set_rules(TableRules.build([{"id": &"cold_sixes", "params": {"face": 6}}]), 1)
	check(ColdRuleText.blocker(r, 6) != null and ColdRuleText.blocker(r, 5) == null, "Cold Sixes blocks 6 only")
	check(ColdRuleText.note_for(r, [2, 6, 3]) == "Cold Sixes: 6s can't score.", "note_for finds the 6 (%s)" % ColdRuleText.note_for(r, [2, 6, 3]))
	check(ColdRuleText.note_for(r, [1, 2, 3]) == "", "no 6: no note")
	var plain := BonfireRun.new(t)
	check(ColdRuleText.note_for(plain, [6, 6]) == "" and ColdRuleText.blocker(null, 6) == null, "no rule: no note")


func _scene(t: BonfireTuning, faces: Array[int]) -> void:
	var sv := SubViewport.new()
	sv.size = Vector2i(1280, 720)
	root.add_child(sv)
	var st := TableSetup.sandbox(t, 5)
	st.table_seed = 5
	st.rules = [{"id": &"cold_sixes", "params": {"face": 6}}]
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = st
	s.tutorial_override = 0
	s.test_speed = 10.0
	sv.add_child(s)
	await process_frame
	await process_frame
	s.rig_faces(faces)
	check(s.quick_throw(), "throw %s starts" % str(faces))
	await s.throw_resolved
	await s.sequence_finished
	var six := s.run.throw_faces.find(6)
	var one := s.run.throw_faces.find(1)
	check(six >= 0, "a 6 landed (%s)" % str(s.run.throw_faces))
	if six >= 0:
		var d := s.throw_dice[six]
		check(FrostLook.is_frosted(d) and not s._lights.has(d), "the 6 is frosted and not lit")
		check(float(d.body_material.get_shader_parameter("die_frost")) == 1.0, "die_frost is on in the shader")
		check(float(d.body_material.get_shader_parameter("emission_energy")) <= 0.3, "no glow on the frozen die")
		check(s.why_label.text.begins_with("Cold Sixes: 6s can't score."), "why line names the rule (%s)" % s.why_label.text)
		check(not s.pick_die(six), "the 6 can't be potted")
		check(s.why_label.text == "Cold Sixes: 6s can't score.", "refusal names the rule (%s)" % s.why_label.text)
		s._set_lit(d, false)  # back to plain (e.g. the hand ends): the frost goes too
		check(not FrostLook.is_frosted(d) and float(d.body_material.get_shader_parameter("die_frost")) == 0.0, "plain again: frost off")
	if one >= 0:
		check(not FrostLook.is_frosted(s.throw_dice[one]), "a 1 is never frosted")
	if faces[0] == 3:
		var three := s.throw_dice[s.run.throw_faces.find(3)]
		check(not FrostLook.is_frosted(three) and s.is_lit(three) if s.has_method("is_lit") else not FrostLook.is_frosted(three), "a lit 3 is not frosted")
	sv.queue_free()
	await process_frame
