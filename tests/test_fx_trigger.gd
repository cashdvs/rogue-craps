## Headless test: trigger FX grammar / pool (scripts/fx/trigger_fx*.gd).
## Split from the former monolithic test_fx_trigger.gd so each file stays
## near the ~400-line newcomer rule. Shared stubs/helpers: TriggerFxHarness.
##
## Run:
##   godot --headless --path . --script res://tests/test_fx_trigger.gd
extends TriggerFxHarness


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("=== Dice of the Damned: trigger FX grammar / pool ===")
	_setup_world()
	_test_defs()
	_test_shapes()
	_test_timing_and_beat()
	_test_cap_and_order()
	_test_audio_sync_and_speed()
	_test_reduced_and_pool()
	_test_budgets()
	_finish()


func _test_defs() -> void:
	for id: StringName in [&"mirror_copy", &"gilded_payout", &"coin_heads_copy", &"hellfire_face"]:
		_check(TriggerFxDefs.ROWS.has(id), "row %s exists" % id)
		var r := TriggerFxDefs.row(id)
		var h := TriggerFxDefs.hit_time(id)
		_check(h >= 0.15 and h <= 0.45, "%s key hit %.3f s is inside the 0.15-0.45 s cue window" % [id, h])
		_check(int(r["hit"]) < int(r["frames"]), "%s hits before it ends" % id)
		for c: Variant in [r["ring"], r.get("ring2"), r.get("spark")]:
			if c is Color:
				_check(not _cyan_or_violet(c) and c != Color("#FF2E3E"), "%s: no cyan, violet or Danger glow (%s)" % [id, c.to_html()])
		for w in FIRE_WORDS:
			_check(not (w in String(r["fx"])) and not (w in String(r["beat"])), "%s: no fire piece or beat" % id)
	_check(is_equal_approx(TriggerFxDefs.hit_time(&"gilded_payout"), 2.0 / 12.0), "Gilded (minor) hits on f2 = 167 ms")
	_check(is_equal_approx(TriggerFxDefs.hit_time(&"mirror_copy"), 3.0 / 12.0) and is_equal_approx(TriggerFxDefs.hit_time(&"hellfire_face"), 3.0 / 12.0), "Mirror / Hellfire (major) hit on f3 = 250 ms")
	_check(is_equal_approx(TriggerFxDefs.hit_time(&"coin_heads_copy"), 4.0 / 12.0), "Coin heads (major) hits on f4 = 333 ms")
	_check(is_equal_approx(TriggerFxDefs.length(&"mirror_copy"), 0.5) and TriggerFxDefs.length(&"gilded_payout") <= 0.42, "major 0.50 s, minor <= 0.42 s")
	_check(TriggerFxDefs.row(&"unknown_row")["icon"] == &"generic", "unknown ids fall back to a generic minor pop")
	# v2 (Art Director): every row reads apart by its own piece AND beat.
	var pieces := {}
	var beats := {}
	for id: StringName in TriggerFxDefs.ROWS:
		pieces[TriggerFxDefs.ROWS[id]["fx"]] = true
		beats[TriggerFxDefs.ROWS[id]["beat"]] = true
	_check(pieces.size() == 5 and beats.size() == 6, "rows read apart: 5 pieces, 6 beats (Coin heads / tails share theirs) (%s / %s)" % [pieces.keys(), beats.keys()])
	_check(TriggerFxDefs.ROWS[&"gilded_payout"]["ring"] == TriggerFxDefs.BRASS_HI and TriggerFxDefs.ROWS[&"hellfire_face"]["ring"] == TriggerFxDefs.BONE
			and TriggerFxDefs.ROWS[&"hellfire_face"]["ring2"] == TriggerFxDefs.EMBER_MID and TriggerFxDefs.ROWS[&"mirror_copy"]["ring"] == TriggerFxDefs.GLASS
			and TriggerFxDefs.ROWS[&"coin_heads_copy"]["ring"] == TriggerFxDefs.GLASS, "ring tints: gold Gilded, bone + ember Hellfire, pale glass Mirror / Coin")
	_check(TriggerFxDefs.GLASS == Color("#F2EEE2") and TriggerFxDefs.GLASS.h < 0.2, "pale glass is the art's warm #F2EEE2, never bluish")


