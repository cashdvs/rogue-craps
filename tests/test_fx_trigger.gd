## Headless test: trigger FX grammar (scripts/fx/trigger_fx.gd, spec
## trigger_fx_spec.md v0.2): row data and timings, the 12 fps beat on the
## die's faces node (restored exactly), the 4-burst cap with the 0.08 s
## stagger and biggest-first order, sound sync through TableAudio, speed
## modes, reduced motion, the pool, icons, links, the Gilded coin and the
## mod_triggered listener. Time is stepped by hand (fx._process) so it's exact.
##
## Run:
##   godot --headless --path . --script res://tests/test_fx_trigger.gd
extends SceneTree

const DT: float = 1.0 / 120.0
const FIRE_WORDS: Array[String] = ["fire", "flame", "ignite", "pillar"]

var _passed: int = 0
var _failed: int = 0
var _world: Node3D
var _cam: Camera3D


## Records every mod_trigger call (with the fx clock) and returns `reply`.
class StubAudio:
	extends Node
	var calls: Array = []
	var reply: float = -1.0
	var fx: TriggerFx

	func mod_trigger(id: StringName, die: Variant = null, anchor: StringName = &"", ctx: Dictionary = {}) -> float:
		calls.append([id, die, anchor, ctx, fx._clock if fx != null else 0.0])
		return reply


## A SfxManager stand-in with the Sound Designer's hook.
class StubSfx:
	extends Node
	var calls: Array = []
	var trigger_speed_mode: int = 0
	var crowd: Node

	func play_mod_trigger(id: StringName, tier: int = -1, intensity: float = 1.0, hit_ms: float = -1.0, flavor: StringName = &"") -> float:
		calls.append([id, tier, intensity, hit_ms, flavor])
		return 0.3


## BonfireJuice stand-in: just its crowd.
class JuiceStub:
	extends Node
	var crowd: Node


## A table stand-in: dice by id, speed / reduced flags, a juice with a crowd.
class StubTable:
	extends Node3D
	var all_dice: Array = []
	var speed_mode: int = 0
	var reduced_motion: bool = false
	var juice: Node


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


func _run() -> void:
	print("=== Dice of the Damned: trigger FX tests ===")
	_world = Node3D.new()
	root.add_child(_world)
	_cam = Camera3D.new()
	_world.add_child(_cam)
	_cam.look_at_from_position(Vector3(0, 1.2, 0.9), Vector3.ZERO)
	_test_defs()
	_test_shapes()
	_test_timing_and_beat()
	_test_cap_and_order()
	_test_audio_sync_and_speed()
	_test_reduced_and_pool()
	_test_links_and_icons()
	await _test_coin_flight()
	await _test_listener()
	_test_table_audio()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _die(at: Vector3, yaw: float = 0.0) -> DieVisual:
	var d := DieVisual.new(0.08)
	_world.add_child(d)
	d.global_transform = Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, 0.3), at)
	d.faces.basis = Basis(Vector3.FORWARD, PI / 2.0)  # a face remap the FX must keep
	return d


func _fx(audio: Node = null) -> TriggerFx:
	var fx := TriggerFx.new()
	fx.camera = _cam
	fx.audio = audio
	_world.add_child(fx)
	fx.set_process(false)
	return fx


func _step(fx: TriggerFx, seconds: float) -> void:
	for i in int(round(seconds / DT)):
		fx._process(DT)


func _free(list: Array) -> void:
	for n: Node in list:
		if is_instance_valid(n):
			n.free()


