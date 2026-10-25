## Puts the 3D Soul Reliquary (art/models/props/soul_reliquary, #150) on the
## Bonfire table and drives it from the real run (issue #149 / #167). It
## replaces the flat 2D Soul bar (SoulMeter), which the table now hides.
##
## What it does:
##   - picks the PC prop or the phone prop for the screen shape, and puts it
##     at the Hearth board's marker for that layout (PC rail, landscape
##     phone rail, portrait rail lip with the stacked "cur over max" plate);
##   - sync(run): the liquid fill and the "cur/max" plate follow run.soul and
##     run.max_soul; `lethal` (the crack on the plate frame) is on when the
##     next bust would take the last Soul; frost at low Soul is the prop's;
##   - loss: a red ghost of the lost chunk for ~0.5 s and a floating "-N";
##     a bust adds a sharp shudder, Soul paid by choice a softer one;
##   - heal: a floating "+N" and a short cyan brighten;
##   - plate_rect(): the plate's box on screen, for the bust crack overlay,
##     the felt band margin and the onboarding hint arrows.
class_name SoulReliquaryHookup
extends Node3D

const PC_SCENE := "res://art/models/props/soul_reliquary/scenes/soul_reliquary.tscn"
const PHONE_SCENE := "res://art/models/props/soul_reliquary/scenes/soul_reliquary_mobile.tscn"
## Layouts (same names the table uses).
const PC := &"pc"
const PHONE := &"phone"
const PORTRAIT := &"portrait"
## The Hearth board's Anchors/SoulReliquary* markers (table coordinates).
const MARKERS := {
	&"pc": Transform3D(Basis.IDENTITY, Vector3(-1.07, 0.105, 0.14)),
	&"phone": Transform3D(Basis.IDENTITY, Vector3(-1.07, 0.105, 0.195)),
	&"portrait": null,  # filled in _portrait_marker() (yaw 90, scale 0.65)
}
## The portrait marker exactly as written in hearth_board.tscn.
const PORTRAIT_TSCN := "Transform3D(0, 0, 0.65, 0, 0.65, 0, -0.65, 0, 0, -0.12, 0.104, 0.555)"
## Danger red for the lost chunk and "-N"; Soul cyan for "+N".
const LOSS_RED := Color("#FF2E3E")
const HEAL_CYAN := Color("#4FE6E0")
const GHOST_TIME := 0.5

## The prop (soul_reliquary.gd); null before the first layout().
var prop: Node3D = null
## Which layout the prop is placed for.
var layout_kind: StringName = &""
## Cuts every animation to its end (Options > Reduced motion).
var reduced_motion := false
## The Soul the plate shows right now (tests read this).
var shown_soul := -1
var shown_max := -1
## The next Soul drop is a bust (sharper shudder) - set by bust().
var _next_is_bust := false
## Was the last Soul drop shown as a bust? (tests)
var last_loss_was_bust := false
## The last "-N" / "+N" shown (tests).
var last_delta := ""
var _marker: Marker3D = null
var _run: BonfireRun = null


## Places the prop for this layout. Swaps PC <-> phone prop if needed.
func layout(kind: StringName) -> void:
	if kind == layout_kind and prop != null:
		return
	var want_phone := kind != PC
	var had_phone := layout_kind != PC and layout_kind != &""
	if prop != null and want_phone != had_phone:
		_marker.queue_free()
		prop = null
	layout_kind = kind
	if prop == null:
		_marker = Marker3D.new()
		_marker.name = "SoulReliquaryMarker"
		add_child(_marker)
	_marker.transform = marker_for(kind)
	_clear_key = []
	nudge = Vector3.ZERO
	# The prop reads its plate layout from its parent marker in _ready().
	_marker.set_meta(&"plate_layout", "stacked" if kind == PORTRAIT else "row")
	if prop == null:
		prop = (load(PHONE_SCENE if want_phone else PC_SCENE) as PackedScene).instantiate() as Node3D
		_marker.add_child(prop)
		# The vessel material is shared: clear a ghost a freed prop left lit.
		prop.set_ghost(0.0, 0.0)
		if shown_max > 0:
			prop.set_soul(shown_soul, shown_max, false)
	else:
		prop.plate_layout = "stacked" if kind == PORTRAIT else "row"
	prop.reduced_motion = reduced_motion


## The marker transform for a layout (table coordinates).
static func marker_for(kind: StringName) -> Transform3D:
	if kind == PORTRAIT:
		return str_to_var(PORTRAIT_TSCN)
	return MARKERS[kind]


## Shows the run's Soul. animate = false snaps (a new table).
func sync(run: BonfireRun, animate: bool = true) -> void:
	if run == null or prop == null:
		return
	_watch(run)
	var s := run.soul
	var m := run.max_soul
	var before := shown_soul
	var before_fill := float(shown_soul) / maxf(1.0, float(shown_max))
	prop.reduced_motion = reduced_motion
	prop.set_soul(s, m, animate and before >= 0)
	prop.lethal = s > 0 and s <= run.soul_cost(run.tuning.bust_soul_loss, &"bust")
	shown_soul = s
	shown_max = m
	if animate and before >= 0 and s != before:
		if s < before:
			_lose(before - s, before_fill)
		else:
			_heal(s - before)
	_next_is_bust = false


