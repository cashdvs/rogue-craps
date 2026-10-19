## Headless test: throw momentum audio. ThrowSynth's baked files, the flick ->
## intensity curve (layers, volume, pitch), the impact curve (silence floor,
## louder/higher/brighter with speed), SfxManager.play_throw / play_impact and
## the per-die rate limit.
##
## Run:
##   godot --headless --path . --script res://tests/test_throw_momentum.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0
var _played: Array[StringName] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


func _run() -> void:
	print("=== Dice of the Damned: throw momentum audio tests ===")
	_test_files()
	_test_throw_curve()
	_test_impact_curve()
	var sfx := SfxManager.new()
	root.add_child(sfx)
	sfx.played.connect(func(e: StringName) -> void: _played.append(e))
	_test_play_throw(sfx)
	_test_play_impact(sfx)
	await create_timer(0.6).timeout
	sfx.free()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _samples(wav: AudioStreamWAV) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in wav.data.size() / 2:
		out.append(wav.data.decode_s16(i * 2) / 32768.0)
	return out


## Number of separate clicks: envelope rises over `level` after 4 ms of quiet.
func _onsets(s: PackedFloat32Array, level: float) -> int:
	var n := 0
	var quiet := 1000
	for v in s:
		if absf(v) > level:
			if quiet > 88:
				n += 1
			quiet = 0
		else:
			quiet += 1
	return n


func _crossings_per_s(s: PackedFloat32Array) -> float:
	var n := 0
	for i in range(1, s.size()):
		if (s[i] >= 0.0) != (s[i - 1] >= 0.0):
			n += 1
	return n / (s.size() / float(ThrowSynth.MIX_RATE))


## Baked files exist (22,050 Hz mono, short), match the synth, and the layers
## really differ: the whump is low, the tail bright, the rattles get denser.
func _test_files() -> void:
	for event in ThrowSynth.EVENTS:
		var path := "res://audio/sfx/%s.wav" % event
		var wav := load(path) as AudioStreamWAV
		_check(wav != null, "file: %s loads" % path)
		if wav == null:
			continue
		_check(wav.mix_rate == ThrowSynth.MIX_RATE and not wav.stereo, "file: %s is 22,050 Hz mono" % path)
		_check(wav.get_length() <= 0.5, "file: %s is at most 0.5 s" % path)
		_check(ThrowSynth.make(event).data == ThrowSynth.make(event).data, "synth: %s is deterministic" % event)
	var whump := _crossings_per_s(_samples(ThrowSynth.make(&"throw_fwip_whump")))
	var fwip := _crossings_per_s(_samples(ThrowSynth.make(&"throw_fwip")))
	var tail := _crossings_per_s(_samples(ThrowSynth.make(&"throw_fwip_tail")))
	_check(whump * 5.0 < fwip, "layers: the whump is much lower than the swish (%d vs %d crossings/s)" % [whump, fwip])
	_check(tail > fwip, "layers: the tail is brighter than the swish (%d vs %d)" % [tail, fwip])
	var counts: Array[int] = []
	for r in ThrowSynth.RATTLES:
		counts.append(_onsets(_samples(ThrowSynth.make(r)), 0.12))
	_check(counts[0] < counts[1] and counts[1] < counts[2], "rattle: more clicks soft < medium < hard %s" % [counts])


