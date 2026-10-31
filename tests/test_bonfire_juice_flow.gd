## Bonfire scoring juice: JuicePlan tiers and count-up timing caps (1x / 2x /
## Instant), the count-up widget in real time and its fast-forward, the
## table-scene hooks (pot / Hot Hand / bank / bust) with no errors whether
## the art + audio branches are present or not (force_fallback), bounty
## cards that pulse, and the Table 1 tutorial (shown once, skippable).
##   godot --headless --path . --script res://tests/test_bonfire_juice_flow.gd
extends SceneTree

const TEST_SETTINGS := "user://test_juice_settings.cfg"

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	# The sandbox table_1 is a real F1 target table now; this suite tests bounties.
	var sandbox_tuning := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	sandbox_tuning.table_goal = preload("res://tests/bounty_fixture.gd").goal(self)
	if sandbox_tuning.table_goal == null:
		return  # fixture missing: goal() printed why and quits
	set_meta(&"sandbox_tuning", sandbox_tuning)  # keep it cached so every load sees the fixture
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
	return res


func make_table(st: TableSetup, fallback: bool, tutorial: int = 0) -> Bonfire3D:
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = st
	s.setup.nerve_uses = 0  # these checks expect a plain bust (no Nerve rescue pause)
	s.test_speed = 10.0
	s.tutorial_override = tutorial
	root.add_child(s)
	s.juice.force_fallback = fallback
	await process_frame
	await process_frame
	return s


func has_prefix(list: Array[String], p: String) -> bool:
	for c in list:
		if c.begins_with(p):
			return true
	return false


func _run() -> void:
	var t := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	_plan_tests(t)
	await _count_up_tests(t)
	await _scene_tests(t, true)
	await _scene_tests(t, false)
	await _tutorial_tests(t)
	print("test_bonfire_juice_flow: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _plan_tests(t: BonfireTuning) -> void:
	var tiers: Array[int] = []
	for p in [0, 99, 100, 299, 300, 999, 1000, 5000]:
		tiers.append(JuicePlan.tier(p, t))
	check(tiers == ([0, 0, 1, 1, 2, 2, 3, 3] as Array[int]), "score tiers sparks/flames/inferno/pillar at 100/300/1000 (%s)" % str(tiers))
	check(JuicePlan.banner_tier(&"pair", t) == 0 and JuicePlan.banner_tier(&"trips", t) == 1 and JuicePlan.banner_tier(&"full_house", t) == 2 and JuicePlan.banner_tier(&"five_kind", t) == 3,
		"banner tint: bone / ember / hellfire / black-gold by combo")
	var worst := [0.0, 0.0]
	var ordered := true
	var halves := true
	var instant_zero := true
	for big in [false, true]:
		var tier := 3 if big else 1
		for n in range(1, 13):
			for extra in 4:
				var p1 := JuicePlan.timeline(n, extra, tier, 0, t)
				var p2 := JuicePlan.timeline(n, extra, tier, 1, t)
				var p3 := JuicePlan.timeline(n, extra, tier, 2, t)
				worst[1 if big else 0] = maxf(worst[1 if big else 0], float(p1["end"]))
				var pips: Array = p1["pips"]
				ordered = ordered and float(pips[-1]) <= float(p1["slam"]) and float(p1["slam"]) <= float(p1["sweep"]) \
					and float(p1["sweep"]) <= float(p1["count_start"]) and float(p1["count_end"]) <= float(p1["banner"]) and float(p1["banner"]) <= float(p1["end"])
				halves = halves and is_equal_approx(float(p2["end"]), float(p1["end"]) * 0.5)
				instant_zero = instant_zero and float(p3["end"]) == 0.0 and float(p3["slam"]) == 0.0
	check(worst[0] <= t.juice_cap + 0.0001 and worst[0] > 0.5, "normal pot count-up <= %.1f s at 1x (worst %.3f s, 1-12 dice, 0-3 extra chips)" % [t.juice_cap, worst[0]])
	check(worst[1] <= t.juice_cap_big + 0.0001 and worst[1] > t.juice_cap, "big pot count-up <= %.1f s at 1x (worst %.3f s)" % [t.juice_cap_big, worst[1]])
	check(ordered, "beats in order: pips -> slam -> sweep -> count -> banner -> end")
	check(halves, "2x halves every count-up")
	check(instant_zero, "Instant: count-up takes 0 s")
	var res := {"mult": 5, "factor": 1.5}
	var ch := JuicePlan.chips(res, 2, 1)
	check(ch.size() == 4 and ch[0]["text"] == "x3" and ch[1]["kind"] == &"hot" and ch[3]["kind"] == &"factor", "Mult chip + one chip per Hot Hand + Hellfire factor (%s)" % str(ch))
	check(JuicePlan.chips({"mult": 2, "factor": 1.0}, 0, 0).size() == 1, "plain pot: one Mult chip")


func _count_up_tests(t: BonfireTuning) -> void:
	var cu := BonfireCountUp.new()
	root.add_child(cu)
	await process_frame
	var counts := {"pip": 0, "slam": 0, "banner": 0, "ticks": 0, "fin": 0}
	cu.pip.connect(func(_i: int) -> void: counts["pip"] += 1)
	cu.slam.connect(func(_k: int) -> void: counts["slam"] += 1)
	cu.banner.connect(func(_a: int, _b: int) -> void: counts["banner"] += 1)
	cu.count_tick.connect(func(_f: float) -> void: counts["ticks"] += 1)
	cu.finished.connect(func() -> void: counts["fin"] += 1)
	var data := {"base": 20, "values": [4, 4, 4], "chips": [{"text": "x3", "kind": &"mult"}], "points": 126, "name": "Trips", "score_tier": 1, "banner_tier": 1}
	var cases := [[0, false, t.juice_cap], [1, false, t.juice_cap * 0.5], [2, false, 0.0], [0, true, t.juice_cap_big]]
	for c in cases:
		var mode: int = c[0]
		var tier := 3 if c[1] else 1
		var d := data.duplicate()
		d["score_tier"] = tier
		for k in counts:
			counts[k] = 0
		cu.play(d, JuicePlan.timeline(3, 0, tier, mode, t), 1.0, false)
		await cu.finished
		var slack := 0.12
		check(cu.last_duration <= float(c[2]) + slack, "count-up mode %d big=%s took %.3f s (cap %.2f)" % [mode, str(c[1]), cu.last_duration, float(c[2])])
		check(counts["pip"] == 3 and counts["slam"] == 1 and counts["banner"] == 1 and counts["fin"] == 1, "every beat once (mode %d: %s)" % [mode, str(counts)])
		check(cu.total_label.text == "126" and cu.base_label.text == "32", "final numbers: base 20+12, total 126 (%s / %s)" % [cu.base_label.text, cu.total_label.text])
	# Fast-forward: synchronous finish, slam + banner now, remaining pips silent.
	for k in counts:
		counts[k] = 0
	cu.play(data, JuicePlan.timeline(3, 0, 1, 0, t), 1.0, false)
	await process_frame
	cu.fast_forward()
	check(counts["fin"] == 1 and not cu.is_playing() and cu.fast_forwarded, "fast-forward finishes at once")
	check(counts["slam"] == 1 and counts["banner"] == 1 and counts["pip"] <= 1, "fast-forward: slam + banner fire, remaining pips skipped (%s)" % str(counts))
	check(cu.total_label.text == "126" and cu.base_label.text == "32" and cu.banner_label.text == "TRIPS!" and cu.banner_panel.modulate.a > 0.9, "fast-forward shows the final total and the banner")
	cu.fast_forward()
	check(counts["fin"] == 1, "fast-forward when idle does nothing")
	cu.queue_free()
	await process_frame


func _scene_tests(t: BonfireTuning, fallback: bool) -> void:
	var tag := "fallback" if fallback else "adapter"
	var st := TableSetup.sandbox(t, 5)
	var s: Bonfire3D = await make_table(st, fallback)
	var r := s.run
	var j := s.juice
	check(fallback == not j.has_art() or not fallback, "[%s] force_fallback disables art" % tag)
	await create_timer(0.3).timeout
	var res := await throw_faces(s, [4, 4, 4, 5, 2] as Array[int])
	await s.sequence_finished
	var cards := s.claimable_bounties()
	check(cards.has(&"triple") and s.bhud.pulsing().has(&"triple"), "[%s] nothing selected: the Triple card pulses for the lit 4-4-4 (%s)" % [tag, str(cards)])
	s.pick_die(0)
	check(s.bhud.pulsing().is_empty(), "[%s] a lone 4 claims no card (%s)" % [tag, str(s.bhud.pulsing())])
	s.pick_die(1); s.pick_die(2)
	check(s.bhud.pulsing() == [&"triple"], "[%s] selected 4-4-4 pulses the Triple card (%s)" % [tag, str(s.bhud.pulsing())])
	j.calls.clear()
	check(s.throw_again() and s.dice.size() == 2 and r.pot == 126, "[%s] throw again stays synchronous" % tag)
	check(s.bhud.countup.is_playing(), "[%s] committing the pot starts the count-up" % tag)
	check(r.pot == 126 and s.bhud.pot_label.text == "Pot 0", "[%s] HUD pot holds until the count-up lands; state is already 126 (%s)" % [tag, s.bhud.pot_label.text])
	await s.bhud.countup.finished
	check(s.bhud.pot_label.text == "Pot 126" and s.bhud.display_hold.is_empty(), "[%s] the pot lands with the count-up (%s)" % [tag, s.bhud.pot_label.text])
	# The pot row is on the felt, in view, and solid for the next throw.
	var on_felt := true
	for k in 12:
		var p := s.pot_slot(k)
		on_felt = on_felt and absf(p.z) < Table3DBuilder.FELT_HALF.y - s.tuning.die_size * 0.5 and absf(p.x) < Table3DBuilder.FELT_HALF.x - s.tuning.die_size * 0.5 and is_equal_approx(p.y, s.tuning.die_size * 0.5)
	check(on_felt, "[%s] all 12 pot slots sit on the felt inside the rails" % tag)
	var sp := s.camera.cam.unproject_position(s.pot_slot(0) + Vector3(0, Bonfire3D.PILLAR_HEIGHT, 0))
	var vs := s.get_viewport().get_visible_rect().size
	check(Rect2(Vector2.ZERO, vs).has_point(sp) and sp.y > 80.0, "[%s] the top of a pillar over the pot is on screen (%s)" % [tag, str(sp)])
	s._sync_colliders()
	var solid := 0
	for b in s._pot_bodies:
		if not (b.get_child(0) as CollisionShape3D).disabled:
			solid += 1
	check(solid == s.pot_dice.size() and solid == 3, "[%s] one solid collider per potted die (%d)" % [tag, solid])
	check(s.bhud.countup.total_label.text == "126" and s.bhud.countup.banner_label.text == "TRIPS!", "[%s] count-up lands on 126 with the Trips banner" % tag)
	check(has_prefix(j.calls, "fb:lift") or has_prefix(j.calls, "art:lift"), "[%s] dice lift (%s)" % [tag, str(j.calls)])
	check(has_prefix(j.calls, "fx:glow_") and not has_prefix(j.calls, "fb:fire") and not has_prefix(j.calls, "art:fire"), "[%s] the pot GLOWS (no fire on dice) (%s)" % [tag, str(j.calls)])
	check(j.calls.has("sfx:mult_slam") or j.calls.has("sfx:dice_drop(fb)"), "[%s] slam sound hook" % tag)
	await create_timer(0.3).timeout
	# Bust: snuff, ash, flask crack, the pending Triple stamp crumbles.
	check(s.bhud.has_pending_stamp(&"triple"), "[%s] pending stamp on the Triple card" % tag)
	j.calls.clear()
	res = await throw_faces(s, [2, 6] as Array[int])
	await process_frame
	check((res[1] as Array).is_empty() and (has_prefix(j.calls, "fb:ash") or has_prefix(j.calls, "art:ash")), "[%s] bust: dice ash over (%s)" % [tag, str(j.calls)])
	check(j.calls.has("sfx:bust") or j.calls.has("sfx:seven_out(fb)"), "[%s] bust sound" % tag)
	check(not s.bhud.has_pending_stamp(&"triple"), "[%s] bust: the pending stamp crumbled" % tag)
	await s.sequence_finished
	await create_timer(0.3).timeout
	check(j.calls.has("sfx:soul_flask_crack") or j.calls.has("sfx:soul_burn(fb)"), "[%s] Soul flask crack sound after the bust (%s)" % [tag, str(j.calls)])
	# Hot Hand: all dice glow, banner, fly back with ember trails.
	res = await throw_faces(s, [3, 3, 3, 5, 5] as Array[int])
	await s.sequence_finished
	for i in 5:
		s.pick_die(i)
	j.calls.clear()
	check(s.throw_again() and s.dice.size() == 5 and s.pot_dice.is_empty(), "[%s] Hot Hand still scoops all 5 back at once" % tag)
	await s.bhud.countup.finished
	await process_frame
	check(j.calls.has("fx:hot_hand_glow") and j.calls.has("fx:ember_trail") and not has_prefix(j.calls, "art:fire_trail"), "[%s] Hot Hand glow pulse + ember trail, no fire (%s)" % [tag, str(j.calls)])
	check(s.bhud.result_label.text.begins_with("Hot Hand"), "[%s] Hot Hand banner (%s)" % [tag, s.bhud.result_label.text])
	await create_timer(0.6).timeout
	# Bank: count-up, embers flow, CLAIMED stamps.
	res = await throw_faces(s, [1, 2, 3, 6, 6] as Array[int])
	await s.sequence_finished
	s.pick_die(0); s.pick_die(1); s.pick_die(2)
	j.calls.clear()
	var pts_before := r.points
	var bank_state: Array = []
	s.bhud.countup.banner.connect(func(_a: int, _b: int) -> void:
		bank_state.append([r.points, s.bhud.points_label.text, s.bhud.coin_label.text, r.embers]), CONNECT_ONE_SHOT)
	var b: Dictionary = await s.bank()
	check(bank_state.size() == 1 and int(bank_state[0][0]) > pts_before and str(bank_state[0][1]).begins_with("points %d " % pts_before),
		"[%s] bank: points stay at %d on the HUD while the count-up plays (state already %s)" % [tag, pts_before, str(bank_state)])
	check(s.bhud.points_label.text.begins_with("points %d " % r.points) and s.bhud.coin_label.text == "EMBERS %d" % ((s.setup.run_embers if s.setup != null else 0) + r.embers), "[%s] bank: points + Embers land after the count-up (EMBERS = run balance + table payout)" % tag)
	check(b["kind"] == &"bank" and r.cleared, "[%s] bank clears the table" % tag)
	check(s.bhud.has_stamp(&"two_pairs") or s.bhud.has_stamp(&"run_three") or not (b["ticked"] as Array).is_empty() and s.bhud.has_stamp(b["ticked"][0]), "[%s] claimed bounty gets the CLAIMED stamp (%s)" % [tag, str(b["ticked"])])
	check(j.calls.has("sfx:bank") or j.calls.has("sfx:chip_collect(fb)"), "[%s] bank sound (%s)" % [tag, str(j.calls)])
	# A click fast-forwards a running count-up.
	s.new_run(5)
	await create_timer(0.3).timeout
	await throw_faces(s, [4, 4, 1, 2, 6] as Array[int])
	await s.sequence_finished
	s.pick_die(0); s.pick_die(1)
	s.test_speed = 0.5
	s.throw_again()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(960, 540)
	s._unhandled_input(click)
	check(not s.bhud.countup.is_playing() and s.bhud.countup.fast_forwarded, "[%s] click fast-forwards the count-up" % tag)
	check(s.bhud.display_hold.is_empty() and s.bhud.pot_label.text == "Pot %d" % s.run.pot, "[%s] fast-forward shows the final HUD numbers at once (%s)" % [tag, s.bhud.pot_label.text])
	s.test_speed = 10.0
	# Instant: no hold at all.
	await create_timer(0.3).timeout
	await throw_faces(s, [3, 3, 1] as Array[int])
	await s.sequence_finished
	s.set_speed_mode(2)
	s.pick_die(0); s.pick_die(1)
	var pot_now := s.run.pot
	s.throw_again()
	check(s.bhud.display_hold.is_empty() and s.bhud.pot_label.text == "Pot %d" % s.run.pot and s.run.pot > pot_now, "[%s] Instant: HUD numbers update immediately (%s)" % [tag, s.bhud.pot_label.text])
	s.set_speed_mode(0)
	s.queue_free()
	await process_frame


func _tutorial_tests(t: BonfireTuning) -> void:
	var gs := root.get_node_or_null("GameSettings")
	var added := false
	if gs == null:
		gs = (load("res://scripts/settings/game_settings.gd") as GDScript).new()
		gs.name = "GameSettings"
		root.add_child(gs)
		added = true
	var old_path: String = gs.path
	gs.path = TEST_SETTINGS
	gs.set_option(&"tutorial_enabled", true)
	check(not gs.tutorial_seen, "re-enabling the tutorial resets 'seen'")
	var st := TableSetup.sandbox(t, 5)
	var s: Bonfire3D = await make_table(st, true, -1)
	check(not s.bhud.tutorial.active, "the tutorial never starts in tests/tools (table not the current scene)")
	s.queue_free()
	await process_frame
	# As the real game: the table is the current scene.
	s = (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = TableSetup.sandbox(t, 5)
	s.setup.nerve_uses = 0  # these checks expect a plain bust (no Nerve rescue pause)
	s.test_speed = 10.0
	root.add_child(s)
	current_scene = s
	# change_scene sets current_scene before _ready; here the table is
	# already up, so deal the first table again as the current scene.
	s.new_run(5)
	await process_frame
	await process_frame
	check(s.bhud.tutorial.active and s.bhud.tutorial.current == &"th0_throw", "Table 1: the tutorial starts with the throw prompt (TH0)")
	check(gs.tutorial_seen, "'seen' saved")
	var cf := ConfigFile.new()
	check(cf.load(TEST_SETTINGS) == OK and bool(cf.get_value("options", "tutorial_seen", false)), "'seen' persisted to the settings file")
	check(cf.get_value("options", "hints_seen", {}).has(&"th0_throw"), "the hint's own 'shown' flag persisted (hints_seen)")
	await create_timer(0.3).timeout
	s.quick_throw()
	var res: Array = await s.throw_resolved
	await s.sequence_finished
	var faces: Array[int] = []
	for d in s.throw_dice:
		faces.append(d.shown_value())
	var want: Array[int] = t.tutorial_first_throw.duplicate()
	check(faces == want, "seeded first throw: 2-3-4 + 4-4, the 6 cold (%s)" % str(faces))
	check(s.bhud.tutorial.current == &"th1_lit" and s.bhud.tutorial.label.text.begins_with("Glowing dice can score"), "TH1 after the first landing")
	s.pick_die(0); s.pick_die(1); s.pick_die(2)
	check(s.bhud.tutorial.current != &"th1_lit", "potting closes TH1")
	s.bhud.tutorial.skip()
	check(not s.bhud.tutorial.active and not s.bhud.tutorial.visible, "SKIP hides the tutorial")
	s.throw_again()
	check(not s.bhud.tutorial.visible and s.bhud.tutorial.current == &"", "no more tutorial hints after skipping")
	s.new_run(5)
	await process_frame
	check(not s.bhud.tutorial.active, "shown once: the next table has no tutorial")
	current_scene = null
	s.queue_free()
	await process_frame
	s = (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = TableSetup.sandbox(t, 5)
	s.setup.nerve_uses = 0  # these checks expect a plain bust (no Nerve rescue pause)
	root.add_child(s)
	current_scene = s
	s.new_run(5)
	await process_frame
	check(not s.bhud.tutorial.active, "shown once: a new session with 'seen' saved has no tutorial")
	current_scene = null
	s.queue_free()
	await process_frame
	gs.path = old_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	if added:
		gs.queue_free()
