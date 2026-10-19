## Headless test: the core-loop cues (BonfireSynth rev 2). The revised cues
## (hot_hand, bust, bank, bounty_claimed) and the new ones (table_cleared,
## no_score) are baked, short and deterministic; the dice cues carry no fire
## (no sustained hiss or crackle) while bust does; hot_hand has the 5 dice
## clacks and no_score is a short bounce. Hooks: scripts/audio/README.md.
##
## Run:
##   godot --headless --path . --script res://tests/test_core_loop_cues.gd
extends SceneTree

const MAX_S: Dictionary[StringName, float] = {
	&"hot_hand": 0.8, &"bust": 1.1, &"bank": 1.0, &"bounty_claimed": 0.5,
	&"table_cleared": 1.6, &"no_score": 0.35,
}

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
	print("=== Dice of the Damned: core-loop cue tests ===")
	_test_files()
	_test_character()
	_test_manager()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _samples(event: StringName) -> PackedFloat32Array:
	# The fresh 16-bit bake: the imported .wav is QOA-compressed.
	var out := PackedFloat32Array()
	var wav := BonfireSynth.make(event)
	out.resize(wav.data.size() / 2)
	for i in out.size():
		out[i] = wav.data.decode_s16(i * 2) / 32768.0
	return out


## 10 ms frames that are loud (> 5% of peak) and noisy (> 5000 zero
## crossings/s): sustained hiss, crackle or a fire whoosh. Bone/felt/wood taps
## ring tonally and die within a frame or two.
func _noisy_frames(s: PackedFloat32Array) -> int:
	var peak := 0.0001
	for v in s:
		peak = maxf(peak, absf(v))
	var n := 220
	var count := 0
	for f in s.size() / n:
		var sum := 0.0
		var zc := 0
		for i in range(f * n, (f + 1) * n):
			sum += s[i] * s[i]
			if i > f * n and signf(s[i]) != signf(s[i - 1]):
				zc += 1
		if sqrt(sum / n) > peak * 0.05 and zc * 100 > 5000:
			count += 1
	return count


## Attacks: 5 ms frames whose peak is > 12% of the max and > 2x the frame before.
func _onsets(s: PackedFloat32Array) -> int:
	var peak := 0.0001
	for v in s:
		peak = maxf(peak, absf(v))
	var prev := 0.0
	var count := 0
	for f in s.size() / 110:
		var m := 0.0
		for i in range(f * 110, (f + 1) * 110):
			m = maxf(m, absf(s[i]))
		if m > peak * 0.12 and m > prev * 2.0:
			count += 1
		prev = m
	return count


func _test_files() -> void:
	var cues: Array[StringName] = BonfireSynth.REVISED.keys()
	cues.append_array(BonfireSynth.ADDED)
	for event in cues:
		_check(BonfireSynth.EVENTS.has(event), "list: %s is a Bonfire event" % event)
		var wav := load("res://audio/sfx/%s.wav" % event) as AudioStreamWAV
		_check(wav != null and wav.mix_rate == 22050 and not wav.stereo, "file: %s.wav is 22,050 Hz mono" % event)
		if wav != null:
			_check(wav.get_length() > 0.1 and wav.get_length() <= MAX_S[event], "file: %s is %.2f s (<= %.2f)" % [event, wav.get_length(), MAX_S[event]])
			_check(BonfireSynth.make(event).data == BonfireSynth.make(event).data, "synth: %s is the same on every bake" % event)
	for event in BonfireSynth.REVISED:
		_check(BonfireSynth.REVISED[event].contains("was "), "revision: %s notes what it replaced" % event)


func _test_character() -> void:
	for event in BonfireSynth.DICE_CUES:
		var noisy := _noisy_frames(_samples(event))
		_check(noisy <= 1, "no fire on dice: %s has %d hiss/crackle frames (<= 1)" % [event, noisy])
	var bust := _noisy_frames(_samples(&"bust"))
	_check(bust >= 15, "bust: the fizzle/burn is audible (%d noisy frames >= 15)" % bust)
	var hits := _onsets(_samples(&"hot_hand"))
	_check(hits >= 5, "hot_hand: at least 5 dice clacks (%d)" % hits)
	var bounces := _onsets(_samples(&"no_score"))
	_check(bounces >= 2 and bounces <= 4, "no_score: a short bounce of 2-4 taps (%d)" % bounces)
	_check(BonfireSynth.LEVELS[&"no_score"] < BonfireSynth.LEVELS[&"hot_hand"], "no_score: sits under the scoring cues")


func _test_manager() -> void:
	var sfx := SfxManager.new()
	root.add_child(sfx)
	for event: StringName in [&"table_cleared", &"no_score"]:
		_check(sfx.has_event(event), "manager: knows %s" % event)
	sfx.free()
