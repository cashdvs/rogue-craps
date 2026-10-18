## Procedural placeholder sound effects.
##
## Every sound is built from simple math (sine tones, noise bursts, decays)
## into 16-bit mono PCM, wrapped in an AudioStreamWAV. No audio files are
## needed, but tools/bake_sfx.gd can save them as .wav so a sound designer
## can see what to replace. Swap in real recordings later by dropping
## res://audio/sfx/<event>.wav files with the same names (SfxManager prefers
## files on disk over these synthesized ones).
class_name SfxSynth
extends RefCounted

const MIX_RATE: int = 22050

## Names of every sound event the game uses.
const EVENTS: Array[StringName] = [
	&"dice_shake", &"dice_hit", &"dice_settle", &"chip_place",
	&"chip_collect", &"win_big", &"seven_out", &"soul_burn", &"dealer_taunt",
	&"chip_refuse", &"heartbeat", &"tension", &"rim_hit", &"dice_grab", &"dice_drop",
]

# Fixed seed: placeholder sounds come out identical every time.
static var _rng := RandomNumberGenerator.new()


static func make(event: StringName) -> AudioStreamWAV:
	_rng.seed = hash(event)
	var samples: PackedFloat32Array
	match event:
		&"dice_shake":
			samples = _dice_shake()
		&"dice_hit":
			samples = _knock(0.09, 900.0, 180.0, 0.9)
		&"dice_settle":
			samples = _knock(0.16, 520.0, 110.0, 0.8)
		&"chip_place":
			samples = _clack(0.08, 2600.0)
		&"chip_collect":
			samples = _clack(0.12, 3400.0)
		&"win_big":
			samples = _win_big()
		&"seven_out":
			samples = _seven_out()
		&"soul_burn":
			samples = _soul_burn()
		&"dealer_taunt":
			samples = _dealer_taunt()
		&"chip_refuse":
			samples = _knock(0.1, 300.0, 140.0, 0.9)
		&"heartbeat":
			samples = _heartbeat()
		&"tension":
			samples = _tension()
		&"rim_hit":
			samples = _knock(0.14, 380.0, 95.0, 1.0)
		&"dice_grab":
			samples = _clack(0.06, 1800.0)
		&"dice_drop":
			samples = _knock(0.12, 700.0, 150.0, 0.6)
		_:
			push_error("SfxSynth: unknown event %s" % event)
			samples = PackedFloat32Array([0.0])
	return _to_wav(samples)


# --- Building blocks ------------------------------------------------------------

static func _buffer(seconds: float) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(int(seconds * MIX_RATE))
	return buf


## A wooden/bone knock: a noise click plus a quickly falling low tone.
static func _knock(seconds: float, click_hz: float, body_hz: float, gain: float) -> PackedFloat32Array:
	var buf := _buffer(seconds)
	var phase := 0.0
	for i in buf.size():
		var t := float(i) / MIX_RATE
		var env := exp(-t * 38.0)
		var click := _rng.randf_range(-1.0, 1.0) * exp(-t * 160.0)
		var freq := body_hz * (1.0 + 2.0 * exp(-t * 60.0))
		phase += TAU * freq / MIX_RATE
		var body := sin(phase) * env
		var ring := sin(TAU * click_hz * t) * exp(-t * 90.0) * 0.3
		buf[i] = (click * 0.6 + body * 0.8 + ring) * gain
	return buf


## A clay-chip clack: short bright noise plus two inharmonic pings.
static func _clack(seconds: float, ping_hz: float) -> PackedFloat32Array:
	var buf := _buffer(seconds)
	for i in buf.size():
		var t := float(i) / MIX_RATE
		var noise := _rng.randf_range(-1.0, 1.0) * exp(-t * 220.0)
		var ping := (sin(TAU * ping_hz * t) + 0.6 * sin(TAU * ping_hz * 1.47 * t)) * exp(-t * 55.0)
		buf[i] = noise * 0.7 + ping * 0.35
	return buf


## Dice rattling in a cupped hand: a burst of small random clicks.
static func _dice_shake() -> PackedFloat32Array:
	var buf := _buffer(0.45)
	var clicks := 14
	for c in clicks:
		var start := int(_rng.randf_range(0.0, 0.4) * MIX_RATE)
		var hz := _rng.randf_range(1400.0, 2600.0)
		var amp := _rng.randf_range(0.25, 0.6)
		for j in range(int(0.03 * MIX_RATE)):
			var idx := start + j
			if idx >= buf.size():
				break
			var t := float(j) / MIX_RATE
			buf[idx] += (_rng.randf_range(-1.0, 1.0) * 0.6 + sin(TAU * hz * t)) * exp(-t * 180.0) * amp
	return buf


