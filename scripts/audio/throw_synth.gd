## Throw momentum sounds and the curves that map a throw's speed to them.
## The throw is physical and has almost no UI, so the sound has to tell the
## player how hard they threw: a soft lob is a light cloth swish and a few
## clicks; a hard flick adds a low air whump, a bright tail and a dense rattle.
## Same recipe style as SfxSynth (noise, sines, decays; 22,050 Hz mono 16-bit).
##
## SfxManager.play_throw() and play_impact() use the curves below. They are
## sound tuning, not game numbers: change them here to taste.
class_name ThrowSynth
extends RefCounted

const MIX_RATE: int = SfxSynth.MIX_RATE

## Fwip layers (soft = layer 1 only, medium = 1-2, hard = all 3) and the
## rattle burst for each band.
const FWIP_LAYERS: Array[StringName] = [&"throw_fwip", &"throw_fwip_whump", &"throw_fwip_tail"]
const RATTLES: Array[StringName] = [&"throw_rattle_soft", &"throw_rattle_medium", &"throw_rattle_hard"]
## Bright transient laid over impacts; its level is the impact's brightness.
const CLICK: StringName = &"impact_click"
## Hollow wooden knock laid under backboard hits (the panel behind the leather).
const WOOD: StringName = &"impact_wood"
const EVENTS: Array[StringName] = [
	&"throw_fwip", &"throw_fwip_whump", &"throw_fwip_tail",
	&"throw_rattle_soft", &"throw_rattle_medium", &"throw_rattle_hard", &"impact_click", &"impact_wood",
]

# --- Throw curve: flick speed (px/s) -> intensity 0..1 ---------------------------
## Flicks at or under FLICK_MIN are the softest throw, FLICK_MAX and up the hardest.
const FLICK_MIN_PX_S: float = 700.0
const FLICK_MAX_PX_S: float = 6000.0
## Exponent on the 0..1 speed: under 1 spreads the slow and medium flicks
## further apart (most real flicks are well under the maximum).
const FLICK_CURVE: float = 0.6
## Intensity from which the whump (2 layers) and the bright tail (3) join.
const LAYER_AT: Array[float] = [0.0, 0.34, 0.67]
const THROW_DB: Vector2 = Vector2(-14.0, 0.0)
const THROW_PITCH: Vector2 = Vector2(0.9, 1.15)

# --- Impact curve: relative contact speed (m/s) -> strength 0..1 ----------------
## Silent below IMPACT_FLOOR_MPS; full strength at IMPACT_FULL_MPS. Logged first
## floor hits: soft ~2, medium ~3.5, hard ~5.9 m/s (max 8.3); backboard on
## hard throws 1.5-6.8 (max 8.9). The curve under 1 lifts the soft ~2 m/s hits.
const IMPACT_FLOOR_MPS: float = 0.3
const IMPACT_FULL_MPS: float = 7.0
const IMPACT_CURVE: float = 0.75
const IMPACT_PITCH: Vector2 = Vector2(0.92, 1.12)
## Click level relative to the body (scaled by the kind's brightness): weak
## taps are dull, hard hits bright.
const CLICK_DB: Vector2 = Vector2(-26.0, -3.0)
## Backboard wood layer relative to the body, weak -> hard.
const WOOD_DB: Vector2 = Vector2(-9.0, 0.0)
## One die makes at most one impact sound per IMPACT_MIN_GAP_S.
const IMPACT_MIN_GAP_S: float = 0.04
## Surface -> [takes to play, pitch, dB at the floor, dB at full, brightness
## 0..1, wood layer]. Felt reuses the bone clack pitched down, with a narrow
## -18..-5 dB range and almost no click: dice skimming the felt at 6 m/s should
## patter, not slam. The backboard is the main wall on hard throws: a deep
## leather rim_hit over a hollow wooden knock, not much click.
const KINDS: Dictionary[StringName, Array] = {
	&"felt": [&"dice_hit", 0.72, -18.0, -5.0, 0.15, false],
	&"rail": [&"rim_hit", 1.0, -22.0, 0.0, 0.5, false],
	&"backboard": [&"rim_hit", 0.8, -20.0, 0.0, 0.4, true],
	&"die": [&"dice_hit", 1.25, -24.0, -2.0, 1.0, false],
	&"chip": [&"chip_place", 1.0, -24.0, -2.0, 0.8, false],
	&"puck": [&"chip_place", 0.8, -22.0, 0.0, 0.6, false],
}
## Die material -> pitch. Unknown materials sound like bone.
const MATERIAL_PITCH: Dictionary[StringName, float] = {&"bone": 1.0}

static var _rng := RandomNumberGenerator.new()


