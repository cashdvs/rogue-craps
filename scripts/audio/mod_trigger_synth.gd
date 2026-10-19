## Procedural trigger cues for face mods and special dice: one short, distinct
## cue per row of the Art Director's trigger FX spec
## (art/concept/special_dice/trigger_fx_spec.md §2), played on top of the score
## count-up when the ability fires (SfxManager.play_mod_trigger). Same recipe
## style as SfxSynth / BonfireSynth (sines, short noise, decays; 22,050 Hz mono).
##
## Mix rules: each cue rings 0.15-0.45 s after its key hit, sits mostly in the
## 1-5 kHz band so it reads over score_tick / count_tick, and peaks at LEVEL,
## 6 dB under the loudest stinger. Tonal cues use the tick scale's notes (C
## harmonic minor), so overlaps stay consonant. No fire on dice (PM): no
## crackle, hiss, burn or whoosh on any cue, Hellfire included.
## The Blood rows (they touch Soul) share the Soul motif (_soul).
class_name ModTriggerSynth
extends RefCounted

const MIX_RATE: int = SfxSynth.MIX_RATE
## Peak level of every cue: 6 dB under stinger_pillar (0.9).
const LEVEL: float = 0.45

enum Tier { MINOR, MAJOR, SIGNATURE }
## Spec row id -> [tier, hit_ms, lead_ms]. The FX starts 2 frames (167 ms)
## before its die's tick; hit_ms is the key-hit frame from that start (12 fps:
## f2 = 167, f3 = 250, f4 = 333). lead_ms is where the transient sits inside
## the baked file (anticipation sound before it), so the hook starts the file
## at hit_ms - lead_ms. Retune hit_ms here; no re-bake needed.
const ROWS: Dictionary[StringName, Array] = {
	# Face mods (spec §2a)
	&"wild_face": [Tier.MINOR, 167, 60], &"ember_pip": [Tier.MINOR, 167, 0],
	&"hellfire_face": [Tier.MAJOR, 250, 0], &"gilded_payout": [Tier.MINOR, 167, 0],
	&"twin_face": [Tier.MINOR, 167, 0], &"step_face": [Tier.MINOR, 167, 120],
	&"stair_face": [Tier.MAJOR, 250, 166], &"kindling_armed": [Tier.MINOR, 167, 0],
	&"kindling_save": [Tier.SIGNATURE, 333, 200], &"blood_face": [Tier.MAJOR, 250, 0],
	# Special dice, batches 1-2 (spec §2b)
	&"twin_flame_pair": [Tier.MINOR, 167, 0], &"coven_set": [Tier.MAJOR, 250, 200],
	&"mirror_copy": [Tier.MAJOR, 250, 210], &"wanderer_gap": [Tier.MAJOR, 250, 120],
	&"bellows_hot": [Tier.MAJOR, 250, 60], &"last_breath": [Tier.SIGNATURE, 333, 300],
	&"blood_pact": [Tier.MAJOR, 250, 0], &"cracked_mult": [Tier.MAJOR, 167, 60],
	&"cracked_shatter": [Tier.SIGNATURE, 250, 0],
	# Not spec rows: any unknown id, and the shared pop (5+ triggers, Instant).
	&"generic": [Tier.MINOR, 167, 0], &"cluster": [Tier.MAJOR, 167, 0],
}
## Second hits (s after the first) of the double-beat rows, baked in one cue.
const SECOND_HIT_S: Dictionary[StringName, float] = {
	&"twin_face": 0.167, &"bellows_hot": 0.167,
}
## Gilded: the coin lands in the ember pile this long after the hit.
const GILDED_PILE_S: float = 0.35
## Mod / special-die ids (and short forms) -> their default row.
const ALIASES: Dictionary[StringName, StringName] = {
	&"wild": &"wild_face", &"hellfire": &"hellfire_face", &"gilded": &"gilded_payout", &"twin": &"twin_face",
	&"step": &"step_face", &"stair": &"stair_face", &"kindling": &"kindling_armed", &"blood": &"blood_face",
	&"twin_flame": &"twin_flame_pair", &"coven": &"coven_set", &"mirror": &"mirror_copy", &"wanderer": &"wanderer_gap",
	&"bellows": &"bellows_hot", &"cracked": &"cracked_mult",
	&"blank": &"no_score",
}
## No cue: passive, confirmed no FX (spec §2a / §2b).
const SILENT: Array[StringName] = [
	&"heavy", &"extra",
]
## Playback level per tier (dB).
const TIER_DB: Array[float] = [-4.0, -2.0, 0.0]
## Start gap between triggers in one pot (spec §1.3, = the pip gap).
const STAGGER_S: float = 0.08
## Live trigger cues at once (= the spec's 4 live bursts); the 5th+ play one cluster.
const MAX_VOICES: int = 4