## A bright rising arpeggio with a shimmer tail.
static func _win_big() -> PackedFloat32Array:
	var buf := _buffer(1.1)
	var notes: Array[float] = [392.0, 493.88, 587.33, 783.99, 987.77]  # G major-ish
	for n in notes.size():
		var start := int(n * 0.07 * MIX_RATE)
		for j in range(buf.size() - start):
			var t := float(j) / MIX_RATE
			var env := minf(t * 60.0, 1.0) * exp(-t * 3.2)
			var tone := sin(TAU * notes[n] * t) + 0.35 * sin(TAU * notes[n] * 2.0 * t) + 0.15 * sin(TAU * notes[n] * 3.0 * t)
			buf[start + j] += tone * env * 0.22
	# Coin-shimmer sparkle on top.
	for i in buf.size():
		var t := float(i) / MIX_RATE
		buf[i] += _rng.randf_range(-1.0, 1.0) * 0.05 * exp(-t * 2.0) * (0.5 + 0.5 * sin(TAU * 23.0 * t))
	return buf


## A sad, sinking "wah": a falling detuned tone with a dull thud.
static func _seven_out() -> PackedFloat32Array:
	var buf := _buffer(1.2)
	var p1 := 0.0
	var p2 := 0.0
	for i in buf.size():
		var t := float(i) / MIX_RATE
		var freq := lerpf(220.0, 70.0, minf(t / 1.0, 1.0))
		p1 += TAU * freq / MIX_RATE
		p2 += TAU * freq * 1.012 / MIX_RATE
		var env := minf(t * 20.0, 1.0) * exp(-t * 1.8)
		var tone := (sin(p1) + 0.5 * signf(sin(p2)) * 0.5) * env
		var thud := sin(TAU * 55.0 * t) * exp(-t * 14.0)
		buf[i] = tone * 0.35 + thud * 0.5
	return buf


## Soul burning: a breathy flame whoosh that rises, crackles, and ends in
## a hollow glassy ring (the piece of soul tearing away).
static func _soul_burn() -> PackedFloat32Array:
	var buf := _buffer(0.9)
	var lp := 0.0
	var phase := 0.0
	for i in buf.size():
		var t := float(i) / MIX_RATE
		# Low-passed noise whoosh; the filter opens as it rises.
		var cutoff := lerpf(0.04, 0.35, minf(t / 0.35, 1.0))
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * cutoff
		var whoosh := lp * minf(t * 12.0, 1.0) * exp(-t * 3.5) * 2.2
		# Crackle: sparse sharp pops.
		var crackle := 0.0
		if _rng.randf() < 0.012 * exp(-t * 2.0):
			crackle = _rng.randf_range(-1.0, 1.0)
		# Hollow ring (two detuned sines, gliding up).
		phase += TAU * lerpf(520.0, 780.0, minf(t / 0.6, 1.0)) / MIX_RATE
		var ring := (sin(phase) + sin(phase * 1.5)) * 0.18 * minf(t * 8.0, 1.0) * exp(-t * 4.0)
		# Thump at the start.
		var thump := sin(TAU * 70.0 * t) * exp(-t * 18.0) * 0.8
		buf[i] = whoosh + crackle * 0.6 + ring + thump
	return buf


## The Dealer's "heh-heh": three low, nasal, falling vowel blips.
static func _dealer_taunt() -> PackedFloat32Array:
	var buf := _buffer(0.6)
	for n in 3:
		var start := int(n * 0.16 * MIX_RATE)
		var f0 := 150.0 - n * 18.0
		var phase := 0.0
		for j in range(int(0.14 * MIX_RATE)):
			var idx := start + j
			if idx >= buf.size():
				break
			var t := float(j) / MIX_RATE
			phase += TAU * f0 * (1.0 - t * 1.5) / MIX_RATE
			# A buzzy pulse wave shaped by a vowel-like formant (two resonances).
			var pulse := 1.0 if fmod(phase, TAU) < 0.9 else -0.25
			var formant := sin(TAU * 700.0 * t) * 0.5 + sin(TAU * 1150.0 * t) * 0.3
			var env := minf(t * 80.0, 1.0) * exp(-t * 14.0)
			buf[idx] += pulse * (0.6 + formant) * env * 0.5
	return buf


## Two low thumps: lub-dub.
static func _heartbeat() -> PackedFloat32Array:
	var buf := _buffer(0.5)
	for i in buf.size():
		var t := float(i) / MIX_RATE
		var a := sin(TAU * 55.0 * t) * exp(-t * 22.0)
		var t2 := t - 0.18
		var b := 0.0
		if t2 > 0.0:
			b = sin(TAU * 48.0 * t2) * exp(-t2 * 20.0) * 0.7
		buf[i] = a + b
	return buf


## A quiet, uneasy pad: two detuned low sines swelling and fading.
static func _tension() -> PackedFloat32Array:
	var buf := _buffer(1.2)
	for i in buf.size():
		var t := float(i) / MIX_RATE
		var env := sin(PI * t / 1.2)
		buf[i] = (sin(TAU * 110.0 * t) + sin(TAU * 116.5 * t) * 0.8 + sin(TAU * 164.8 * t) * 0.3) * env * 0.4
	return buf


## Converts -1..1 floats into a 16-bit AudioStreamWAV.
static func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	# Normalize so every placeholder peaks at the same level.
	var peak := 0.0001
	for s in samples:
		peak = maxf(peak, absf(s))
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i] / peak * 0.85, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav
