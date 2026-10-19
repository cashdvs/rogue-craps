## Tiny Anvil Games boot splash ("Spark" direction).
##
## Plays once per boot: the anvil drops in, the hammer strikes, the anvil
## flashes, sparks burst and the hero spark pops into place, "TINY ANVIL" +
## "GAMES" wipe in, hold, fade, then the next scene opens. Any key / click / tap /
## pad button skips with a fast fade. SplashState (autoload) makes sure it
## never replays during the same boot.
##
## Art + motion are data, not code:
##   - Layers are separate Sprite2D nodes whose textures are plain files in
##     res://assets/branding/studio/ (anvil.png, hammer.png, spark.png,
##     spark_particle.png, wordmark_main_cream.png, wordmark_games_cream.png).
##     Replace a file to swap the art.
##   - The whole timeline (rest poses, pivots, tracks with Godot TRANS_/EASE_
##     names, camera nudge/shake, particle burst, SFX cue times, skip rules and
##     the reduced-motion variant) is read from splash_timings.json (the Art
##     Director's motion spec). Edit that file to retime the splash.
##
## Sound: two mutually exclusive modes, picked once when the splash starts
## (see cue_mode()):
##   - per-cue (default): every "sfx" entry of the variant playing (full or
##     reduced motion) fires cue(&"splash_<id>") at its time (splash_clang is
##     the hammer strike).
##   - single: ONLY when none of those per-cue events has a stream and a
##     studio_splash stream exists, cue(&"studio_splash") fires once at t=0
##     (one pre-mixed sting) and no splash_<id> cues fire.
## So the sting never plays on top of the per-cue sounds. A cue plays a stream
## from `cue_streams` (inspector) or, if none is set,
## <sfx_dir>/<event>.wav (default res://audio/sfx/) when that file exists; otherwise it is silent.
## See assets/branding/studio/GODOT.md.
extends Node2D

## Emitted at every sound-cue moment (see header).
signal cue(event: StringName)
## Emitted right before the scene changes.
signal finished(skipped: bool)

const DEFAULT_NEXT_SCENE: String = "res://scenes/table_3d.tscn"
## project.godot setting with the scene to open after the splash.
const NEXT_SCENE_SETTING: String = "boot/next_scene"
const SFX_DIR: String = "res://audio/sfx/"
## The single pre-mixed sting (fallback when no per-cue sound exists).
const STING_EVENT: StringName = &"studio_splash"
const LAYOUT_SIZE := Vector2(1920, 1080)
const TRANS := {
	"LINEAR": Tween.TRANS_LINEAR, "SINE": Tween.TRANS_SINE, "QUINT": Tween.TRANS_QUINT,
	"QUART": Tween.TRANS_QUART, "QUAD": Tween.TRANS_QUAD, "EXPO": Tween.TRANS_EXPO,
	"ELASTIC": Tween.TRANS_ELASTIC, "CUBIC": Tween.TRANS_CUBIC, "CIRC": Tween.TRANS_CIRC,
	"BOUNCE": Tween.TRANS_BOUNCE, "BACK": Tween.TRANS_BACK, "SPRING": Tween.TRANS_SPRING,
}
const EASE := {
	"IN": Tween.EASE_IN, "OUT": Tween.EASE_OUT, "IN_OUT": Tween.EASE_IN_OUT, "OUT_IN": Tween.EASE_OUT_IN,
}

## The motion spec (Art Director's splash_timings.json).
@export_file("*.json") var timings_path: String = "res://assets/branding/studio/splash_timings.json"
## Leave empty to use the project setting boot/next_scene.
@export_file("*.tscn") var next_scene_override: String = ""
## Optional sound per cue event, e.g. {&"splash_clang": preload(...)}.
@export var cue_streams: Dictionary[StringName, AudioStream] = {}
## Folder searched for <event>.wav when cue_streams has no stream (set before
## the splash starts; tests point it at an empty folder).
@export_dir var sfx_dir: String = SFX_DIR
## Layer PNGs are authored at 2x; every scale in the timeline multiplies this.
@export var base_scale: float = 0.5
## Force the reduced-motion variant (SplashState.reduced_motion also enables it).
@export var reduced_motion: bool = false
## Extra juice beyond the spec: a warm forge glow under the strike point.
@export var impact_glow: bool = true
## Extra juice beyond the spec: a light full-screen flash on the strike.
@export var impact_flash: bool = false
## In-engine particle tuning on top of the spec's burst numbers (1 = exactly the spec).
@export var burst_amount_scale: float = 1.75
@export var burst_size_scale: float = 1.35