static var _rng := RandomNumberGenerator.new()


## The row an id plays: a row id, a mod / die id or short form, &"" for a
## silent one, &"no_score" for Blank, &"generic" for anything unknown.
static func row_for(id: StringName) -> StringName:
	if SILENT.has(id):
		return &""
	var row: StringName = ALIASES.get(id, id)
	return row if ROWS.has(row) or row == &"no_score" else &"generic"


## [tier, hit_ms, lead_ms] of a row (Blank's no_score: minor, hit at once).
static func timing(row: StringName) -> Array:
	return ROWS.get(row, [Tier.MINOR, 167, 0])


static func event(row: StringName) -> StringName:
	return row if row == &"no_score" else StringName("trigger_" + String(row))


## Start offset (s) of trigger number k (0, 1, 2 ...) in one pot, in resolve
## order. speed_mode as JuicePlan: 0 = 1x, 1 = 2x, 2 = Instant (all at 0).
static func stagger(k: int, speed_mode: int = 0) -> float:
	return 0.0 if speed_mode >= 2 else k * STAGGER_S * (0.5 if speed_mode == 1 else 1.0)


## Playback volume: the tier's level, then intensity 0..1 trims -9..0 dB.
static func volume_db(tier: int, intensity: float = 1.0) -> float:
	return TIER_DB[clampi(tier, 0, 2)] + lerpf(-9.0, 0.0, clampf(intensity, 0.0, 1.0))


static func bake_all() -> Dictionary[String, AudioStreamWAV]:
	var out: Dictionary[String, AudioStreamWAV] = {}
	for row in ROWS:
		out["trigger_%s.wav" % row] = make(row)
	return out


