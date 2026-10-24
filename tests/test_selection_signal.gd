## BonfireRun.can_join and TableEvents.selection_changed (VFX Dev, #162
## listener): which dice are potted and which could still join the pot.
##   godot --headless --path . --script res://tests/test_selection_signal.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0
## Every selection_changed: [potted_ids, joinable_ids].
var sent: Array = []


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


func _run() -> void:
	var tuning := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var st := TableSetup.sandbox(tuning, 5)
	st.table_seed = 5
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = st
	s.test_speed = 10.0
	s.tutorial_override = 0
	root.add_child(s)
	await process_frame
	await process_frame
	s.reduced_motion = true
	s.events.selection_changed.connect(func(p: Array, j: Array) -> void: sent.append([p, j]))
	var r := s.run
	check(not r.can_join(0), "no throw yet: nothing can join")
	# Three 3s, a 2 and a 6: only the 3s make a combo.
	s.rig_faces([3, 3, 3, 2, 6] as Array[int])
	s.quick_throw()
	await s.sequence_finished
	var id := func(i: int) -> int: return s.event_id(s.throw_dice[i])
	check(r.can_join(0) and r.can_join(1) and r.can_join(2), "nothing potted: the 3s can join")
	check(not r.can_join(3) and not r.can_join(4), "the 2 and the 6 can't")
	check(not r.can_join(-1) and not r.can_join(9), "out of range: false")
	check(sent.size() == 1 and sent[0][0].is_empty() and sent[0][1].has(id.call(0)) and not sent[0][1].has(id.call(3)), "throw resolve sends the joinable 3s (%s)" % str(sent))
	# Nerve nudges the 2 up to a 3: now it can join, and the signal says so.
	sent.clear()
	check(s.nerve.nudge(3, NerveState.UP) == 3, "nudge the 2 to a 3")
	check(r.can_join(3), "the nudged 3 can join")
	check(sent.size() == 1 and sent[0][1].has(id.call(3)), "nudge sends the new joinable die")
	sent.clear()
	check(s.nerve.undo_pending(), "undo the nudge")
	check(not r.can_join(3) and sent.size() == 1 and not sent[0][1].has(id.call(3)), "undo sends it again, without the 2")
	# Pot a 3: it is potted, not joinable; the other 3s still join.
	sent.clear()
	check(s.pick_die(0), "pot a 3")
	check(not r.can_join(0) and r.can_join(1), "potted die can't join again; the next 3 can")
	check(sent.size() == 1 and sent[0][0] == [id.call(0)] and sent[0][1].has(id.call(1)) and not sent[0][1].has(id.call(0)), "pot sends potted + joinable (%s)" % str(sent))
	# Unpot: back to nothing potted.
	sent.clear()
	check(s.pick_die(0), "unpot it")
	check(sent.size() == 1 and sent[0][0].is_empty() and sent[0][1].has(id.call(0)), "unpot sends the change")
	# A refused tap (the 6) changes nothing and sends nothing.
	sent.clear()
	check(not s.pick_die(4) and sent.is_empty(), "refused pot: no signal")
	print("test_selection_signal: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
