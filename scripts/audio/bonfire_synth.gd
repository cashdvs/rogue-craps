## Procedural sounds for Bonfire scoring (design: bonfire_map_events_juice.md
## section 3): pip ticks, the mult slam, 4 score-tier stingers, Hot Hand,
## bank, bounty stamp, bust and the Soul flask crack. The 3 looping crowd stems
## and the shared buffer helpers live in CrowdStemSynth (the base class).
## Same recipe style as SfxSynth (sines, noise, decays; 22,050 Hz mono 16-bit).
##
## The one-shots go through SfxManager like every other event. The crowd
## stems are loops, so they get their own players: see CrowdLayers. Hook names
## and parameters are listed in scripts/audio/README.md.
##
## Core-loop cues (rev 2, PM Oct 19): hot_hand, bust, bank and bounty_claimed
## are revisions of the first versions (see REVISED); table_cleared and
## no_score are new. Rule: no fire on the dice. Dice sounds (hot_hand,
## no_score) are bone, felt and wood only; fire/ember texture is only on bust
## and in bank's embers.
class_name BonfireSynth
extends CrowdStemSynth

## One-shot events (played with SfxManager.play).
const EVENTS: Array[StringName] = [
	&"score_tick", &"count_tick", &"mult_slam", &"combo_banner",
	&"stinger_ember", &"stinger_flames", &"stinger_inferno", &"stinger_pillar",
	&"hot_hand", &"bank", &"bounty_claimed", &"bust", &"soul_flask_crack",
	&"table_cleared", &"no_score",
]

## Cues revised in rev 2 and what changed (README and SOURCES.md list them too).
const REVISED: Dictionary[StringName, String] = {
	&"hot_hand": "all 5 dice clack back into the hand (bone, felt, wood); was a fire ignition + crowd roar",
	&"bust": "a fizzle/burn: hissing sizzle that dies out, ash puff, low thud at +0.28 s; was a flame snuff",
	&"bank": "register + points flowing as ember tinks into the pile; was register + random ember pops",
	&"bounty_claimed": "a wax CLAIMED stamp: wooden handle knock, wax press, sticky lift; was a soft thump",
}
## New in rev 2.
const ADDED: Array[StringName] = [&"table_cleared", &"no_score"]
## Dice cues: must never carry fire (crackle, hiss, whoosh). Tested.
const DICE_CUES: Array[StringName] = [&"hot_hand", &"no_score"]

## Score tier -> stinger: 0 = under 100 (ember sparks), 1 = 100-299 (flames),
## 2 = 300-999 (inferno), 3 = 1000+ (pillar of fire, slow-mo, crowd roar).
## The tier itself comes from game logic (the same tier picks the flame VFX).
const TIER_STINGERS: Array[StringName] = [
	&"stinger_ember", &"stinger_flames", &"stinger_inferno", &"stinger_pillar",
]

## Pip ticks climb this scale (semitones above the tick's root note, C5):
## harmonic minor, a little devilish. Tick index 0 is the first die.
const TICK_SCALE: Array[int] = [0, 2, 3, 5, 7, 8, 11, 12, 14, 15, 17, 19]

## Peak level per sound (0..1): stingers lead, ticks and crowd sit under.
const LEVELS: Dictionary[StringName, float] = {
	&"score_tick": 0.6, &"count_tick": 0.35, &"mult_slam": 0.9, &"combo_banner": 0.45,
	&"stinger_ember": 0.6, &"stinger_flames": 0.72, &"stinger_inferno": 0.85, &"stinger_pillar": 0.9,
	&"hot_hand": 0.8, &"bank": 0.8, &"bounty_claimed": 0.8, &"bust": 0.85, &"soul_flask_crack": 0.75,
	&"table_cleared": 0.9, &"no_score": 0.45,
	&"crowd_low": 0.2, &"crowd_mid": 0.45, &"crowd_high": 0.55,
}


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
		&"hot_hand":  # rev 2: dice return (no fire)
			s = _dice_return(0.6)
		&"bank":
			s = _bank(0.95)
		&"bounty_claimed":  # rev 2
			s = _stamp(0.4)
		&"bust":  # rev 2: fizzle/burn
			s = _mix([_fizzle(1.0), _delay(_thump(0.72, 50.0, 0.7), 0.28)], [0.9, 1.0])
		&"table_cleared":  # new
			s = _mix([_notes(0.3, [392.0, 493.88, 587.33], 0.06, 4), _delay(_chord(1.1, [261.63, 311.13, 392.0, 523.25, 783.99], 3.0), 0.2), _delay(_thump(0.9, 55.0, 0.9), 0.2), _delay(_bell(1.0, 1567.98), 0.22)], [0.8, 1.0, 0.8, 0.35])
		&"no_score":  # new
			s = _no_score(0.3)
		&"soul_flask_crack":
			s = _flask(0.85)
		&"crowd_low", &"crowd_mid", &"crowd_high":
			s = _stem(event)
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
		buf[i] = clacks + slide + bell * 0.45 + growl
	# rev 2: the points flow into the pile as 9 ember tinks, quick then thinning.
	for k in 9:
		var at := 0.24 + 0.6 * pow(k / 9.0, 1.5)
		_add_tap(buf, at, _rng.randf_range(2600.0, 3600.0), 0.22 * (1.0 - k * 0.07), 160.0, 0.2)
	return _fade_tail(buf, 0.15)


