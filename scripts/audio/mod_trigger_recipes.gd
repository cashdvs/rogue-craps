## The recipes behind ModTriggerSynth.make: one match arm per cue (the spec
## rows, the flavour layers, generic and cluster) and the building blocks they
## use. Kept apart from mod_trigger_synth.gd (tables, timing, the bake) so each
## file stays small. Ring partials are [ratio, amp, decay x].
class_name ModTriggerRecipes
extends RefCounted

const MIX_RATE: int = SfxSynth.MIX_RATE
## Gilded: the coin lands in the ember pile this long after the hit.
const GILDED_PILE_S: float = 0.35

static var _rng := RandomNumberGenerator.new()


## The raw cue for a row (ModTriggerSynth normalises it): h is its key hit
## inside the file (s), h2 its second hit (double-beat rows, else h).
## Seeded by the row, so every bake is the same.
static func build(row: StringName, h: float, h2: float) -> PackedFloat32Array:
	_rng.seed = hash(row)
	var b := _buf(0.3)
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
		&"caltrop_run":  # a quick run of three iron tinks
			b = _buf(0.3)
			for k in 3:
				_click(b, k * 0.06, 0.5 - k * 0.12, 1.0)
				_ring(b, k * 0.06, [3135.96, 3322.44, 3951.07][k], [[1.0, 0.7 - k * 0.15, 1.0], [1.41, 0.2, 1.3]], 45.0)
		&"coin_heads_copy", &"coin_tails_copy":  # a flick ping, a whirring spin that speeds up, a flat landing ring
			b = _buf(0.6)
			_ring(b, 0.0, 4186.0, [[1.0, 0.5, 1.0]], 45.0)
			_whir(b, 0.02, h - 0.02, 2793.83, 14.0, 40.0, 0.22)
			var land := 2093.0 if row == &"coin_heads_copy" else 1567.98  # tails lands a fourth lower
			_click(b, h, 0.6, 0.7)
			_ring(b, h, land, [[1.0, 0.7, 1.0], [2.31, 0.4, 1.2], [4.1, 0.2, 1.6]], 6.0)
		&"verdict_20_alt":  # the gavel lifts (a short wooden creak), then a wood crack + deep brass hit, a crowd gasp
			_rng.seed = hash(&"verdict_20")  # the v0.1 verdict_20 seed, so the variant is that exact sound
			b = _buf(0.56)
			_ring(b, 0.03, 523.25, [[1.0, 0.12, 1.0], [3.0, 0.08, 1.0]], 4.0, 0.85, 0.09, 0.0, 0.0, 0.08)
			_click(b, h, 1.0, 0.8, 500.0)
			_ring(b, h, 783.99, [[1.0, 0.6, 1.0], [1.73, 0.9, 1.2], [2.9, 0.8, 1.5]], 35.0)
			_brass(b, h, 0.36, 98.0, 0.01, 40, 0.25, 0.005, 0.35)
			_thump(b, h, 55.0, 9.0, 0.2)
			BonfireSynth._rng.seed = hash(&"verdict_20")
			var gasp := BonfireSynth._crowd(0.34, 14, 700.0, 2200.0, 0.1)
			for i in gasp.size():
				b[int((h + 0.08) * MIX_RATE) + i] += gasp[i] * 0.25
		&"knucklebone_level":  # a dry bone clack + an ascending two-note brass "level up" blip
			b = _buf(0.4)
			for k in 2:
				_click(b, k * 0.018, 0.7, 0.8, 900.0)
				_ring(b, k * 0.018, 1396.91 * (1.0 + 0.07 * k), [[1.0, 0.5, 1.0]], 150.0)
			_brass(b, 0.06, 0.08, 783.99, 0.003, 6, 0.35, 0.005, 0.7)
			_brass(b, 0.14, 0.2, 1046.5, 0.003, 5, 0.4, 0.005, 0.7)
		&"coin_alone_heads":  # a flick ping, a short one-turn spin, a bright lucky landing ring + a glint
			b = _buf(0.62)
			_ring(b, 0.0, 4186.0, [[1.0, 0.5, 1.0]], 45.0)
			_whir(b, 0.02, h - 0.02, 3135.96, 18.0, 24.0, 0.3)
			_click(b, h, 0.6, 0.8)
			_ring(b, h, 2489.02, [[1.0, 0.7, 1.0], [2.31, 0.35, 1.2], [4.1, 0.15, 1.6]], 5.0)
			_ring(b, h + 0.16, 3951.07, [[1.0, 0.35, 1.0]], 30.0)
		&"flavor_verdict":  # a small dry wood gavel tap
			b = _buf(0.2)
			_click(b, 0.0, 1.0, 0.8, 500.0)
			_ring(b, 0.0, 783.99, [[1.0, 0.6, 1.0], [1.73, 0.9, 1.2], [2.9, 0.8, 1.5]], 40.0)
		&"flavor_midnight":  # one soft clock tick, just after the bell
			b = _buf(0.2)
			_click(b, 0.1, 0.3, 0.6, 1200.0)
			_ring(b, 0.1, 2793.83, [[1.0, 0.5, 1.0]], 150.0)
		&"flavor_tithe":  # a soft wooden slot-clunk just before the clink
			b = _buf(0.2)
			_click(b, 0.0, 0.5, 0.2)
			_thump(b, 0.0, 180.0, 30.0, 0.4)
			_ring(b, 0.0, 1046.5, [[1.0, 0.5, 1.0], [1.6, 0.35, 1.2]], 60.0)
		&"flavor_keg":  # a hollow wooden-barrel thump on each of the two ticks (no blast)
			b = _buf(0.4)
			for at: float in [0.0, 0.167]:
				_thump(b, at, 120.0, 22.0, 0.35)
				_ring(b, at, 392.0, [[1.0, 0.3, 1.0], [2.3, 0.4, 1.3], [4.1, 0.3, 1.6]], 28.0)
		&"flavor_lantern":  # a faint glass chime under the wild ting
			b = _buf(0.3)
			_ring(b, 0.0, 1661.22, [[1.0, 0.6, 1.0], [2.0, 0.3, 1.3], [3.0, 0.2, 1.6]], 12.0)
		&"cluster":  # the shared pop: a fan of four quick mini chimes over a soft low pop
			b = _buf(0.4)
			_thump(b, 0.0, 150.0, 25.0, 0.2)
			for k in 4:
				_ring(b, k * 0.03, [1046.5, 1244.51, 1567.98, 2093.0][k], [[1.0, 0.4, 1.0], [2.0, 0.3, 1.5]], 7.0)
		_:  # generic, for any other id: a plain bright two-note "ding-ding"
			b = _buf(0.25)
			_ring(b, 0.0, 1046.5, [[1.0, 0.7, 1.0], [3.0, 0.15, 2.0]], 34.0)
			_ring(b, 0.09, 1567.98, [[1.0, 0.7, 1.0], [3.0, 0.15, 2.0]], 24.0)
	return b


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


## A spinning whirr: a tone fluttering at a rate rising from r0 to r1 per s.
static func _whir(b: PackedFloat32Array, at: float, len_s: float, hz: float, r0: float, r1: float, amp: float) -> void:
	var ph := 0.0
	for j in int(len_s * MIX_RATE):
		var t := float(j) / MIX_RATE
		ph += TAU * lerpf(r0, r1, t / len_s) / MIX_RATE
		_add(b, at + t, sin(TAU * hz * t) * (0.5 + 0.5 * sin(ph)) * amp * minf(t / 0.06, 1.0))