## Flick speed -> intensity, layers, volume and pitch.
func _test_throw_curve() -> void:
	_check(ThrowSynth.throw_intensity(0.0) == 0.0 and ThrowSynth.throw_intensity(700.0) == 0.0, "throw: 700 px/s and under is intensity 0")
	_check(ThrowSynth.throw_intensity(6000.0) == 1.0 and ThrowSynth.throw_intensity(9000.0) == 1.0, "throw: 6000 px/s and over is intensity 1")
	var prev := -1.0
	var rising := true
	for px in range(700, 6001, 100):
		var k := ThrowSynth.throw_intensity(px)
		rising = rising and k > prev
		prev = k
	_check(rising, "throw: intensity rises with every faster flick")
	_check(ThrowSynth.throw_params(850.0)["layers"] == 1, "throw: a soft flick (850 px/s, logged 820-870) is the swish only")
	_check(ThrowSynth.throw_params(2000.0)["layers"] == 2, "throw: a medium flick (2000 px/s, logged 1800-2150) adds the whump")
	_check(ThrowSynth.throw_params(4300.0)["layers"] == 3, "throw: a hard flick (4300 px/s, logged 4150-4400) adds the bright tail")
	var soft := ThrowSynth.throw_params(850.0)
	var mid := ThrowSynth.throw_params(2000.0)
	var hard := ThrowSynth.throw_params(4300.0)
	_check(mid["volume_db"] - soft["volume_db"] >= 4.0 and hard["volume_db"] - mid["volume_db"] >= 4.0, "throw: logged soft / medium / hard are 4+ dB apart")
	var lo := ThrowSynth.throw_params(700.0)
	var hi := ThrowSynth.throw_params(6000.0)
	_check(is_equal_approx(lo["volume_db"], -14.0) and is_equal_approx(hi["volume_db"], 0.0), "throw: volume runs -14 to 0 dB")
	_check(is_equal_approx(lo["pitch"], 0.9) and is_equal_approx(hi["pitch"], 1.15), "throw: pitch runs 0.9 to 1.15")
	_check(lo["rattle"] == &"throw_rattle_soft" and hi["rattle"] == &"throw_rattle_hard", "throw: rattle goes soft -> hard")


## Contact speed -> silence floor, then louder, higher and brighter.
func _test_impact_curve() -> void:
	_check(ThrowSynth.impact_params(&"felt", 0.29).is_empty(), "impact: 0.29 m/s is silent")
	_check(not ThrowSynth.impact_params(&"felt", 0.3).is_empty(), "impact: 0.3 m/s plays")
	for kind: StringName in ThrowSynth.KINDS:
		# Godot Dev's logged first floor hits: soft ~2, medium ~3.5, hard ~5.9 m/s.
		var soft := ThrowSynth.impact_params(kind, 2.0)
		var mid := ThrowSynth.impact_params(kind, 3.5)
		var hard := ThrowSynth.impact_params(kind, 5.9)
		_check(mid["volume_db"] - soft["volume_db"] >= 2.5 and hard["volume_db"] - mid["volume_db"] >= 2.5, "impact: %s soft / medium / hard are 2.5+ dB apart" % kind)
		_check(soft["pitch"] < mid["pitch"] and mid["pitch"] < hard["pitch"], "impact: %s gets higher with speed" % kind)
		_check(soft["click_db"] - soft["volume_db"] < hard["click_db"] - hard["volume_db"], "impact: %s gets brighter with speed" % kind)
		_check(SfxSynth.variant_count(hard["event"]) >= 3, "impact: %s rotates takes of %s" % [kind, hard["event"]])
	var felt := ThrowSynth.impact_params(&"felt", 3.0)
	var die := ThrowSynth.impact_params(&"die", 3.0)
	_check(felt["click_db"] - felt["volume_db"] < die["click_db"] - die["volume_db"] - 6.0, "impact: felt is duller than die-on-die")
	_check(felt["pitch"] < ThrowSynth.impact_params(&"rail", 3.0)["pitch"], "impact: felt thud is lower than the rail")
	_check(ThrowSynth.impact_params(&"carpet", 3.0)["event"] == &"dice_hit", "impact: an unknown kind falls back to felt")
	_check(ThrowSynth.impact_params(&"felt", 3.0, &"obsidian")["pitch"] == felt["pitch"], "impact: an unknown material sounds like bone")
	var skim := ThrowSynth.impact_params(&"felt", 6.0)
	_check(skim["volume_db"] <= -5.0 and skim["volume_db"] < ThrowSynth.impact_params(&"backboard", 6.0)["volume_db"] - 3.0, "impact: felt skimming at 6 m/s isn't a slam (<= -5 dB, under the backboard)")
	_check(skim["click_db"] < -35.0, "impact: felt at 6 m/s has almost no click")
	_check(ThrowSynth.impact_params(&"felt", 2.0)["volume_db"] >= -15.0, "impact: a soft 2 m/s floor hit isn't too quiet (>= -15 dB)")
	_check(ThrowSynth.impact_strength(7.0) == 1.0 and ThrowSynth.impact_strength(8.9) == 1.0, "impact: full strength from 7 m/s (logged max 8.9)")
	var board := ThrowSynth.impact_params(&"backboard", 5.5)
	_check(board["wood_db"] > board["volume_db"] - 3.0 and is_inf(felt["wood_db"]), "impact: only the backboard gets the wood knock, near full level on hard hits")
	_check(board["click_db"] - board["volume_db"] < die["click_db"] - die["volume_db"], "impact: the backboard is a thump, less click than die-on-die")
	var wood := _samples(ThrowSynth.make(ThrowSynth.WOOD))
	_check(_crossings_per_s(wood) < 1200.0, "impact: impact_wood is a low wooden knock (%d crossings/s)" % _crossings_per_s(wood))


