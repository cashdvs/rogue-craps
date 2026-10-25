## Headless test: the Nerve nudge tick (SfxSynth nerve_nudge, played by
## TableAudio on every nudge and undo) is short, tonal, small and has takes.
##
## Run:
##   godot --headless --path . --script res://tests/test_nerve_nudge.gd
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
	print("=== Dice of the Damned: Nerve nudge tests ===")
	var files: Array[String] = ["nerve_nudge"]
	for n in range(1, SfxSynth.variant_count(&"nerve_nudge") + 1):
		files.append("nerve_nudge_%02d" % n)
	_check(files.size() == 4, "nerve_nudge has 3 takes")
	var datas: Array[PackedByteArray] = []
	for f in files:
		var wav := load("res://audio/sfx/%s.wav" % f) as AudioStreamWAV
		_check(wav != null, "%s.wav is baked" % f)
		if wav == null:
			continue
		var len_ms := wav.get_length() * 1000.0
		_check(len_ms >= 60.0 and len_ms <= 120.0, "%s is 60-120 ms (%.0f)" % [f, len_ms])
		_check(wav.mix_rate == SfxSynth.MIX_RATE and not wav.stereo, "%s is 22,050 Hz mono" % f)
		_check(wav.loop_mode == AudioStreamWAV.LOOP_DISABLED, "%s is a one-shot" % f)
		_check(FileAccess.get_file_as_bytes("res://audio/sfx/%s.wav" % f).size() < 8 * 1024, "%s.wav < 8 KB" % f)
		var x := _pcm("res://audio/sfx/%s.wav" % f)
		var head := 0.0
		for i in mini(110, x.size()):  # first 5 ms
			head = maxf(head, absf(x[i]))
		_check(head > 0.1, "%s: the click is at the start (%.2f)" % [f, head])
		_check(absf(x[x.size() - 1]) < 0.01, "%s ends in silence" % f)
		# Tonal, not noisy: first-difference RMS well under white noise (~1.4x).
		var e := 0.0
		var d := 0.0
		for i in range(1, x.size()):
			e += x[i] * x[i]
			d += (x[i] - x[i - 1]) * (x[i] - x[i - 1])
		_check(sqrt(d / e) < 0.6, "%s: no hiss (diff/rms %.2f)" % [f, sqrt(d / e)])
		datas.append(_pcm_bytes("res://audio/sfx/%s.wav" % f))
	_check(datas.size() == 4 and datas[1] != datas[2] and datas[2] != datas[3], "takes differ")
	_check(files.size() == 4 and SfxSynth.make(&"nerve_nudge").data == datas[0], "nerve_nudge.wav == SfxSynth.make (no drift)")
	var sfx := SfxManager.new()
	root.add_child(sfx)
	_check(sfx.has_event(&"nerve_nudge"), "SfxManager plays nerve_nudge (TableAudio's chip_place fallback not needed)")
	_check(sfx.variant_count(&"nerve_nudge") == 3, "SfxManager rotates the 3 takes")
	sfx.free()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


## The raw 16-bit PCM of a .wav on disk (the imported stream is compressed).
func _pcm_bytes(path: String) -> PackedByteArray:
	var b := FileAccess.get_file_as_bytes(path)
	var at := 12
	while at + 8 <= b.size():
		var size := b.decode_u32(at + 4)
		if b.slice(at, at + 4).get_string_from_ascii() == "data":
			return b.slice(at + 8, at + 8 + size)
		at += 8 + size + (size & 1)
	return PackedByteArray()


func _pcm(path: String) -> PackedFloat32Array:
	var d := _pcm_bytes(path)
	var x := PackedFloat32Array()
	x.resize(d.size() / 2)
	for i in x.size():
		x[i] = d.decode_s16(i * 2) / 32768.0
	return x