var playing: bool = false
var skipped: bool = false
var done: bool = false
var replay_blocked: bool = false
var elapsed: float = 0.0
## Parsed timeline (empty if it failed to load).
var timeline: Dictionary = {}

var _tween: Tween
var _shake_left: float = 0.0
var _shake_total: float = 0.0
var _shake_px: float = 0.0
var _shake_period: float = 0.025
var _shake_tick: float = 0.0
var _nudge := Vector2.ZERO
var _shake_offset := Vector2.ZERO
var _rng := RandomNumberGenerator.new()
var _players: Dictionary[StringName, AudioStreamPlayer] = {}
## This play uses the single studio_splash sting (see cue_mode()).
var _single_sting: bool = false

@onready var _bg: ColorRect = %Background
@onready var _stage: Node2D = %Stage
@onready var _shaker: Node2D = %Shaker
@onready var _anvil: Sprite2D = %Anvil
@onready var _hammer: Sprite2D = %Hammer
@onready var _spark: Sprite2D = %Spark
@onready var _glow: Sprite2D = %Glow
@onready var _burst: CPUParticles2D = %SparkBurst
@onready var _embers: CPUParticles2D = %Embers
@onready var _wordmark: Sprite2D = %WordmarkMain
@onready var _games: Sprite2D = %WordmarkGames
@onready var _flash: ColorRect = %Flash
@onready var _fade: ColorRect = %Fade


func _ready() -> void:
	_fade.color = Color(_bg.color, 0.0)
	var state := _state()
	if state != null and state.played:
		# Already shown this boot: go straight on, never replay.
		replay_blocked = true
		visible = false
		_fade.color.a = 1.0
		_go_next.call_deferred()
		return
	if state != null:
		state.played = true
	timeline = load_timeline(timings_path)
	if timeline.is_empty():
		push_error("StudioSplash: could not read '%s'; skipping the splash." % timings_path)
		_finish.call_deferred()
		return
	_setup()
	# Start on the next frame so the (long) boot/load frame's delta doesn't
	# eat the first beats of the timeline. Hidden until then.
	_stage.visible = false
	await get_tree().process_frame
	await get_tree().process_frame
	if is_inside_tree():
		_play()


## Reads the motion spec JSON. Returns {} on failure.
static func load_timeline(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}


func is_reduced_motion() -> bool:
	var state := _state()
	return reduced_motion or (state != null and state.reduced_motion)


## Seconds until the scene changes (when not skipped).
func duration() -> float:
	if is_reduced_motion():
		return float(timeline.get("reduced_motion", {}).get("total", timeline.get("total", 2.5)))
	return float(timeline.get("total", 2.5))


func next_scene_path() -> String:
	if next_scene_override != "":
		return next_scene_override
	return str(ProjectSettings.get_setting(NEXT_SCENE_SETTING, DEFAULT_NEXT_SCENE))


func _state() -> Node:
	return get_node_or_null(^"/root/SplashState")


func _layers() -> Dictionary:
	return timeline.get("layers", {})


func _setup() -> void:
	_bg.color = Color.html(str(timeline.get("background", {}).get("color", "#1E1B1A")))
	_fade.color = Color(_bg.color, 0.0)  # everything fades to the background
	_flash.color = Color(Color.html("#F4EDE4"), 0.0)
	var layers := _layers()
	_rest(_anvil, layers.get("anvil", {}))
	_rest(_hammer, layers.get("hammer", {}))
	var wm: Dictionary = layers.get("wordmark", {})
	_rest(_wordmark, wm.get("main", wm))
	if wm.has("games"):
		_rest(_games, wm.games)
	else:
		_games.visible = false
	var sparks: Dictionary = layers.get("sparks", {})
	_rest(_spark, sparks.get("hero", {}))
	_setup_burst(sparks.get("burst", {}))
	_glow.modulate.a = 0.0
	_layout()
	get_viewport().size_changed.connect(_layout)


