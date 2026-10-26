## Shared base for the Bonfire synth: the crowd/roar recipes (one-shot roars
## and gasps) and the buffer helpers every Bonfire recipe uses. There is no
## looping crowd bed any more (removed by request). Split out of BonfireSynth to
## keep each file under 400 lines; BonfireSynth extends this, so its recipes
## call these helpers unqualified and share the one seeded _rng (bakes are
## byte-identical to before the split).
class_name CrowdStemSynth
extends RefCounted

const MIX_RATE: int = SfxSynth.MIX_RATE

## Syllable period of a crowd: syllable rates are whole cycles per this.
const LOOP_SECONDS: float = 3.0

static var _rng := RandomNumberGenerator.new()

# --- Crowd recipes (also used by BonfireSynth one-shots) --------------------

## A fire roar: rumbling low-passed noise with crackle. peak_s < 0 = steady
## (for loops); otherwise it swells to peak_s and dies away.
static func _roar(seconds: float, peak_s: float, crackle: float) -> PackedFloat32Array:
	var buf := _buffer(seconds)
	var lp := 0.0
	var lp2 := 0.0
	for i in buf.size():
		var t := float(i) / MIX_RATE
		var env := 1.0
		if peak_s >= 0.0:
			env = minf(t / maxf(peak_s, 0.01), 1.0) * exp(-maxf(t - peak_s, 0.0) * 2.2)
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * 0.12
		lp2 += (lp - lp2) * 0.2
		var pop := _rng.randf_range(-1.0, 1.0) if _rng.randf() < crackle else 0.0
		buf[i] = (lp2 * 3.0 + pop * 0.5) * env
	return _fade_tail(buf, 0.1) if peak_s >= 0.0 else buf


## A crowd: `voices` band-limited noise voices (each a "person") whose
## loudness rises and falls in syllables (whole cycles per LOOP_SECONDS).
## peak_s >= 0 makes it a one-shot roar that swells to peak_s; < 0 keeps it steady.
static func _crowd(seconds: float, voices: int, lo_hz: float, hi_hz: float, peak_s: float) -> PackedFloat32Array:
	var buf := _buffer(seconds)
	for v in voices:
		var fc := _rng.randf_range(lo_hz, hi_hz)
		var a := clampf(TAU * fc * 1.4 / MIX_RATE, 0.0, 1.0)
		var b := clampf(TAU * fc * 0.6 / MIX_RATE, 0.0, 1.0)
		var rate := float(_rng.randi_range(6, 18)) / LOOP_SECONDS
		var ph := _rng.randf_range(0.0, TAU)
		var gain := _rng.randf_range(0.5, 1.0)
		var lp := 0.0
		var lp2 := 0.0
		for i in buf.size():
			var t := float(i) / MIX_RATE
			lp += (_rng.randf_range(-1.0, 1.0) - lp) * a
			lp2 += (lp - lp2) * b
			var syl := pow(0.5 + 0.5 * sin(TAU * rate * t + ph), 2.0)
			buf[i] += (lp - lp2) * syl * gain
	# Two gentle low-passes over the whole crowd: voices, not hiss.
	var c := clampf(TAU * hi_hz * 0.9 / MIX_RATE, 0.0, 1.0)
	var y1 := 0.0
	var y2 := 0.0
	for i in buf.size():
		y1 += (buf[i] - y1) * c
		y2 += (y1 - y2) * c
		buf[i] = y2
	if peak_s >= 0.0:
		for i in buf.size():
			var t := float(i) / MIX_RATE
			buf[i] *= minf(t / peak_s, 1.0) * exp(-maxf(t - peak_s, 0.0) * 2.0)
		return _fade_tail(buf, 0.15)
	return buf


# --- Helpers ------------------------------------------------------------------

static func _buffer(seconds: float) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(int(seconds * MIX_RATE))
	return buf


## Sums layers (each scaled by its gain) into one buffer as long as the longest.
static func _mix(layers: Array[PackedFloat32Array], gains: Array[float]) -> PackedFloat32Array:
	var n := 0
	for l in layers:
		n = maxi(n, l.size())
	var out := PackedFloat32Array()
	out.resize(n)
	for k in layers.size():
		for i in layers[k].size():
			out[i] += layers[k][i] * gains[k]
	return out


## Shifts a sound later by `seconds` (pads the front with silence).
static func _delay(buf: PackedFloat32Array, seconds: float) -> PackedFloat32Array:
	var pad := PackedFloat32Array()
	pad.resize(int(seconds * MIX_RATE))
	pad.append_array(buf)
	return pad


## Linear fade over the last `seconds`, so a tail always ends in silence.
static func _fade_tail(buf: PackedFloat32Array, seconds: float) -> PackedFloat32Array:
	var n := mini(int(seconds * MIX_RATE), buf.size())
	for j in n:
		buf[buf.size() - 1 - j] *= float(j) / n
	return buf


## Converts -1..1 floats into a 16-bit AudioStreamWAV peaking at `level`.
static func to_wav(samples: PackedFloat32Array, level: float) -> AudioStreamWAV:
	var peak := 0.0001
	for s in samples:
		peak = maxf(peak, absf(s))
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i] / peak * level, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav
