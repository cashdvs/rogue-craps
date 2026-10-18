## Procedural sounds for the Bonfire scoring sequence (design:
## bonfire_map_events_juice.md section 3): pip ticks, the mult slam, the
## count-up tick, the combo banner and 4 score-tier stingers. Same recipe
## style as SfxSynth (sines, noise, decays; 22,050 Hz mono 16-bit).
##
## They play through SfxManager like every other event. Hook names and
## parameters are listed in scripts/audio/README.md.
class_name BonfireSynth
extends RefCounted

const MIX_RATE: int = SfxSynth.MIX_RATE

## One-shot events (played with SfxManager.play).
const EVENTS: Array[StringName] = [
	&"score_tick", &"count_tick", &"mult_slam", &"combo_banner",
	&"stinger_ember", &"stinger_flames", &"stinger_inferno", &"stinger_pillar",
]

## Score tier -> stinger: 0 = under 100 (ember sparks), 1 = 100-299 (flames),
## 2 = 300-999 (inferno), 3 = 1000+ (pillar of fire, slow-mo, crowd roar).
## The tier itself comes from game logic (the same tier picks the flame VFX).
const TIER_STINGERS: Array[StringName] = [
	&"stinger_ember", &"stinger_flames", &"stinger_inferno", &"stinger_pillar",
]

## Crowd voices rise and fall in syllables that repeat every LOOP_SECONDS
## (so crowd sounds can be made into seamless loops).
const LOOP_SECONDS: float = 3.0

## Pip ticks climb this scale (semitones above the tick's root note, C5):
## harmonic minor, a little devilish. Tick index 0 is the first die.
const TICK_SCALE: Array[int] = [0, 2, 3, 5, 7, 8, 11, 12, 14, 15, 17, 19]

## Peak level per sound (0..1): stingers lead, ticks sit under.
const LEVELS: Dictionary[StringName, float] = {
	&"score_tick": 0.6, &"count_tick": 0.35, &"mult_slam": 0.9, &"combo_banner": 0.45,
	&"stinger_ember": 0.6, &"stinger_flames": 0.72, &"stinger_inferno": 0.85, &"stinger_pillar": 0.9,
}

static var _rng := RandomNumberGenerator.new()


## Pitch for pip tick number `index` (0, 1, 2, ...) of the current pot. Pass
## it to SfxManager.play with pitch_jitter 0 so the scale stays in tune; start
## again at index 0 for every pot.
static func tick_pitch(index: int) -> float:
	var step := TICK_SCALE[clampi(index, 0, TICK_SCALE.size() - 1)]
	return pow(2.0, step / 12.0)


## Stinger event for a score tier (0-3, see TIER_STINGERS).
static func stinger_for_tier(tier: int) -> StringName:
	return TIER_STINGERS[clampi(tier, 0, TIER_STINGERS.size() - 1)]


static func make(event: StringName) -> AudioStreamWAV:
	_rng.seed = hash(event)
	var s: PackedFloat32Array
	match event:
		&"score_tick":
			s = _pip(0.09, 523.25)
		&"count_tick":
			s = _tick(0.03, 3000.0)
		&"mult_slam":
			s = _mix([_thump(0.45, 60.0, 0.9), _tick(0.08, 2400.0), _flare(0.45, 0.03, 0.3)], [1.0, 0.5, 0.6])
		&"combo_banner":
			s = _flare(0.4, 0.0, 0.12)
		&"stinger_ember":
			s = _mix([_notes(0.35, [783.99, 1174.66], 0.06, 2), _crackle(0.35, 0.004)], [1.0, 0.25])
		&"stinger_flames":
			s = _mix([_notes(0.65, [523.25, 622.25, 783.99], 0.07, 5), _flare(0.65, 0.0, 0.2)], [1.0, 0.35])
		&"stinger_inferno":
			s = _mix([_chord(1.1, [130.81, 196.0, 261.63, 311.13], 6.0), _roar(1.1, 0.25, 0.008), _thump(1.1, 48.0, 0.9)], [0.8, 0.6, 0.8])
		&"stinger_pillar":
			s = _mix([_thump(1.9, 42.0, 1.4), _roar(1.9, 0.45, 0.01), _chord(1.9, [65.41, 130.81, 155.56, 196.0, 261.63], 4.0), _crowd(1.9, 26, 500.0, 2400.0, 0.5)], [0.9, 0.6, 0.6, 0.7])
		_:
			push_error("BonfireSynth: unknown event %s" % event)
			s = PackedFloat32Array([0.0])
	return to_wav(s, LEVELS.get(event, 0.85))


## Every file tools/bake_sfx.gd writes for this synth: {file name: sound}.
static func bake_all() -> Dictionary[String, AudioStreamWAV]:
	var out: Dictionary[String, AudioStreamWAV] = {}
	for event in EVENTS:
		out[String(event) + ".wav"] = make(event)
	return out


# --- Recipes ------------------------------------------------------------------

