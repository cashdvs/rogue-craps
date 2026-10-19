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
## Tests: a fixed clock in seconds for play_impact's rate limit (-1 = real time).
var impact_clock: float = -1.0


func _ready() -> void:
	_ensure_bus()
	for event in SfxSynth.EVENTS:
		_streams[event] = _load_stream(event)
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = BUS_NAME
		add_child(player)
		_players.append(player)
	_add_throw_events()


## Plays an event. pitch: 1.0 = normal. pitch_jitter adds a little random
## variation so repeated sounds (chips!) don't sound robotic.
func play(event: StringName, pitch: float = 1.0, volume_db: float = 0.0, pitch_jitter: float = 0.06) -> void:
	if not _streams.has(event):
		push_warning("SfxManager: no sound for event '%s'." % event)
		return
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
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
	var now := Time.get_ticks_usec() / 1e6 if impact_clock < 0.0 else impact_clock
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
