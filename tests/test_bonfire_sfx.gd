## Headless test: the Bonfire scoring sounds (BonfireSynth) are baked and
## small, the timing budget fits (normal sequence <= 1.2 s, big <= 2.0 s), the
## pip-tick scale climbs, stingers map to tiers, the crowd stems loop and
## CrowdLayers follows the pot. Hooks are documented in scripts/audio/README.md.
##
## Run:
##   godot --headless --path . --script res://tests/test_bonfire_sfx.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


func _run() -> void:
	print("=== Dice of the Damned: Bonfire SFX tests ===")
	_test_files()
	_test_helpers()
	_test_bed()
	await _test_players()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _len(event: StringName) -> float:
	var wav := load("res://audio/sfx/%s.wav" % event) as AudioStreamWAV
	return wav.get_length() if wav != null else -1.0


func _test_files() -> void:
	for event in BonfireSynth.EVENTS + BonfireSynth.LOOPS:
		var path := "res://audio/sfx/%s.wav" % event
		var wav := load(path) as AudioStreamWAV
		_check(wav != null, "file: %s exists" % path)
		if wav != null:
			_check(wav.mix_rate == 22050 and not wav.stereo, "file: %s is 22,050 Hz mono" % path)
	for event in BonfireSynth.LOOPS:
		var wav := load("res://audio/sfx/%s.wav" % event) as AudioStreamWAV
		_check(wav != null and wav.loop_mode == AudioStreamWAV.LOOP_FORWARD, "loop: %s is imported as a forward loop" % event)
		_check(absf(_len(event) - BonfireSynth.LOOP_LENGTHS[event]) < 0.001, "loop: %s is %.1f s" % [event, BonfireSynth.LOOP_LENGTHS[event]])
	# Normal sequence (<= 1.2 s): the stinger of tiers 0-2 must fit inside it.
	for event: StringName in [&"score_tick", &"count_tick", &"mult_slam", &"combo_banner", &"bounty_claimed"]:
		_check(_len(event) <= 0.5, "timing: %s is short (%.2f s)" % [event, _len(event)])
	var prev := 0.0
	for tier in 4:
		var l := _len(BonfireSynth.stinger_for_tier(tier))
		_check(l > prev, "timing: tier %d stinger is longer than the one below (%.2f s)" % [tier, l])
		prev = l
		_check(l <= (1.2 if tier < 3 else 2.0), "timing: tier %d stinger fits its sequence (%.2f s)" % [tier, l])
	for event: StringName in [&"mult_slam", &"bank"]:
		_check(BonfireSynth.make(event).data == BonfireSynth.make(event).data, "synth: %s is the same on every bake" % event)


func _test_helpers() -> void:
	_check(is_equal_approx(BonfireSynth.tick_pitch(0), 1.0), "tick: index 0 plays at the root")
	var rising := true
	for i in range(1, BonfireSynth.TICK_SCALE.size()):
		rising = rising and BonfireSynth.tick_pitch(i) > BonfireSynth.tick_pitch(i - 1)
	_check(rising, "tick: every next pip is higher")
	_check(is_equal_approx(BonfireSynth.tick_pitch(99), BonfireSynth.tick_pitch(BonfireSynth.TICK_SCALE.size() - 1)), "tick: pitch caps at the top of the scale")
	_check(BonfireSynth.stinger_for_tier(0) == &"stinger_ember" and BonfireSynth.stinger_for_tier(3) == &"stinger_pillar", "stinger: tiers 0 and 3")
	_check(BonfireSynth.stinger_for_tier(-1) == &"stinger_ember" and BonfireSynth.stinger_for_tier(9) == &"stinger_pillar", "stinger: tier is clamped")
	var g0 := BonfireSynth.crowd_gains_db(0.0)
	var g1 := BonfireSynth.crowd_gains_db(1.0)
	_check(g0[1] <= -59.0 and g0[2] <= -59.0 and g0[0] > -20.0, "crowd: empty pot = only the low murmur")
	_check(g1[0] >= -0.1 and g1[1] >= -0.1 and g1[2] >= -0.1, "crowd: full pot = all stems up")
	var building := true
	var last := BonfireSynth.crowd_gains_db(0.0)
	for k in range(1, 21):
		var g := BonfireSynth.crowd_gains_db(k / 20.0)
		for s in 3:
			building = building and g[s] >= last[s]
		last = g
	_check(building, "crowd: no stem gets quieter as the pot grows")