## Centres the 1920x1080 layout in whatever the viewport is (stretch=expand).
func _layout() -> void:
	_stage.position = ((get_viewport_rect().size - LAYOUT_SIZE) * 0.5).round()


func _rest(sprite: Sprite2D, layer: Dictionary) -> void:
	if layer.has("pivot_px"):
		sprite.centered = false
		sprite.offset = -_vec(layer.pivot_px)
	if layer.has("z"):
		sprite.z_index = int(layer.z)
	var rest: Dictionary = layer.get("rest", {})
	for key: String in rest:
		_apply(_value(rest[key]), sprite, key)


func _setup_burst(b: Dictionary) -> void:
	if b.is_empty():
		return
	var pos := _vec(b.get("position", [0, 0]))
	_burst.position = pos
	_embers.position = pos
	_glow.position = pos
	if b.has("z"):
		_burst.z_index = int(b.z)
		_embers.z_index = int(b.z)
	_burst.amount = maxi(1, roundi(float(b.get("amount", 28)) * burst_amount_scale))
	_burst.lifetime = float(b.get("lifetime", 0.55))
	_burst.explosiveness = float(b.get("explosiveness", 1.0))
	_burst.randomness = float(b.get("randomness", 0.4))
	_burst.direction = _vec(b.get("direction", [0, -1]))
	_burst.spread = float(b.get("spread_deg", 70))
	var v := _vec(b.get("initial_velocity", [380, 720]))
	_burst.initial_velocity_min = v.x
	_burst.initial_velocity_max = v.y
	_burst.gravity = _vec(b.get("gravity", [0, 1400]))
	var d := _vec(b.get("damping", [120, 200]))
	_burst.damping_min = d.x
	_burst.damping_max = d.y
	var a := _vec(b.get("angle_deg", [0, 90]))
	_burst.angle_min = a.x
	_burst.angle_max = a.y
	var s := _vec(b.get("scale", [0.18, 0.45]))
	_burst.scale_amount_min = s.x * burst_size_scale
	_burst.scale_amount_max = s.y * burst_size_scale
	var ramp := Gradient.new()
	var stops: Array = b.get("color_ramp", [])
	if stops.size() >= 2:
		ramp.offsets = PackedFloat32Array()
		ramp.colors = PackedColorArray()
		for stop: Array in stops:
			ramp.add_point(float(stop[0]), Color(Color.html(str(stop[1])), float(stop[2])))
		_burst.color_ramp = ramp
	var e: Dictionary = b.get("secondary_embers", {})
	if not e.is_empty():
		_embers.amount = maxi(1, roundi(float(e.get("amount", 10)) * burst_amount_scale))
		_embers.lifetime = float(e.get("lifetime", 0.9))
		var ev := _vec(e.get("initial_velocity", [120, 260]))
		_embers.initial_velocity_min = ev.x
		_embers.initial_velocity_max = ev.y
		_embers.spread = float(e.get("spread_deg", 110))
		_embers.gravity = _vec(e.get("gravity", [0, 500]))
		var es := _vec(e.get("scale", [0.08, 0.16]))
		_embers.scale_amount_min = es.x * burst_size_scale
		_embers.scale_amount_max = es.y * burst_size_scale
		var ec := Color.html(str(e.get("color", "#F26A1B")))
		var er := Gradient.new()
		er.set_color(0, ec)
		er.set_color(1, Color(ec, 0.0))
		_embers.color_ramp = er


func _play() -> void:
	playing = true
	_stage.visible = true
	var t := create_tween().set_parallel(true)
	_tween = t
	_single_sting = cue_mode() == &"single"
	if is_reduced_motion():
		_play_reduced(t)
	else:
		_play_full(t)
	if _single_sting:
		_cue_at(t, STING_EVENT, 0.0, 0.0)
	t.tween_callback(_finish).set_delay(duration())


