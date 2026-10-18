## Procedural sounds for the Tiny Anvil Games boot splash: a little
## anvil-forge sting with a toon-noir edge (a dark low "boom" under a bright
## clang). Same recipe style as SfxSynth: sines, noise bursts and decays into
## 16-bit mono PCM at 22,050 Hz.
##
## The splash (scripts/splash/studio_splash.gd) plays
## res://audio/sfx/<event>.wav at each cue time listed in
## assets/branding/studio/splash_timings.json, so bake_all() lists one file
## per cue. We ship the per-cue files, not one pre-mixed studio_splash.wav:
## the splash uses either the per-cue sounds or the single sting, and the
## per-cue files win, so a sting next to them would never play. Per-cue also
## gives reduced motion its own clang + whoosh at -6 dB.
class_name SplashSynth
extends RefCounted

const MIX_RATE: int = SfxSynth.MIX_RATE

## One event per splash cue (cue time in brackets, from splash_timings.json).
const EVENTS: Array[StringName] = [
	&"splash_anvil_thud",   # 0.40 the anvil lands
	&"splash_hammer_swish", # 0.52 the hammer swings (peak near 0.58)
	&"splash_clang",        # 0.60 impact: the transient is the first sample
	&"splash_sizzle",       # 0.61 sparks, faded out by 1.35
	&"splash_whoosh",       # 0.86 wordmark reveal (peak ~1.05, gone by 1.45)
	&"splash_games_tick",   # 1.15 GAMES lands, very soft
	&"splash_twinkle",      # 1.55 the spark twinkles, very quiet
]

## Peak level per event (0..1). The splash plays files at 0 dB, so the mix
## lives in the files: the clang leads, the optional cues sit well under it.
const LEVELS: Dictionary[StringName, float] = {
	&"splash_anvil_thud": 0.28,
	&"splash_hammer_swish": 0.32,
	&"splash_clang": 0.85,
	&"splash_sizzle": 0.22,
	&"splash_whoosh": 0.3,
	&"splash_games_tick": 0.16,
	&"splash_twinkle": 0.12,
}

# Fixed seed per event: the files come out identical on every bake.
static var _rng := RandomNumberGenerator.new()


static func make(event: StringName) -> AudioStreamWAV:
	_rng.seed = hash(event)
	var s: PackedFloat32Array
	match event:
		&"splash_anvil_thud":
			s = _thud(0.35)
		&"splash_hammer_swish":
			s = _swish(0.12, 0.06)
		&"splash_clang":
			s = _clang(0.9)
		&"splash_sizzle":
			s = _sizzle(0.72)
		&"splash_whoosh":
			s = _whoosh(0.58, 0.19)
		&"splash_games_tick":
			s = _tick(0.07)
		&"splash_twinkle":
			s = _twinkle(0.4)
		_:
			push_error("SplashSynth: unknown event %s" % event)
			s = PackedFloat32Array([0.0])
	return to_wav(s, LEVELS.get(event, 0.85))


## Every file tools/bake_sfx.gd writes for this synth: {file name: sound}.
static func bake_all() -> Dictionary[String, AudioStreamWAV]:
	var out: Dictionary[String, AudioStreamWAV] = {}
	for event in EVENTS:
		out[String(event) + ".wav"] = make(event)
	return out


# --- Recipes ------------------------------------------------------------------

## A soft, heavy landing: a low sine that drops in pitch plus a muffled puff.
static func _thud(seconds: float) -> PackedFloat32Array:
	var buf := _buffer(seconds)
	var phase := 0.0
	var lp := 0.0
	for i in buf.size():
		var t := float(i) / MIX_RATE
		phase += TAU * 58.0 * (1.0 + 0.7 * exp(-t * 40.0)) / MIX_RATE
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * 0.05
		buf[i] = sin(phase) * minf(t * 400.0, 1.0) * exp(-t * 14.0) + lp * exp(-t * 30.0) * 0.8
	return _fade_tail(buf, 0.05)


## Air cut by the hammer: band-limited noise sweeping up, peaking at peak_s.
static func _swish(seconds: float, peak_s: float) -> PackedFloat32Array:
	var buf := _buffer(seconds)
	var lp := 0.0
	var lp2 := 0.0
	for i in buf.size():
		var t := float(i) / MIX_RATE
		var k := clampf(t / seconds, 0.0, 1.0)
		var cut := lerpf(0.08, 0.45, k)
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * cut
		lp2 += (lp - lp2) * cut * 0.3
		var env := exp(-pow((t - peak_s) / (seconds * 0.28), 2.0))
		buf[i] = (lp - lp2) * env
	return buf


