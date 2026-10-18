## Plays named sound events on the "SFX" audio bus.
##
## Usage: sfx.play(&"dice_hit")   or   sfx.play(&"chip_collect", 1.2, -3.0)
##
## Sounds are looked up by event name. If res://audio/sfx/<event>.wav exists
## it is used; otherwise SfxSynth builds a placeholder. A small pool of
## players lets several sounds overlap (lots of chips clacking at once).
class_name SfxManager
extends Node

const BUS_NAME: StringName = &"SFX"
const POOL_SIZE: int = 12
const SFX_DIR: String = "res://audio/sfx/"

## Emitted every time an event is played (handy for tests and debugging).
signal played(event: StringName)

var _streams: Dictionary[StringName, AudioStream] = {}
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _rng := RandomNumberGenerator.new()


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
	player.stream = _streams[event]
	player.pitch_scale = maxf(0.05, pitch + _rng.randf_range(-pitch_jitter, pitch_jitter))
	player.volume_db = volume_db
	player.play()
	played.emit(event)


func has_event(event: StringName) -> bool:
	return _streams.has(event)


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
