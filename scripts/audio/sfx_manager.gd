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


func _ready() -> void:
	_ensure_bus()
	for event in SfxSynth.EVENTS:
		_streams[event] = _load_stream(event)
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = BUS_NAME
		add_child(player)
		_players.append(player)


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


## Creates the SFX bus (routed to Master) if the project doesn't have one.
func _ensure_bus() -> void:
	if AudioServer.get_bus_index(BUS_NAME) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, BUS_NAME)
	AudioServer.set_bus_send(idx, &"Master")
