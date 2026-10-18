## Procedural sounds for Bonfire scoring (design: bonfire_map_events_juice.md
## section 3): pip ticks, the mult slam, 4 score-tier stingers, Hot Hand,
## bank, bounty stamp, bust, the Soul flask crack and 3 looping crowd stems.
## Same recipe style as SfxSynth (sines, noise, decays; 22,050 Hz mono 16-bit).
##
## The one-shots go through SfxManager like every other event. The crowd
## stems are loops, so they get their own players: see CrowdLayers. Hook names
## and parameters are listed in scripts/audio/README.md.
class_name BonfireSynth
extends RefCounted

const MIX_RATE: int = SfxSynth.MIX_RATE

## One-shot events (played with SfxManager.play).
const EVENTS: Array[StringName] = [
	&"score_tick", &"count_tick", &"mult_slam", &"combo_banner",
	&"stinger_ember", &"stinger_flames", &"stinger_inferno", &"stinger_pillar",
	&"hot_hand", &"bank", &"bounty_claimed", &"bust", &"soul_flask_crack",
]

## Score tier -> stinger: 0 = under 100 (ember sparks), 1 = 100-299 (flames),
## 2 = 300-999 (inferno), 3 = 1000+ (pillar of fire, slow-mo, crowd roar).
## The tier itself comes from game logic (the same tier picks the flame VFX).
const TIER_STINGERS: Array[StringName] = [
	&"stinger_ember", &"stinger_flames", &"stinger_inferno", &"stinger_pillar",
]

## Looping crowd stems, quietest first (played by CrowdLayers).
const LOOPS: Array[StringName] = [&"crowd_low", &"crowd_mid", &"crowd_high"]
const LOOP_SECONDS: float = 3.0

## Pip ticks climb this scale (semitones above the tick's root note, C5):
## harmonic minor, a little devilish. Tick index 0 is the first die.
const TICK_SCALE: Array[int] = [0, 2, 3, 5, 7, 8, 11, 12, 14, 15, 17, 19]

