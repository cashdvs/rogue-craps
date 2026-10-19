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
## The Blood rows (they touch Soul) share the Soul motif (ModTriggerRecipes._soul).
## Recipes and building blocks: mod_trigger_recipes.gd.
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
	# Batch 3 own rows (spec v0.2 §2c; final rules, nonstandard_dice.md §10). Pre-carved
	# faces reuse a face-mod row plus a flavour layer (FLAVORS).
	&"caltrop_run": [Tier.MINOR, 167, 0], &"ferryman_heads_copy": [Tier.MAJOR, 333, 333],
	&"ferryman_tails_copy": [Tier.MAJOR, 333, 333], &"ferryman_alone_heads": [Tier.MINOR, 250, 200],
	&"knucklebone_level": [Tier.MAJOR, 250, 0],
	# Optional variant kept at the Art Director's request: the v0.1 Verdict 20 cue. No alias
	# points here, so it plays only when called by this id (the default is hellfire_face).
	&"verdict_20_alt": [Tier.SIGNATURE, 250, 120],
	# Not spec rows: any unknown id, and the shared pop (5+ triggers, Instant).
	&"generic": [Tier.MINOR, 167, 0], &"cluster": [Tier.MAJOR, 167, 0],
}
## Second hits (s after the first) of the double-beat rows, baked in one cue.
const SECOND_HIT_S: Dictionary[StringName, float] = {
	&"twin_face": 0.167, &"bellows_hot": 0.167,
}
## Mod / special-die ids (and short forms) -> their default row.
const ALIASES: Dictionary[StringName, StringName] = {
	&"wild": &"wild_face", &"hellfire": &"hellfire_face", &"gilded": &"gilded_payout", &"twin": &"twin_face",
	&"step": &"step_face", &"stair": &"stair_face", &"kindling": &"kindling_armed", &"blood": &"blood_face",
	&"twin_flame": &"twin_flame_pair", &"coven": &"coven_set", &"mirror": &"mirror_copy", &"wanderer": &"wanderer_gap",
	&"bellows": &"bellows_hot", &"cracked": &"cracked_mult",
	&"blank": &"no_score",
	&"caltrop": &"caltrop_run", &"ferryman": &"ferryman_heads_copy",
	&"ferryman_heads": &"ferryman_heads_copy", &"ferryman_tails": &"ferryman_tails_copy", &"ferryman_alone": &"ferryman_alone_heads",
	&"knucklebone": &"knucklebone_level",
	# Pre-carved batch-3 faces reuse the face-mod row (spec v0.2 reuse rule).
	&"lantern": &"wild_face", &"lantern_8": &"wild_face", &"tithe": &"gilded_payout", &"tithe_10": &"gilded_payout",
	&"midnight": &"hellfire_face", &"midnight_12": &"hellfire_face", &"verdict_20": &"hellfire_face",
	&"verdict_1": &"blood_face", &"powder_keg": &"twin_face", &"powder_keg_3": &"twin_face",
}
## No cue: passive, confirmed no FX (spec §2a / §2b).
const SILENT: Array[StringName] = [
	&"heavy", &"extra",
	&"ferryman_alone_tails", &"ferryman_edge",  # a Blank face / a physics re-settle (spec v0.2 §2c)
]
## Flavour layers for the pre-carved batch-3 faces: flavour -> [the row it
## layers on, lead_ms]. One small layer played with that row's cue, its
## transient on the same hit (spec v0.2 §2 reuse rule: <= 1 sound layer, never
## a new beat). Other rows ignore the flavour (Verdict 1's Blood has none).
const FLAVORS: Dictionary[StringName, Array] = {
	&"verdict": [&"hellfire_face", 0], &"midnight": [&"hellfire_face", 0], &"tithe": [&"gilded_payout", 60],
	&"powder_keg": [&"twin_face", 0], &"lantern": [&"wild_face", 0],
}
## Ids that imply a flavour when the game passes none.
const FLAVOR_OF: Dictionary[StringName, StringName] = {
	&"lantern": &"lantern", &"lantern_8": &"lantern", &"tithe": &"tithe", &"tithe_10": &"tithe",
	&"midnight": &"midnight", &"midnight_12": &"midnight", &"verdict_20": &"verdict", &"powder_keg": &"powder_keg", &"powder_keg_3": &"powder_keg",
}
## A flavour layer plays this far under its row's cue.
const FLAVOR_DB: float = -6.0
## Playback level per tier (dB).
const TIER_DB: Array[float] = [-4.0, -2.0, 0.0]
## Start gap between triggers in one pot (spec §1.3, = the pip gap).
const STAGGER_S: float = 0.08
## Live trigger cues at once (= the spec's 4 live bursts); the 5th+ play one cluster.
const MAX_VOICES: int = 4


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


## The SfxManager event (file stem) a row plays: trigger_<row>, or no_score
## for Blank's no_score row.
static func event(row: StringName) -> StringName:
	return row if row == &"no_score" else StringName("trigger_" + String(row))


## Start offset (s) of trigger number k (0, 1, 2 ...) in one pot, in resolve
## order. speed_mode as JuicePlan: 0 = 1x, 1 = 2x, 2 = Instant (all at 0).
static func stagger(k: int, speed_mode: int = 0) -> float:
	return 0.0 if speed_mode >= 2 else k * STAGGER_S * (0.5 if speed_mode == 1 else 1.0)


## Playback volume: the tier's level, then intensity 0..1 trims -9..0 dB.
static func volume_db(tier: int, intensity: float = 1.0) -> float:
	return TIER_DB[clampi(tier, 0, 2)] + lerpf(-9.0, 0.0, clampf(intensity, 0.0, 1.0))


## Every cue file this synth owns, {file name: AudioStreamWAV}: one
## trigger_<row>.wav per ROWS row and one trigger_flavor_<flavour>.wav per
## FLAVORS layer. tools/bake_sfx.gd finds and saves these.
static func bake_all() -> Dictionary[String, AudioStreamWAV]:
	var out: Dictionary[String, AudioStreamWAV] = {}
	for row in ROWS:
		out["trigger_%s.wav" % row] = make(row)
	for fl in FLAVORS:
		out["trigger_flavor_%s.wav" % fl] = make(StringName("flavor_" + fl))
	return out


## Builds a row's cue (recipe: ModTriggerRecipes.build); its key-hit transient
## sits at lead_ms.
static func make(row: StringName) -> AudioStreamWAV:
	var h := float(timing(row)[2]) / 1000.0  # the hit inside the file
	if String(row).begins_with("flavor_"):
		h = FLAVORS[StringName(String(row).substr(7))][1] / 1000.0
	var h2: float = h + SECOND_HIT_S.get(row, 0.0)
	return BonfireSynth.to_wav(BonfireSynth._fade_tail(ModTriggerRecipes.build(row, h, h2), 0.02), LEVEL)
