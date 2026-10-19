## QA full run pass 1, HUD minors on the Bonfire table:
## (a) POT doesn't show double at the end of a table,
## (b) HANDS LEFT is current right after the bust that ends the table,
## (d) a greyed-out THROW / BANK says why (caption + tooltip).
##   godot --headless --path . --script res://tests/test_bonfire_hud_minors.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0
var t: BonfireTuning


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


func table(st: TableSetup) -> Bonfire3D:
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = st
	s.tutorial_override = 0
	s.test_speed = 10.0
	root.add_child(s)
	await process_frame
	await process_frame
	return s


func throw_faces(s: Bonfire3D, faces: Array[int]) -> void:
	for k in 400:
		if s.phase == Table3D.Phase.BET and not s.bhud.countup.is_playing() and not s.hand_moving():
			break
		await process_frame
	s.rig_faces(faces)
	s.quick_throw()
	await s.sequence_finished


func _run() -> void:
	t = load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	# (a) Pure run: the last bank of a 1-hand table, then POT.
	var g := TableGoal.new()
	g.hands = 1
	var r := BonfireRun.new(t, g, 10, 5)
	r.set_throw([4, 4, 4, 2, 3] as Array[int])
	for i in 3:
		r.toggle(i)
	var gain := int(r.bank()["gain"])
	check(r.is_over(), "(a) 1-hand table ends on its bank")
	check(r.hand_pot() == 0 and r.potted.is_empty(), "(a) after the table ends hand_pot() is 0, not the last pot again (%d, banked %d)" % [r.hand_pot(), gain])
	# (a) On the table: the end panel's POT line.
	var st := TableSetup.sandbox(t, 5)
	st.goal = g
	var s: Bonfire3D = await table(st)
	await throw_faces(s, [4, 4, 4, 2, 3] as Array[int])
	for i in 3:
		s.pick_die(i)
	var br: Dictionary = await s.bank()
	for k in 60:
		await process_frame
	check(s.run.is_over() and s.bhud.pot_label.text == "POT 0", "(a) end of table: '%s' under Banked %d (not POT %d)" % [s.bhud.pot_label.text, int(br.get("gain", 0)), 2 * int(br.get("gain", 0))])
	s.queue_free()
	await process_frame
	# (b) The final bust: HANDS LEFT is current when hand_result fires.
	st = TableSetup.sandbox(t, 2)
	st.starting_soul = 1
	s = await table(st)
	var at_result: Array = []
	s.hand_result.connect(func(_r: Dictionary) -> void: at_result.append([s.run.hands_left, s.bhud.hands_label.text]))
	await throw_faces(s, [2, 3] as Array[int])
	check(s.run.is_over() and s.run.state == BonfireRun.State.RUN_OVER, "(b) the bust burns the last Soul")
	check(at_result.size() == 1 and at_result[0][1] == "HANDS LEFT %d" % at_result[0][0], "(b) HANDS LEFT is current at the final bust (%s)" % str(at_result))
	check(s.bhud.hands_label.text == "HANDS LEFT %d" % s.run.hands_left, "(b) and after it (%s)" % s.bhud.hands_label.text)
	s.queue_free()
	await process_frame
	# (d) Greyed-out buttons say why.
	st = TableSetup.sandbox(t, 5)
	s = await table(st)
	var h := s.bhud
	check(h.bank_button.disabled and h.bank_button.tooltip_text != "", "(d) BANK before a throw: disabled, tooltip '%s'" % h.bank_button.tooltip_text)
	check(h.action_reason.text == "", "(d) no caption before the throw (THROW works)")
	await throw_faces(s, [4, 4, 4, 2, 3] as Array[int])
	check(h.throw_button.disabled and h.bank_button.disabled, "(d) nothing potted: THROW and BANK greyed")
	check(h.action_reason.text == "Pot a lit die first" and h.throw_button.tooltip_text == "Pot a lit die first" and h.bank_button.tooltip_text == "Pot a lit die first",
		"(d) caption + tooltips: '%s'" % h.action_reason.text)
	check(h.action_reason.is_visible_in_tree() and h.action_reason.get_parent() == h.throw_button, "(d) the caption sits on the THROW button (moves with it)")
	s.pick_die(0)
	await process_frame
	check(h.throw_button.disabled and h.action_reason.text == "Not a combo yet: pot ONE combo", "(d) one 4 potted: '%s'" % h.action_reason.text)
	s.pick_die(1)
	s.pick_die(2)
	await process_frame
	check(not h.throw_button.disabled and not h.bank_button.disabled and h.action_reason.text == "" and h.throw_button.tooltip_text == "", "(d) a combo potted: both work, no reason")
	var why := BonfireHud.action_reasons(s.run, false)
	check(why["throw"] == "" and why["bank"] == "", "(d) busy (rolling / counting): no reason shown")
	s.queue_free()
	await process_frame
	print("test_bonfire_hud_minors: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
