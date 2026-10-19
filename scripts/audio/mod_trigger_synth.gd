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
	# Not spec rows: any unknown id, and the shared pop (5+ triggers, Instant).
	&"generic": [Tier.MINOR, 167, 0], &"cluster": [Tier.MAJOR, 167, 0],
}
## Second hits (s after the first) of the double-beat rows, baked in one cue.
const SECOND_HIT_S: Dictionary[StringName, float] = {
}
## Mod / special-die ids (and short forms) -> their default row.
const ALIASES: Dictionary[StringName, StringName] = {
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
