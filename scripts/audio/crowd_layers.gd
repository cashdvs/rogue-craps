## The Bonfire crowd: three looping stems (crowd_low, crowd_mid, crowd_high)
## that play together, with their volumes following the unbanked pot so the
## room gets louder as you push your luck (bonfire_map_events_juice.md §3).
##
## Usage (the table's director owns one):
##   var crowd := CrowdLayers.new(); add_child(crowd); crowd.start()
##   crowd.set_pot_fraction(pot_so_far / some_big_pot)   # after every pot
##   crowd.set_pot_fraction(0.0)                          # after bank or bust
##   crowd.stop()                                         # leaving the table
## The stems loop on their own players (not SfxManager's pool), so one-shots
## can never cut them off.
class_name CrowdLayers
extends Node

const SFX_DIR: String = "res://audio/sfx/"
const SILENT_DB: float = -60.0

## Overall crowd level on top of the per-stem gains.
@export var volume_db: float = -6.0
## The unbanked-pot fraction the volumes are heading towards (0..1).
var pot_fraction: float = 0.0

var _players: Array[AudioStreamPlayer] = []
var _tween: Tween


func _ready() -> void:
	var bus: StringName = &"SFX" if AudioServer.get_bus_index(&"SFX") != -1 else &"Master"
	for event in BonfireSynth.LOOPS:
		var player := AudioStreamPlayer.new()
		player.stream = _load_loop(event)
		player.bus = bus
		player.volume_db = SILENT_DB
		add_child(player)
		_players.append(player)


## Starts all stems in sync (silent), then fades to the current pot level.
func start(fade_seconds: float = 0.6) -> void:
	for p in _players:
		p.play()
	set_pot_fraction(pot_fraction, fade_seconds)


## Moves every stem's volume to match an unbanked-pot fraction over `seconds`.
func set_pot_fraction(fraction: float, seconds: float = 0.4) -> void:
	pot_fraction = clampf(fraction, 0.0, 1.0)
	_fade_to(BonfireSynth.crowd_gains_db(pot_fraction), seconds)


## Fades everything out, then stops the players.
func stop(fade_seconds: float = 0.6) -> void:
	var silent := PackedFloat32Array([SILENT_DB, SILENT_DB, SILENT_DB])
	_fade_to(silent, fade_seconds, true)


## A quick swell on top of the pot level (at a signature trigger's hit): the
## playing stems jump up by `db`, then glide back to the pot gains over
## `seconds`. Does nothing while the crowd is stopped.
func nudge(db: float = 3.0, seconds: float = 0.3) -> void:
	if _players.is_empty() or not _players[0].playing:
		return
	var gains := BonfireSynth.crowd_gains_db(pot_fraction)
	for i in _players.size():
		if gains[i] > SILENT_DB:
			_players[i].volume_db = maxf(_players[i].volume_db, gains[i] + volume_db) + db
	_fade_to(gains, seconds)


## The volume (dB) each stem is at right now (for tests and debug overlays).
func current_db() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for p in _players:
		out.append(p.volume_db)
	return out


func _fade_to(gains: PackedFloat32Array, seconds: float, then_stop: bool = false) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	for i in _players.size():
		var target := gains[i] + volume_db if gains[i] > SILENT_DB else SILENT_DB
		_tween.tween_property(_players[i], "volume_db", target, maxf(seconds, 0.01))
	if then_stop:
		_tween.chain().tween_callback(func() -> void:
			for p in _players:
				p.stop())


## The baked loop if it exists (its .import sets loop_mode Forward), else the
## synthesized one. Either way, make sure it loops (on a copy, so the shared
## imported resource other players may use is never changed).
func _load_loop(event: StringName) -> AudioStream:
	var path := SFX_DIR + String(event) + ".wav"
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path) as AudioStream
	if stream == null:
		stream = BonfireSynth.make(event)
	var wav := stream as AudioStreamWAV
	if wav != null and wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		wav = wav.duplicate() as AudioStreamWAV
		stream = wav
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
	return stream
