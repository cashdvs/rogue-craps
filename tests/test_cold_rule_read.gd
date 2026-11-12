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
	await _pit(t, [3, 3, 5, 5, 1])  # locked 3s must not read as a live pair
	print("test_cold_rule_read: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _pure(t: BonfireTuning) -> void:
	check(ColdRuleText.note("Cold Sixes", 6) == "Cold Sixes: 6s can't score.", "note text (%s)" % ColdRuleText.note("Cold Sixes", 6))
	check(ColdRuleText.get_text("nope") == "", "unknown id is empty")
	var r := BonfireRun.new(t)
	r.set_rules(TableRules.build([{"id": &"cold_sixes", "params": {"face": 6}}]), 1)
	check(ColdRuleText.blocker(r, 6) != null and ColdRuleText.blocker(r, 5) == null, "Cold Sixes blocks 6 only")
	check(not ColdRuleText.can_score(r, 6) and ColdRuleText.can_score(r, 5), "can_score is the same can_light answer")
	var wick := BonfireRun.new(t)
	wick.set_rules(TableRules.build([&"mister_wick"]), 1)
	check(not ColdRuleText.can_score(wick, 6) and ColdRuleText.can_score(wick, 2), "Mister Wick: 6s can't score, 2s can")
	var boss := RulePitBoss.new()
	boss.locked = 3
	check(not boss.can_light(r, 3) and boss.can_light(r, 5), "Pit Boss lock is can_light, not a second list")
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
	for i in s.run.throw_faces.size():
		var dead := not ColdRuleText.can_score(s.run, s.run.throw_faces[i])
		check(FrostLook.is_frosted(s.throw_dice[i]) == dead, "look matches can_score for face %d (dead %s)" % [s.run.throw_faces[i], dead])
	if six >= 0:
		var d := s.throw_dice[six]
		_dead_look(d, "Cold Sixes 6")
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


## Pit Boss locks one number. The locked dice get the dead look; a face
## that can still score does not, even when it didn't light this throw.
func _pit(t: BonfireTuning, faces: Array[int]) -> void:
	var sv := SubViewport.new()
	sv.size = Vector2i(1280, 720)
	root.add_child(sv)
	var st := TableSetup.sandbox(t, 5)
	st.table_seed = 9
	st.rules = [&"pit_boss"]
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = st
	s.tutorial_override = 0
	s.test_speed = 10.0
	sv.add_child(s)
	await process_frame
	await process_frame
	var lock: RulePitBoss = null
	for r in s.run.rules:
		if r is RulePitBoss:
			lock = r
	check(lock != null, "the table has a Pit Boss rule")
	if lock != null:
		lock.locked = 3
	s.rig_faces(faces)
	check(s.quick_throw(), "pit throw %s starts" % str(faces))
	await s.throw_resolved
	await s.sequence_finished
	var lit := s.run.lit()
	for i in s.run.throw_faces.size():
		var v := s.run.throw_faces[i]
		if v == 3:
			check(not lit.has(i), "locked 3 at %d stays dark (lit %s)" % [i, str(lit)])
		elif v == 5:
			check(lit.has(i), "a 5 at %d lights (lit %s)" % [i, str(lit)])
	for i in s.run.throw_faces.size():
		var v := s.run.throw_faces[i]
		var d := s.throw_dice[i]
		var dead := not ColdRuleText.can_score(s.run, v)
		check(FrostLook.is_frosted(d) == dead, "Pit Boss face %d dead look is %s" % [v, dead])
		if dead:
			_dead_look(d, "locked %d" % v)
		else:
			check(FrostLook.mark(d) == null or not FrostLook.mark(d).visible, "a scorable %d has no ✕" % v)
	sv.queue_free()
	await process_frame


## The dead look: frost on, pips faded, no lit rim, emission at or under 0.3, an ✕.
func _dead_look(d: DieVisual, tag: String) -> void:
	check(FrostLook.is_frosted(d), "%s is frosted" % tag)
	check(float(d.body_material.get_shader_parameter("die_frost")) == 1.0, "%s die_frost is on" % tag)
	check(is_equal_approx(float(d.body_material.get_shader_parameter("frost_dim")), FrostLook.DIM), "%s frost is dimmed" % tag)
	check(float(d.body_material.get_shader_parameter("die_lit")) == 0.0, "%s is not lit in the shader" % tag)
	check(float(d.body_material.get_shader_parameter("emission_energy")) <= 0.3, "%s body emission <= 0.3" % tag)
	var pip: Color = d.pip_material.get_shader_parameter("albedo")
	var gap := pip - FrostLook.DEAD_PIP
	check(Vector3(gap.r, gap.g, gap.b).length() < 0.2, "%s pips are faded (%s)" % [tag, pip])
	check(float(d.pip_material.get_shader_parameter("emission_energy")) <= 0.3, "%s pip emission <= 0.3" % tag)
	var mk := FrostLook.mark(d)
	check(mk != null and mk.visible and mk.text == "✕", "%s shows the no-score mark" % tag)
	check(d.hull_outline == null or not d.hull_outline.visible, "%s has no lit outline" % tag)