## Soul cyan and Satanic violet families (hue 170-200 / 260-300 with colour).

func _test_shapes() -> void:
	for id in TriggerShapes.SHAPES:
		_check(TriggerShapes.is_art(id), "shape %s comes from the Art Director's sheet" % id)
		var img := TriggerShapes.texture(id, TriggerFxDefs.BONE).get_image()
		var filled := 0
		for y in range(0, img.get_height(), 3):
			for x in range(0, img.get_width(), 3):
				if img.get_pixel(x, y).a > 0.3:
					filled += 1
		_check(filled > 0, "shape %s has a fill" % id)
		_check(img.has_mipmaps(), "shape %s has mipmaps" % id)
		if id in [&"ring_pulse_soft", &"needles_radial", &"frame_square", &"frame_hex"]:
			var c := img.get_pixel(img.get_width() / 2, img.get_height() / 2)
			_check(c.a < 0.05, "glow %s is open in the middle: it never covers the die body" % id)
	# Tinting: a white soft shape takes the row colour; hard shapes keep the oxblood outline.
	var gold := TriggerShapes.texture(&"ring_pulse_soft", TriggerFxDefs.BRASS_HI).get_image()
	var best := Color(0, 0, 0, 0)
	for x in gold.get_width():
		var c := gold.get_pixel(x, gold.get_height() / 2)
		if c.a > best.a:
			best = c
	_check(absf(best.h - TriggerFxDefs.BRASS_HI.h) < 0.03 and best.s > 0.3, "ring_pulse_soft is tinted gold (%s)" % best.to_html())
	var nd := TriggerShapes.texture(&"needles_radial", TriggerFxDefs.BONE).get_image()
	var ox := 0
	for y in nd.get_height():
		for x in nd.get_width():
			var c := nd.get_pixel(x, y)
			if c.a > 0.9 and c.r < 0.35 and c.b < 0.2:
				ox += 1
	_check(ox > 0, "needles_radial keeps its oxblood outline behind the bone fill")
	_check(TriggerShapes.texture(&"ring_pulse_soft", TriggerFxDefs.BONE) == TriggerShapes.texture(&"ring_pulse_soft", TriggerFxDefs.BONE), "shape textures are cached")
	for n in ["coin_brass_face", "coin_brass_tilt", "coin_brass_edge", "chip_x1_5"]:
		_check(TriggerShapes.fixed(n) != null, "fixed sprite %s is in the repo" % n)
	for id: StringName in TriggerFxDefs.ROWS:
		var icon: StringName = TriggerFxDefs.ROWS[id]["icon"]
		_check(ResourceLoader.exists(TriggerFxDefs.ART_DIR + "icons/icon_%s.png" % icon), "row %s uses the baked icon icon_%s.png" % [id, icon])
	_check(TriggerShapes._procedural(&"frame_hex", TriggerFxDefs.BONE).get_width() == TriggerShapes.SIZE, "procedural stand-ins still work if a file is missing")


