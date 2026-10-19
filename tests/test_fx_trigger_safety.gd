## Headless test: trigger FX links / safety (scripts/fx/trigger_fx*.gd).
## Split from the former monolithic test_fx_trigger.gd so each file stays
## near the ~400-line newcomer rule. Shared stubs/helpers: TriggerFxHarness.
##
## Run:
##   godot --headless --path . --script res://tests/test_fx_trigger_safety.gd
extends TriggerFxHarness


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("=== Dice of the Damned: trigger FX links, audio hook, remap / abort safety ===")
	_setup_world()
	await _test_listener()
	_test_table_audio()
	await _test_table_audio_parent_bind()
	_test_glint_lengths()
	_test_remap_mid_effect()
	_test_abort_and_freed_die()
	_test_restores_exactly()
	_test_flavor_whitelist()
	_finish()


func _test_listener() -> void:
	var t := StubTable.new()
	_world.add_child(t)
	var d0 := _die(Vector3(-0.1, 0.04, 0))
	var d1 := _die(Vector3(0.1, 0.04, 0))
	t.all_dice = [d0, d1]
	var ev := Node.new()
	ev.add_user_signal("mod_triggered", [{"name": "row_id", "type": TYPE_STRING_NAME}, {"name": "tier", "type": TYPE_INT},
			{"name": "die_id", "type": TYPE_INT}, {"name": "intensity", "type": TYPE_FLOAT}, {"name": "hit_ms", "type": TYPE_INT}])
	var audio := StubAudio.new()
	var fx := _fx(audio)
	audio.fx = fx
	_check(fx.bind(ev, t), "binds to mod_triggered")
	ev.emit_signal("mod_triggered", &"hellfire_face", 2, 1, 0.5, 123456)
	_check(fx.live_count() == 1 and fx._live[0].die == d1, "today's 5-argument mod_triggered plays on die_by_id")
	_check(audio.calls.size() == 1 and float((audio.calls[0][3] as Dictionary)["intensity"]) == 0.5, "intensity passes through to the sound")
	fx._on_mod_triggered(&"mirror_copy", 1, 0, 1.0, 0, &"LAND", {"source": 1, "flavor": &"verdict"})
	_step(fx, 0.1)
	var b: TriggerFxPool.Burst = fx._live[fx._live.size() - 1]
	_check(b.source == d1 and b.id == &"mirror_copy", "the requested anchor / ctx form works; ctx.source (a die id) becomes the die")
	_check(audio.calls.size() == 2 and audio.calls[1][2] == &"LAND", "anchor passes to the sound")
	ev.emit_signal("mod_triggered", &"hellfire_face", 0, 9, 1.0, 0)
	_check(audio.calls.size() == 2, "an unknown die id is ignored")
	_step(fx, 1.0)
	_free([fx, audio, ev])
	# #91: triggers_resolved drives the bursts at start_s; mod_triggered is ignored.
	var ev2 := Node.new()
	ev2.add_user_signal("triggers_resolved", [{"name": "triggers", "type": TYPE_ARRAY}])
	ev2.add_user_signal("mod_triggered")
	var audio2 := StubAudio.new()
	var fx2 := _fx(audio2)
	audio2.fx = fx2
	_check(fx2.bind(ev2, t), "binds to triggers_resolved")
	_check(not ev2.is_connected("mod_triggered", fx2._on_mod_triggered), "with triggers_resolved, mod_triggered isn't used (no doubles)")
	ev2.emit_signal("triggers_resolved", [
		{"stage": &"copies", "row_id": &"mirror", "tier": 0, "die_id": 1, "intensity": 0.0, "anchor": &"die",
			"ctx": {"flavor": &"copies", "target_die": 0, "count": 1, "direction": 1}, "start_s": 0.0},
		{"stage": &"lit", "row_id": &"bust", "tier": 0, "die_id": -1, "intensity": 0.0, "anchor": &"table", "ctx": {}, "start_s": 0.0},
	])
	_check(audio2.calls.size() == 1 and audio2.calls[0][0] == &"mirror_copy", "copies: &\"mirror\" plays the mirror_copy row at once; the lit stage isn't a trigger (%s)" % str(audio2.calls))
	_check(fx2._live.size() == 1 and fx2._live[0].source == d0, "ctx.target_die becomes the copy source")
	_step(fx2, 1.0)
	ev2.emit_signal("triggers_resolved", [{"stage": &"scoring", "row_id": &"hellfire", "tier": 2, "die_id": 0, "intensity": 0.5,
			"anchor": &"pip", "ctx": {"flavor": &"mult_factor", "target_die": 0}, "start_s": 0.15, "pip_s": 0.317, "lift_s": 0.0}])
	_check(audio2.calls.size() == 1, "scoring entries wait for their start_s")
	await create_timer(0.3).timeout
	_check(audio2.calls.size() == 2 and audio2.calls[1][0] == &"hellfire_face" and audio2.calls[1][2] == &"pip", "scoring: &\"hellfire\" starts hellfire_face at start_s (pip - 0.167 s)")
	_step(fx2, 1.0)
	_free([fx2, audio2, ev2, d0, d1, t])


