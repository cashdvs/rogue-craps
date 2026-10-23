## Nerve "spent" cue: listens to table.events.nerve_spent(die_id, from_face,
## to_face) (1-based faces; Godot Dev's PR #143, emitted once when a pending
## nudge is kept for good: pot, rethrow, bank or rescue-save; never on undo).
## Guarded with has_signal, so it binds to nothing until #143 lands.
## The cue is tiny and warm, never touching the die. Cleared at once on
## dice_thrown / rethrow / close_throw (whichever exist), undo (die_nudged on
## that die) and table_cleared.
## - one brief warm gold (Ember #FFC870) glint band lying flat on the die's camera-side
##   top bevel (off the pips), fading out in GLINT_TIME (<= 0.3 s);
## - outside reduced motion / Instant it also stretches slightly along the
##   edge while fading; under reduced motion it holds still and just fades;
## - leftover nudge FX on that die (sibling NerveTurnFx, has_method "clear")
##   are cleared first so the two never stack;
## - sound via the sibling TableAudio: its `nerve_spent` method if it has one,
##   else cue(&"nerve_spent"); if that event is missing, nothing plays.
class_name NerveSpentFx
extends Node3D

## Ember-family saturated gold at peak 1.0: on white / ivory dice a paler or
## brighter (HDR) tint clips and the tonemapper turns it cool grey; a deeper
## gold below 1.0 per channel stays warm and reads against the ivory, and
## never exceeds the bevel-line highlight.
const COLOR := Color("#FFC870")
const PEAK: float = 1.0
const GLINT_TIME: float = 0.26
const TOTAL_TIME: float = 0.3
## Band on the camera-side top edge (x edge): centre depth, length, width.
const EDGE_Z: float = 0.44
const LEN: float = 0.8
const THICK: float = 0.16
## Pips sit within this of the face centre (x edge).
const PIP_REACH: float = 0.34
## Stretch along the edge outside reduced motion.
const STRETCH: float = 1.15
const CUE := &"nerve_spent"
## Events that end the throw / table: any live glint is cleared at once.
const CLEAR_ON: Array[StringName] = [&"dice_thrown", &"rethrow", &"close_throw", &"throw_closed", &"table_cleared"]
const BAND_W: int = 64
const BAND_H: int = 8
const ASPECT: float = float(BAND_H) / float(BAND_W)
static var _band: ImageTexture

var table: Node
var events: Object
var audio: Node
## Every cue played: "<die_id>:<from>><to>" (tests and captures).
var calls: Array[String] = []
var pieces: Array[Sprite3D] = []
## Captures on slow renderers: tweens start paused and advance(dt) steps them.
var hold: bool = false
var _tweens: Array[Tween] = []


func _init() -> void:
	name = "NerveSpentFx"


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


## Hooks nerve_spent if the events node has it.
func bind(ev: Object, t: Node) -> bool:
	table = t
	events = ev
	if audio == null and t != null:
		audio = t.get_node_or_null("TableAudio")
	if ev == null or not ev.has_signal(&"nerve_spent"):
		return false
	if not ev.is_connected(&"nerve_spent", _on_nerve_spent):
		ev.connect(&"nerve_spent", _on_nerve_spent)
	for sig: StringName in CLEAR_ON:
		if ev.has_signal(sig) and not ev.is_connected(sig, _on_clear_all):
			ev.connect(sig, _on_clear_all)
	if ev.has_signal(&"die_nudged") and not ev.is_connected(&"die_nudged", _on_die_nudged):
		ev.connect(&"die_nudged", _on_die_nudged)
	return true


func _on_clear_all(_a: Variant = null) -> void:
	clear()


## A nudge or undo on a die drops its spent glint (undo re-emits die_nudged).
func _on_die_nudged(die_id: int, _f: int, _t: int, _dir: int) -> void:
	if table != null and table.has_method("die_by_id"):
		var d := table.call("die_by_id", die_id) as Node3D
		if d != null:
			clear(d)