func _play_full(t: Tween) -> void:
	var layers := _layers()
	_tracks(t, _anvil, layers.get("anvil", {}).get("tracks", []))
	_tracks(t, _hammer, layers.get("hammer", {}).get("tracks", []))
	var wm: Dictionary = layers.get("wordmark", {})
	_tracks(t, _wordmark, wm.get("main", wm).get("tracks", []))
	_tracks(t, _games, wm.get("games", {}).get("tracks", []))
	var sparks: Dictionary = layers.get("sparks", {})
	_tracks(t, _spark, sparks.get("hero", {}).get("tracks", []))
	var burst: Dictionary = sparks.get("burst", {})
	if not burst.is_empty():
		var at := float(burst.get("emit_at", 0.6))
		t.tween_callback(_impact).set_delay(at)
	for cam: Dictionary in timeline.get("camera", []):
		var at := float(cam.get("at", 0.0))
		match str(cam.get("type", "")):
			"nudge":
				var dur := float(cam.get("dur", 0.1))
				var off := Vector2(float(cam.get("offset_x", 0.0)), float(cam.get("offset_y", 0.0)))
				var tr: Tween.TransitionType = TRANS.get(str(cam.get("trans", "SINE")), Tween.TRANS_SINE)
				t.tween_method(_set_nudge, Vector2.ZERO, off, dur * 0.5).set_delay(at).set_trans(tr).set_ease(Tween.EASE_OUT)
				t.tween_method(_set_nudge, off, Vector2.ZERO, dur * 0.5).set_delay(at + dur * 0.5).set_trans(tr).set_ease(Tween.EASE_IN_OUT)
			"shake":
				var hz := maxf(1.0, float(cam.get("frequency_hz", 40.0)))
				t.tween_callback(_shake.bind(float(cam.get("amplitude_px", 7.0)), float(cam.get("dur", 0.18)), 1.0 / hz)).set_delay(at)
	_sfx_cues(t, timeline.get("sfx", []))


## Reduced motion: no hammer, burst or camera; the lockup fades in and out.
func _play_reduced(t: Tween) -> void:
	var r: Dictionary = timeline.get("reduced_motion", {})
	_hammer.visible = false
	_glow.visible = false
	_tracks(t, _anvil, _list(r.get("anvil", [])))
	_tracks(t, _spark, _list(r.get("spark_hero", [])))
	var rw: Variant = r.get("wordmark", [])
	if rw is Dictionary:
		_tracks(t, _wordmark, _list(rw.get("main", [])))
		_tracks(t, _games, _list(rw.get("games", [])))
	else:
		_tracks(t, _wordmark, _list(rw))
	var fo: Dictionary = r.get("fade_out", {})
	if not fo.is_empty():
		for sprite: Sprite2D in [_anvil, _spark, _wordmark, _games]:
			_tracks(t, sprite, [{"prop": "modulate_a", "to": 0.0, "start": fo.get("start", 2.0), "dur": fo.get("dur", 0.3), "trans": fo.get("trans", "SINE"), "ease": fo.get("ease", "IN")}])
	_sfx_cues(t, r.get("sfx", []))


func _sfx_cues(t: Tween, sfx: Array) -> void:
	if _single_sting:
		return
	for s: Dictionary in sfx:
		_cue_at(t, StringName("splash_" + str(s.id)), float(s.get("at", 0.0)), float(s.get("volume_db", 0.0)))


## The splash_<id> events of the variant that plays (full or reduced motion).
func sfx_events() -> Array[StringName]:
	var list: Array = timeline.get("reduced_motion", {}).get("sfx", []) if is_reduced_motion() else timeline.get("sfx", [])
	var out: Array[StringName] = []
	for s: Dictionary in list:
		out.append(StringName("splash_" + str(s.id)))
	return out


