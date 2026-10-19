## Plays named sound events on the "SFX" audio bus.
##
## Usage: sfx.play(&"dice_hit")   or   sfx.play(&"chip_collect", 1.2, -3.0)
##
## Sounds are looked up by event name. If res://audio/sfx/<event>.wav exists
## it is used; otherwise SfxSynth builds a placeholder. A small pool of
## players lets several sounds overlap (lots of chips clacking at once).
##
## Variants: if res://audio/sfx/<event>_01.wav, _02.wav, ... exist, each play
## picks one of them at random, never the same take twice in a row (repeated
## hits sound robotic otherwise). They load the first time the event plays.
## Order of preference: variant files, then the single <event>.wav, then
## SfxSynth's variants, then SfxSynth's single sound.
class_name SfxManager
extends Node

const BUS_NAME: StringName = &"SFX"
const POOL_SIZE: int = 12
const SFX_DIR: String = "res://audio/sfx/"
## Highest take number looked for on disk (<event>_01 .. _99).
const MAX_VARIANTS: int = 99

## Emitted every time an event is played (handy for tests and debugging).
signal played(event: StringName)

var _streams: Dictionary[StringName, AudioStream] = {}
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
# Cosmetic only (pitch jitter, which take plays), so it isn't seeded.
var _rng := RandomNumberGenerator.new()
# event -> its takes (Array of AudioStream); empty = no takes. Filled lazily.
var _variants: Dictionary[StringName, Array] = {}
# event -> index of the take played last, so the next pick can avoid it.
var _last_variant: Dictionary[StringName, int] = {}
# die id -> time of its last impact sound (per-die rate limit).
var _last_impact: Dictionary[int, float] = {}
## Tests: a fixed clock in seconds for play_impact's rate limit (-1 = game clock).
var impact_clock: float = -1.0
# Game clock for the rate limit: process time, so it follows Engine.time_scale
# (slow-mo) and fixed-fps recordings the way the table's contacts do.
var _game_time: float = 0.0
## Mod trigger cues: the FX speed (JuicePlan): 0 = 1x, 1 = 2x, 2 = Instant.
var trigger_speed_mode: int = 0
# Trigger cues play on their own small pool, so the count-up's ticks never steal them.
var _trigger_players: Array[AudioStreamPlayer] = []
# Game times each live or scheduled trigger cue ends (the voice cap counts these).
var _trigger_ends: Array[float] = []
# Scheduled cues: [game time, row, pitch, volume_db, start offset].
var _trigger_queue: Array[Array] = []
var _cluster_until: float = -1.0
var _instant_frame: int = -1
## Optional: the table's crowd. Set it once (sfx.crowd = crowd) and every
## SIGNATURE trigger nudges it on its hit (+3 dB, back over 0.3 s, spec §4.6).
var crowd: CrowdLayers
## Rows that play once while one is still sounding (spec §2b: extra Bellows
## play the effect once, on the first Bellows in resolve order).
const ONCE_ROWS: Array[StringName] = [&"bellows_hot"]
# Same-moment triggers (one resolve step) are staggered here: the game time of the
# current burst and how many it has had.
var _burst_time: float = -1.0
var _burst_k: int = 0
# Once-rows: game time each one's cue ends.
var _once_until: Dictionary[StringName, float] = {}


func _ready() -> void:
	_ensure_bus()
	for event in SfxSynth.EVENTS + BonfireSynth.EVENTS:
		_streams[event] = _load_stream(event)
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = BUS_NAME
		add_child(player)
		_players.append(player)
	_add_throw_events()


func _process(delta: float) -> void:
	_game_time += delta
	_run_trigger_queue()


## Plays an event. pitch: 1.0 = normal. pitch_jitter adds a little random
## variation so repeated sounds (chips!) don't sound robotic.
func play(event: StringName, pitch: float = 1.0, volume_db: float = 0.0, pitch_jitter: float = 0.06) -> void:
	if not _streams.has(event):
		push_warning("SfxManager: no sound for event '%s'." % event)
		return
	# Prefer a player that's free, so a quick burst (5 dice landing) doesn't
	# cut off a longer sound still ringing (the throw tail); when every player
	# is busy, the oldest one in turn is reused.
	var idx := _next
	for k in _players.size():
		if not _players[(_next + k) % _players.size()].playing:
			idx = (_next + k) % _players.size()
			break
	var player := _players[idx]
	_next = (idx + 1) % _players.size()
	var takes := _get_variants(event)
	player.stream = _streams[event] if takes.is_empty() else takes[pick_variant(event)] as AudioStream
	player.pitch_scale = maxf(0.05, pitch + _rng.randf_range(-pitch_jitter, pitch_jitter))
	player.volume_db = volume_db
	player.play()
	played.emit(event)