## Listens to the run's table events so a bust's Soul drop plays as a
## bust even when the HUD refreshes before the bust overlay.
func _watch(run: BonfireRun) -> void:
	if run == _run:
		return
	_run = run
	run.table_event.connect(func(kind: StringName, _r: Dictionary) -> void:
		if kind == &"bust":
			_next_is_bust = true)


## A bust happened: the next Soul drop reads as a bust. Re-syncs the plate
## and returns its screen box for the crack overlay.
func bust(run: BonfireRun, cam: Camera3D) -> Rect2:
	_next_is_bust = true
	sync(run)
	return plate_rect(cam)


## Slides the prop along the rail (table x / z, up to MAX_NUDGE m) until
## its plate is clear of `avoid` (screen px), e.g. the Throw / Bank column
## in portrait. Tries the smallest moves first; stays put if none works.
## Returns the offset used (tests read nudge).
const MAX_NUDGE := 0.4
var nudge := Vector3.ZERO
var _clear_key := []
func clear_of(avoid: Rect2, cam: Camera3D) -> Vector3:
	if prop == null or cam == null:
		return Vector3.ZERO
	# Same screen, same column, same camera: the answer hasn't changed.
	var key := [avoid, cam.get_viewport().get_visible_rect().size, cam.global_transform, layout_kind]
	if key == _clear_key:
		return nudge
	_clear_key = key
	var home := marker_for(layout_kind)
	nudge = Vector3.ZERO
	_marker.transform = home
	if not plate_rect(cam).intersects(avoid):
		return nudge
	var step := 0.02
	var d := step
	while d <= MAX_NUDGE + 0.001:
		for dir in [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]:
			_marker.transform = home.translated(dir * d)
			var r := plate_rect(cam)
			if r.size.x > 0.0 and not r.intersects(avoid):
				nudge = dir * d
				return nudge
		d += step
	_marker.transform = home
	return nudge


## The digits plate on screen (for overlays, margins and hint arrows).
func plate_rect(cam: Camera3D) -> Rect2:
	if prop == null or cam == null or not prop.is_inside_tree():
		return Rect2()
	var r := Rect2()
	var first := true
	# Row plate (PC / landscape) or the stacked plate (portrait); hidden
	# parts are skipped, so only the plate on show counts.
	for path in ["Rig/Plate", "Rig/Frame", "Rig/Stacked/Plate", "Rig/Stacked/Frame"]:
		var mi := prop.get_node_or_null(path) as VisualInstance3D
		if mi == null or not mi.is_visible_in_tree():
			continue
		var box := mi.get_aabb()
		for i in 8:
			var world := mi.global_transform * box.get_endpoint(i)
			if cam.is_position_behind(world):
				continue
			var p := cam.unproject_position(world)
			r = Rect2(p, Vector2.ZERO) if first else r.expand(p)
			first = false
	return r


## Lost Soul: red ghost of the chunk, "-N", a shudder (sharper on a bust).
func _lose(n: int, from_fill: float) -> void:
	last_loss_was_bust = _next_is_bust
	_float_text("-%d" % n, LOSS_RED)
	if reduced_motion:
		return
	prop.set_ghost(from_fill, 1.0)
	var tw := prop.create_tween()  # dies with the prop if it is swapped
	var p := prop  # this prop, not whichever one is current later
	tw.tween_method(func(a: float) -> void: p.set_ghost(from_fill, a), 1.0, 0.0, GHOST_TIME)
	_shudder(0.006 if _next_is_bust else 0.002, 0.3 if _next_is_bust else 0.2)


## Healed: "+N" and a short cyan brighten (the prop clamps at full).
func _heal(n: int) -> void:
	_float_text("+%d" % n, HEAL_CYAN)
	if reduced_motion:
		return
	var tw := prop.create_tween()  # dies with the prop if it is swapped
	tw.tween_property(prop, "pulse", 1.0, 0.12)
	tw.tween_property(prop, "pulse", 0.0, 0.35)


## Quick side-to-side shake of the whole prop.
func _shudder(amount: float, time: float) -> void:
	var rig := prop.get_node_or_null("Rig") as Node3D
	if rig == null:
		return
	var home := rig.position
	var tw := prop.create_tween()  # dies with the prop if it is swapped
	var steps := 6
	for i in steps:
		var side := amount * (1.0 - float(i) / steps) * (1.0 if i % 2 == 0 else -1.0)
		tw.tween_property(rig, "position", home + Vector3(side, 0, 0), time / steps)
	tw.tween_property(rig, "position", home, 0.03)


## "-N" / "+N" rising from the top of the cage, fading out.
func _float_text(text: String, color: Color) -> void:
	var at := prop.get_node_or_null("Rig/Cage/Top/DeltaAnchor") as Node3D
	last_delta = text
	var l := Label3D.new()
	l.name = "SoulDelta"
	l.text = text
	l.modulate = color
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.outline_size = 12
	l.font_size = 64
	l.pixel_size = 0.0006
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.shaded = false
	(at if at != null else prop).add_child(l)
	if reduced_motion:
		get_tree().create_timer(0.6).timeout.connect(l.queue_free)
		return
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", 0.05, 0.8)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tw.tween_callback(l.queue_free)