## &"per_cue" when any of this variant's splash_<id> events has a stream (or
## when nothing has one: silent, but the moments are still signalled);
## &"single" only when no per-cue stream exists and studio_splash has one.
func cue_mode() -> StringName:
	for e in sfx_events():
		if _stream_for(e) != null:
			return &"per_cue"
	return &"single" if _stream_for(STING_EVENT) != null else &"per_cue"


func _stream_for(event: StringName) -> AudioStream:
	var stream: AudioStream = cue_streams.get(event)
	if stream == null:
		var path := sfx_dir.path_join(String(event) + ".wav")
		if ResourceLoader.exists(path):
			stream = load(path) as AudioStream
	return stream


func _list(v: Variant) -> Array:
	return v if v is Array else []


## Adds one layer's tracks to the (parallel) tween. A track is either
## {"prop", "at", "set"} (instant) or {"prop", "from"?, "to", "start", "dur",
## "trans", "ease"}. Missing "from" means "from the current value at start".
func _tracks(t: Tween, node: Node2D, tracks: Array) -> void:
	for tr: Dictionary in tracks:
		var prop := str(tr.get("prop", ""))
		if tr.has("set"):
			var at := float(tr.get("at", 0.0))
			var value: Variant = _value(tr.set)
			if at <= 0.0:
				_apply(value, node, prop)
			else:
				t.tween_callback(_apply.bind(value, node, prop)).set_delay(at)
			continue
		var start := float(tr.get("start", 0.0))
		var dur := maxf(0.0001, float(tr.get("dur", 0.0)))
		var to: Variant = _value(tr.get("to", 0.0))
		var tw: MethodTweener
		if tr.has("from"):
			var from: Variant = _value(tr.from)
			if start <= 0.0:
				_apply(from, node, prop)
			tw = t.tween_method(_apply.bind(node, prop), from, to, dur)
		else:
			# Resolve "from" when the track starts.
			tw = t.tween_method(_apply_lerp.bind(node, prop, to, [null]), 0.0, 1.0, dur)
		tw.set_delay(start)
		tw.set_trans(TRANS.get(str(tr.get("trans", "LINEAR")), Tween.TRANS_LINEAR))
		tw.set_ease(EASE.get(str(tr.get("ease", "IN_OUT")), Tween.EASE_IN_OUT))


func _apply_lerp(k: float, node: Node2D, prop: String, to: Variant, from_box: Array) -> void:
	if from_box[0] == null:
		from_box[0] = _read(node, prop)
	_apply(lerp(from_box[0], to, k), node, prop)


func _read(node: Node2D, prop: String) -> Variant:
	match prop:
		"position:x": return node.position.x
		"position:y": return node.position.y
		"position": return node.position
		"scale": return node.scale / base_scale
		"rotation": return node.rotation_degrees
		"modulate_a": return node.modulate.a
		"modulate_rgb": return node.modulate.r
		"reveal": return node.get_meta(&"reveal", 1.0)
	return 0.0


func _apply(value: Variant, node: Node2D, prop: String) -> void:
	match prop:
		"position:x": node.position.x = value
		"position:y": node.position.y = value
		"position": node.position = value
		"scale":
			node.scale = (value if value is Vector2 else Vector2.ONE * float(value)) * base_scale
		"rotation": node.rotation_degrees = value
		"modulate_a": node.modulate.a = value
		"modulate_rgb": node.modulate = Color(value, value, value, node.modulate.a)
		"reveal": _set_reveal(node as Sprite2D, value)
		_: push_warning("StudioSplash: unknown track prop '%s'." % prop)


## Left-to-right wipe: the soft-edge wipe shader's `reveal` uniform when the
## sprite has it (wordmark/main), else a hard crop of the sprite's region.
func _set_reveal(sprite: Sprite2D, v: float) -> void:
	if sprite == null or sprite.texture == null:
		return
	v = clampf(v, 0.0, 1.0)
	sprite.set_meta(&"reveal", v)
	var mat := sprite.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter(&"reveal", v)
		return
	var size := sprite.texture.get_size()
	sprite.region_enabled = v < 1.0
	sprite.region_rect = Rect2(0, 0, size.x * v, size.y)