func _test_table_audio() -> void:
	var sfx := StubSfx.new()
	var t := StubTable.new()
	t.speed_mode = 1
	var crowd := Node.new()
	var juice := JuiceStub.new()
	juice.crowd = crowd
	t.juice = juice
	var a := TableAudio.new()
	a.sfx = sfx
	a.table = t
	var s := a.mod_trigger(&"hellfire_face", 2, &"PIP", {"flavor": &"verdict", "intensity": 0.75})
	_check(is_equal_approx(s, 0.3), "TableAudio.mod_trigger returns the hook's seconds until the hit")
	_check(sfx.calls == [[&"hellfire_face", -1, 0.75, -1.0, &"verdict"]], "play_mod_trigger(id, tier -1, intensity, -1, flavor) (%s)" % str(sfx.calls))
	_check(sfx.trigger_speed_mode == 1, "trigger_speed_mode follows the table's speed (2x)")
	_check(sfx.crowd == crowd, "sfx.crowd = BonfireJuice's crowd")
	var bare := Node.new()
	a.sfx = bare
	_check(a.mod_trigger(&"mirror_copy") == -1.0, "without play_mod_trigger: -1 (silent), no error")
	_free([a, sfx, t, crowd, bare, juice])


## QA B1: TableAudio as a real child of a table binds to it (table, events,
## sfx) on its own; nothing sets a.table by hand.

func _test_table_audio_parent_bind() -> void:
	var t := EventsTable.new()
	t.speed_mode = 1
	t.events = Node.new()
	t.events.add_user_signal("dice_thrown")
	t.sfx = StubSfx.new()
	_world.add_child(t)
	var a := TableAudio.new()
	t.add_child(a)
	await process_frame
	_check(a.table == t, "TableAudio binds its table through the parent (QA B1)")
	_check(a.events == t.events and a.sfx == t.sfx, "and the table's events and sfx")
	a.mod_trigger(&"mirror_copy")
	_check((t.sfx as StubSfx).trigger_speed_mode == 1, "the parent table's speed reaches the hook")
	_free([t.events, t.sfx, t])


## Art Director: every row fits its tier budget (minor <= 5 f, major <= 6 f,
## signature <= 7 f at 12 fps) and its beat fits inside the row.

func _test_glint_lengths() -> void:
	var fx := _fx()
	for pair: Array in [[Vector3(-0.15, 0.04, 0), Vector3(0.15, 0.04, 0)], [Vector3(-0.2, 0.04, 0), Vector3(0.2, 0.04, 0)],
			[Vector3(-0.15, 0.04, -0.15), Vector3(0.15, 0.04, 0.15)]]:
		var src := _die(pair[0])
		var m := _die(pair[1])
		var from: Vector3 = src.global_position
		var to: Vector3 = m.global_position
		var dist := from.distance_to(to)
		fx.trigger_fx(&"mirror_copy", m, {"source": src})
		var b: TriggerFxPool.Burst = fx._live[0]
		var lengths: Array[float] = []
		var on_path := true
		for f in [1, 2]:
			_step(fx, 1.0 / 12.0)
			var gb := b.glint.global_basis
			lengths.append((b.glint.mesh as QuadMesh).size.x * gb.x.length())
			_check(absf(gb.x.length() - 1.0) < 0.001 and absf(gb.y.length() - 1.0) < 0.001 and absf(gb.x.dot(gb.y)) < 0.001,
					"%.2f m apart: the glint basis is orthonormal on f%d" % [dist, f])
			on_path = on_path and b.glint.global_position.is_equal_approx(TriggerFxLinks.glint_point(from, to, f / 3.0, _cam))
		var want := m.edge * TriggerFxLinks.STREAK
		_check(lengths.all(func(x: float) -> bool: return absf(x - want) < 0.001), "%.2f m apart: the streak is %.3f m long every frame (%s)" % [dist, want, str(lengths)])
		_check(on_path, "%.2f m apart: the glint rides its arc" % dist)
		var p0 := TriggerFxLinks.glint_point(from, to, 0.0, _cam)
		var p1 := TriggerFxLinks.glint_point(from, to, 1.0, _cam)
		var mid := TriggerFxLinks.glint_point(from, to, 0.5, _cam)
		var bow := mid - (from + to) * 0.5
		_check(p0.is_equal_approx(from) and p1.is_equal_approx(to), "%.2f m apart: the arc starts on the source and ends on the target" % dist)
		_check(absf(bow.y) < 0.0001 and absf(bow.length() - 0.3 * dist) < 0.001 and absf(bow.dot(to - from)) < 0.0001,
				"%.2f m apart: it bows sideways along the felt by 0.3 x the distance (%.3f m)" % [dist, bow.length()])
		_check(bow.dot(_cam.global_position - (from + to) * 0.5) > 0.0, "%.2f m apart: the bow comes toward the camera" % dist)
		_step(fx, 1.0)
		_free([src, m])
	_free([fx])


## QA B4 (qa/pr105_scratch/remap_clobber.gd): the table remaps the faces
## mid-effect (next throw); the effect must not put back its stale rest.

