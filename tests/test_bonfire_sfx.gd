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
		_check(is_equal_approx(_len(event), BonfireSynth.LOOP_SECONDS), "loop: %s is %.1f s" % [event, BonfireSynth.LOOP_SECONDS])
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