## The strike. Sample 0 is the transient (a noise crack), then a ring of
## inharmonic anvil partials, each a slightly detuned pair so they shimmer,
## with higher partials dying first. A low 73 Hz "boom" underneath gives it
## the noir weight. The tail is faded out to silence by `seconds` (<= 0.9 s).
static func _clang(seconds: float) -> PackedFloat32Array:
	var buf := _buffer(seconds)
	var partials: Array[float] = [612.0, 1474.0, 2390.0, 3311.0, 4688.0, 6120.0]
	var gains: Array[float] = [0.55, 0.5, 0.42, 0.3, 0.2, 0.12]
	var decays: Array[float] = [4.5, 5.5, 7.0, 9.0, 12.0, 16.0]
	for i in buf.size():
		var t := float(i) / MIX_RATE
		var ring := 0.0
		for p in partials.size():
			var f := partials[p]
			# Detuned pair = slow beating = shimmer.
			ring += (sin(TAU * f * t) + sin(TAU * f * 1.0035 * t + 1.3)) * 0.5 * gains[p] * exp(-t * decays[p])
		var crack := _rng.randf_range(-1.0, 1.0) * exp(-t * 260.0)
		var boom := sin(TAU * 73.0 * t) * exp(-t * 9.0) * 0.6
		buf[i] = crack * 0.9 + ring + boom
	return _fade_tail(buf, 0.25)


## Spark crackle: sparse sharp pops (fewer as it cools) over a thin hiss.
static func _sizzle(seconds: float) -> PackedFloat32Array:
	var buf := _buffer(seconds)
	var hp := 0.0
	var prev := 0.0
	for i in buf.size():
		var t := float(i) / MIX_RATE
		var n := _rng.randf_range(-1.0, 1.0)
		hp = n - prev  # a crude high-pass: the difference of two samples
		prev = n
		var hiss := hp * 0.18 * minf(t * 40.0, 1.0) * exp(-t * 4.5)
		var pop := 0.0
		if _rng.randf() < 0.004 * exp(-t * 3.0):
			pop = _rng.randf_range(0.5, 1.0) * (1.0 if _rng.randf() < 0.5 else -1.0)
		buf[i] = hiss + pop
	# Smear each pop over ~1 ms so they crackle instead of click.
	for i in range(buf.size() - 1, 0, -1):
		buf[i] = buf[i] * 0.6 + buf[i - 1] * 0.4
	return _fade_tail(buf, 0.15)


## A soft airy whoosh: low-passed noise whose filter opens towards peak_s.
static func _whoosh(seconds: float, peak_s: float) -> PackedFloat32Array:
	var buf := _buffer(seconds)
	var lp := 0.0
	for i in buf.size():
		var t := float(i) / MIX_RATE
		# Rise to the peak, then a longer fall (a lopsided bell curve).
		var width := 0.09 if t < peak_s else 0.14
		var env := exp(-pow((t - peak_s) / width, 2.0))
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * (0.03 + 0.12 * env)
		buf[i] = lp * env
	return _fade_tail(buf, 0.06)


## A tiny wooden-metal tick as GAMES lands.
static func _tick(seconds: float) -> PackedFloat32Array:
	var buf := _buffer(seconds)
	for i in buf.size():
		var t := float(i) / MIX_RATE
		var click := _rng.randf_range(-1.0, 1.0) * exp(-t * 400.0)
		var ping := (sin(TAU * 2350.0 * t) + 0.5 * sin(TAU * 3520.0 * t)) * exp(-t * 70.0)
		var body := sin(TAU * 520.0 * t) * exp(-t * 90.0) * 0.5
		buf[i] = click * 0.6 + ping * 0.4 + body
	return buf


## A tiny "tink" for the spark twinkle: two high bell sines, soft attack.
static func _twinkle(seconds: float) -> PackedFloat32Array:
	var buf := _buffer(seconds)
	for i in buf.size():
		var t := float(i) / MIX_RATE
		var env := minf(t * 300.0, 1.0) * exp(-t * 9.0)
		var t2 := maxf(t - 0.07, 0.0)
		var env2 := minf(t2 * 300.0, 1.0) * exp(-t2 * 11.0) * (1.0 if t > 0.07 else 0.0)
		buf[i] = (sin(TAU * 3136.0 * t) + 0.3 * sin(TAU * 6272.0 * t)) * env + sin(TAU * 4186.0 * t) * env2 * 0.6
	return _fade_tail(buf, 0.08)


# --- Helpers ------------------------------------------------------------------

static func _buffer(seconds: float) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(int(seconds * MIX_RATE))
	return buf


## Linear fade over the last `seconds`, so a tail always ends in silence.
static func _fade_tail(buf: PackedFloat32Array, seconds: float) -> PackedFloat32Array:
	var n := mini(int(seconds * MIX_RATE), buf.size())
	for j in n:
		buf[buf.size() - 1 - j] *= float(j) / n
	return buf


## Converts -1..1 floats into a 16-bit AudioStreamWAV that peaks at `level`
## (SfxSynth always peaks at 0.85; splash cues need their own levels).
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
