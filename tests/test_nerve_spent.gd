## table.events.nerve_spent: fires once when NerveState.commit() spends a
## pending nudge (a pot, a rethrow / bank, a rescue-save), and never when no
## nudge is pending or the nudge was undone.
##   godot --headless --path . --script res://tests/test_nerve_spent.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0
## Every nerve_spent seen: [die_id, from_face, to_face].
var spent: Array = []


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


## A sandbox table with fast, snapping dice; nerve_spent is recorded.
func make_table() -> Bonfire3D:
	var tuning := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var st := TableSetup.sandbox(tuning, 5)
	st.table_seed = 5
	st.starting_soul = 9
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = st
	s.test_speed = 10.0
	root.add_child(s)
	await process_frame
	await process_frame
	s.reduced_motion = true
	s.events.nerve_spent.connect(func(id: int, a: int, b: int) -> void: spent.append([id, a, b]))
	spent.clear()
	return s


func throw_faces(s: Bonfire3D, faces: Array[int]) -> void:
	s.rig_faces(faces)
	check(s.quick_throw(), "throw %s starts" % str(faces))
	await s.sequence_finished
	await process_frame


func done(s: Bonfire3D) -> void:
	s.queue_free()
	await process_frame


func _run() -> void:
	await pot_fires_once()
	await rethrow_fires()
	await no_nudge_no_fire()
	await undo_no_fire()
	await rescue_save_fires()
	print("nerve_spent: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


## Nudge the 2 up to 3, then pot: one nerve_spent(id, 2, 3), even after
## potting more dice.
func pot_fires_once() -> void:
	var s := await make_table()
	await throw_faces(s, [3, 3, 3, 2, 6] as Array[int])
	var id := s.event_id(s.throw_dice[3])
	check(s.nerve.nudge(3, NerveState.UP) == 3, "nudge the 2 up to 3")
	check(spent.is_empty(), "a pending nudge doesn't fire yet")
	check(s.pick_die(3), "pot the nudged die")
	check(spent.size() == 1 and spent[0] == [id, 2, 3], "pot: nerve_spent(id, 2, 3) once (%s)" % str(spent))
	s.pick_die(0)
	s.pick_die(1)
	check(spent.size() == 1, "potting more dice doesn't fire again (%s)" % str(spent))
	await done(s)


## Rethrow / bank both go through NerveTable.close_throw(): a pending nudge
## is spent there and fires once.
func rethrow_fires() -> void:
	var s := await make_table()
	await throw_faces(s, [3, 3, 3, 2, 6] as Array[int])
	var id := s.event_id(s.throw_dice[4])
	check(s.nerve.nudge(4, NerveState.DOWN) == 5, "nudge the 6 down to 5")
	s.nerve.close_throw()
	check(spent.size() == 1 and spent[0] == [id, 6, 5], "rethrow commit: nerve_spent(id, 6, 5) (%s)" % str(spent))
	s.nerve.close_throw()
	check(spent.size() == 1, "a second commit doesn't fire again")
	await done(s)


## No nudge pending: pot, rethrow and bank fire nothing.
func no_nudge_no_fire() -> void:
	var s := await make_table()
	await throw_faces(s, [3, 3, 3, 2, 6] as Array[int])
	s.pick_die(0)
	s.pick_die(1)
	s.pick_die(2)
	check(s.throw_again(), "rethrow without a nudge")
	await process_frame
	check(spent.is_empty(), "no pending nudge: no nerve_spent (%s)" % str(spent))
	await done(s)


## Nudge then undo: Nerve comes back and nothing fires, then or at the pot.
func undo_no_fire() -> void:
	var s := await make_table()
	await throw_faces(s, [3, 3, 3, 2, 6] as Array[int])
	check(s.nerve.nudge(3, NerveState.UP) == 3, "nudge the 2 up")
	check(s.nerve.undo(3), "undo it")
	check(spent.is_empty(), "undo doesn't fire")
	s.pick_die(0)
	check(spent.is_empty(), "pot after the undo doesn't fire (%s)" % str(spent))
	await done(s)


## The bust-rescue: the saving nudge is spent when its die is potted.
func rescue_save_fires() -> void:
	var s := await make_table()
	await throw_faces(s, [3, 3, 1, 1, 6] as Array[int])
	s.pick_die(0)
	s.pick_die(1)
	check(s.throw_again(), "rethrow the cold dice")
	await process_frame
	await throw_faces(s, [2, 4, 6] as Array[int])
	check(s.run.bust_pending, "the bust waits for a rescue")
	var opts := s.nerve.state.rescue_options(s.nerve.lights, s.nerve.score)
	check(not opts.is_empty(), "a saving nudge exists")
	if opts.is_empty():
		await done(s)
		return
	var i := s.nerve.index_of(int(opts[0]["die"]))
	s.nerve.arm()
	s.nerve.tap(i)
	s.nerve.nudge(i, int(opts[0]["dir"]))
	check(spent.is_empty() and not s.run.bust_pending, "saved, still pending")
	var lit: Array = s.run.lit()
	check(not lit.is_empty() and s.pick_die(int(lit[0])), "pot a lit die")
	check(spent.size() == 1 and spent[0][0] == s.event_id(s.throw_dice[i]), "rescue-save spent: nerve_spent once (%s)" % str(spent))
	await done(s)
