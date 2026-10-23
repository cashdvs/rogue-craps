## Nerve "die turns" accent (nerve_v1.md): listens to table.events.die_nudged
## (PR #126; fires on each nudge and on undo with the dir reversed). The
## rotation itself is TableDie.set_face()'s tween (Godot Dev); this only adds
## the feel on top, never touching the die:
## - a quick flick: one pale-glass glint_streak beside the die that slides
##   0.02 m in the nudge direction (UP = away from the camera, -z; DOWN =
##   toward it) and fades in 0.14 s;
## - a short glint: 3 spark_dot_soft motes beside the die (never over its
##   face centre: always >= SIDE_MIN x edge to the side) that drift out
##   sideways and down, never up, and fade in 0.24 s;
## - the sound through the sibling TableAudio (`nerve_nudge`, falling back to
##   `chip_place`), guarded with has_method.
## Reduced motion / Instant speed: no slide or drift, the glint just fades in
## place. There's no "Nerve spent" event on TableEvents (a nudge is only
## spent at pot commit), so no spent cue yet.
class_name NerveTurnFx
extends Node3D

const GLASS := Color("#F2EEE2")
const FLICK_TIME: float = 0.14
const GLINT_TIME: float = 0.24
const FLICK_SLIDE: float = 0.02
const MOTES: int = 3
## Horizontal distance from the die centre, as a multiple of the die edge.
const SIDE_MIN: float = 0.6
const MOTE_DRIFT: float = 0.012
const CUE := &"nerve_nudge"
const CUE_FALLBACK := &"chip_place"

var table: Node
var events: Object
var audio: Node
## Every effect played, "<die_id>:<dir>" (tests and captures).
var calls: Array[String] = []
## Live sprites -> {"vel": Vector3} for tests.
var pieces: Array[Sprite3D] = []


func _init() -> void:
	name = "NerveTurnFx"


func _ready() -> void:
	_bind_to_parent.call_deferred()


func _bind_to_parent() -> void:
	if table != null:
		return
	var t := get_parent()
	if t == null:
		return
	var ev: Variant = t.get("events")
	bind(ev as Object if ev is Object else null, t)


## Hooks die_nudged if the events node has it (has_signal guard).
func bind(ev: Object, t: Node) -> bool:
	table = t
	events = ev
	if audio == null and t != null:
		audio = t.get_node_or_null("TableAudio")
	if ev == null or not ev.has_signal(&"die_nudged"):
		return false
	if not ev.is_connected(&"die_nudged", _on_die_nudged):
		ev.connect(&"die_nudged", _on_die_nudged)
	return true


func _reduced() -> bool:
	if table == null:
		return false
	if table.has_method("is_reduced_motion") and bool(table.call("is_reduced_motion")):
		return true
	if "speed_mode" in table and int(table.get("speed_mode")) >= 2:
		return true
	return false


## World direction of a nudge (UP away from the camera, DOWN toward it).
static func flick_dir(dir: int) -> Vector3:
	return Vector3(0, 0, -1) if dir == NerveState.UP else Vector3(0, 0, 1)


func _on_die_nudged(die_id: int, _from_face: int, _to_face: int, dir: int) -> void:
	var die: Node3D = null
	if table != null and table.has_method("die_by_id"):
		die = table.call("die_by_id", die_id) as Node3D
	if die == null or not is_instance_valid(die):
		return
	play(die, dir)
	calls.append("%d:%d" % [die_id, dir])
	if audio != null and audio.has_method("cue"):
		if audio.call("cue", CUE) == &"":
			audio.call("cue", CUE_FALLBACK)


## The flick + glint at `die` (tests and captures call it directly).
func play(die: Node3D, dir: int) -> void:
	var edge := float(die.get("edge")) if "edge" in die else 0.08
	var c := die.global_position
	var still := _reduced()
	# Flick: on the side away from the camera's centre line, at die height.
	var side := 1.0 if c.x <= 0.0 else -1.0
	var f0 := c + Vector3(side * edge * SIDE_MIN * 1.1, 0.0, 0.0)
	var fd := flick_dir(dir) * (0.0 if still else FLICK_SLIDE)
	_piece(&"glint_streak", f0, fd, edge * 1.3, FLICK_TIME)
	for i in MOTES:
		var s := -1.0 if i % 2 == 0 else 1.0
		var p := c + Vector3(s * edge * (SIDE_MIN + 0.15 * i), -edge * 0.1 * i, flick_dir(dir).z * edge * 0.2)
		var v := Vector3(s * MOTE_DRIFT, -MOTE_DRIFT * 0.5, 0.0) * (0.0 if still else 1.0)
		_piece(&"spark_dot_soft", p, v, edge * 0.4, GLINT_TIME)


func _piece(shape: StringName, at: Vector3, move: Vector3, size: float, life: float) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = TriggerShapes.texture(shape, GLASS)
	s.modulate = GLASS
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.shaded = false
	s.no_depth_test = false
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	s.top_level = true
	if s.texture != null:
		s.pixel_size = size / float(maxi(s.texture.get_width(), 1))
	s.set_meta("move", move)
	s.set_meta("origin", at)
	add_child(s)
	s.global_position = at
	pieces.append(s)
	var tw := s.create_tween().set_ignore_time_scale(true).set_parallel(true)
	tw.tween_property(s, "global_position", at + move, life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(s, "modulate:a", 0.0, life).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func() -> void:
		pieces.erase(s)
		s.queue_free())
	return s
