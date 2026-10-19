## Sounds per gameplay moment on the real Bonfire table (from QA's
## qa/pr72_scratch/events_count.gd). The throw, impact, Hot Hand, no_score
## and table_cleared sounds are owned by the feel layer (scripts/fx/
## TableAudio, PR #72), which plays them from table.events. So:
## - with TableAudio on the table: exactly ONE cue per moment (no doubles);
## - without it (this branch before #72): the table plays NONE of them itself.
##   godot --headless --path . --script res://tests/test_table_sound_counts.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0
var counts: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


func n(events: Array) -> int:
	var k := 0
	for e in events:
		k += (counts.get(e, []) as Array).size()
	return k


func _table(faces_seed: int) -> Bonfire3D:
	var st := TableSetup.sandbox(load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning, 5)
	st.table_seed = faces_seed
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = st
	s.tutorial_override = 0
	s.test_speed = 10.0
	root.add_child(s)
	await process_frame
	await process_frame
	await process_frame
	s.sfx.played.connect(func(e: StringName) -> void:
		if not counts.has(e):
			counts[e] = []
		(counts[e] as Array).append(Time.get_ticks_msec()))
	return s


## 1 if the feel layer is on this table and bound to its events, else 0.
func expected(s: Bonfire3D) -> int:
	var a := s.get_node_or_null("TableAudio")
	return 1 if a != null and a.get("events") != null else 0


func _run() -> void:
	# One throw: one throw cue (dice_shake here; play_throw where the SfxManager has it).
	var s: Bonfire3D = await _table(42)
	var want := expected(s)
	print("TableAudio bound: %s" % (want == 1))
	counts.clear()
	s.rig_faces([5, 5, 5, 2, 6] as Array[int])
	s.quick_throw()
	await s.throw_resolved
	await s.sequence_finished
	check(n([&"dice_shake"]) == want, "one throw: %d throw cue (dice_shake x%d)" % [want, n([&"dice_shake"])])
	# A refused pick: exactly one cue (no_score, or its chip_refuse fallback).
	s.pick_die(0)
	await create_timer(0.2).timeout
	counts.clear()
	var refused := not s.pick_die(3)
	await create_timer(0.2).timeout
	check(refused, "the 2 is refused next to a potted 5")
	check(n([&"no_score", &"chip_refuse"]) == want, "a refused pick: %d cue (no_score %d, chip_refuse %d)" % [want, n([&"no_score"]), n([&"chip_refuse"])])
	s.queue_free()
	await create_timer(0.3).timeout
	# Hot Hand: one hot_hand cue (or its win_big fallback) when the dice arrive.
	var h: Bonfire3D = await _table(43)
	want = expected(h)
	h.rig_faces([3, 3, 3, 5, 5] as Array[int])
	h.quick_throw()
	await h.throw_resolved
	await h.sequence_finished
	for i in 5:
		h.pick_die(i)
	check(h.throw_again(), "pot all five: Hot Hand")
	await h.bhud.countup.finished
	counts.clear()
	var hh: Array = []
	h.events.hot_hand.connect(func(_c: int) -> void: hh.append(Time.get_ticks_msec()))
	await create_timer(1.5).timeout
	var cue := &"hot_hand" if h.sfx.has_event(&"hot_hand") else &"win_big"
	check(hh.size() == 1, "one hot_hand event (%d)" % hh.size())
	check(n([&"hot_hand", &"win_big"]) == want, "Hot Hand: %d cue (%s x%d)" % [want, cue, n([cue])])
	if want == 1 and hh.size() == 1 and n([cue]) == 1:
		check(absi(int((counts[cue] as Array)[0]) - int(hh[0])) <= 20, "the Hot Hand cue plays as the dice arrive (hot_hand event)")
	h.queue_free()
	await create_timer(0.3).timeout
	print("test_table_sound_counts: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