func _test_timing_and_beat() -> void:
	var fx := _fx()
	var d := _die(Vector3(0, 0.04, 0), 0.7)
	var rest := d.faces.transform
	var rest_g := d.faces.global_basis
	var hits: Array[float] = []
	fx.hit.connect(func(_id: StringName, _d: Node3D) -> void: hits.append(fx._clock))
	var ret := fx.trigger_fx(&"mirror_copy", d)
	_check(is_equal_approx(ret, 0.25), "trigger_fx returns the key-hit time (%.3f)" % ret)
	_step(fx, 1.0 / 12.0 + DT)
	var w := (d.faces.global_basis * rest_g.inverse()) * Vector3.UP
	_check(absf(w.y - 0.88) < 0.01 and absf(w.x) < 0.01 and absf(w.z) < 0.01, "anticipation squashes along WORLD up (%s)" % w)
	var squash := d.faces.transform
	_step(fx, 1.0 / 240.0)
	_check(d.faces.transform.is_equal_approx(squash), "stepped on twos: no change inside a 12 fps frame")
	_step(fx, 0.25 - fx._clock + DT)
	_check(hits.size() == 1 and absf(hits[0] - 0.25) <= 1.0 / 60.0, "the hit fires on f3 (%s)" % str(hits))
	w = (d.faces.global_basis * rest_g.inverse()) * Vector3.UP
	_check(absf(w.length() - 1.10) < 0.02, "the hit frame stretches to 1.10 (%.3f)" % w.length())
	_check(fx.live_count() == 1, "one live burst")
	var high := 0
	for f in 3:
		for sp: MeshInstance3D in fx._live[0].sparks:
			if sp.visible and sp.global_position.y > d.global_position.y + 0.0001:
				high += 1
		_step(fx, 1.0 / 12.0)
	_check(high == 0, "sparks burst out and down, never above the die (%d high)" % high)
	_step(fx, 0.6)
	_check(d.faces.transform.is_equal_approx(rest), "after the burst the faces node (face remap) is exactly at rest")
	_check(fx.live_count() == 0, "the burst goes back to the pool")
	var lights := 0
	for n in fx.find_children("*", "Light3D", true, false):
		lights += 1
	_check(lights == 0, "no real lights (bloom only)")
	_free([fx, d])


func _test_cap_and_order() -> void:
	var audio := StubAudio.new()
	var fx := _fx(audio)
	audio.fx = fx
	var dice: Array[DieVisual] = []
	for i in 6:
		dice.append(_die(Vector3(-0.3 + i * 0.1, 0.04, 0)))
	var ids: Array[StringName] = [&"gilded_payout", &"gilded_payout", &"mirror_copy", &"hellfire_face", &"gilded_payout", &"coin_heads_copy"]
	var list: Array = []
	for i in 6:
		list.append({"id": ids[i], "die": dice[i]})
	fx.play_pot(list)
	var max_live := 0
	for i in 120:
		_step(fx, DT)
		max_live = maxi(max_live, fx.live_count())
	_check(max_live <= TriggerFxDefs.MAX_LIVE and max_live == 4, "at most 4 visible bursts at once (max %d)" % max_live)
	_check(audio.calls.size() == 6, "every trigger starts in the end (%d)" % audio.calls.size())
	var order: Array = audio.calls.map(func(c: Array) -> StringName: return c[0])
	_check(order.slice(0, 4) == [&"gilded_payout", &"mirror_copy", &"hellfire_face", &"coin_heads_copy"], "biggest first after the one already started, resolve order within a tier (%s)" % str(order))
	var gaps_ok := true
	for i in range(1, audio.calls.size()):
		gaps_ok = gaps_ok and float(audio.calls[i][4]) - float(audio.calls[i - 1][4]) >= TriggerFxDefs.STAGGER - 0.0001
	_check(gaps_ok, "starts are at least 0.08 s apart")
	_check(fx.queued_count() == 0 and fx.live_count() == 0, "queue drains and every burst returns")
	_free([fx, audio])
	_free(dice)


func _test_audio_sync_and_speed() -> void:
	var audio := StubAudio.new()
	audio.reply = 0.5
	var fx := _fx(audio)
	audio.fx = fx
	var d := _die(Vector3.ZERO)
	var hits: Array[float] = []
	fx.hit.connect(func(_id: StringName, _d: Node3D) -> void: hits.append(fx._clock))
	var ret := fx.trigger_fx(&"mirror_copy", d, {"flavor": &"x", "die_id": 3})
	_check(audio.calls.size() == 1 and audio.calls[0][0] == &"mirror_copy" and audio.calls[0][1] == 3 and audio.calls[0][2] == &"LAND", "the sound is asked once at FX start via mod_trigger(id, die, anchor, ctx)")
	_check(is_equal_approx(ret, 0.5), "the visual hit moves to the audio hit (returns %.3f)" % ret)
	_step(fx, 0.7)
	_check(hits.size() == 1 and absf(hits[0] - 0.5) <= 1.0 / 24.0, "flash lands on the audio hit at 0.5 s (%s)" % str(hits))
	_step(fx, 1.0)
	# 2x: everything twice as fast, no audio reply.
	audio.reply = -1.0
	hits.clear()
	fx._clock = 0.0
	fx._next_start = 0.0
	fx.speed_mode = 1
	ret = fx.trigger_fx(&"coin_heads_copy", d)
	_step(fx, 0.3)
	_check(is_equal_approx(ret, 1.0 / 6.0) and hits.size() == 1 and absf(hits[0] - 1.0 / 6.0) <= 1.0 / 60.0, "2x halves the hit (%.3f, %s)" % [ret, str(hits)])
	_step(fx, 1.0)
	# Instant: icons only, static, one sound call, no burst.
	fx.speed_mode = 2
	var before := audio.calls.size()
	ret = fx.trigger_fx(&"hellfire_face", d)
	_check(ret == 0.0 and fx.live_count() == 0 and audio.calls.size() == before + 1, "Instant: no burst, one sound call")
	_check(fx.icon_layer.get_child_count() > 2 * fx.pool_size(), "Instant: a static icon shows")
	_free([fx, audio, d])