func _test_play_throw(sfx: SfxManager) -> void:
	for event in ThrowSynth.EVENTS:
		_check(sfx.has_event(event), "manager: knows %s" % event)
	var expect := {850.0: 2, 2000.0: 3, 4300.0: 4}
	for px: float in expect:
		_played.clear()
		var k := sfx.play_throw(px)
		_check(_played.size() == expect[px], "play_throw(%d): %d sounds (layers + rattle)" % [px, expect[px]])
		_check(is_equal_approx(k, ThrowSynth.throw_intensity(px)), "play_throw(%d): returns the intensity" % px)
	_check(_played.has(&"throw_fwip_tail") and _played.has(&"throw_rattle_hard"), "play_throw: a hard flick plays the tail and the hard rattle")


func _test_play_impact(sfx: SfxManager) -> void:
	sfx.impact_clock = 10.0
	_played.clear()
	_check(not sfx.play_impact(&"felt", 0.2, &"bone", 0) and _played.is_empty(), "play_impact: under 0.3 m/s plays nothing")
	_check(sfx.play_impact(&"die", 4.0, &"bone", 0), "play_impact: a hard die hit plays")
	_check(_played.has(&"dice_hit") and _played.has(&"impact_click"), "play_impact: a hard hit adds the bright click")
	_played.clear()
	sfx.play_impact(&"backboard", 5.5)
	_check(_played.has(&"rim_hit") and _played.has(&"impact_wood"), "play_impact: a backboard hit is rim_hit + impact_wood")
	sfx.impact_clock = 10.02
	_check(not sfx.play_impact(&"felt", 3.0, &"bone", 0), "play_impact: the same die 20 ms later is rate-limited")
	_check(sfx.play_impact(&"felt", 3.0, &"bone", 1), "play_impact: another die isn't limited")
	_check(sfx.play_impact(&"felt", 3.0) and sfx.play_impact(&"felt", 3.0), "play_impact: no die id, no limit")
	sfx.impact_clock = 10.05
	_check(sfx.play_impact(&"rail", 2.0, &"bone", 0), "play_impact: the same die plays again after the gap")
	_played.clear()
	sfx.impact_clock = 11.0
	_check(bool(sfx.call("play_impact", "rail", 2.0, "bone")) and _played.has(&"rim_hit"), "play_impact: works with String args via call() (Table3D style)")
	_played.clear()
	sfx.play_impact(&"felt", 0.5)
	_check(not _played.has(&"impact_click"), "play_impact: a soft felt tap has no click")
