## Shared base for the Bonfire synth: the 3 looping crowd stems (crowd_low,
## crowd_mid, crowd_high, played by CrowdLayers), their pot-driven gains, and
## the buffer helpers every Bonfire recipe uses. Split out of BonfireSynth to
## keep each file under 400 lines; BonfireSynth extends this, so its recipes
## call these helpers unqualified and share the one seeded _rng (bakes are
## byte-identical to before the split).
class_name CrowdStemSynth
extends RefCounted

const MIX_RATE: int = SfxSynth.MIX_RATE

## Looping crowd stems, quietest first (played by CrowdLayers).
const LOOPS: Array[StringName] = [&"crowd_low", &"crowd_mid", &"crowd_high"]
const LOOP_SECONDS: float = 3.0

static var _rng := RandomNumberGenerator.new()

## Volume (dB) for each crowd stem [low, mid, high] at an unbanked-pot
## fraction (0 = empty pot, 1 = as big as it gets; game logic decides the
## scale). Low murmurs all the time, mid joins from 0.2, the roar from 0.55.
static func crowd_gains_db(pot_fraction: float) -> PackedFloat32Array:
	var f := clampf(pot_fraction, 0.0, 1.0)
	var lin: Array[float] = [0.35 + 0.65 * smoothstep(0.0, 0.3, f), smoothstep(0.2, 0.6, f), smoothstep(0.55, 1.0, f)]
	var out := PackedFloat32Array()
	for a in lin:
		out.append(maxf(linear_to_db(a), -60.0))
	return out


## The crowd stems (rev 2: softer, warmer bed; see README).
static func _stem(event: StringName) -> PackedFloat32Array:
	match event:
		&"crowd_low":  # rev 2: warm C-minor room drone + a few distant voices
			return _loop(_mix([_drone(LOOP_SECONDS + 0.3), _crowd(LOOP_SECONDS + 0.3, 8, 220.0, 600.0, -1.0)], [1.0, 0.3]))
		&"crowd_mid":  # rev 2: fewer voices, darker
			return _loop(_crowd(LOOP_SECONDS + 0.3, 12, 300.0, 1000.0, -1.0))
		_:  # crowd_high, rev 2: darker, less rumble noise under it
			return _loop(_mix([_crowd(LOOP_SECONDS + 0.3, 16, 400.0, 1200.0, -1.0), _roar(LOOP_SECONDS + 0.3, -1.0, 0.0)], [1.0, 0.2]))



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


## A warm room tone: C2, G2, C3 and Eb3 sines (C minor) that swell and
## ebb slowly. Every frequency and LFO rate is a whole number of cycles per
## LOOP_SECONDS, so the loop seam is sample-continuous (no click, no beat).
static func _drone(seconds: float) -> PackedFloat32Array:
	var buf := _buffer(seconds)
	var cycles: Array[int] = [196, 294, 392, 467]  # /3 s = 65.3, 98.0, 130.7, 155.7 Hz
	var amps: Array[float] = [1.0, 0.45, 0.35, 0.22]
	for i in buf.size():
		var t := float(i) / MIX_RATE
		var v := 0.0
		for k in cycles.size():
			var f := cycles[k] / LOOP_SECONDS
			var lfo := 0.75 + 0.25 * sin(TAU * (k + 1) * t / LOOP_SECONDS + k * 1.7)
			v += sin(TAU * f * t) * amps[k] * lfo
		buf[i] = v
	return buf


## A crowd: `voices` band-limited noise voices (each a "person") whose
## loudness rises and falls in syllables. Syllable rates are whole cycles per
## LOOP_SECONDS, so the stems loop cleanly. peak_s >= 0 makes it a one-shot
## roar that swells to peak_s; < 0 keeps it steady.
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


## Turns LOOP_SECONDS + 0.3 s of sound into a seamless LOOP_SECONDS loop by
## crossfading the extra tail over the start.
static func _loop(buf: PackedFloat32Array) -> PackedFloat32Array:
	var n := int(LOOP_SECONDS * MIX_RATE)
	var x := mini(buf.size() - n, int(0.3 * MIX_RATE))
	var out := buf.slice(0, n)
	for i in x:
		var k := float(i) / x
		out[i] = buf[i] * k + buf[n + i] * (1.0 - k)
	return out


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
