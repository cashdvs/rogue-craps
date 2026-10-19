## Headless test: the mod trigger cues (ModTriggerSynth), one per row of the
## trigger FX spec. Every cue rings 0.15-0.45 s after its hit, peaks at LEVEL
## (6 dB under the loudest stinger), sits mostly in 1-5 kHz, carries no fire
## (no hiss or crackle), and no two cues are alike in brightness + envelope.
## Ids map to rows (aliases, silent rows, generic fallback); stagger, volume.
##
## Run:
##   godot --headless --path . --script res://tests/test_mod_trigger_cues.gd
extends SceneTree

const SR: float = 22050.0

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
	print("=== Dice of the Damned: mod trigger cue tests ===")
	_test_cues()
	_test_mapping()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _samples(wav: AudioStreamWAV) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(wav.data.size() / 2)
	for i in out.size():
		out[i] = wav.data.decode_s16(i * 2) / 32768.0
	return out


## RMS frequency (Hz): how bright the cue is, from the slope energy.
func _rms_hz(s: PackedFloat32Array) -> float:
	var e := 0.0
	var d := 0.0
	for i in range(1, s.size()):
		e += s[i] * s[i]
		d += (s[i] - s[i - 1]) * (s[i] - s[i - 1])
	return SR / TAU * sqrt(d / e)


## Share of the energy in 1-5 kHz (a 2nd-order band-pass, Q ~0.75).
func _band_share(s: PackedFloat32Array) -> float:
	var w := TAU * 2236.0 / SR
	var alpha := sin(w) / 1.5
	var c := [alpha / (1.0 + alpha), -2.0 * cos(w) / (1.0 + alpha), (1.0 - alpha) / (1.0 + alpha)]
	var z := [0.0, 0.0, 0.0, 0.0]  # x[n-1], x[n-2], y[n-1], y[n-2]
	var eb := 0.0
	var e := 0.0
	for x in s:
		var y: float = c[0] * (x - z[1]) - c[1] * z[2] - c[2] * z[3]
		z = [x, z[0], y, z[2]]
		eb += y * y
		e += x * x
	return eb / e


## Loudness in 30 frames of 20 ms from 0.16 s before the hit, 0..1.
func _envelope(s: PackedFloat32Array, hit_s: float) -> PackedFloat32Array:
	var env := PackedFloat32Array()
	env.resize(30)
	var top := 0.0001
	var start := int((hit_s - 0.16) * SR)
	for f in 30:
		var sum := 0.0
		for i in range(maxi(start + f * 441, 0), clampi(start + (f + 1) * 441, 0, s.size())):
			sum += s[i] * s[i]
		env[f] = sqrt(sum / 441.0)
		top = maxf(top, env[f])
	for f in 30:
		env[f] /= top
	return env


## Loud 46 ms frames (half-overlapped) with a flat spectrum (flatness > 0.2):
## noise such as hiss, crackle or a fire whoosh. Rings, brass and short clicks
## stay peaky. bust's fizzle scores 11, soul_burn 20.
func _noisy_frames(s: PackedFloat32Array) -> int:
	var peak := 0.0001
	for v in s:
		peak = maxf(peak, absf(v))
	var count := 0
	for start in range(0, s.size() - 1023, 512):
		var re := PackedFloat32Array()
		re.resize(1024)
		var e := 0.0
		for i in 1024:
			re[i] = s[start + i] * (0.5 - 0.5 * cos(TAU * i / 1023.0))
			e += s[start + i] * s[start + i]
		if sqrt(e / 1024.0) <= peak * 0.05:
			continue
		var pw := _power(re)
		var lg := 0.0
		var ar := 0.0
		for k in range(1, 513):
			lg += log(pw[k] + 1e-12)
			ar += pw[k] + 1e-12
		if exp(lg / 512.0) / (ar / 512.0) > 0.2:
			count += 1
	return count


## Power spectrum of a 1024-sample real frame (iterative radix-2 FFT).
func _power(re: PackedFloat32Array) -> PackedFloat32Array:
	var n := re.size()
	var im := PackedFloat32Array()
	im.resize(n)
	var j := 0
	for i in range(1, n):
		var bit := n >> 1
		while j & bit:
			j ^= bit
			bit >>= 1
		j |= bit
		if i < j:
			var t := re[i]
			re[i] = re[j]
			re[j] = t
	var size := 2
	while size <= n:
		var ang := -TAU / size
		for s0 in range(0, n, size):
			for k in size / 2:
				var wr := cos(ang * k)
				var wi := sin(ang * k)
				var a := s0 + k
				var b := a + size / 2
				var tr := re[b] * wr - im[b] * wi
				var ti := re[b] * wi + im[b] * wr
				re[b] = re[a] - tr
				im[b] = im[a] - ti
				re[a] += tr
				im[a] += ti
		size *= 2
	var out := PackedFloat32Array()
	out.resize(n / 2 + 1)
	for k in out.size():
		out[k] = re[k] * re[k] + im[k] * im[k]
	return out


func _test_cues() -> void:
	var stinger_max := 0.0
	for st in BonfireSynth.TIER_STINGERS:
		stinger_max = maxf(stinger_max, BonfireSynth.LEVELS[st])
	_check(absf(linear_to_db(ModTriggerSynth.LEVEL) - linear_to_db(stinger_max) + 6.0) < 0.1, "level: cues peak 6 dB under the loudest stinger")
	var feats: Dictionary = {}
	var rows: Array = ModTriggerSynth.ROWS.keys()
	for row: StringName in rows:
		var t := ModTriggerSynth.timing(row)
		var file := load("res://audio/sfx/trigger_%s.wav" % row) as AudioStreamWAV
		_check(file != null and file.mix_rate == 22050 and not file.stereo, "file: trigger_%s.wav is 22,050 Hz mono" % row)
		var wav := ModTriggerSynth.make(row)
		_check(wav.data == ModTriggerSynth.make(row).data, "synth: %s is the same on every bake" % row)
		_check(int(t[2]) <= int(t[1]) and int(t[0]) in [0, 1, 2], "timing: %s leads %d ms <= its hit %d ms" % [row, t[2], t[1]])
		var s := _samples(wav)
		var hit_s := float(t[2]) / 1000.0
		var post := s.size() / SR - hit_s
		_check(post >= 0.15 and post <= 0.455, "length: %s rings %.2f s after its hit (0.15-0.45)" % [row, post])
		var band := _band_share(s)
		_check(band >= 0.35, "band: %s has %.0f%% of its energy in 1-5 kHz (>= 35%%)" % [row, band * 100.0])
		var noisy := _noisy_frames(s)
		_check(noisy <= 2, "no fire: %s has %d hiss/crackle frames (<= 2)" % [row, noisy])
		feats[row] = [_rms_hz(s), _envelope(s, hit_s)]
	for fl: StringName in ModTriggerSynth.FLAVORS:
		var wav := ModTriggerSynth.make(StringName("flavor_" + fl))
		var s := _samples(wav)
		_check(load("res://audio/sfx/trigger_flavor_%s.wav" % fl) != null and wav.data == ModTriggerSynth.make(StringName("flavor_" + fl)).data, "flavour: %s is baked and stable" % fl)
		_check(s.size() / SR <= 0.45 and _noisy_frames(s) <= 2, "flavour: %s is short (%.2f s) with no hiss" % [fl, s.size() / SR])
	for id: StringName in ModTriggerSynth.FLAVOR_OF:
		var fl: StringName = ModTriggerSynth.FLAVOR_OF[id]
		_check(ModTriggerSynth.FLAVORS.has(fl) and ModTriggerSynth.FLAVORS[fl][0] == ModTriggerSynth.row_for(id), "flavour: %s -> %s layers on its own row" % [id, fl])
	var bust := _noisy_frames(_samples(BonfireSynth.make(&"bust")))
	_check(bust >= 8, "no fire: the detector does catch bust's fizzle (%d frames)" % bust)
	# Alike = within 0.25 octave of brightness AND within 0.15 of the hit-aligned envelope (scored together).
	for a in rows.size():
		for b in range(a + 1, rows.size()):
			var fa: Array = feats[rows[a]]
			var fb: Array = feats[rows[b]]
			var octs := absf(log(float(fa[0]) / float(fb[0])) / log(2.0))
			var env := 0.0
			for f in 30:
				env += absf(fa[1][f] - fb[1][f]) / 30.0
			_check(octs / 0.25 + env / 0.15 >= 1.0, "distinct: %s vs %s (%.2f oct, envelope %.2f)" % [rows[a], rows[b], octs, env])


func _test_mapping() -> void:
	var cases := {
		&"hellfire": &"hellfire_face", &"mirror": &"mirror_copy", &"gilded_payout": &"gilded_payout",
		&"blank": &"no_score", &"heavy": &"", &"extra": &"", &"not_a_mod": &"generic",
		&"ferrymans_coin": &"coin_heads_copy", &"coin_tails": &"coin_tails_copy", &"coin_edge": &"", &"coin_alone_tails": &"",
		&"verdict_20": &"hellfire_face", &"verdict_1": &"blood_face", &"midnight": &"hellfire_face", &"powder_keg": &"twin_face",
	}
	for id: StringName in cases:
		_check(ModTriggerSynth.row_for(id) == cases[id], "map: %s -> %s" % [id, cases[id]])
	for id: StringName in ModTriggerSynth.ALIASES:
		var row := ModTriggerSynth.row_for(id)
		_check(row != &"generic" and (ModTriggerSynth.ROWS.has(row) or row == &"no_score"), "map: alias %s -> a real row" % id)
	_check(ModTriggerSynth.event(&"mirror_copy") == &"trigger_mirror_copy" and ModTriggerSynth.event(&"no_score") == &"no_score", "event: row -> trigger_<row>")
	_check(is_zero_approx(ModTriggerSynth.stagger(0)) and is_equal_approx(ModTriggerSynth.stagger(2), 0.16), "stagger: 0.08 s apart at 1x")
	_check(is_equal_approx(ModTriggerSynth.stagger(2, 1), 0.08) and is_zero_approx(ModTriggerSynth.stagger(2, 2)), "stagger: halved at 2x, 0 at Instant")
	_check(ModTriggerSynth.volume_db(2, 1.0) == 0.0 and ModTriggerSynth.volume_db(0, 0.0) == -13.0 and ModTriggerSynth.volume_db(1, 5.0) == -2.0, "volume: tier dB, intensity 0..1 -> -9..0 dB, clamped")
	var files := ModTriggerSynth.bake_all()
	var layers := 0
	layers = ModTriggerSynth.FLAVORS.size()
	_check(files.size() == ModTriggerSynth.ROWS.size() + layers and files.has("trigger_generic.wav") and files.has("trigger_cluster.wav"), "bake: one file per row (+ flavour layers)")