func _test_reduced_and_pool() -> void:
	var fx := _fx()
	fx.reduced = true
	var d := _die(Vector3.ZERO)
	var rest := d.faces.transform
	var children := fx.get_child_count() + fx.icon_layer.get_child_count()
	_check(fx.pool_size() == TriggerFxDefs.POOL_PC or fx.pool_size() == TriggerFxDefs.POOL_MOBILE, "pool pre-warmed (%d)" % fx.pool_size())
	fx.trigger_fx(&"hellfire_face", d)
	var moved := false
	var sparks := false
	var icon := false
	for i in 80:
		_step(fx, DT)
		moved = moved or not d.faces.transform.is_equal_approx(rest)
		for b in fx._live:
			for s in b.sparks:
				sparks = sparks or s.visible
			icon = icon or b.icon.visible
	_check(not moved, "reduced motion: the die never moves")
	_check(not sparks, "reduced motion: no sparks")
	_check(icon, "reduced motion: the icon still pops")
	_check(fx.get_child_count() + fx.icon_layer.get_child_count() == children, "nothing is allocated at runtime (pooled nodes only)")
	_free([fx, d])


func _test_budgets() -> void:
	_check(TriggerFxDefs.BUDGET_FRAMES == [5, 6, 7], "tier budgets: minor 5 f, major 6 f, signature 7 f")
	var rows := TriggerFxDefs.ROWS.duplicate()
	rows[&"generic"] = TriggerFxDefs.GENERIC
	for id: StringName in rows:
		var r: Dictionary = rows[id]
		var cap: int = TriggerFxDefs.BUDGET_FRAMES[int(r["tier"])]
		_check(int(r["frames"]) <= cap, "%s: %d f within its tier budget (%d f)" % [id, int(r["frames"]), cap])
		_check((TriggerFxDefs.BEATS[r["beat"]] as Array).size() <= int(r["frames"]), "%s: its beat fits the row" % id)
	_check(TriggerFxDefs.length(&"coin_heads_copy") <= 0.5 + 0.0001, "Coin heads: 0.50 s (major budget)")
	# ONE flip: the flip angle passes 360 once and the hit frame lands flat.
	var keys: Array = TriggerFxDefs.BEATS[&"spin_flip"]
	var flips := 0.0
	for i in range(1, keys.size()):
		flips += absf(float(keys[i][1]) - float(keys[i - 1][1]))
	_check(is_equal_approx(flips, 360.0), "Coin: exactly one flip (%.0f deg)" % flips)
	var hit_key: Array = TriggerFxDefs.beat_key(&"spin_flip", int(TriggerFxDefs.ROWS[&"coin_heads_copy"]["hit"]))
	_check(float(hit_key[0]) == 0.0 and is_equal_approx(fmod(float(hit_key[1]), 360.0), 0.0), "Coin: lands flat on the hit (f4)")
	_check(is_equal_approx(TriggerFxDefs.ICON_PX_720, 32.0), "one flat 32 px icon at 720p, every tier")


## QA N3: Systems Dev's DiceIds (#107), their old aliases and the face keys
## all land on their own rows, not the generic pop.

