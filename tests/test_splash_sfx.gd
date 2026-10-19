## Headless test: the boot splash sound cues (SplashSynth, baked by
## tools/bake_sfx.gd) exist for every cue in splash_timings.json, fit the
## timing notes in assets/branding/studio/splash_motion.md, the splash picks
## its per-cue mode with them present (full and reduced motion), and no
## pre-mixed studio_splash.wav is shipped (it would never play next to them).
##
## Run:
##   godot --headless --path . --script res://tests/test_splash_sfx.gd
extends SceneTree

const TIMINGS: String = "res://assets/branding/studio/splash_timings.json"

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	print("=== Dice of the Damned: splash SFX tests ===")
	var tl: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TIMINGS))
	_check(tl != null and tl.has("sfx"), "timings: splash_timings.json loads")
	var cue_at: Dictionary[StringName, float] = {}
	for s: Dictionary in tl.get("sfx", []):
		cue_at[StringName("splash_" + str(s.id))] = float(s.at)
	for s: Dictionary in tl.get("reduced_motion", {}).get("sfx", []):
		_check(cue_at.has(StringName("splash_" + str(s.id))), "reduced: cue '%s' is also a full-splash cue" % s.id)
	for event: StringName in cue_at:
		_check(SplashSynth.EVENTS.has(event), "synth: has a recipe for cue '%s'" % event)
	for event in SplashSynth.EVENTS:
		_check_file(event, cue_at.get(event, -1.0))
	_check(not ResourceLoader.exists("res://audio/sfx/studio_splash.wav"), "no studio_splash.wav (dead weight: the per-cue files win)")
	_check_cue_mode(tl)
	_check(SplashSynth.make(&"splash_clang").data == SplashSynth.make(&"splash_clang").data, "synth: same sound on every bake")
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


## With the baked files in res://audio/sfx/, the real splash finds a stream
## for every cue of both variants (full and reduced motion), so its
## cue_mode() picks per-cue sounds and never the single sting.
func _check_cue_mode(tl: Dictionary) -> void:
	var probe := (load("res://scenes/studio_splash.tscn") as PackedScene).instantiate()
	var variants: Dictionary = {"full": tl.get("sfx", []), "reduced": tl.get("reduced_motion", {}).get("sfx", [])}
	for v: String in variants:
		var found := 0
		for s: Dictionary in variants[v]:
			if probe._stream_for(StringName("splash_" + str(s.id))) != null:
				found += 1
		_check(found > 0 and found == (variants[v] as Array).size(), "splash: finds every %s-motion cue file, so it plays per-cue (%d)" % [v, found])
	probe.free()


## The baked file loads, is small (22,050 Hz mono) and ends when the motion
## spec says it should.
func _check_file(event: StringName, at: float) -> void:
	var path := "res://audio/sfx/%s.wav" % event
	var wav := load(path) as AudioStreamWAV
	_check(wav != null, "file: %s exists" % path)
	if wav == null:
		return
	_check(wav.mix_rate == 22050 and not wav.stereo, "file: %s is 22,050 Hz mono" % path)
	_check(at >= 0.0, "timings: %s has a cue time" % event)
	var ends := at + wav.get_length()
	_check(ends <= 2.5, "timing: %s ends by 2.5 s (%.2f)" % [event, ends])
	match event:
		&"splash_clang":
			_check(wav.get_length() <= 0.9, "timing: clang tail <= 0.9 s")
			# The transient must be on the impact frame: loud within 2 ms.
			var first := SplashSynth.make(event).data.slice(0, 2 * 44)
			var loud := 0
			for i in range(0, first.size(), 2):
				loud = maxi(loud, absi(first.decode_s16(i)))
			_check(loud > 16000, "timing: clang transient is in its first 2 ms")
		&"splash_sizzle":
			_check(ends <= 1.36, "timing: sizzle fades out by 1.35 s (%.2f)" % ends)
		&"splash_whoosh":
			_check(ends <= 1.45, "timing: whoosh gone by 1.45 s (%.2f)" % ends)
		&"splash_hammer_swish":
			_check(wav.get_length() <= 0.15, "timing: swish is short")
