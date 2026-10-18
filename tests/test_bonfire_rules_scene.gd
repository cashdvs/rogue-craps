## Table rules on the 3D table: setup.rules reach the BonfireRun, the HUD lists
## them (name + one line), the Pit Boss lock is on the felt, a rule's face
## change (Madame Shuffle) flips the die to the new value before lighting, a
## shattered Cracked die leaves the table, and starting Soul is clamped to
## max Soul.
##   godot --headless --path . --script res://tests/test_bonfire_rules_scene.gd
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


func throw_faces(s: Bonfire3D, faces: Array[int]) -> Array:
	s.rig_faces(faces)
	if not s.quick_throw():
		check(false, "throw %s starts" % str(faces))
		return []
	var res: Array = await s.throw_resolved
	await s.sequence_finished
	return res


func make_table(st: TableSetup) -> Bonfire3D:
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = st
	s.test_speed = 10.0
	root.add_child(s)
	await process_frame
	await process_frame
	return s


func _run() -> void:
	var tuning := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var st := TableSetup.sandbox(tuning, 5)
	st.run_mode = true
	st.table_seed = 11
	st.starting_soul = 50
	st.max_soul = 30
	st.rules = [{"id": &"madame_shuffle", "params": {}}, {"id": &"pit_boss", "params": {}}, {"id": &"heavy_burn", "params": {}}]
	var s: Bonfire3D = await make_table(st)
	var r := s.run
	check(r.soul == 30 and r.max_soul == 30, "starting Soul 50 clamped to max Soul 30 (%d)" % r.soul)
	check(r.rules.size() == 3 and r.has_rule(&"madame_shuffle") and r.has_rule(&"pit_boss"), "setup.rules -> handlers on the run")
	var rows := s.bhud.rule_rows()
	check(s.bhud.rules_panel.visible and rows.size() == 3 and rows[0].begins_with("Madame Shuffle|Rerolls") and rows[2].begins_with("Heavy Burn|"), "HUD lists each rule: name + one line (%s)" % str(rows))
	var L := (r.rules[1] as RulePitBoss).locked
	check(s.felt_label.visible and s.felt_label.text == "LOCKED  %d" % L, "Pit Boss lock on the felt (%s)" % s.felt_label.text)
	check(rows[1].contains("Locked this hand: %d" % L), "Pit Boss HUD line names the lock")
	# Madame rerolls the highest die; the die shows the new face.
	var faces: Array[int] = [1, 2, 3, 4, 6]
	for i in faces.size():
		if faces[i] == L:
			faces[i] = 5 if L != 5 else 1
	await throw_faces(s, faces)
	var ch := r.last_throw.changes if r.last_throw != null else []
	check(ch.size() == 1 and ch[0]["by"] == &"madame_shuffle" and int(ch[0]["index"]) == faces.find(faces.max()), "Madame Shuffle rerolled the highest die on the table")
	if ch.size() == 1 and not r.throw_faces.is_empty():
		var i := int(ch[0]["index"])
		check(s.throw_dice[i].shown_value() == r.throw_faces[i], "the rerolled die shows its new face (%d vs %d)" % [s.throw_dice[i].shown_value(), r.throw_faces[i]])
	s.queue_free()
	await process_frame

	# A Cracked die that always shatters, potted with a plain die.
	var tc := tuning.duplicate() as BonfireTuning
	tc.cracked_shatter_chance = 1.0
	st = TableSetup.sandbox(tc, 3)
	st.run_mode = true
	st.table_seed = 3
	st.dice[0].special = &"cracked"
	st.dice[0].run_die_id = &"cracked_5"
	s = await make_table(st)
	r = s.run
	check(r.rules.size() == 1 and r.rules[0] is DieCracked and s.bhud.rule_rows().size() == 1, "a Cracked die in the handful adds its handler + HUD row")
	await throw_faces(s, [4, 4, 2] as Array[int])
	var cracked_vis := s.throw_dice[0]
	s.pick_die(0)
	s.pick_die(1)
	check(s.throw_again(), "pot 4-4 with the Cracked die, throw the rest")
	await create_timer(0.5).timeout
	check(r.shattered == ([&"cracked_5"] as Array[StringName]) and not s.all_dice.has(cracked_vis) and s.dice_left() == 2, "the Cracked die shattered and left the table")
	check(not cracked_vis.visible, "its die is gone from view")
	check(s.outcome().shattered_dice == ([&"cracked_5"] as Array[StringName]), "TableOutcome.shattered_dice = run_die_id")
	s.queue_free()
	await process_frame
	print("test_bonfire_rules_scene: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