## A musical bone "pip": a knock click plus a clear tone with an overtone.
static func _pip(seconds: float, hz: float) -> PackedFloat32Array:
	var buf := _buffer(seconds)
	for i in buf.size():
		var t := float(i) / MIX_RATE
		var tone := (sin(TAU * hz * t) + 0.4 * sin(TAU * hz * 2.0 * t) + 0.15 * sin(TAU * hz * 3.01 * t)) * minf(t * 600.0, 1.0) * exp(-t * 32.0)
		var click := _rng.randf_range(-1.0, 1.0) * exp(-t * 300.0)
		buf[i] = tone * 0.7 + click * 0.4
	return _fade_tail(buf, 0.02)


## A short clay/metal tick (the SfxSynth clack, shorter).
static func _tick(seconds: float, hz: float) -> PackedFloat32Array:
	var buf := _buffer(seconds)
	for i in buf.size():
		var t := float(i) / MIX_RATE
		buf[i] = _rng.randf_range(-1.0, 1.0) * exp(-t * 320.0) * 0.7 + (sin(TAU * hz * t) + 0.5 * sin(TAU * hz * 1.47 * t)) * exp(-t * 90.0) * 0.4
	return _fade_tail(buf, 0.005)


## A heavy low hit whose pitch drops (the slam/boom/thud), `decay` seconds-ish.
static func _thump(seconds: float, hz: float, decay: float) -> PackedFloat32Array:
	var buf := _buffer(seconds)
	var phase := 0.0
	for i in buf.size():
		var t := float(i) / MIX_RATE
		phase += TAU * hz * (1.0 + 1.2 * exp(-t * 35.0)) / MIX_RATE
		var click := _rng.randf_range(-1.0, 1.0) * exp(-t * 200.0) * 0.4
		buf[i] = sin(phase) * minf(t * 800.0, 1.0) * exp(-t * 4.0 / decay) + click
	return _fade_tail(buf, 0.05)


## A fire flare / whoosh: low-passed noise whose filter opens and closes,
## peaking at peak_s after start_s.
static func _flare(seconds: float, start_s: float, peak_s: float) -> PackedFloat32Array:
	var buf := _buffer(seconds)
	var lp := 0.0
	for i in buf.size():
		var t := float(i) / MIX_RATE - start_s
		if t < 0.0:
			continue
		var env := minf(t / maxf(peak_s, 0.01), 1.0) * exp(-maxf(t - peak_s, 0.0) * 5.0)
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * (0.04 + 0.3 * env)
		buf[i] = lp * env * 2.0
	return _fade_tail(buf, 0.08)


## Ember crackle: sparse pops, `density` = chance per sample, thinning out.
static func _crackle(seconds: float, density: float) -> PackedFloat32Array:
	var buf := _buffer(seconds)
	for i in buf.size():
		var t := float(i) / MIX_RATE
		if _rng.randf() < density * exp(-t * 2.0):
			buf[i] = _rng.randf_range(-1.0, 1.0)
	for i in range(buf.size() - 1, 0, -1):
		buf[i] = buf[i] * 0.6 + buf[i - 1] * 0.4
	return buf


## Rising plucked/brassy notes `gap` seconds apart; `harmonics` = how brassy.
static func _notes(seconds: float, hz: Array, gap: float, harmonics: int) -> PackedFloat32Array:
	var buf := _buffer(seconds)
	for n in hz.size():
		var start := int(n * gap * MIX_RATE)
		var f: float = hz[n]
		for j in range(buf.size() - start):
			var t := float(j) / MIX_RATE
			var tone := 0.0
			for h in range(1, harmonics + 1):
				tone += sin(TAU * f * h * t) / (h * h * 0.6 + 0.4)
			buf[start + j] += tone * minf(t * 200.0, 1.0) * exp(-t * (5.0 if n == hz.size() - 1 else 9.0)) * 0.3
	return _fade_tail(buf, 0.06)


## A dark brass chord stab with slow tremolo (detuned sawtooth-ish voices).
static func _chord(seconds: float, hz: Array, decay: float) -> PackedFloat32Array:
	var buf := _buffer(seconds)
	for i in buf.size():
		var t := float(i) / MIX_RATE
		var v := 0.0
		for f: float in hz:
			for h in range(1, 6):
				v += (sin(TAU * f * h * t) + sin(TAU * f * 1.004 * h * t)) / (h * 1.6)
		var env := minf(t * 60.0, 1.0) * exp(-t * 3.0 / decay * 2.0) * (0.85 + 0.15 * sin(TAU * 5.5 * t))
		buf[i] = v * env / hz.size()
	return _fade_tail(buf, 0.2)


## A fire roar: rumbling low-passed noise with crackle. peak_s < 0 = steady;
## otherwise it swells to peak_s and dies away.
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
## loudness rises and falls in syllables. Syllable rates are whole cycles per
## LOOP_SECONDS, so a steady crowd can loop cleanly. peak_s >= 0 makes it a
## one-shot roar that swells to peak_s; < 0 keeps it steady.
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