## 0..1 intensity of a flick (FLICK_* curve).
static func throw_intensity(flick_speed_px_s: float) -> float:
	var x := clampf((flick_speed_px_s - FLICK_MIN_PX_S) / (FLICK_MAX_PX_S - FLICK_MIN_PX_S), 0.0, 1.0)
	return pow(x, FLICK_CURVE)


## How many fwip layers (1-3) play at this intensity; also the rattle band.
static func throw_layers(intensity: float) -> int:
	var n := 0
	for at in LAYER_AT:
		if intensity >= at:
			n += 1
	return n


## {volume_db, pitch, layers, rattle} for a flick.
static func throw_params(flick_speed_px_s: float) -> Dictionary:
	var k := throw_intensity(flick_speed_px_s)
	var n := throw_layers(k)
	return {"intensity": k, "volume_db": lerpf(THROW_DB.x, THROW_DB.y, k),
		"pitch": lerpf(THROW_PITCH.x, THROW_PITCH.y, k), "layers": n, "rattle": RATTLES[n - 1]}


## 0..1 strength of a contact; negative = under the floor (silent).
static func impact_strength(speed_mps: float) -> float:
	if speed_mps < IMPACT_FLOOR_MPS:
		return -1.0
	var x := clampf((speed_mps - IMPACT_FLOOR_MPS) / (IMPACT_FULL_MPS - IMPACT_FLOOR_MPS), 0.0, 1.0)
	return pow(x, IMPACT_CURVE)


## {event, pitch, volume_db, click_db, wood_db} for a contact, or {} if it's
## silent. wood_db is -INF for kinds without the wood layer.
static func impact_params(kind: StringName, speed_mps: float, material: StringName = &"bone") -> Dictionary:
	var s := impact_strength(speed_mps)
	if s < 0.0:
		return {}
	var k: Array = KINDS.get(kind, KINDS[&"felt"])
	var db := lerpf(float(k[2]), float(k[3]), s)
	var bright := float(k[4])
	return {"event": k[0], "strength": s, "volume_db": db,
		"pitch": lerpf(IMPACT_PITCH.x, IMPACT_PITCH.y, s) * float(k[1]) * MATERIAL_PITCH.get(material, 1.0),
		"click_db": db + lerpf(CLICK_DB.x, CLICK_DB.y, s * bright) - (1.0 - bright) * 12.0,
		"wood_db": db + lerpf(WOOD_DB.x, WOOD_DB.y, s) if k[5] else -INF}


static func make(event: StringName) -> AudioStreamWAV:
	_rng.seed = hash(event)
	match event:
		&"throw_fwip":
			return _wav(_swish(0.2, 900.0, 2600.0, 0.07), 0.5)
		&"throw_fwip_whump":
			return _wav(_whump(0.38, 62.0), 0.85)
		&"throw_fwip_tail":
			return _wav(_tail(0.45, 0.05), 0.42)
		&"throw_rattle_soft":
			return _wav(_rattle(0.22, 5, 1300.0, 2000.0, 0.35), 0.4)
		&"throw_rattle_medium":
			return _wav(_rattle(0.3, 12, 1500.0, 2600.0, 0.6), 0.6)
		&"throw_rattle_hard":
			return _wav(_rattle(0.34, 26, 1700.0, 3400.0, 1.0), 0.8)
		&"impact_click":
			return _wav(_click(0.03, 3300.0), 0.7)
		&"impact_wood":
			return _wav(_wood(0.32, [118.0, 196.0, 331.0, 547.0]), 0.85)
	push_error("ThrowSynth: unknown event %s" % event)
	return _wav(PackedFloat32Array([0.0]), 0.0)


## Every file tools/bake_sfx.gd writes for this synth: {file name: sound}.
static func bake_all() -> Dictionary[String, AudioStreamWAV]:
	var out: Dictionary[String, AudioStreamWAV] = {}
	for event in EVENTS:
		out[String(event) + ".wav"] = make(event)
	return out


# --- Recipes ----------------------------------------------------------------------

## Cloth swish: noise through a band that sweeps up from lo_hz to hi_hz and
## back while the level swells and dies (a sleeve cutting the air).
static func _swish(seconds: float, lo_hz: float, hi_hz: float, peak_s: float) -> PackedFloat32Array:
	var buf := _buffer(seconds)
	var lp := 0.0
	var lp2 := 0.0
	var hp := 0.0
	for i in buf.size():
		var t := float(i) / MIX_RATE
		var env := _swell(t, peak_s, seconds)
		var hz := lerpf(lo_hz, hi_hz, sin(PI * t / seconds))
		# Two low-pass stages (soft, cloth-like top) minus a slow one (no rumble).
		var a := clampf(TAU * hz / MIX_RATE, 0.0, 1.0)
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * a
		lp2 += (lp - lp2) * a
		hp += (lp2 - hp) * clampf(TAU * hz * 0.25 / MIX_RATE, 0.0, 1.0)
		buf[i] = (lp2 - hp) * env
	return buf