static func band_texture() -> ImageTexture:
	if _band != null:
		return _band
	var img := Image.create(BAND_W, BAND_H, false, Image.FORMAT_RGBA8)
	for x in BAND_W:
		var along := pow(sin((float(x) + 0.5) / float(BAND_W) * PI), 0.8)
		for y in BAND_H:
			var v := absf((float(y) + 0.5) / float(BAND_H) * 2.0 - 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, along * (1.0 - smoothstep(0.55, 1.0, v))))
	_band = ImageTexture.create_from_image(img)
	return _band


func _reduced() -> bool:
	if table == null:
		return false
	if table.has_method("is_reduced_motion") and bool(table.call("is_reduced_motion")):
		return true
	if "speed_mode" in table and int(table.get("speed_mode")) >= 2:
		return true
	return false


func _on_nerve_spent(die_id: int, from_face: int, to_face: int) -> void:
	var die: Node3D = null
	if table != null and table.has_method("die_by_id"):
		die = table.call("die_by_id", die_id) as Node3D
	if die == null or not is_instance_valid(die):
		return
	var turn := table.get_node_or_null("NerveTurnFx") if table != null else null
	if turn != null and turn.has_method("clear"):
		turn.call("clear", die)
	clear(die)
	play(die)
	calls.append("%d:%d>%d" % [die_id, from_face, to_face])
	if audio != null:
		if audio.has_method("nerve_spent"):
			audio.call("nerve_spent")
		elif audio.has_method("cue"):
			audio.call("cue", CUE)


func clear(die: Node3D = null) -> void:
	for s in pieces.duplicate():
		if die != null and s.get_meta("die", null) != die:
			continue
		pieces.erase(s)
		var tw: Variant = s.get_meta("tween", null)
		if tw is Tween and (tw as Tween).is_valid():
			(tw as Tween).kill()
			_tweens.erase(tw)
		s.queue_free()


func advance(dt: float) -> void:
	for tw in _tweens.duplicate():
		if tw.is_valid():
			tw.custom_step(dt)
	_tweens = _tweens.filter(func(t: Tween) -> bool: return t.is_valid())


## Yaw picking the top-face edge facing the camera (+z).
static func die_yaw(die: Node3D) -> float:
	var x := die.global_basis.x
	var flat := Vector2(x.x, x.z)
	var y := 0.0 if flat.length() < 0.1 else -atan2(flat.y, flat.x)
	return wrapf(y, -PI / 4.0, PI / 4.0)


## Nearest the band ever gets to the face centre (x edge), at full stretch.
static func min_depth() -> float:
	return EDGE_Z - THICK * 0.5


func play(die: Node3D) -> Sprite3D:
	var edge := float(die.get("edge")) if "edge" in die else 0.08
	var c := die.global_position
	var yaw := die_yaw(die)
	var s := Sprite3D.new()
	s.texture = band_texture()
	s.modulate = Color(COLOR.r * PEAK, COLOR.g * PEAK, COLOR.b * PEAK, 1.0)
	s.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	s.axis = Vector3.AXIS_Y
	s.shaded = false
	s.double_sided = true
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	s.render_priority = 10
	s.top_level = true
	s.pixel_size = edge * LEN / float(BAND_W)
	s.set_meta("kind", &"glint")
	s.set_meta("die", die)
	s.set_meta("life", GLINT_TIME)
	add_child(s)
	s.global_position = Vector3(c.x, c.y + edge * 0.5 + 0.0015, c.z) + Basis(Vector3.UP, yaw) * Vector3(0, 0, EDGE_Z * edge)
	s.rotation = Vector3(0.0, yaw, 0.0)
	s.scale = Vector3(1.0, 1.0, THICK / (LEN * ASPECT))
	pieces.append(s)
	var tw := s.create_tween().set_ignore_time_scale(true).set_parallel(true)
	tw.tween_property(s, "modulate:a", 0.0, GLINT_TIME).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	if not _reduced():
		tw.tween_property(s, "scale:x", STRETCH, GLINT_TIME).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(func() -> void:
		pieces.erase(s)
		s.queue_free())
	s.set_meta("tween", tw)
	if hold:
		tw.pause()
		_tweens.append(tw)
	return s