## The always-on bed (crowd_low at an empty pot) stays quiet, warm and
## seamless (playtest: "too loud, not satisfying", main 7b978b9).
func _test_bed() -> void:
	var crowd := CrowdLayers.new()
	_check(crowd.volume_db <= -12.0, "bed: CrowdLayers.volume_db <= -12 dB (%.1f)" % crowd.volume_db)
	crowd.free()
	var bed_db := BonfireSynth.crowd_gains_db(0.0)[0] + linear_to_db(BonfireSynth.LEVELS[&"crowd_low"])
	_check(bed_db <= -22.0, "bed: empty-pot stem gain + peak level <= -22 dB (%.1f)" % bed_db)
	for event in BonfireSynth.LOOPS:
		_check(_pcm(event) == BonfireSynth.make(event).data, "bed: %s.wav == BonfireSynth.make (re-baked)" % event)
	var pcm := _pcm(&"crowd_low")
	var n := pcm.size() / 2
	var x := _floats(pcm)
	# High-frequency energy: first differences boost hiss; for a warm bed the
	# difference RMS stays far below the signal RMS (white noise ~ 1.4x).
	var e := 0.0
	var d := 0.0
	var max_step := 0.0
	for i in range(1, n):
		e += x[i] * x[i]
		var step := absf(x[i] - x[i - 1])
		d += step * step
		max_step = maxf(max_step, step)
	_check(sqrt(d / e) < 0.1, "bed: crowd_low has no broadband hiss (diff/rms %.3f)" % sqrt(d / e))
	_check(absf(x[0] - x[n - 1]) <= max_step * 1.5, "bed: crowd_low loop seam is continuous (%.4f)" % absf(x[0] - x[n - 1]))
	_check(BonfireSynth.LOOP_LENGTHS.values().all(func(l): return l >= 4.0 and BonfireSynth.LOOP_LENGTHS.values().count(l) == 1), "bed: stem loops are >= 4 s and unique")
	for event in BonfireSynth.LOOPS:  # rev 3 high-pass: no DC, no sub-20 Hz rumble
		var y := _floats(_pcm(event))
		var dc := 0.0
		for v in y: dc += v / y.size()
		_check(absf(dc) < 0.0005, "bed: %s has no DC offset (%.5f)" % [event, dc])
		var sub := _band_share(y, 0.0, 20.0)
		_check(sub < 0.001, "bed: %s sub-20 Hz energy < 0.1 %% (%.2f %%)" % [event, sub * 100.0])
	# Drone growl (rev 3): beating partials make crowd_low's loudness buzz at 15-60 Hz.
	var env := _floats(pcm)
	for i in env.size(): env[i] = absf(env[i])
	var buzz := _band_share(env, 15.0, 60.0)
	_check(buzz < 0.03, "bed: crowd_low envelope buzz 15-60 Hz < 3 %% (%.1f %%)" % (buzz * 100.0))


## The raw PCM of a WAV on disk (the imported stream is compressed): its data chunk.
func _pcm(event: StringName) -> PackedByteArray:
	var b := FileAccess.get_file_as_bytes("res://audio/sfx/%s.wav" % event)
	var at := 12
	while at + 8 <= b.size():
		var size := b.decode_u32(at + 4)
		if b.slice(at, at + 4).get_string_from_ascii() == "data":
			return b.slice(at + 8, at + 8 + size)
		at += 8 + size + (size & 1)
	return PackedByteArray()


func _floats(pcm: PackedByteArray) -> PackedFloat32Array:
	var x := PackedFloat32Array()
	x.resize(pcm.size() / 2)
	for i in x.size(): x[i] = pcm.decode_s16(i * 2) / 32768.0
	return x


## Share of x's AC energy between lo_hz and hi_hz (four-pole low-passes).
func _band_share(x: PackedFloat32Array, lo_hz: float, hi_hz: float) -> float:
	var mean: float = Array(x).reduce(func(m, v): return m + v / x.size(), 0.0)
	var lp := PackedFloat64Array()
	lp.resize(8)
	var band := 0.0
	var total := 0.0
	for i in x.size():
		for j in 2:
			var a := 1.0 - exp(-TAU * [hi_hz, lo_hz][j] / 22050.0)
			lp[j * 4] += a * (x[i] - mean - lp[j * 4])
			for k in range(j * 4, j * 4 + 3): lp[k + 1] += a * (lp[k] - lp[k + 1])
		band += (lp[3] - lp[7]) ** 2
		total += (x[i] - mean) ** 2
	return band / total

func _test_players() -> void:
	var sfx := SfxManager.new()
	root.add_child(sfx)
	var all := true
	for event in BonfireSynth.EVENTS:
		all = all and sfx.has_event(event)
	_check(all, "manager: knows every Bonfire one-shot")
	var crowd := CrowdLayers.new()
	root.add_child(crowd)
	crowd.start(0.01)
	for p in crowd.get_children(): p.seek(2.0)
	crowd.start(0.01)  # a new run: the bed carries on, no restart click
	var kept := crowd.get_children().map(func(p): return p.get_playback_position())
	_check(kept.all(func(t): return t >= 1.99), "crowd: start() again does not restart the stems %s" % [kept])
	crowd.set_pot_fraction(1.0, 0.01)
	await create_timer(0.1).timeout
	var db := crowd.current_db()
	_check(absf(db[2] - crowd.volume_db) < 0.5, "crowd: full pot brings the roar to the crowd level (%.1f dB)" % db[2])
	crowd.set_pot_fraction(0.0, 0.01)
	await create_timer(0.1).timeout
	_check(crowd.current_db()[2] <= -59.0, "crowd: bank/bust drops the roar")
	crowd.stop(0.01)
	await create_timer(0.1).timeout
	var stopped := true
	for p in crowd.get_children():
		stopped = stopped and not (p as AudioStreamPlayer).playing
	_check(stopped, "crowd: stop() stops the stems")
	sfx.free()
	crowd.free()