## rev 2: the wax CLAIMED stamp: a wooden handle knock, the stamp pressing
## into thick wax (a low squelch that drops in pitch) with a paper slap, then
## the stamp lifting off with a small sticky "tk".
static func _stamp(seconds: float) -> PackedFloat32Array:
	var buf := _buffer(seconds)
	var lp := 0.0
	var phase := 0.0
	for i in buf.size():
		var t := float(i) / MIX_RATE
		var knock := (sin(TAU * 230.0 * t) + 0.6 * sin(TAU * 365.0 * t)) * exp(-t * 45.0) * 0.5
		phase += TAU * lerpf(150.0, 85.0, minf(t / 0.12, 1.0)) / MIX_RATE
		var press := sin(phase) * minf(t * 400.0, 1.0) * exp(-t * 18.0)
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * 0.1
		var squelch := lp * clampf((t - 0.01) * 60.0, 0.0, 1.0) * exp(-t * 20.0) * 1.6
		var slap := _rng.randf_range(-1.0, 1.0) * exp(-t * 500.0) * 0.45
		buf[i] = knock + press + squelch + slap
	_add_tap(buf, 0.21, 2200.0, 0.25, 260.0, 0.6)
	return _fade_tail(buf, 0.05)


## rev 2 bust: a fizzle/burn. Bright hiss with sizzle pops that dies out and
## darkens over ~0.6 s (the fire going out on the felt), then a soft ash puff.
static func _fizzle(seconds: float) -> PackedFloat32Array:
	var buf := _buffer(seconds)
	var lp := 0.0
	var lp2 := 0.0
	for i in buf.size():
		var t := float(i) / MIX_RATE
		var k := clampf(t / 0.6, 0.0, 1.0)
		var n := _rng.randf_range(-1.0, 1.0)
		lp += (n - lp) * lerpf(0.9, 0.08, k)
		var hiss := (lp - lp2) * (1.0 - k) * (0.7 + 0.3 * sin(TAU * 23.0 * t))
		lp2 += (lp - lp2) * 0.05
		var pop := n * 1.2 if _rng.randf() < 0.004 * (1.0 - k) else 0.0
		var puff := lp2 * clampf((t - 0.3) * 30.0, 0.0, 1.0) * exp(-maxf(t - 0.3, 0.0) * 9.0) * 3.0
		buf[i] = hiss * 1.4 + pop + puff
	return _fade_tail(buf, 0.2)


## rev 2 hot_hand: all 5 dice come back into the hand. Five bone clacks
## landing in the palm (quick, slightly rising), a felt-soft palm catch under
## the first, the cupped hand closing like a wooden knock, two settle ticks.
static func _dice_return(seconds: float) -> PackedFloat32Array:
	var buf := _buffer(seconds)
	var at := 0.0
	for d in 5:
		_add_tap(buf, at, 1000.0 + d * 90.0 + _rng.randf_range(-60.0, 60.0), 0.9 - d * 0.08, 110.0, 0.5)
		at += _rng.randf_range(0.032, 0.048)
	var phase := 0.0
	for i in int(0.25 * MIX_RATE):
		var t := float(i) / MIX_RATE
		phase += TAU * 140.0 * (1.0 + 0.4 * exp(-t * 40.0)) / MIX_RATE
		buf[i] += sin(phase) * minf(t * 900.0, 1.0) * exp(-t * 30.0) * 0.45
		var u := t - (at + 0.03)
		if u >= 0.0:
			buf[i] += (sin(TAU * 260.0 * u) + 0.6 * sin(TAU * 410.0 * u)) * exp(-u * 30.0) * 0.6
	_add_tap(buf, at + 0.12, 1500.0, 0.3, 160.0, 0.3)
	_add_tap(buf, at + 0.17, 1350.0, 0.18, 160.0, 0.3)
	return _fade_tail(buf, 0.05)


## new no_score: a die that doesn't score bounces back on the felt, a dull
## bone tap, then two smaller, lower ones (a soft "nope", no fire).
static func _no_score(seconds: float) -> PackedFloat32Array:
	var buf := _buffer(seconds)
	for b: Array in [[0.0, 760.0, 1.0], [0.1, 690.0, 0.5], [0.165, 640.0, 0.22]]:
		_add_tap(buf, b[0], b[1], b[2], 140.0, 0.15)
	for i in int(0.12 * MIX_RATE):
		var t := float(i) / MIX_RATE
		buf[i] += sin(TAU * 120.0 * t) * minf(t * 900.0, 1.0) * exp(-t * 40.0) * 0.5
	return _fade_tail(buf, 0.04)


## A struck bell partial set (the table_cleared shimmer).
static func _bell(seconds: float, hz: float) -> PackedFloat32Array:
	var buf := _buffer(seconds)
	for i in buf.size():
		var t := float(i) / MIX_RATE
		buf[i] = (sin(TAU * hz * t) + 0.5 * sin(TAU * hz * 2.76 * t) + 0.25 * sin(TAU * hz * 5.4 * t)) * minf(t * 600.0, 1.0) * exp(-t * 4.0)
	return _fade_tail(buf, 0.1)


## Adds one bone/wood tap at `at` s: a short click (bright by `click` 0..1),
## a tone at hz and a duller overtone, decaying at `damp` per second.
static func _add_tap(buf: PackedFloat32Array, at: float, hz: float, amp: float, damp: float, click: float) -> void:
	var start := int(at * MIX_RATE)
	for j in range(int(0.08 * MIX_RATE)):
		if start + j >= buf.size():
			return
		var t := float(j) / MIX_RATE
		var v := _rng.randf_range(-1.0, 1.0) * exp(-t * 400.0) * click
		v += (sin(TAU * hz * t) + 0.35 * sin(TAU * hz * 2.31 * t) * exp(-t * 80.0)) * exp(-t * damp)
		buf[start + j] += v * amp


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