func _test_remap_mid_effect() -> void:
	for wanted_v in [6, 1]:
		var d := DieVisual.new(0.08)
		_world.add_child(d)
		var fx := _fx()
		var before := d.up_value()
		var target: int = wanted_v if before != wanted_v else (1 if wanted_v == 6 else 6)
		fx.trigger_fx(&"hellfire_face", d)
		for i in 12:
			fx._process(1.0 / 120.0)
		d.faces.basis = DieVisual.remap_basis(d.up_value(), target, 0.0)
		var wanted := d.up_value()
		var remapped := d.faces.transform
		for i in 120:
			fx._process(1.0 / 120.0)
		_check(wanted == target and d.up_value() == wanted, "remap to %d mid-effect: the die still shows %d after the burst (shows %d)" % [target, wanted, d.up_value()])
		_check(d.faces.transform.is_equal_approx(remapped), "remap to %d mid-effect: the faces stay exactly where the table put them" % target)
		_check(fx.live_count() == 0, "and the burst still finishes")
		_free([fx, d])


## QA B4: dice_thrown / table_started end live effects WITHOUT restoring the
## faces; a freed die ends its effect quietly.

func _test_abort_and_freed_die() -> void:
	for sig: StringName in [&"dice_thrown", &"table_started"]:
		var ev := Node.new()
		ev.add_user_signal("mod_triggered")
		ev.add_user_signal(String(sig))
		var fx := _fx()
		fx.bind(ev)
		var d := _die(Vector3(0, 0.04, 0))
		fx.trigger_fx(&"coin_heads_copy", d)
		fx.trigger_fx(&"hellfire_face", d)
		_step(fx, 2.0 / 12.0)
		var mid := d.faces.transform
		ev.emit_signal(sig)
		_check(fx.live_count() == 0 and fx.queued_count() == 0, "%s ends every live and queued effect" % sig)
		_check(d.faces.transform.is_equal_approx(mid), "%s: the faces are left for the table (no restore)" % sig)
		_step(fx, 1.0)
		_check(d.faces.transform.is_equal_approx(mid), "%s: nothing writes the faces afterwards" % sig)
		_free([fx, ev, d])
	var fx := _fx()
	var d := _die(Vector3(0, 0.04, 0))
	fx.trigger_fx(&"hellfire_face", d)
	_step(fx, 1.0 / 12.0)
	d.free()
	_step(fx, 1.0 / 12.0)
	_check(fx.live_count() == 0 and fx.pool_size() == TriggerFxDefs.POOL_PC, "a freed die's effect ends and its burst returns to the pool")
	# QA N5: a delayed (start_s) trigger never fires once the FX node is gone.
	var ev := Node.new()
	ev.add_user_signal("triggers_resolved", [{"name": "triggers", "type": TYPE_ARRAY}])
	var fx2 := _fx()
	fx2.bind(ev)
	ev.emit_signal("triggers_resolved", [{"stage": &"scoring", "row_id": &"hellfire", "die_id": 0, "start_s": 0.2}])
	_check(fx2.find_children("*", "Timer", false, false).size() == 1, "a delayed trigger waits on a child Timer (freed with the FX)")
	_free([fx, fx2, ev])


## QA N6: face-touching effects that finish normally restore the faces
## exactly (Hellfire's jolt, Mirror's hop-flip, the Coin flips, Wild's snap).

func _test_restores_exactly() -> void:
	var fx := _fx()
	var d := _die(Vector3(0, 0.04, 0), 0.4)
	var rest := d.faces.transform
	for id: StringName in [&"hellfire_face", &"mirror_copy", &"gilded_payout", &"coin_heads_copy", &"coin_tails_copy", &"coin_alone_heads", &"wild_face"]:
		fx.trigger_fx(id, d)
		var moved := false
		for i in 120:
			_step(fx, DT)
			moved = moved or not d.faces.transform.is_equal_approx(rest)
		_check(moved, "%s moves the faces while it plays" % id)
		_check(d.faces.transform == rest, "%s restores the faces exactly when it finishes" % id)
	_free([fx, d])


## QA N4: TableAudio hands play_mod_trigger only real #98 flavours.

func _test_flavor_whitelist() -> void:
	var sfx := StubSfx.new()
	var a := TableAudio.new()
	a.sfx = sfx
	for f: StringName in [&"verdict", &"midnight", &"tithe", &"powder_keg", &"lantern"]:
		a.mod_trigger(&"hellfire_face", null, &"", {"flavor": f})
	a.mod_trigger(&"mirror_copy", null, &"", {"flavor": &"copies"})
	a.mod_trigger(&"hellfire_face", null, &"", {"flavor": &"mult_factor"})
	var got: Array = sfx.calls.map(func(c: Array) -> StringName: return c[4])
	_check(got == [&"verdict", &"midnight", &"tithe", &"powder_keg", &"lantern", &"", &""], "only #98 flavours pass; #91 effect names play unflavoured (%s)" % str(got))
	_free([a, sfx])


## The arrival motes: two, small, glass, off the die's centre toward its
## top-right corner on screen (Art Director: never over the face).

