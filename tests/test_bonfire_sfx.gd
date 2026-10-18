## Headless test: the Bonfire scoring sounds (BonfireSynth) are baked and
## small, the timing budget fits (normal sequence <= 1.2 s, big <= 2.0 s), the
## pip-tick scale climbs and stingers map to tiers. Hooks are documented in
## scripts/audio/README.md.
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
	for event in BonfireSynth.EVENTS:
		var path := "res://audio/sfx/%s.wav" % event
		var wav := load(path) as AudioStreamWAV
		_check(wav != null, "file: %s exists" % path)
		if wav != null:
			_check(wav.mix_rate == 22050 and not wav.stereo, "file: %s is 22,050 Hz mono" % path)
	# Normal sequence (<= 1.2 s): the stinger of tiers 0-2 must fit inside it.
	for event: StringName in [&"score_tick", &"count_tick", &"mult_slam", &"combo_banner"]:
		_check(_len(event) <= 0.5, "timing: %s is short (%.2f s)" % [event, _len(event)])
	var prev := 0.0
	for tier in 4:
		var l := _len(BonfireSynth.stinger_for_tier(tier))
		_check(l > prev, "timing: tier %d stinger is longer than the one below (%.2f s)" % [tier, l])
		prev = l
		_check(l <= (1.2 if tier < 3 else 2.0), "timing: tier %d stinger fits its sequence (%.2f s)" % [tier, l])
	_check(BonfireSynth.make(&"mult_slam").data == BonfireSynth.make(&"mult_slam").data, "synth: same sound on every bake")


func _test_helpers() -> void:
	_check(is_equal_approx(BonfireSynth.tick_pitch(0), 1.0), "tick: index 0 plays at the root")
	var rising := true
	for i in range(1, BonfireSynth.TICK_SCALE.size()):
		rising = rising and BonfireSynth.tick_pitch(i) > BonfireSynth.tick_pitch(i - 1)
	_check(rising, "tick: every next pip is higher")
	_check(is_equal_approx(BonfireSynth.tick_pitch(99), BonfireSynth.tick_pitch(BonfireSynth.TICK_SCALE.size() - 1)), "tick: pitch caps at the top of the scale")
	_check(BonfireSynth.stinger_for_tier(0) == &"stinger_ember" and BonfireSynth.stinger_for_tier(3) == &"stinger_pillar", "stinger: tiers 0 and 3")
	_check(BonfireSynth.stinger_for_tier(-1) == &"stinger_ember" and BonfireSynth.stinger_for_tier(9) == &"stinger_pillar", "stinger: tier is clamped")


func _test_players() -> void:
	var sfx := SfxManager.new()
	root.add_child(sfx)
	var all := true
	for event in BonfireSynth.EVENTS:
		all = all and sfx.has_event(event)
	_check(all, "manager: knows every Bonfire one-shot")
	await create_timer(0.1).timeout
	sfx.free()
