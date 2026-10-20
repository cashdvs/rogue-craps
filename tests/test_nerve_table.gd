## Nerve on the 3D table (design/nerve_v1.md): the HUD pip, a nudge and its
## undo (faces turned, lit re-run, die_nudged emitted), refusals, the
## arrows and keys, and the bust-rescue pause (save it with Nerve, or take
## the bust). Plus BonfireRun's side: bust_hold / relight / confirm_bust.
##   godot --headless --path . --script res://tests/test_nerve_table.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0
var nudges: Array = []


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


func throw_faces(s: Bonfire3D, faces: Array[int]) -> void:
	s.rig_faces(faces)
	if not s.quick_throw():
		check(false, "throw %s starts" % str(faces))
		return
	check(not s.nerve.can_show() and not s.nerve_ui.visible, "Nerve hidden while the dice roll")
	await s.sequence_finished


func make_table(fourth: TableDie = null) -> Bonfire3D:
	var tuning := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var st := TableSetup.sandbox(tuning, 5)
	st.table_seed = 5
	st.starting_soul = 9
	if fourth != null:
		st.dice[3] = fourth
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = st
	s.test_speed = 10.0
	root.add_child(s)
	await process_frame
	await process_frame
	s.reduced_motion = true  # faces snap: the checks read them at once
	s.events.die_nudged.connect(func(id: int, a: int, b: int, dir: int) -> void: nudges.append([id, a, b, dir]))
	return s