func _value(v: Variant) -> Variant:
	if v is Array and v.size() == 2:
		return Vector2(float(v[0]), float(v[1]))
	if v is float or v is int:
		return float(v)
	return v


func _vec(v: Variant) -> Vector2:
	var out: Variant = _value(v)
	return out if out is Vector2 else Vector2.ZERO


func _impact() -> void:
	_burst.restart()
	_burst.emitting = true
	_embers.restart()
	_embers.emitting = true
	if impact_glow:
		var g := create_tween().set_parallel(true)
		_glow.scale = Vector2(1.0, 0.55)
		_glow.modulate.a = 0.6
		g.tween_property(_glow, "scale", Vector2(5.0, 2.6), 0.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		g.tween_property(_glow, "modulate:a", 0.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if impact_flash:
		var f := create_tween()
		_flash.color.a = 0.3
		f.tween_property(_flash, "color:a", 0.0, 0.16)


func _cue_at(t: Tween, event: StringName, at: float, volume_db: float) -> void:
	if at <= 0.0:
		_cue(event, volume_db)
	else:
		t.tween_callback(_cue.bind(event, volume_db)).set_delay(at)


func _cue(event: StringName, volume_db: float = 0.0) -> void:
	var stream := _stream_for(event)
	if stream != null:
		var player: AudioStreamPlayer = _players.get(event)
		if player == null:
			player = AudioStreamPlayer.new()
			player.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") != -1 else &"Master"
			add_child(player)
			_players[event] = player
		player.stream = stream
		player.volume_db = volume_db
		player.play()
	cue.emit(event)


func _set_nudge(v: Vector2) -> void:
	_nudge = v
	_shaker.position = _nudge + _shake_offset


func _shake(px: float, time: float, period: float) -> void:
	_shake_px = px
	_shake_total = maxf(time, 0.001)
	_shake_left = time
	_shake_period = period
	_shake_tick = 0.0


func _process(delta: float) -> void:
	if playing:
		elapsed += delta
	if _shake_left > 0.0:
		_shake_left = maxf(0.0, _shake_left - delta)
		_shake_tick -= delta
		if _shake_tick <= 0.0 or _shake_left == 0.0:
			_shake_tick = _shake_period
			var k := _shake_left / _shake_total  # linear decay to 0
			# Both axes, y weighted 1.0 and x 0.6 (splash_motion.md).
			_shake_offset = Vector2(_rng.randf_range(-0.6, 0.6), _rng.randf_range(-1, 1)) * _shake_px * k
		_shaker.position = _nudge + _shake_offset


func _input(event: InputEvent) -> void:
	if not playing or skipped or done:
		return
	if elapsed < float(timeline.get("skip", {}).get("ignore_input_before", 0.15)):
		return
	if _is_skip_event(event):
		get_viewport().set_input_as_handled()
		skip()


func _is_skip_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo
	if event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventJoypadButton:
		return event.pressed
	return false


## Skips to the next scene with a fast fade.
func skip() -> void:
	if skipped or done:
		return
	skipped = true
	if _tween != null:
		_tween.kill()
	_shake_left = 0.0
	var fade := float(timeline.get("skip", {}).get("skip_fade", 0.2))
	var t := create_tween().set_parallel(true)
	_tween = t
	# Fade content (and our own cue players, not the bus) to the background.
	t.tween_property(_fade, "color:a", 1.0, maxf(0.01, fade * (1.0 - _fade.color.a))).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	for player: AudioStreamPlayer in _players.values():
		if player.playing:
			t.tween_property(player, "volume_db", -60.0, fade).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_callback(_finish).set_delay(fade)


func _finish() -> void:
	if done:
		return
	done = true
	playing = false
	finished.emit(skipped)
	_go_next()


func _go_next() -> void:
	var path := next_scene_path()
	if not ResourceLoader.exists(path):
		push_error("StudioSplash: next scene '%s' not found (set %s in project.godot)." % [path, NEXT_SCENE_SETTING])
		return
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("StudioSplash: could not open '%s' (error %d)." % [path, err])