## A throw leaves the hand: plays the fwip layers and the rattle burst, all
## scaled by the flick speed (ThrowSynth curve). Returns the 0..1 intensity.
## Soft: cloth swish + a few clicks at about -14 dB. Hard: + air whump +
## bright tail + dense rattle at about 0 dB, pitched up to 1.15.
func play_throw(flick_speed_px_s: float) -> float:
	var p := ThrowSynth.throw_params(flick_speed_px_s)
	for n in int(p["layers"]):
		play(ThrowSynth.FWIP_LAYERS[n], p["pitch"], p["volume_db"], 0.03)
	play(p["rattle"], p["pitch"], p["volume_db"] - 2.0, 0.04)
	return p["intensity"]


## A die hit something: kind = felt / rail / backboard / die / chip / puck,
## speed_mps = relative contact speed. Under 0.3 m/s it's silent; faster
## hits are louder, higher and brighter (more impact_click). Takes rotate
## (dice_hit / rim_hit / chip_place variants); backboard hits add a wooden
## knock (impact_wood). die_id >= 0 limits that die to
## one sound per ThrowSynth.IMPACT_MIN_GAP_S. Returns true if it played.
func play_impact(kind: StringName, speed_mps: float, material: StringName = &"bone", die_id: int = -1) -> bool:
	var p := ThrowSynth.impact_params(kind, speed_mps, material)
	if p.is_empty():
		return false
	var now := _game_time if impact_clock < 0.0 else impact_clock
	if die_id >= 0:
		if now - float(_last_impact.get(die_id, -1e9)) < ThrowSynth.IMPACT_MIN_GAP_S:
			return false
		_last_impact[die_id] = now
	play(p["event"], p["pitch"], p["volume_db"], 0.03)
	if p["click_db"] > -40.0:
		play(ThrowSynth.CLICK, p["pitch"] * 1.1, p["click_db"], 0.05)
	if p["wood_db"] > -40.0:
		play(ThrowSynth.WOOD, 0.95 + 0.1 * float(p["strength"]), p["wood_db"], 0.04)
	return true


func has_event(event: StringName) -> bool:
	return _streams.has(event)


## A face mod or special die fired (its trigger FX starts now). id: a spec row
## (&"coin_heads_copy"), a mod / die id (&"mirror") or a short form; unknown
## ids play trigger_generic, Heavy / Extra play nothing.
## tier -1 = the row's (ModTriggerSynth.Tier); intensity 0..1 trims -9..0 dB;
## hit_ms -1 = the row's hit frame. The cue's transient lands on the hit.
## Returns the seconds until the hit, or -1 if nothing plays (silent, capped,
## an extra Bellows). Call it once per trigger, in resolve order, at FX start:
## triggers called at the same moment are staggered here (k * 0.08 s, halved at
## 2x; the return value includes it), so callers add no timers of their own.
## The hook also owns the voice cap, the shared cluster, the speed modes and
## the crowd nudge.
## flavor: a pre-carved batch-3 face's layer (ctx.flavor: &"verdict", &"midnight",
## &"tithe", &"keg", &"lantern"); &"" = the one its id implies, if any.
func play_mod_trigger(id: StringName, tier: int = -1, intensity: float = 1.0, hit_ms: float = -1.0, flavor: StringName = &"") -> float:
	var row := ModTriggerSynth.row_for(id)
	var t := ModTriggerSynth.timing(row)
	var tier_i := int(t[0]) if tier < 0 else tier
	var vol := ModTriggerSynth.volume_db(tier_i, intensity)
	if row == &"":
		return -1.0
	if row == &"no_score":  # Blank: the existing soft bounce, right away
		play(row, 1.0, vol)
		return 0.0
	var now := _game_time
	if ONCE_ROWS.has(row) and float(_once_until.get(row, -1.0)) > now:
		return -1.0
	if trigger_speed_mode >= 2:  # Instant: one shared pop per frame, no stagger
		if _instant_frame == Engine.get_process_frames():
			return -1.0
		_instant_frame = Engine.get_process_frames()
		_schedule_trigger(&"cluster", 0.0, 1.0, vol)
		_once_until[row] = now + _trigger_stream(&"cluster").get_length()
		return 0.0
	if is_equal_approx(_burst_time, now):
		_burst_k += 1
	else:
		_burst_time = now
		_burst_k = 0
	var fast := trigger_speed_mode == 1  # 2x: the FX hit comes twice as soon
	var pitch := 1.12 if fast else 1.0
	var hit_s := ModTriggerSynth.stagger(_burst_k, trigger_speed_mode) + (float(t[1]) if hit_ms < 0.0 else hit_ms) / 1000.0 / (2.0 if fast else 1.0)
	_trigger_ends = _trigger_ends.filter(func(e: float) -> bool: return e > now)
	var capped := _trigger_ends.size() >= ModTriggerSynth.MAX_VOICES
	if capped and _cluster_until > now:
		return -1.0
	if tier_i == ModTriggerSynth.Tier.SIGNATURE and crowd != null:
		_schedule_trigger(&"", hit_s, 1.0, 0.0)  # the crowd nudge, on the hit
	if capped:
		_cluster_until = now + hit_s + _trigger_stream(&"cluster").get_length()
		_once_until[row] = _cluster_until
		_schedule_trigger(&"cluster", hit_s, 1.0, vol)
		return hit_s
	var start := hit_s - float(t[2]) / 1000.0 / pitch
	_trigger_ends.append(now + start + _trigger_stream(row).get_length() / pitch)
	_once_until[row] = _trigger_ends.back()
	_schedule_trigger(row, start, pitch, vol + (-2.0 if fast else 0.0))
	var fl: StringName = flavor if flavor != &"" else ModTriggerSynth.FLAVOR_OF.get(id, &"")
	if ModTriggerSynth.FLAVORS.has(fl) and ModTriggerSynth.FLAVORS[fl][0] == row:  # the face's layer, on the same hit
		var layer := StringName("flavor_" + fl)
		_schedule_trigger(layer, hit_s - float(ModTriggerSynth.FLAVORS[fl][1]) / 1000.0 / pitch, pitch, vol + ModTriggerSynth.FLAVOR_DB + (-2.0 if fast else 0.0))
	return hit_s


