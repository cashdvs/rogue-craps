## Nerve "die turns" accent (nerve_v1.md): listens to table.events.die_nudged
## (PR #126; fires on each nudge and on undo with the dir reversed). The
## rotation itself is TableDie.set_face()'s tween (Godot Dev); this only adds
## the feel on top, never touching the die:
## - a bevel sweep: one bright white-gold band overlay that slides
##   across the top of the turning die (FX piece, no material change);
## - a quick flick: one white-gold glint_streak beside the die that slides
##   0.02 m in the nudge direction (UP = away from the camera, -z; DOWN =
##   toward it) and fades in 0.14 s;
## - a short glint: 3 warm spark_dot_soft motes beside the die (never over its
##   face centre: always >= SIDE_MIN x edge to the side) that drift out
##   sideways and down, never up, and fade in 0.24 s;
## - the sound through the sibling TableAudio (`nerve_nudge`, falling back to
##   `chip_place`), guarded with has_method.
## All under 0.3 s. Reduced motion / Instant speed: the sweep only. There's no "Nerve spent" event on TableEvents (a nudge is only
## spent at pot commit), so no spent cue yet.
class_name NerveTurnFx
extends Node3D

## Warm white-gold (TriggerFxDefs.EMBER_CORE) for flick + motes; the sweep is
## a paler white-gold, like the material bevel line catching light.
const SPARK_COLOR := Color("#FFE6A8")
const SWEEP_COLOR := Color("#FFE0A0")
## Peak modulate multiplier (1.5x the v1 brightness of 1.0).
const PEAK: float = 1.5
const FLICK_TIME: float = 0.14
const GLINT_TIME: float = 0.24
const SWEEP_TIME: float = 0.22
## AD sign-off: 1.6x the v2 strength (peak 1.5), kept under the dice's
## bevel-line highlight on screen.
const SWEEP_PEAK: float = 2.4
## QA: the sweep is a thin flat band lying on the camera-side bevel (never
## over the pips), sliding along that edge. Band width is 1.3x the base 0.07
## x edge; length 0.82 x edge; tilted 6 deg; centred 0.44 x edge from the
## face centre.
const SWEEP_THICK_BASE: float = 0.07
const SWEEP_THICK: float = SWEEP_THICK_BASE * 1.3
const SWEEP_LEN: float = 0.82
const SWEEP_TILT: float = deg_to_rad(6.0)
const SWEEP_EDGE_Z: float = 0.44
const SWEEP_RUN: float = 0.5
## Pips sit within this of the face centre (x edge).
const PIP_REACH: float = 0.34
## Band texture: BAND_W x BAND_H px (the whole height is the visible band).
## glint_streak's bright core is only ~6 of its 128 px, so squashed to a thin
## band it went sub-pixel at table distance: that is why v2/v3 sweeps never
## showed in Forward+. The band gets its own small solid-core texture.
const BAND_W: int = 64
const BAND_H: int = 8
const STREAK_ASPECT: float = float(BAND_H) / float(BAND_W)
static var _band: ImageTexture


## The sweep band: solid core across its height, soft along its length.
static func band_texture() -> ImageTexture:
	if _band != null:
		return _band
	var img := Image.create(BAND_W, BAND_H, false, Image.FORMAT_RGBA8)
	for x in BAND_W:
		var u := (float(x) + 0.5) / float(BAND_W)
		var along := pow(sin(u * PI), 0.8)
		for y in BAND_H:
			var v := absf((float(y) + 0.5) / float(BAND_H) * 2.0 - 1.0)
			var across := 1.0 - smoothstep(0.55, 1.0, v)
			img.set_pixel(x, y, Color(1, 1, 1, along * across))
	_band = ImageTexture.create_from_image(img)
	return _band
## 1.5x the v1 mote size (0.4 x edge).
const MOTE_SIZE: float = 0.6
## Whole accent ends by this (all lives start at the nudge).
const TOTAL_TIME: float = 0.3
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
## Live sprites (meta: kind, origin, move, life, die).
var pieces: Array[Sprite3D] = []
## Captures on slow renderers: tweens start paused and advance(dt) steps them.
var hold: bool = false
var _tweens: Array[Tween] = []


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
	for sig: StringName in [&"dice_thrown", &"table_cleared"]:
		if ev.has_signal(sig) and not ev.is_connected(sig, _on_clear_all):
			ev.connect(sig, _on_clear_all)
	return true


func _on_clear_all(_a: Variant = null) -> void:
	clear()


## Removes live pieces at once: all of them, or only those on `die`. Called
## on a new die_nudged for the same die (re-nudge and undo, which re-emits
## die_nudged) and on dice_thrown / table_cleared, so nothing stacks or lingers.
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


## Steps held tweens (captures only).
func advance(dt: float) -> void:
	for tw in _tweens.duplicate():
		if tw.is_valid():
			tw.custom_step(dt)
	_tweens = _tweens.filter(func(t: Tween) -> bool: return t.is_valid())


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
	clear(die)
	play(die, dir)
	calls.append("%d:%d" % [die_id, dir])
	if audio != null and audio.has_method("cue"):
		if audio.call("cue", CUE) == &"":
			audio.call("cue", CUE_FALLBACK)