## Builds a row's cue; its key-hit transient sits at lead_ms. Ring partials
## are [ratio, amp, decay x].
static func make(row: StringName) -> AudioStreamWAV:
	_rng.seed = hash(row)
	var b := _buf(0.3)
	var h := float(timing(row)[2]) / 1000.0  # the hit inside the file
	var h2: float = h + SECOND_HIT_S.get(row, 0.0)
	match row:
		&"wild_face":  # a card-shuffle flick into a short crystalline ting bending up
			b = _buf(0.3)
			for k in 4:
				_click(b, k * 0.016, 0.3 + k * 0.08, 1.0, 900.0)
				_ring(b, k * 0.016, 3135.96 + 300.0 * k, [[1.0, 0.25, 1.0]], 120.0)
			_ring(b, h, 2093.0, [[1.0, 0.8, 1.0], [2.0, 0.3, 1.4], [2.76, 0.2, 1.8]], 16.0, 0.75, 0.05)
		&"ember_pip":  # warm soft pop + a small ember tick
			b = _buf(0.24)
			_thump(b, 0.0, 330.0, 28.0, 0.2)
			_click(b, 0.0, 0.4, 0.2)
			_ring(b, 0.0, 783.99, [[1.0, 0.3, 1.0], [2.0, 0.6, 1.3], [3.0, 0.4, 1.6]], 22.0)
			_ring(b, 0.06, 3951.07, [[1.0, 0.45, 1.0]], 80.0)
			_ring(b, 0.12, 3951.07, [[1.0, 0.2, 1.0]], 80.0)
		&"hellfire_face":  # infernal brass hand-bell clang + a dry bone sting (no fire)
			b = _buf(0.42)
			_click(b, 0.0, 0.8, 1.0, 900.0)
			_ring(b, 0.0, 1975.53, [[1.0, 0.6, 1.0], [2.31, 0.3, 1.5]], 120.0)
			_ring(b, 0.0, 1244.51, [[1.0, 0.6, 1.0], [2.0, 0.35, 1.2], [2.76, 0.4, 1.4], [4.07, 0.25, 1.8], [5.4, 0.15, 2.2]], 7.0)
			_brass(b, 0.0, 0.28, 155.56, 0.012, 24, 0.3, 0.005, 0.5)
		&"gilded_payout":  # bright coin clink + brass shimmer; a tiny chink into the pile later
			b = _buf(0.45)
			_click(b, 0.0, 0.5, 0.9)
			_ring(b, 0.0, 2489.02, [[1.0, 0.8, 1.0], [2.31, 0.45, 1.3], [4.1, 0.2, 1.8]], 16.0)
			_ring(b, 0.01, 1567.98, [[1.0, 0.3, 1.0], [1.27, 0.25, 1.1], [1.71, 0.2, 1.2]], 7.0, 1.0, 0.0, 18.0, 0.6)
			_click(b, GILDED_PILE_S, 0.25, 0.9)
			_ring(b, GILDED_PILE_S, 4186.0, [[1.0, 0.35, 1.0], [1.41, 0.15, 1.3]], 40.0)
		&"twin_face":  # two quick wooden knocks, the second higher
			b = _buf(0.42)
			for k: Array in [[h, 783.99], [h2, 1046.5]]:
				_click(b, k[0], 0.5, 0.4)
				_ring(b, k[0], k[1], [[1.0, 0.8, 1.0], [1.73, 0.4, 1.4], [2.9, 0.2, 1.8]], 45.0)
		&"step_face":  # a soft wooden slide into a click
			b = _buf(0.3)
			_creak(b, 0.0, h, 1046.5, 0.3, 1.4)
			_click(b, h, 0.5, 0.5)
			_ring(b, h, 1396.91, [[1.0, 0.7, 1.0], [2.4, 0.25, 1.5]], 55.0)
		&"stair_face":  # three ascending stone/wood steps, a firm thunk on the last
			b = _buf(0.48)
			for k in 3:
				_click(b, h - 0.083 * (2 - k), 0.4, 0.4)
				_ring(b, h - 0.083 * (2 - k), [1046.5, 1244.51, 1567.98][k], [[1.0, 0.7, 1.0], [2.7, 0.25, 1.5]], 40.0)
			_thump(b, h, 90.0, 18.0, 0.7)
			_ring(b, h, 523.25, [[1.0, 0.4, 1.0], [3.0, 0.3, 1.4]], 25.0)
		&"kindling_armed":  # a dry twig snap + a papery flick
			b = _buf(0.24)
			_click(b, 0.0, 0.9, 0.9, 900.0)
			_ring(b, 0.0, 2349.32, [[1.0, 0.4, 1.0], [1.6, 0.3, 1.2]], 150.0)
			_click(b, 0.016, 0.5, 0.9, 900.0)
			_ring(b, 0.05, 3135.96, [[1.0, 0.15, 1.0]], 60.0)
			_click(b, 0.05, 0.2, 1.0, 300.0)
		&"kindling_save":  # the bust thud reversed into a warm breath, then a wooden knock
			b = _buf(0.62)
			var rev := _buf(h)
			_thump(rev, 0.0, 55.0, 14.0, 0.6)
			_ring(rev, 0.0, 1046.5, [[1.0, 0.3, 1.0], [1.5, 0.25, 1.0]], 10.0)
			rev.reverse()
			for i in rev.size():
				b[i] = rev[i]
			_click(b, h, 0.5, 0.4)
			_ring(b, h, 523.25, [[1.0, 0.5, 1.0], [1.5, 0.4, 1.2], [2.9, 0.3, 1.6]], 30.0)
			_ring(b, h + 0.02, 1046.5, [[1.0, 0.45, 1.0], [1.5, 0.4, 1.0], [2.0, 0.3, 1.3]], 5.0, 1.0, 0.0, 0.0, 0.0, 0.05)
		&"blood_face":  # a wet heartbeat thump-thump + a glassy Soul drip (the Soul motif)
			b = _buf(0.45)
			for at: float in [0.0, 0.16]:
				_thump(b, at, 62.0, 16.0, 0.5)
				_wet(b, at, 0.08, 0.3)
				_ring(b, at, 1244.51, [[1.0, 0.7, 1.0], [2.0, 0.3, 1.3]], 45.0)
			_soul(b, 0.24, 0.5, true)
		&"twin_flame_pair":  # two-note rising chime in a fifth, warm glass; the partner answers 1 frame later
			b = _buf(0.42)
			_ring(b, 0.0, 2093.0, [[1.0, 0.6, 1.0], [1.004, 0.5, 1.0], [2.76, 0.1, 1.6]], 12.0)
			_ring(b, 0.083, 3135.96, [[1.0, 0.6, 1.0], [1.004, 0.5, 1.0]], 9.0)
		&"coven_set":  # three soft hums converge into one low chord + a light bone rattle
			b = _buf(0.5)
			var hum := [[1.0, 0.15, 1.0], [2.0, 0.2, 1.0], [4.0, 0.35, 1.2], [6.0, 0.3, 1.4], [8.0, 0.25, 1.6]]
			for v: Array in [[261.63, 1.06], [311.13, 0.94], [392.0, 1.03]]:
				_ring(b, 0.0, v[0], hum, 2.5, v[1], h, 5.0, 0.15, 0.15)
			for k in 3:
				_click(b, h + k * 0.028, 0.5, 0.6)
				_ring(b, h + k * 0.028, _rng.randf_range(1300.0, 1900.0), [[1.0, 0.7, 1.0]], 110.0)
		&"mirror_copy":  # glass shimmer swelling up through the hop, a soft knock on the copied face, glass tail
			b = _buf(0.5)
			var sw := _buf(h)
			_ring(sw, 0.0, 2093.0, [[1.0, 0.6, 1.0], [1.5, 0.5, 1.2], [2.0, 0.3, 1.5]], 12.0, 1.0, 0.0, 24.0, 0.5)
			sw.reverse()
			for i in sw.size():
				b[i] = sw[i] * 0.8
			_click(b, h, 0.5, 0.3)
			_ring(b, h, 1174.66, [[1.0, 0.6, 1.0], [2.7, 0.2, 1.5]], 50.0)
			_ring(b, h, 3135.96, [[1.0, 0.45, 1.0], [1.335, 0.3, 1.2], [2.0, 0.2, 1.6]], 9.0, 1.0, 0.0, 16.0, 0.4)
		&"wanderer_gap":  # an airy skip (a light whistle glide) + a brass compass ping
			b = _buf(0.45)
			_ring(b, 0.0, 2349.32, [[1.0, 0.25, 1.0]], 2.0, 0.6, h, 0.0, 0.0, h)
			for i in range(int(h * MIX_RATE), b.size()):
				b[i] *= exp(-(float(i) / MIX_RATE - h) * 60.0)
			_click(b, h, 0.4, 0.8)
			_ring(b, h, 1174.66, [[1.0, 0.8, 1.0], [2.76, 0.4, 1.5], [5.4, 0.15, 2.0]], 14.0)
		&"bellows_hot":  # a leathery reed wheeze x2 + a wooden creak between
			b = _buf(0.45)
			for at: float in [h, h2]:
				_brass(b, at - h, h + 0.12, 622.25, 0.006, 8, 0.5, h, 0.6)
			_creak(b, h + 0.1, 0.06, 180.0, 0.3, 2.0)
		&"last_breath":  # a hushed reedy intake, then an 80 ms iron thunk with no ring + a short exhale tail
			b = _buf(0.62)
			_ring(b, 0.0, 1046.5, [[1.0, 0.18, 1.0], [1.5, 0.1, 1.0]], 0.5, 0.5, h, 0.0, 0.0, h)
			for i in range(int(h * MIX_RATE), b.size()):
				b[i] *= exp(-(float(i) / MIX_RATE - h) * 80.0)
			_thump(b, h, 110.0, 45.0, 0.6)  # an 80 ms thunk (spec v0.2)
			_click(b, h, 0.6, 0.3, 400.0)
			_ring(b, h, 587.33, [[1.0, 0.3, 1.0], [2.21, 0.6, 1.0], [3.9, 0.6, 1.2]], 60.0)
			_ring(b, h + 0.06, 1567.98, [[1.0, 0.15, 1.0]], 6.0, 1.0, 0.0, 0.0, 0.0, 0.04)
			for i in range(int((h + 0.06) * MIX_RATE), b.size()):
				var t := float(i) / MIX_RATE - h - 0.06
				b[i] += sin(TAU * lerpf(2093.0, 1046.5, minf(t / 0.25, 1.0)) * t) * 0.3 * exp(-t * 4.0) * minf(t / 0.04, 1.0)
		&"blood_pact":  # a wax-seal stamp thud + cold glass drawn upward (the Soul motif) + soft ticks
			b = _buf(0.42)
			_thump(b, 0.0, 90.0, 20.0, 0.6)
			_wet(b, 0.0, 0.06, 0.25)
			_click(b, 0.0, 0.5, 0.3)
			_ring(b, 0.0, 830.61, [[1.0, 0.4, 1.0], [2.9, 0.3, 1.4]], 40.0)
			_soul(b, 0.05, 0.45, true)
			for k in 3:
				_ring(b, 0.14 + k * 0.05, 2793.83, [[1.0, 0.25, 1.0]], 90.0)
		&"cracked_mult":  # a ceramic stress creak, a stone tick + ceramic ring, discrete grit ticks (no crackle)
			b = _buf(0.36)
			_creak(b, 0.0, h, 1396.91, 0.18, 0.6)
			_click(b, h, 0.8, 0.8, 800.0)
			_ring(b, h, 1661.22, [[1.0, 0.6, 1.0], [2.43, 0.35, 1.3]], 45.0)
			for k in 3:
				_ring(b, h + 0.03 * (k + 1), [3322.44, 3951.07, 3135.96][k], [[1.0, 0.25 - k * 0.05, 1.0]], 110.0)
		&"cracked_shatter":  # a ceramic shatter (shard pings) + a low thud + a dry dust trickle of tiny ticks
			b = _buf(0.45)
			_click(b, 0.0, 1.0, 0.7, 700.0)
			_thump(b, 0.0, 58.0, 12.0, 0.6)
			for k in 6:
				_ring(b, k * 0.014, _rng.randf_range(2500.0, 5000.0), [[1.0, 0.45, 1.0], [1.53, 0.2, 1.3]], 22.0)
			for k in 6:
				_click(b, 0.12 + k * 0.045, 0.18 * (1.0 - k * 0.13), 0.9, 900.0)
		&"cluster":  # the shared pop: a fan of four quick mini chimes over a soft low pop
			b = _buf(0.4)
			_thump(b, 0.0, 150.0, 25.0, 0.2)
			for k in 4:
				_ring(b, k * 0.03, [1046.5, 1244.51, 1567.98, 2093.0][k], [[1.0, 0.4, 1.0], [2.0, 0.3, 1.5]], 7.0)
		_:  # generic, for any other id: a plain bright two-note "ding-ding"
			b = _buf(0.25)
			_ring(b, 0.0, 1046.5, [[1.0, 0.7, 1.0], [3.0, 0.15, 2.0]], 34.0)
			_ring(b, 0.09, 1567.98, [[1.0, 0.7, 1.0], [3.0, 0.15, 2.0]], 24.0)
	return BonfireSynth.to_wav(BonfireSynth._fade_tail(b, 0.02), LEVEL)
# --- Building blocks ----------------------------------------------------------

static func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * MIX_RATE))
	return b


## Adds a ringing tone at `at` s: partials [ratio, amp, decay x] of hz, decaying
## at `decay` per s. Optional: start at bend x hz and glide to hz over bend_s;
## tremolo trem_hz with depth; attack_s fade-in.
static func _ring(b: PackedFloat32Array, at: float, hz: float, partials: Array, decay: float, bend: float = 1.0, bend_s: float = 0.0,
		trem_hz: float = 0.0, depth: float = 0.0, attack_s: float = 0.002) -> void:
	var phase := 0.0
	for i in range(int(at * MIX_RATE), b.size()):
		var t := float(i) / MIX_RATE - at
		var f := hz * (lerpf(bend, 1.0, minf(t / bend_s, 1.0)) if bend_s > 0.0 else 1.0)
		phase += TAU * f / MIX_RATE
		var v := 0.0
		for p: Array in partials:
			v += sin(phase * float(p[0])) * float(p[1]) * exp(-t * decay * float(p[2]))
		b[i] += v * minf(t / attack_s, 1.0) * (1.0 - depth * 0.5 * (1.0 + sin(TAU * trem_hz * t)))


## A low pitch-dropping thump.
static func _thump(b: PackedFloat32Array, at: float, hz: float, decay: float, amp: float) -> void:
	var phase := 0.0
	for i in range(int(at * MIX_RATE), mini(b.size(), int((at + 0.25) * MIX_RATE))):
		var t := float(i) / MIX_RATE - at
		phase += TAU * hz * (1.0 + exp(-t * 40.0)) / MIX_RATE
		b[i] += sin(phase) * amp * minf(t * 900.0, 1.0) * exp(-t * decay)


