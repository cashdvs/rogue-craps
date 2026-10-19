## Headless test: every sound event in SfxSynth.VARIANTS has its baked takes
## (<event>_01.wav, ...) in the right format, SfxManager finds them, and its
## picker never plays the same take twice in a row.
##
## Run:
##   godot --headless --path . --script res://tests/test_sfx_variants.gd
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
	print("=== Dice of the Damned: SFX variant tests ===")
	_test_files()
	_test_synth()
	var sfx := SfxManager.new()
	root.add_child(sfx)
	_test_picker(sfx)
	# Let the short test sounds finish before freeing the players, so the
	# audio server has let go of them and the test exits cleanly.
	await create_timer(0.4).timeout
	sfx.free()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


## Baked takes exist, load, and stay small: 22,050 Hz, mono, 16-bit.
func _test_files() -> void:
	for event: StringName in SfxSynth.VARIANTS:
		var count := SfxSynth.variant_count(event)
		_check(count >= 3, "synth: '%s' has at least 3 takes" % event)
		for n in range(1, count + 1):
			var path := "res://audio/sfx/%s_%02d.wav" % [event, n]
			var wav := load(path) as AudioStreamWAV
			_check(wav != null, "file: %s exists and loads" % path)
			if wav == null:
				continue
			_check(wav.mix_rate == SfxSynth.MIX_RATE and not wav.stereo, "file: %s is 22,050 Hz mono" % path)
			_check(wav.get_length() > 0.03 and wav.get_length() < 0.3, "file: %s is a short hit" % path)
		var extra := "res://audio/sfx/%s_%02d.wav" % [event, count + 1]
		_check(not ResourceLoader.exists(extra), "file: no stray take %s" % extra)


## Takes are repeatable (fixed seeds) and actually differ from each other.
func _test_synth() -> void:
	for event: StringName in SfxSynth.VARIANTS:
		var a := SfxSynth.make_variant(event, 1).data
		_check(a == SfxSynth.make_variant(event, 1).data, "synth: '%s' take 1 is the same every time" % event)
		_check(a != SfxSynth.make_variant(event, 2).data, "synth: '%s' takes 1 and 2 differ" % event)
	_check(SfxSynth.variant_count(&"dice_settle") == 0, "synth: single-sound events have no takes")


## The manager rotates through every take without a back-to-back repeat.
func _test_picker(sfx: SfxManager) -> void:
	for event: StringName in SfxSynth.VARIANTS:
		var count := sfx.variant_count(event)
		_check(count == SfxSynth.variant_count(event), "manager: finds all %d takes of '%s'" % [SfxSynth.variant_count(event), event])
		var prev := -1
		var no_repeat := true
		var seen := {}
		for i in 300:
			var idx := sfx.pick_variant(event)
			if idx == prev or idx < 0 or idx >= count:
				no_repeat = false
			prev = idx
			seen[idx] = true
		_check(no_repeat, "picker: '%s' never repeats a take back-to-back over 300 picks" % event)
		_check(seen.size() == count, "picker: '%s' uses every take" % event)
	_check(sfx.variant_count(&"dice_settle") == 0 and sfx.pick_variant(&"dice_settle") == 0, "picker: single-sound event falls back to its one sound")
	var plays: Array[StringName] = []
	sfx.played.connect(func(e: StringName) -> void: plays.append(e))
	for i in 5:
		sfx.play(&"dice_hit")
		sfx.play(&"rim_hit")
		sfx.play(&"chip_place")
	sfx.play(&"dice_settle")
	_check(plays.size() == 16, "manager: playing variant and single events works")