func _run() -> void:
	await nudge_flow()
	await rescue_save()
	await rescue_bust()
	await repeated_values()
	run_side()
	print("nerve_table: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func nudge_flow() -> void:
	var s := await make_table()
	var n := s.nerve
	check(n.state.uses_left() == 1 and not s.nerve_ui.visible, "a new table: 1 Nerve, pip hidden before the first throw")
	await throw_faces(s, [3, 3, 3, 2, 6] as Array[int])
	await process_frame
	check(n.can_show() and s.nerve_ui.visible and s.nerve_ui.pip.text == "Nerve  1", "settled: the pip shows Nerve 1 (%s)" % s.nerve_ui.pip.text)
	check(s.nerve_ui.pip_state.text == NerveText.get_text("nerve_ready"), "pip state: ready")
	check(not s.run.lit().has(3), "the 2 is cold before the nudge")
	nudges.clear()
	var to := n.nudge(3, NerveState.UP)
	check(to == 3 and s.run.throw_faces[3] == 3 and s.throw_dice[3].up_slot() == 3, "nudge up: the 2 shows 3 on the felt")
	check(s.run.lit().has(3) and s.is_lit(s.throw_dice[3]), "lit re-runs: the new 3 lights")
	check(nudges.size() == 1 and nudges[0][1] == 2 and nudges[0][2] == 3 and nudges[0][3] == 1 and nudges[0][0] == s.event_id(s.throw_dice[3]), "die_nudged(id, 2, 3, +1) (%s)" % str(nudges))
	check(n.state.uses_left() == 0 and s.nerve_ui.pip.disabled, "Nerve spent: pip greyed out")
	check(n.nudge(4, NerveState.DOWN) == -1 and s.why_label.text == NerveText.get_text("nerve_used_refusal"), "a second nudge is refused with nerve_used_refusal")
	check(n.tap(3) and s.run.throw_faces[3] == 2 and s.throw_dice[3].up_slot() == 2 and not s.run.lit().has(3), "tap the nudged die: undo back to 2, cold again")
	check(nudges.size() == 2 and nudges[1][1] == 3 and nudges[1][2] == 2 and nudges[1][3] == -1, "undo emits die_nudged(3 -> 2, -1)")
	check(n.state.uses_left() == 1, "undo gives Nerve back")
	# Nerve button -> click a die -> arrows; a 6 can't go higher.
	check(n.arm() and n.tap(4) and n.arrows_die == 4, "Nerve button, then a die: its arrows show")
	await process_frame
	check(s.nerve_ui.up_button.visible and s.nerve_ui.up_button.disabled and not s.nerve_ui.down_button.disabled, "the 6: up arrow greyed out, down open")
	check(s.nerve_ui.up_button.tooltip_text == NerveText.get_text("nerve_high_refusal"), "greyed arrow says why")
	var key := InputEventKey.new()
	key.keycode = KEY_DOWN
	key.pressed = true
	check(n.handle_input(key) and s.run.throw_faces[4] == 5, "Down key turns the 6 to 5")
	# Pot it: locked, no undo.
	check(s.pick_die(0), "pot a 3")
	check(not n.tap(4) or s.run.throw_faces[4] == 2, "tap after the pot doesn't undo (pot / undo)")
	check(n.state.refusal(n.hid(0)) == "nerve_potted_refusal" or n.state.uses_left() == 0, "potted die: refused")
	s.queue_free()
	await process_frame


## Pot the 3s, rethrow [2, 4, 5]: nothing lights, but 2 -> 3 makes a run.
func to_rescue(s: Bonfire3D) -> void:
	await throw_faces(s, [3, 3, 1, 1, 6] as Array[int])
	s.pick_die(0)
	s.pick_die(1)
	check(s.throw_again(), "rethrow the cold dice")
	await process_frame
	await throw_faces(s, [2, 4, 6] as Array[int])
	await process_frame


func rescue_save() -> void:
	var s := await make_table()
	var soul := s.run.soul
	await to_rescue(s)
	check(s.run.bust_pending and s.run.soul == soul and not s.run.is_over(), "nothing lit + a nudge would light: the bust waits")
	check(s.nerve_ui.visible and s.nerve_ui.rescue_panel.visible and s.nerve_ui.rescue_label.text == NerveText.get_text("nerve_bust_save"), "the rescue prompt shows (nerve_bust_save)")
	var opts := s.nerve.state.rescue_options(s.nerve.lights, s.nerve.score)
	check(not opts.is_empty(), "rescue_options lists the saving nudges (%s)" % str(opts))
	var i := s.nerve.index_of(int(opts[0]["die"])) if not opts.is_empty() else 0
	check(s.nerve.arm() and s.nerve.tap(i), "Nerve, then pick the die")
	s.nerve.nudge(i, int(opts[0]["dir"]) if not opts.is_empty() else 1)
	check(not s.run.bust_pending and not s.run.lit().is_empty() and not s.nerve_ui.rescue_panel.visible, "the nudge lights: no bust, prompt gone")
	s.queue_free()
	await process_frame


func rescue_bust() -> void:
	var s := await make_table()
	var soul := s.run.soul
	await to_rescue(s)
	s.nerve.take_bust()
	await create_timer(1.0).timeout
	check(not s.run.bust_pending and s.run.soul < soul, "Bust: the held bust happens (Soul %d -> %d)" % [soul, s.run.soul])
	s.queue_free()
	await process_frame


## A die with two 3 faces (slot 3 plain, slot 4 x3 mult): nudging its 2
## up lands on the face that scores best (score_fn), not the first 3.
func repeated_values() -> void:
	var keg := TableDie.new(&"twin3", "Twin Three")
	keg.faces.assign([1, 2, 3, 3, 4, 5])
	var m := FaceModData.new()
	m.id = &"test_x3"
	m.effect = FaceModData.Effect.MULT_FACTOR
	m.mult_factor = 3.0
	keg.mods = [null, null, null, m, null, null]
	var s := await make_table(keg)
	await throw_faces(s, [3, 3, 3, 2, 6] as Array[int])
	await process_frame
	var to := s.nerve.nudge(3, NerveState.UP)
	check(to == 4 and s.run.throw_faces[3] == 3 and s.run.throw_mods[3] == m, "repeated 3s: the x3 face (slot 4) wins over the plain first 3 (got slot %d)" % to)
	check(s.throw_dice[3].up_slot() == 4 or s.throw_dice[3].shape == &"coin", "the felt shows slot 4")
	s.queue_free()
	await process_frame


## BonfireRun alone: no bust_hold = busts at once; a hold keeps it open.
func run_side() -> void:
	var t := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var r := BonfireRun.new(t, null, 9, 3)
	r.set_rules(TableRules.build([], []), 3)
	r.bust_hold = func() -> bool: return true
	r.land_throw(TableThrow.make([3, 3, 1] as Array[int]))
	r.toggle(0)
	r.toggle(1)
	r.rethrow()
	var soul := r.soul
	check(not r.land_throw(TableThrow.make([4] as Array[int])) and r.bust_pending and r.soul == soul, "bust_hold true: the bust is held")
	check(not r.relight(TableThrow.make([4] as Array[int])) and r.bust_pending, "relight to a face that still lights nothing: still pending")
	check(r.relight(TableThrow.make([5] as Array[int])) and not r.bust_pending and r.lit() == [0], "relight to a 5: it lights, no bust")
	check(not r.relight(TableThrow.make([4] as Array[int])) and r.bust_pending, "relight back (undo): pending again")
	r.confirm_bust()
	check(not r.bust_pending and r.soul < soul, "confirm_bust: the bust happens")