## Peak level per sound (0..1): stingers lead, ticks and crowd sit under.
const LEVELS: Dictionary[StringName, float] = {
	&"score_tick": 0.6, &"count_tick": 0.35, &"mult_slam": 0.9, &"combo_banner": 0.45,
	&"stinger_ember": 0.6, &"stinger_flames": 0.72, &"stinger_inferno": 0.85, &"stinger_pillar": 0.9,
	&"hot_hand": 0.85, &"bank": 0.8, &"bounty_claimed": 0.75, &"bust": 0.85, &"soul_flask_crack": 0.75,
	&"crowd_low": 0.35, &"crowd_mid": 0.45, &"crowd_high": 0.55,
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
		&"hot_hand":
			s = _mix([_flare(1.3, 0.0, 0.18), _thump(1.3, 80.0, 0.5), _crackle(1.3, 0.01), _crowd(1.3, 24, 500.0, 2200.0, 0.55)], [0.9, 0.7, 0.4, 0.8])
		&"bank":
			s = _bank(0.95)
		&"bounty_claimed":
			s = _stamp(0.3)
		&"bust":
			s = _mix([_snuff(1.0), _delay(_thump(0.72, 50.0, 0.7), 0.28)], [0.8, 1.0])
		&"soul_flask_crack":
			s = _flask(0.85)
		&"crowd_low":
			s = _loop(_crowd(LOOP_SECONDS + 0.3, 14, 280.0, 800.0, -1.0))
		&"crowd_mid":
			s = _loop(_crowd(LOOP_SECONDS + 0.3, 20, 400.0, 1500.0, -1.0))
		&"crowd_high":
			s = _loop(_mix([_crowd(LOOP_SECONDS + 0.3, 24, 500.0, 1800.0, -1.0), _roar(LOOP_SECONDS + 0.3, -1.0, 0.0)], [1.0, 0.5]))
		_:
			push_error("BonfireSynth: unknown event %s" % event)
			s = PackedFloat32Array([0.0])
	var wav := to_wav(s, LEVELS.get(event, 0.85))
	if LOOPS.has(event):
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = s.size()
	return wav


## Every file tools/bake_sfx.gd writes for this synth: {file name: sound}.
static func bake_all() -> Dictionary[String, AudioStreamWAV]:
	var out: Dictionary[String, AudioStreamWAV] = {}
	for event in EVENTS + LOOPS:
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


## The hellish cash register: two mechanism clacks, the drawer sliding out,
## a "ka-ching" bell bent slightly flat, a low infernal hum under it, and
## embers crackling as the points flow.
static func _bank(seconds: float) -> PackedFloat32Array:
	var buf := _buffer(seconds)
	var lp := 0.0
	var hum := 0.0
	for i in buf.size():
		var t := float(i) / MIX_RATE
		var clacks := 0.0
		for at: float in [0.0, 0.055]:
			var u := t - at
			if u >= 0.0:
				clacks += (_rng.randf_range(-1.0, 1.0) * exp(-u * 250.0) + sin(TAU * 1700.0 * u) * exp(-u * 120.0) * 0.5) * 0.6
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * 0.25
		var slide := lp * clampf((t - 0.06) / 0.04, 0.0, 1.0) * exp(-maxf(t - 0.1, 0.0) * 18.0) * 0.6
		var bell := 0.0
		var u2 := t - 0.11
		if u2 >= 0.0:
			var bend := 1.0 - 0.02 * minf(u2 / 0.6, 1.0)
			for p: Array in [[1318.5, 1.0, 4.0], [2637.0, 0.5, 6.0], [3638.0, 0.35, 7.0], [7120.0, 0.15, 12.0], [1980.0, 0.4, 5.0]]:
				bell += sin(TAU * float(p[0]) * bend * u2) * float(p[1]) * exp(-u2 * float(p[2]))
			bell *= minf(u2 * 800.0, 1.0)
		hum += TAU * 55.0 / MIX_RATE
		var growl := (sin(hum) + 0.5 * sin(hum * 2.0) + 0.3 * sin(hum * 3.0)) * minf(t * 6.0, 1.0) * exp(-t * 2.5) * 0.25
		var ember := _rng.randf_range(-1.0, 1.0) * 0.7 if _rng.randf() < 0.003 * minf(t * 4.0, 1.0) else 0.0
		buf[i] = clacks + slide + bell * 0.45 + growl + ember
	return _fade_tail(buf, 0.15)


## A wax-seal stamp: a soft pressed thump, a squishy low-mid squelch and a
## paper slap on top.
static func _stamp(seconds: float) -> PackedFloat32Array:
	var buf := _buffer(seconds)
	var lp := 0.0
	var phase := 0.0
	for i in buf.size():
		var t := float(i) / MIX_RATE
		phase += TAU * 115.0 * (1.0 + 0.6 * exp(-t * 50.0)) / MIX_RATE
		var thump := sin(phase) * minf(t * 500.0, 1.0) * exp(-t * 22.0)
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * 0.12
		var squelch := lp * exp(-t * 28.0) * (1.0 + 0.5 * sin(TAU * 38.0 * t)) * 1.4
		var slap := _rng.randf_range(-1.0, 1.0) * exp(-t * 400.0) * 0.5
		buf[i] = thump + squelch + slap
	return _fade_tail(buf, 0.05)


## Flames snuffed out: a roar whose filter closes and fades over ~0.35 s,
## ending in a soft "fff" puff.
static func _snuff(seconds: float) -> PackedFloat32Array:
	var buf := _buffer(seconds)
	var lp := 0.0
	for i in buf.size():
		var t := float(i) / MIX_RATE
		var k := clampf(t / 0.35, 0.0, 1.0)
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * lerpf(0.4, 0.015, k)
		buf[i] = lp * (1.0 - k * 0.85) * exp(-t * 3.0) * 1.5
	return _fade_tail(buf, 0.2)


## The Soul flask cracking: three glass crackles with a short glassy ring,
## then three drips.
static func _flask(seconds: float) -> PackedFloat32Array:
	var buf := _buffer(seconds)
	for c in 3:
		var at := c * 0.035 + _rng.randf_range(0.0, 0.01)
		var start := int(at * MIX_RATE)
		for j in range(int(0.25 * MIX_RATE)):
			var t := float(j) / MIX_RATE
			var crack := _rng.randf_range(-1.0, 1.0) * exp(-t * 180.0)
			var ring := (sin(TAU * 2637.0 * t) + 0.7 * sin(TAU * 3951.0 * t) + 0.4 * sin(TAU * 5741.0 * t)) * exp(-t * 18.0) * 0.25
			buf[start + j] += (crack + ring) * (1.0 - c * 0.25)
	for at: float in [0.38, 0.56, 0.72]:
		var start := int(at * MIX_RATE)
		for j in range(int(0.08 * MIX_RATE)):
			var t := float(j) / MIX_RATE
			var f := 700.0 + 900.0 * minf(t / 0.025, 1.0)
			buf[start + j] += sin(TAU * f * t) * exp(-t * 60.0) * 0.45
	return _fade_tail(buf, 0.05)


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