## Low air whump: a sine that drops from 1.6x to hz, under low-passed noise
## (a heavy hand moving a lot of air).
static func _whump(seconds: float, hz: float) -> PackedFloat32Array:
	var buf := _buffer(seconds)
	var phase := 0.0
	var lp := 0.0
	for i in buf.size():
		var t := float(i) / MIX_RATE
		var env := _swell(t, 0.06, seconds)
		phase += TAU * hz * (1.0 + 0.6 * exp(-t * 12.0)) / MIX_RATE
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * 0.05
		buf[i] = (sin(phase) * 0.8 + lp * 3.0) * env
	return buf


## Bright tail: high noise (above ~5 kHz) that starts start_s late and slides
## down as it fades, with a faint glassy shimmer (the dice cutting through).
static func _tail(seconds: float, start_s: float) -> PackedFloat32Array:
	var buf := _buffer(seconds)
	var lp := 0.0
	for i in buf.size():
		var t := float(i) / MIX_RATE
		var env := _swell(t - start_s, 0.04, seconds - start_s) if t > start_s else 0.0
		var n := _rng.randf_range(-1.0, 1.0)
		lp += (n - lp) * lerpf(0.75, 0.45, t / seconds)
		buf[i] = ((n - lp) + sin(TAU * 7200.0 * t) * 0.15) * env
	return buf


## Dice rattling out of the hand: `clicks` bone ticks scattered over the
## first 80% (denser near the start). energy 0..1 adds weight to each tick.
static func _rattle(seconds: float, clicks: int, lo_hz: float, hi_hz: float, energy: float) -> PackedFloat32Array:
	var buf := _buffer(seconds)
	var tick_len := int(0.035 * MIX_RATE)
	for c in clicks:
		var at := int(pow(_rng.randf(), 1.6) * seconds * 0.8 * MIX_RATE)
		var hz := _rng.randf_range(lo_hz, hi_hz)
		var amp := _rng.randf_range(0.4, 1.0) * lerpf(0.6, 1.0, energy)
		for j in tick_len:
			if at + j >= buf.size():
				break
			var t := float(j) / MIX_RATE
			var tick := _rng.randf_range(-1.0, 1.0) * exp(-t * 260.0) + sin(TAU * hz * t) * exp(-t * 150.0)
			var body := sin(TAU * hz * 0.31 * t) * exp(-t * 90.0) * energy * 0.5
			buf[at + j] += (tick + body) * amp
	return buf


## A short bright click: high-passed noise and a high ping (the contact edge).
static func _click(seconds: float, hz: float) -> PackedFloat32Array:
	var buf := _buffer(seconds)
	var lp := 0.0
	for i in buf.size():
		var t := float(i) / MIX_RATE
		var n := _rng.randf_range(-1.0, 1.0)
		lp += (n - lp) * 0.35
		buf[i] = ((n - lp) * exp(-t * 300.0) + sin(TAU * hz * t) * exp(-t * 180.0) * 0.5)
	return buf


## Hollow wooden panel knock: a low thump that drops in pitch, a few damped
## panel modes (hz, lower ones ring longer) and a short dull leather slap.
static func _wood(seconds: float, modes: Array) -> PackedFloat32Array:
	var buf := _buffer(seconds)
	var phase := 0.0
	var lp := 0.0
	for i in buf.size():
		var t := float(i) / MIX_RATE
		phase += TAU * 58.0 * (1.0 + 0.7 * exp(-t * 40.0)) / MIX_RATE
		var v := sin(phase) * minf(t * 1500.0, 1.0) * exp(-t * 30.0) * 0.45
		for m in modes.size():
			v += sin(TAU * float(modes[m]) * t + m) * minf(t * 3000.0, 1.0) * exp(-t * (20.0 + 12.0 * m)) * (0.7 - 0.1 * m)
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * 0.2
		buf[i] = v + lp * exp(-t * 110.0) * 1.6
	return buf


# --- Building blocks ---------------------------------------------------------------

static func _buffer(seconds: float) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(int(seconds * MIX_RATE))
	return buf


## Rises to 1 at peak_s (smooth), then falls to 0 at end_s.
static func _swell(t: float, peak_s: float, end_s: float) -> float:
	if t < 0.0 or t >= end_s:
		return 0.0
	if t < peak_s:
		return sin(0.5 * PI * t / peak_s)
	return pow(1.0 - (t - peak_s) / (end_s - peak_s), 2.0)


## Normalizes to `level` peak (0..1) and makes a 16-bit wav.
static func _wav(samples: PackedFloat32Array, level: float) -> AudioStreamWAV:
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