func _test_defs() -> void:
	for id: StringName in [&"mirror_copy", &"gilded_payout", &"coin_heads_copy", &"hellfire_face"]:
		_check(TriggerFxDefs.ROWS.has(id), "row %s exists" % id)
		var r := TriggerFxDefs.row(id)
		var h := TriggerFxDefs.hit_time(id)
		_check(h >= 0.15 and h <= 0.45, "%s key hit %.3f s is inside the 0.15-0.45 s cue window" % [id, h])
		_check(int(r["hit"]) < int(r["frames"]), "%s hits before it ends" % id)
		for c: Color in [r["tint"], r["tint2"]]:
			_check(c != Color("#4FE6E0") and c != Color("#FF2E3E"), "%s uses no Soul cyan / Danger (it touches neither)" % id)
		for w in FIRE_WORDS:
			_check(not (w in String(r["shape"])) and not (w in String(r["beat"])), "%s: no fire shape or beat" % id)
	_check(is_equal_approx(TriggerFxDefs.hit_time(&"gilded_payout"), 2.0 / 12.0), "Gilded (minor) hits on f2 = 167 ms")
	_check(is_equal_approx(TriggerFxDefs.hit_time(&"mirror_copy"), 3.0 / 12.0) and is_equal_approx(TriggerFxDefs.hit_time(&"hellfire_face"), 3.0 / 12.0), "Mirror / Hellfire (major) hit on f3 = 250 ms")
	_check(is_equal_approx(TriggerFxDefs.hit_time(&"coin_heads_copy"), 4.0 / 12.0), "Coin heads (major) hits on f4 = 333 ms")
	_check(is_equal_approx(TriggerFxDefs.length(&"mirror_copy"), 0.5) and TriggerFxDefs.length(&"gilded_payout") <= 0.42, "major 0.50 s, minor <= 0.42 s")
	_check(TriggerFxDefs.row(&"unknown_row")["icon"] == &"generic", "unknown ids fall back to a generic minor pop")


func _test_shapes() -> void:
	for id in TriggerShapes.SHAPES:
		var img := TriggerShapes.texture(id, TriggerFxDefs.BONE).get_image()
		var filled := 0
		var outline := 0
		for y in range(0, img.get_height(), 3):
			for x in range(0, img.get_width(), 3):
				var c := img.get_pixel(x, y)
				if c.a > 0.5 and c.is_equal_approx(TriggerFxDefs.OXBLOOD):
					outline += 1
				elif c.a > 0.5:
					filled += 1
		_check(filled > 0, "shape %s has a fill" % id)
		_check(id == &"flash" or outline > 0, "shape %s has the oxblood outline baked in" % id)
	_check(TriggerShapes.texture(&"ring", TriggerFxDefs.BONE) == TriggerShapes.texture(&"ring", TriggerFxDefs.BONE), "shape textures are cached")


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


func _test_links_and_icons() -> void:
	var fx := _fx()
	var src := _die(Vector3(-0.2, 0.04, 0))
	var m := _die(Vector3(0.2, 0.04, 0))
	fx.trigger_fx(&"mirror_copy", m, {"source": src})
	_step(fx, 1.0 / 12.0 + DT)
	var b: TriggerFx.Burst = fx._live[0]
	_check(b.link.visible, "Mirror: the beam runs from the source die during anticipation")
	_step(fx, 0.25)
	_check(b.icon.visible and is_equal_approx(b.icon.diameter, 28.0 * fx._px_per_pt()) and b.icon.studs == 4, "major icon: 28 pt disc with 4 studs (%.1f)" % b.icon.diameter)
	_step(fx, 1.0)
	fx.trigger_fx(&"coin_heads_copy", m, {"source": src})
	_step(fx, 2.0 / 12.0 + DT)
	b = fx._live[0]
	var shown := b.arc.filter(func(a: MeshInstance3D) -> bool: return a.visible).size()
	_check(shown > 0 and not b.link.visible, "Coin: a spark arc (not a beam) swoops from the source (%d)" % shown)
	_check(b.arc.all(func(a: MeshInstance3D) -> bool: return not a.visible or a.global_position.y <= src.global_position.y + 0.08 * 0.5 + 0.001), "the arc stays low (half a die)")
	_step(fx, 1.0)
	fx.trigger_fx(&"gilded_payout", m)
	_step(fx, 2.0 / 12.0 + DT)
	b = fx._live[0]
	_check(b.icon.visible and is_equal_approx(b.icon.diameter, 24.0 * fx._px_per_pt()) and b.icon.studs == 0, "minor icon pops ON the hit: 24 pt, plain rim")
	_step(fx, 1.0)
	_free([fx, src, m])


func _test_coin_flight() -> void:
	var fx := _fx()
	var d := _die(Vector3.ZERO)
	var landed: Array[Node3D] = []
	fx.coin_landed.connect(func(x: Node3D) -> void: landed.append(x))
	fx.trigger_fx(&"gilded_payout", d)
	_step(fx, 0.6)
	_check(landed.is_empty(), "Gilded: the coin is still flying when the burst ends")
	await create_timer(0.6).timeout
	_check(landed == [d], "Gilded: coin_landed fires when the coin reaches the pile (counter tick)")
	_free([fx, d])


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
	var b: TriggerFx.Burst = fx._live[fx._live.size() - 1]
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
