## Bonfire HUD layout after QA's #63 review: the bottom text lines sit
## between the THROW / BANK column (bottom left, ends at x 494) and the hand,
## the rethrow risk line never prints over the status line, and the felt
## combo table is printed away from the bottom HUD band.
##   godot --headless --path . --script res://tests/test_bonfire_hud_layout.gd
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


func _run() -> void:
	var t := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = TableSetup.sandbox(t, 5)
	s.tutorial_override = 0
	s.test_speed = 10.0
	root.add_child(s)
	await process_frame
	await process_frame
	var h := s.bhud
	# Every bottom text line: x >= 520 and width <= 880 (clear of the buttons).
	for l: Control in [h.throw_label, h.notes_label, h.risk_label, s.why_label]:
		check(l.position.x >= 520.0 and l.size.x <= 880.0, "%s at x %d, width %d" % [l.name, l.position.x, l.size.x])
	var col := h.throw_button.get_parent() as Control
	check(col.position.x + col.size.x <= 520.0, "the button column ends left of x 520 (%s)" % str(col.position.x + col.size.x))
	# Pick a valid pot with dice left to rethrow: the risk line shows and
	# the status line steps aside; nothing picked: the status line is back.
	for k in 600:
		if s.phase == Table3D.Phase.BET and s.run.state == BonfireRun.State.AIM and not s.hand_moving():
			break
		await process_frame
	s.rig_faces([4, 4, 4, 5, 2] as Array[int])
	s.quick_throw()
	await s.throw_resolved
	await s.sequence_finished
	for i in 3:
		s.pick_die(i)
	await process_frame
	check(h.risk_label.text != "" and not s.why_label.visible, "risk line up: the status line is hidden (%s)" % h.risk_label.text)
	for i in 3:
		s.pick_die(i)
	await process_frame
	check(h.risk_label.text == "" and s.why_label.visible, "no risk line: the status line shows")
	# The felt print: landscape slots sit toward the middle, not at the near rail.
	for id in s.felt_combos.labels:
		var z := (s.felt_combos.labels[id] as Node3D).position.z
		check(z < 0.0, "felt slot %s printed toward the middle (z %.2f)" % [id, z])
		break
	s.queue_free()
	await process_frame
	print("test_bonfire_hud_layout: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
