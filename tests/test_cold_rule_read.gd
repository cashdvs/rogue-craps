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
	await _stopgap(t)  # Madame Shuffle's stopgap: a 2 or a 4 never lights
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
		_dead_look(d, "Cold Sixes 6", s.camera.cam)
		if faces[0] == 1:
			_mark_other_faces(d, s.camera.cam)
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
			_dead_look(d, "locked %d" % v, s.camera.cam)
		else:
			check(FrostLook.mark(d) == null or not FrostLook.mark(d).visible, "a scorable %d has no ✕" % v)
	sv.queue_free()
	await process_frame


## Madame Shuffle's stopgap borrows the Pit Boss handler (a 2 or a 4).
## The locked face gets the dead look; a face she didn't lock does not.
func _stopgap(t: BonfireTuning) -> void:
	var sv := SubViewport.new()
	sv.size = Vector2i(1280, 720)
	root.add_child(sv)
	var st := TableSetup.sandbox(t, 5)
	st.table_seed = 4
	st.rules = [&"madame_shuffle_stopgap"]
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
	check(lock != null and lock.id == &"madame_shuffle_stopgap", "stopgap is the Pit Boss handler under her id")
	if lock != null:
		lock.locked = 2
	check(not ColdRuleText.can_score(s.run, 2) and ColdRuleText.can_score(s.run, 5), "stopgap: 2s can't score, 5s can")
	s.rig_faces([2, 2, 5, 5, 1])
	check(s.quick_throw(), "stopgap throw starts")
	await s.throw_resolved
	await s.sequence_finished
	for i in s.run.throw_faces.size():
		var v := s.run.throw_faces[i]
		var dead := not ColdRuleText.can_score(s.run, v)
		check(FrostLook.is_frosted(s.throw_dice[i]) == dead, "stopgap face %d dead look is %s" % [v, dead])
		if v == 2:
			_dead_look(s.throw_dice[i], "stopgap 2", s.camera.cam)
	sv.queue_free()
	await process_frame


## The dead look: frost on, pips faded, no lit rim, emission at or under 0.3, an ✕.
func _dead_look(d: DieVisual, tag: String, cam: Camera3D = null) -> void:
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
	if cam != null and mk != null:
		_mark_at_camera(d, cam, tag)
	check(d.hull_outline == null or not d.hull_outline.visible, "%s has no lit outline" % tag)


## The ✕ faces the play camera and draws a real box on screen.
func _mark_at_camera(d: DieVisual, cam: Camera3D, tag: String) -> void:
	var mk := FrostLook.mark(d)
	if mk == null:
		check(false, "%s has a mark to face the camera" % tag)
		return
	var front := mk.global_transform.basis.z.normalized()
	var to_cam := (cam.global_position - mk.global_position).normalized()
	check(front.dot(to_cam) > 0.0, "%s ✕ faces the camera (dot %.2f)" % [tag, front.dot(to_cam)])
	var rect := _mark_rect(cam, mk)
	var on := rect.intersection(cam.get_viewport().get_visible_rect())
	check(on.size.x >= 6.0 and on.size.y >= 6.0, "%s ✕ is on screen and readable (%s)" % [tag, rect])


## Every cube face up, then a d4 (a non-d6 that can show a dead value).
func _mark_other_faces(d: DieVisual, cam: Camera3D) -> void:
	var saved := d.global_transform
	var ups: Array[Vector3] = [Vector3.UP, Vector3.DOWN, Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]
	for axis: Vector3 in ups:
		d.global_transform = Transform3D(Basis(Quaternion(axis, Vector3.UP)), saved.origin)
		FrostLook.set_frost(d, true)
		_mark_at_camera(d, cam, "d6 %s up" % axis)
	d.global_transform = saved
	FrostLook.set_frost(d, true)
	var poly := DieVisual.new(d.edge)
	poly.shape = &"d4"
	poly.name = "DeadD4"
	d.get_parent().add_child(poly)
	var at := Vector3(0.0, d.edge * 0.5, 0.0)
	for axis: Vector3 in [Vector3.UP, Vector3.RIGHT, Vector3(0.4, 1.0, 0.2).normalized()]:
		poly.global_transform = Transform3D(Basis(Quaternion(axis, Vector3.UP)), at)
		FrostLook.set_frost(poly, true)
		_mark_at_camera(poly, cam, "d4 %s up" % axis)


## Screen box of the ✕. Label3D's mesh aabb is empty until it draws, so the
## box is the glyph plane (local X/Y, font_size * pixel_size) instead.
func _mark_rect(cam: Camera3D, mk: Label3D) -> Rect2:
	var h := float(mk.font_size) * mk.pixel_size
	var o := mk.global_position
	var bx := mk.global_transform.basis.x * (h * 0.5)
	var by := mk.global_transform.basis.y * (h * 0.5)
	var rect := Rect2()
	var first := true
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			var world := o + bx * sx + by * sy
			if cam.is_position_behind(world):
				continue
			var p := cam.unproject_position(world)
			rect = Rect2(p, Vector2.ZERO) if first else rect.expand(p)
			first = false
	return rect