## Yaw of the die about world Y (its top-face edges follow it).
static func die_yaw(die: Node3D) -> float:
	var x := die.global_basis.x
	var flat := Vector2(x.x, x.z)
	var y := 0.0 if flat.length() < 0.1 else -atan2(flat.y, flat.x)
	# Cube symmetry: pick the top-face edge facing the camera (+z).
	return wrapf(y, -PI / 4.0, PI / 4.0)


## Sweep band in the die's top-face frame: a thin streak lying flat on the
## near (+z, camera-side) bevel, tilted SWEEP_TILT, sliding along that edge.
## Returns [start, end] local XZ centres (multiples of edge).
static func sweep_path(dir: int) -> Array[Vector2]:
	var a := Vector2(-SWEEP_RUN * 0.5, SWEEP_EDGE_Z)
	var b := Vector2(SWEEP_RUN * 0.5, SWEEP_EDGE_Z)
	var out: Array[Vector2] = []
	if dir == NerveState.DOWN:
		out.append_array([b, a])
	else:
		out.append_array([a, b])
	return out


## Distance (x edge) from the face centre to the nearest point of the band
## anywhere along its path, in the top face's depth axis (pips sit inside
## PIP_REACH of the centre).
static func sweep_min_depth() -> float:
	var half_len := SWEEP_LEN * 0.5
	return SWEEP_EDGE_Z - half_len * sin(SWEEP_TILT) - SWEEP_THICK * 0.5


## The sweep + flick + glint at `die` (tests and captures call it directly).
func play(die: Node3D, dir: int) -> void:
	var edge := float(die.get("edge")) if "edge" in die else 0.08
	var c := die.global_position
	var still := _reduced()
	var yaw := die_yaw(die)
	var basis := Basis(Vector3.UP, yaw)
	var top_y := c.y + edge * 0.5 + 0.0015
	var path := sweep_path(dir)
	var p0 := basis * Vector3(path[0].x, 0.0, path[0].y) * edge
	var p1 := basis * Vector3(path[1].x, 0.0, path[1].y) * edge
	var a := Vector3(c.x, top_y, c.z) + p0
	var sw := _piece(&"band", a, p1 - p0, edge * SWEEP_LEN, SWEEP_TIME, SWEEP_COLOR, &"sweep", die, SWEEP_PEAK, false)
	sw.axis = Vector3.AXIS_Y
	sw.rotation = Vector3(0.0, yaw + SWEEP_TILT, 0.0)
	sw.scale = Vector3(1.0, 1.0, SWEEP_THICK / (SWEEP_LEN * STREAK_ASPECT))
	if still:
		return
	var side := 1.0 if c.x <= 0.0 else -1.0
	var f0 := c + Vector3(side * edge * SIDE_MIN * 1.1, 0.0, 0.0)
	_piece(&"glint_streak", f0, flick_dir(dir) * FLICK_SLIDE, edge * 1.3, FLICK_TIME, SPARK_COLOR, &"flick", die)
	for i in MOTES:
		var s := -1.0 if i % 2 == 0 else 1.0
		var p := c + Vector3(s * edge * (SIDE_MIN + 0.15 * i), -edge * 0.1 * i, flick_dir(dir).z * edge * 0.2)
		var v := Vector3(s * MOTE_DRIFT, -MOTE_DRIFT * 0.5, 0.0)
		_piece(&"spark_dot_soft", p, v, edge * MOTE_SIZE, GLINT_TIME, SPARK_COLOR, &"mote", die)


func _piece(shape: StringName, at: Vector3, move: Vector3, size: float, life: float, tint: Color, kind: StringName, die: Node3D, peak: float = PEAK, billboard: bool = true) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = band_texture() if shape == &"band" else TriggerShapes.texture(shape, tint)
	s.modulate = Color(tint.r * peak, tint.g * peak, tint.b * peak, 1.0)
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED if billboard else BaseMaterial3D.BILLBOARD_DISABLED
	s.shaded = false
	s.double_sided = true
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	s.render_priority = 10
	s.top_level = true
	if s.texture != null:
		s.pixel_size = size / float(maxi(s.texture.get_width(), 1))
	s.set_meta("move", move)
	s.set_meta("origin", at)
	s.set_meta("kind", kind)
	s.set_meta("life", life)
	s.set_meta("die", die)
	add_child(s)
	s.global_position = at
	pieces.append(s)
	var tw := s.create_tween().set_ignore_time_scale(true).set_parallel(true)
	tw.tween_property(s, "global_position", at + move, life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(s, "modulate:a", 0.0, life).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func() -> void:
		pieces.erase(s)
		s.queue_free())
	s.set_meta("tween", tw)
	if hold:
		tw.pause()
		_tweens.append(tw)
	return s
