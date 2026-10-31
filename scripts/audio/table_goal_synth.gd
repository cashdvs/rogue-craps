## Procedural stings for table goals (table_goals_v1): the moment the banked
## points reach the table's target, and the moment a table runs out of hands
## short of it (a miss costs goal.miss_soul, 5 Soul on main). Same recipe
## style as SfxSynth: sines, noise and decays into 16-bit mono PCM at
## 22,050 Hz, fixed seeds, no loops.
##
## - table_goal_reached: three bone-bell notes climbing A minor (A4 C5 E5)
##   that land on a held A5 + E6 bell over a soft wooden knock. Bright but
##   still in the game's minor key. 1.1 s.
## - table_goal_missed: the Soul motif turned around. soul_burn's hollow
##   ring (two sines a fifth apart) glides DOWN instead of up, under a low
##   funeral-bell toll and a breath drawn out of the table. 1.5 s, ominous,
##   no fire crackle (the Soul family is ring and breath).
##
## Played by scripts/fx/table_audio.gd on TableEvents.goal_reached /
## goal_missed when those signals exist (scripts/audio/README.md).
class_name TableGoalSynth
extends RefCounted

const MIX_RATE: int = SfxSynth.MIX_RATE

const EVENTS: Array[StringName] = [&"table_goal_reached", &"table_goal_missed"]

## Peak level per event (0..1); both sit under table_cleared / bust (0.85).
const LEVELS: Dictionary[StringName, float] = {
	&"table_goal_reached": 0.75,
	&"table_goal_missed": 0.72,
}

static var _rng := RandomNumberGenerator.new()


static func make(event: StringName) -> AudioStreamWAV:
	_rng.seed = hash(event)
	var s: PackedFloat32Array
	match event:
		&"table_goal_reached":
			s = _reached()
		&"table_goal_missed":
			s = _missed()
		_:
			push_error("TableGoalSynth: unknown event %s" % event)
			s = PackedFloat32Array([0.0])
	return SplashSynth.to_wav(s, LEVELS.get(event, 0.75))


## Every file tools/bake_sfx.gd writes for this synth: {file name: sound}.
static func bake_all() -> Dictionary[String, AudioStreamWAV]:
	var out: Dictionary[String, AudioStreamWAV] = {}
	for event in EVENTS:
		out[String(event) + ".wav"] = make(event)
	return out


# --- Recipes ------------------------------------------------------------------

static func _buffer(seconds: float) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(int(seconds * MIX_RATE))
	buf.fill(0.0)
	return buf


## Adds a bell partial set at `start` s: fundamental, a bright 2.76x
## partial and a soft octave, each with its own decay.
static func _bell(buf: PackedFloat32Array, start: float, freq: float, amp: float, decay: float) -> void:
	var s0 := int(start * MIX_RATE)
	for j in range(buf.size() - s0):
		var t := float(j) / MIX_RATE
		var att := minf(t * 400.0, 1.0)
		var v := sin(TAU * freq * t) * exp(-t * decay)
		v += sin(TAU * freq * 2.76 * t) * 0.35 * exp(-t * decay * 2.5)
		v += sin(TAU * freq * 2.0 * t) * 0.25 * exp(-t * decay * 1.5)
		buf[s0 + j] += v * att * amp


static func _reached() -> PackedFloat32Array:
	var buf := _buffer(1.1)
	# Wooden knock under the first note.
	for i in int(0.08 * MIX_RATE):
		var t := float(i) / MIX_RATE
		buf[i] += (sin(TAU * 180.0 * t) * 0.6 + _rng.randf_range(-1.0, 1.0) * 0.25) * exp(-t * 60.0)
	# A4, C5, E5 climbing, then A5 + E6 held.
	var notes := [440.0, 523.25, 659.25]
	for n in notes.size():
		_bell(buf, n * 0.09, notes[n], 0.45, 9.0)
	_bell(buf, 0.27, 880.0, 0.55, 3.2)
	_bell(buf, 0.29, 1318.5, 0.22, 4.0)
	# Gentle tail fade so nothing is cut at the end.
	_fade_out(buf, 0.25)
	return buf


static func _missed() -> PackedFloat32Array:
	var buf := _buffer(1.5)
	# Low funeral toll (D2 bell, slow decay) with a thump.
	_bell(buf, 0.0, 73.42, 0.6, 2.2)
	var lp := 0.0
	var phase := 0.0
	for i in buf.size():
		var t := float(i) / MIX_RATE
		var thump := sin(TAU * 55.0 * t) * exp(-t * 14.0) * 0.7
		# The soul ring gliding down (soul_burn glides 520 -> 780 Hz).
		phase += TAU * lerpf(780.0, 390.0, minf(t / 1.1, 1.0)) / MIX_RATE
		var ring := (sin(phase) + sin(phase * 1.5)) * 0.2 * minf(t * 6.0, 1.0) * exp(-t * 1.9)
		# A breath drawn out: low-passed noise that closes as it fades.
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * lerpf(0.2, 0.03, minf(t / 1.2, 1.0))
		var breath := lp * minf(t * 4.0, 1.0) * exp(-t * 2.4) * 1.6
		buf[i] += thump + ring + breath
	_fade_out(buf, 0.3)
	return buf


static func _fade_out(buf: PackedFloat32Array, seconds: float) -> void:
	var n := int(seconds * MIX_RATE)
	for k in n:
		buf[buf.size() - n + k] *= 1.0 - float(k) / n