## A short click: a noise tick (amp), its brightness 0..1 (one-pole high-pass).
static func _click(b: PackedFloat32Array, at: float, amp: float, bright: float, decay: float = 600.0) -> void:
	var lp := 0.0
	for j in int(0.03 * MIX_RATE):
		var i := int(at * MIX_RATE) + j
		if i >= b.size():
			return
		var n := _rng.randf_range(-1.0, 1.0)
		lp += (n - lp) * (1.0 - bright * 0.9)
		b[i] += (n - lp * bright) * amp * exp(-float(j) / MIX_RATE * decay)


## A wet squelch: dark noise with a wobble, over len_s.
static func _wet(b: PackedFloat32Array, at: float, len_s: float, amp: float) -> void:
	var lp := 0.0
	for j in int(len_s * MIX_RATE):
		var t := float(j) / MIX_RATE
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * 0.08
		_add(b, at + t, lp * amp * 3.0 * (1.0 + 0.6 * sin(TAU * 31.0 * t)) * exp(-t * 22.0))


## Brass / reed: harmonics of two detuned saws (growl), swell_s fade-in;
## harmonic h at 1/h^roll (lower roll = brighter, more brassy).
static func _brass(b: PackedFloat32Array, at: float, len_s: float, hz: float, detune: float, harmonics: int, amp: float, swell_s: float = 0.02, roll: float = 1.0) -> void:
	for j in int(len_s * MIX_RATE):
		var t := float(j) / MIX_RATE
		var v := 0.0
		for h in range(1, harmonics + 1):
			v += (sin(TAU * hz * h * t) + sin(TAU * hz * (1.0 + detune) * h * t)) / pow(h, roll)
		_add(b, at + t, v * 0.5 * amp * minf(t / swell_s, 1.0) * minf((len_s - t) / 0.06, 1.0))


