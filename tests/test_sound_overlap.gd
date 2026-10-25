## Playtest sound fixes (Sound Designer, Oct 24):
##  1. dice_shake (0.45 s) replayed every 0.22 s while held must not stack:
##     SfxManager.play_alone stops the last copy first.
##  2. The 2D table's impact sounds use the 3D per-die rate limit.
##  3. The crowd stops when a Bonfire table ends, is left or forfeited.
##   godot --headless --path . --script res://tests/test_sound_overlap.gd
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


func copies(sfx: SfxManager, event: StringName) -> int:
	var n := 0
	for c in sfx.get_children():
		if c is AudioStreamPlayer and c.playing and c.get_meta(&"event", &"") == event:
			n += 1
	return n


func _run() -> void:
	await shake_test()
	await impact_test()
	await crowd_test()
	print("test_sound_overlap: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func shake_test() -> void:
	var sfx := SfxManager.new()
	root.add_child(sfx)
	await process_frame
	sfx.play(&"dice_shake")
	sfx.play(&"dice_shake")
	check(copies(sfx, &"dice_shake") == 2, "plain play stacks (%d)" % copies(sfx, &"dice_shake"))
	sfx.play_alone(&"dice_shake")
	check(copies(sfx, &"dice_shake") == 1, "play_alone leaves one copy (%d)" % copies(sfx, &"dice_shake"))
	for k in 5:
		sfx.play_alone(&"dice_shake", 1.0, -8.0)
	check(copies(sfx, &"dice_shake") == 1, "five rattle ticks: still one copy")
	sfx.play(&"chip_place")
	sfx.play_alone(&"dice_shake")
	check(copies(sfx, &"chip_place") == 1, "other sounds keep playing")
	check(sfx.stop_event(&"dice_shake") == 1 and copies(sfx, &"dice_shake") == 0, "stop_event stops it")
	# The 3D and 2D tables both use play_alone for the held rattle.
	for path in ["res://scripts/table3d/table_3d.gd", "res://scripts/table/table_scene.gd"]:
		var src := FileAccess.get_file_as_string(path)
		check(src.contains("sfx.play_alone(&\"dice_shake\"") and not src.contains("sfx.play(&\"dice_shake\""), "%s: held rattle uses play_alone" % path)
	sfx.queue_free()


func impact_test() -> void:
	var sfx := SfxManager.new()
	root.add_child(sfx)
	await process_frame
	sfx.impact_clock = 10.0
	check(sfx.impact_allowed(7), "first hit sounds")
	check(not sfx.impact_allowed(7), "same die, same moment: throttled")
	check(sfx.impact_allowed(8), "another die is not")
	sfx.impact_clock = 10.0 + ThrowSynth.IMPACT_MIN_GAP_S + 0.001
	check(sfx.impact_allowed(7), "after the gap it sounds again")
	# 2D table: two impacts of one die at once make one dice_hit.
	var t := (load("res://scenes/table.tscn") as PackedScene).instantiate()
	root.add_child(t)
	await process_frame
	var hits := [0]
	t.sfx.played.connect(func(e: StringName) -> void:
		if e == &"dice_hit":
			hits[0] += 1)
	t.sfx.impact_clock = 50.0
	var d: DieView = t._dice[0]
	t._on_die_impact(d, 0.4)
	t._on_die_impact(d, 0.4)
	check(hits[0] == 1, "2D: one die chattering makes one sound (%d)" % hits[0])
	t._on_die_impact(t._dice[1], 0.4)
	check(hits[0] == 2, "2D: a second die still sounds")
	t.queue_free()
	sfx.queue_free()
	await process_frame


# --- Crowd: each way a table ends really stops it ---------------------------
# These run the real code paths (Leave button, last hand, forfeit while the
# dice roll, scene exit) on a sandbox Bonfire table and then look at the
# crowd's own AudioStreamPlayers. No source-text checks.

## A sandbox Bonfire table (run mode, sped up) with its crowd playing.
func make_bonfire(table_seed: int) -> Bonfire3D:
	var tuning := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var st := TableSetup.sandbox(tuning, 5)
	st.run_mode = true
	st.table_seed = table_seed
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = st
	s.test_speed = 10.0
	s.tutorial_override = 0
	root.add_child(s)
	await process_frame
	await process_frame
	s.juice.crowd_start()
	await process_frame
	return s


## The crowd's players (the murmur / chatter / roar stems).
func crowd_players(s: Bonfire3D) -> Array:
	if s.juice.crowd == null:
		return []
	return s.juice.crowd.get_children().filter(func(c: Node) -> bool: return c is AudioStreamPlayer)


func crowd_playing(s: Bonfire3D) -> bool:
	return crowd_players(s).any(func(p: AudioStreamPlayer) -> bool: return p.playing)


## True once every crowd player has stopped (the stop fades out over
## about 0.6 s, so this waits up to 2 s of real time).
func crowd_stops(s: Bonfire3D) -> bool:
	var until := Time.get_ticks_msec() + 2000
	while Time.get_ticks_msec() < until:
		if not crowd_playing(s):
			return true
		await process_frame
	return false


## Throws rigged faces and waits for the whole throw sequence to finish.
func throw_faces(s: Bonfire3D, faces: Array[int]) -> void:
	s.rig_faces(faces)
	if not s.quick_throw():
		check(false, "throw %s starts" % str(faces))
		return
	await s.sequence_finished


func wait_bet(s: Bonfire3D) -> void:
	for k in 600:
		if s.phase == Table3D.Phase.BET:
			return
		await process_frame


## One hand: throw, pick dice `idx`, bank.
func bank_hand(s: Bonfire3D, faces: Array[int], idx: Array[int]) -> void:
	await wait_bet(s)
	await throw_faces(s, faces)
	for i in idx:
		s.pick_die(i)
	await s.bank()
	await wait_bet(s)


## Banks the three hands that clear the sandbox goal (as in test_leave_table).
func clear_table(s: Bonfire3D) -> void:
	await bank_hand(s, [1, 2, 3, 6, 6] as Array[int], [0, 1, 2] as Array[int])
	await bank_hand(s, [4, 4, 4, 2, 6] as Array[int], [0, 1, 2] as Array[int])
	await bank_hand(s, [2, 2, 6, 6, 3] as Array[int], [0, 1, 2, 3] as Array[int])


func done(s: Bonfire3D) -> void:
	s.queue_free()
	await process_frame
	Engine.time_scale = 1.0


func crowd_test() -> void:
	# 1) Leave: the Leave table button between hands after the clear.
	var s := await make_bonfire(5)
	check(crowd_playing(s), "leave: crowd plays during the table")
	await clear_table(s)
	s.juice.crowd_start()  # make sure it is sounding right before leaving
	await process_frame
	check(s.run.cleared and s.can_leave_now(), "leave: table cleared, Leave is live")
	s.bhud.leave_pressed.emit()
	check(s.run.is_over(), "leave: the table ended")
	check(await crowd_stops(s), "leave stops the crowd")
	await done(s)

	# 2) Table end: the hands run out, the last hand ends the table.
	s = await make_bonfire(6)
	await clear_table(s)
	await bank_hand(s, [6, 6, 2, 4, 3] as Array[int], [0, 1] as Array[int])
	check(not s.run.is_over() and crowd_playing(s), "table end: crowd still on before the last hand")
	await bank_hand(s, [6, 6, 2, 4, 3] as Array[int], [0, 1] as Array[int])
	check(s.run.is_over(), "table end: out of hands")
	check(await crowd_stops(s), "the table's last hand stops the crowd")
	await done(s)

	# 3) Forfeit while the dice are rolling: the run is forfeited mid-throw
	# (bypassing Bonfire3D.forfeit(), which has its own stop), so only the
	# throw's end (_end_sequence_after_forfeit) can stop the crowd.
	s = await make_bonfire(7)
	await wait_bet(s)
	s.rig_faces([1, 2, 3, 6, 6] as Array[int])
	check(s.quick_throw(), "forfeit mid-roll: throw starts")
	check(s.run.forfeit(), "forfeit mid-roll: run forfeited while rolling")
	check(crowd_playing(s), "forfeit mid-roll: crowd still on until the throw ends")
	await s.sequence_finished
	check(s.phase == Table3D.Phase.OVER, "forfeit mid-roll: table over after the throw")
	check(await crowd_stops(s), "forfeit mid-roll stops the crowd")
	await done(s)

	# 4) Forfeit between hands (Pause > Forfeit table).
	s = await make_bonfire(8)
	await wait_bet(s)
	check(s.forfeit(), "forfeit")
	check(await crowd_stops(s), "forfeit stops the crowd")
	await done(s)

	# 5) Scene exit: leaving the tree stops the crowd at once. A player
	# that only left the tree reports not playing but resumes when the
	# node comes back, so the check re-adds the table and looks again.
	s = await make_bonfire(9)
	check(crowd_playing(s), "scene exit: crowd plays")
	root.remove_child(s)
	root.add_child(s)
	await process_frame
	check(not crowd_players(s).is_empty() and not crowd_playing(s), "scene exit stops the crowd")
	await done(s)