func _schedule_trigger(row: StringName, delay: float, pitch: float, vol: float) -> void:
	if delay > 0.0:
		_trigger_queue.append([_game_time + delay, row, pitch, vol, 0.0])
	else:  # already late: start now, skipping into the cue so the hit still lands on time
		_play_trigger(row, pitch, vol, -delay * pitch)


func _run_trigger_queue() -> void:
	while not _trigger_queue.is_empty():
		var k := _trigger_queue.find_custom(func(q: Array) -> bool: return q[0] <= _game_time)
		if k < 0:
			return
		var q: Array = _trigger_queue.pop_at(k)
		_play_trigger(q[1], q[2], q[3], q[4])


func _play_trigger(row: StringName, pitch: float, vol: float, from_s: float) -> void:
	if row == &"":  # a scheduled crowd nudge
		if crowd != null:
			crowd.nudge()
		return
	if _trigger_players.is_empty():
		for i in ModTriggerSynth.MAX_VOICES * 2:  # room for the cluster (and flavour layers)
			var p := AudioStreamPlayer.new()
			p.bus = BUS_NAME
			add_child(p)
			_trigger_players.append(p)
	var player: AudioStreamPlayer = _trigger_players[0]
	for p in _trigger_players:
		if not p.playing:
			player = p
			break
	_trigger_players.erase(player)
	_trigger_players.append(player)  # the oldest is reused first if all are busy
	player.stream = _trigger_stream(row)
	player.pitch_scale = pitch
	player.volume_db = vol
	player.play(from_s)
	played.emit(ModTriggerSynth.event(row))


func _trigger_stream(row: StringName) -> AudioStream:
	var event := ModTriggerSynth.event(row)
	if not _streams.has(event):
		var path := SFX_DIR + String(event) + ".wav"
		_streams[event] = load(path) as AudioStream if ResourceLoader.exists(path) else ModTriggerSynth.make(row)
	return _streams[event]


## How many takes this event rotates through (0 = it has a single sound).
func variant_count(event: StringName) -> int:
	return _get_variants(event).size()


## Picks the index of the next take: random, but never the one played last.
func pick_variant(event: StringName) -> int:
	var count := variant_count(event)
	if count <= 1:
		return 0
	var last: int = _last_variant.get(event, -1)
	var idx := _rng.randi_range(0, count - 1)
	if last >= 0:
		# Choose among the other count - 1 takes, skipping over the last one.
		idx = _rng.randi_range(0, count - 2)
		if idx >= last:
			idx += 1
	_last_variant[event] = idx
	return idx


## Loads (once) the takes for an event; see the order at the top of the file.
func _get_variants(event: StringName) -> Array:
	if _variants.has(event):
		return _variants[event]
	var takes: Array = []
	for n in range(1, MAX_VARIANTS + 1):
		var path := SFX_DIR + "%s_%02d.wav" % [event, n]
		if not ResourceLoader.exists(path):
			break
		var stream := load(path) as AudioStream
		if stream != null:
			takes.append(stream)
	var single_on_disk := ResourceLoader.exists(SFX_DIR + String(event) + ".wav")
	if takes.is_empty() and not single_on_disk:
		for n in range(1, SfxSynth.variant_count(event) + 1):
			takes.append(SfxSynth.make_variant(event, n))
	_variants[event] = takes
	return takes


func _load_stream(event: StringName) -> AudioStream:
	var path := SFX_DIR + String(event) + ".wav"
	if ResourceLoader.exists(path):
		var stream := load(path) as AudioStream
		if stream != null:
			return stream
	if BonfireSynth.EVENTS.has(event):
		return BonfireSynth.make(event)
	return SfxSynth.make(event)


func _add_throw_events() -> void:
	for event in ThrowSynth.EVENTS:
		var path := SFX_DIR + String(event) + ".wav"
		_streams[event] = load(path) as AudioStream if ResourceLoader.exists(path) else ThrowSynth.make(event)


## Creates the SFX bus (routed to Master) if the project doesn't have one.
func _ensure_bus() -> void:
	if AudioServer.get_bus_index(BUS_NAME) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, BUS_NAME)
	AudioServer.set_bus_send(idx, &"Master")