## A creak / slide: a tone at hz with fast random wobble (friction), tonal, never noise.
static func _creak(b: PackedFloat32Array, at: float, len_s: float, hz: float, amp: float, wobble: float) -> void:
	var ph := 0.0
	var f := hz
	for j in int(len_s * MIX_RATE):
		var t := float(j) / MIX_RATE
		if j % 220 == 0:
			f = hz * (1.0 + _rng.randf_range(-0.04, 0.04) * wobble)
		ph += TAU * f / MIX_RATE
		var env := sin(PI * t / len_s)
		_add(b, at + t, (sin(ph) + 0.5 * sin(2.0 * ph) + 0.3 * sin(3.0 * ph)) * amp * env)


## The Soul motif (soul_burn's hollow ring and the flask's drip, an octave
## up): a hollow two-tone ring gliding up (or down) plus a glassy drip blip.
static func _soul(b: PackedFloat32Array, at: float, amp: float, up: bool) -> void:
	_ring(b, at, 1567.98 if up else 1046.5, [[1.0, 0.6, 1.0], [1.5, 0.4, 1.2]], 9.0, 0.667 if up else 1.5, 0.12)
	for j in int(0.08 * MIX_RATE):
		var t := float(j) / MIX_RATE
		_add(b, at + 0.1 + t, sin(TAU * (1400.0 + 1800.0 * minf(t / 0.025, 1.0)) * t) * exp(-t * 60.0) * amp * 0.8)


static func _add(b: PackedFloat32Array, t: float, v: float) -> void:
	var i := int(t * MIX_RATE)
	if i < b.size():
		b[i] += v
