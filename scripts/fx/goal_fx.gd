## Table goal FX: listens to TableEvents.goal_reached and goal_missed(soul_loss)
## (#229) and plays a short, visual-only cue on the HUD's TargetPlate. Nothing
## here touches the dice, the run or the pot flow (tweens ignore time scale and
## nothing awaits), so a pot is never slowed.
## - reached: an Ember (#E8622A) flare on the plate, FLARE_TIME long;
## - missed (locked v2 miss state; AD exception to no-red / no-cyan, HUD miss
##   only): the plate dims and "Missed: -N Soul" drops in 8 px under it, left
##   on the plate text: "Missed:" danger red, "-N Soul" Soul cyan, no Ember.
##   N is the soul_loss #229 sends (never recomputed here);
## - reduced motion / Instant: nothing moves; flare / dim / tag hold, then snap off.
## Cleared at once on table_started.
class_name GoalFx
extends Node

const EMBER := Color("#E8622A")
## The flare: an Ember border (FLARE_BORDER px) and a faint Ember wash, a
## first child of the plate so it draws behind the TARGET number and lines.
const FLARE_BORDER: int = 3
const FLARE_WASH: float = 0.11
const FLARE_TIME: float = 0.35
## Plate modulate at the miss dim, and how long the dim and tag last.
const DIM := Color(0.55, 0.5, 0.48)
const DIM_TIME: float = 0.25
const MISS_HOLD: float = 1.4
const DROP_PX: float = 14.0
## "Missed:" reuses goal_miss (TableGoalStrings.MISS, the plate's own miss
## line); the amount is goal_miss_soul_float "-{n} Soul" (strings_v1 row in
## bffe9c3, #231); {n} = goal_missed's soul_loss.
const SOUL_TEXT := "-%d Soul"  # goal_miss_soul_float
## Tag text size: >= 14 px on PC (spec px), >= 12 pt on phone; gap under the plate.
const TAG_PX_PC: float = 14.0
const TAG_PT_PHONE: float = 12.0
const TAG_GAP: float = 8.0

var table: Node
var events: Object
## The plate the cue plays on (found via table.bhud.target_plate; tests set it).
var plate: Control
## The "Missed: -N Soul" tag: an HBox of the two labels (null until a miss).
var soul_tag: HBoxContainer
## The flare overlay (null when no flare is playing).
var flare: Panel
## Every cue played: "reached" or "missed:<soul>" (tests and captures).
var calls: Array[String] = []
## Captures on slow renderers: tweens start paused and advance(dt) steps them.
var hold: bool = false
var _tweens: Array[Tween] = []


func _init() -> void:
	name = "GoalFx"


func _ready() -> void:
	(func() -> void:
		var ev: Variant = get_parent().get("events") if get_parent() != null else null
		if table == null and get_parent() != null:
			bind(ev as Object if ev is Object else null, get_parent())).call_deferred()


## Hooks goal_reached / goal_missed (and table_started to clear) if the events
## node has them. Returns false when #229's signals are missing.
func bind(ev: Object, t: Node) -> bool:
	table = t
	events = ev
	if ev == null or not ev.has_signal(&"goal_reached") or not ev.has_signal(&"goal_missed"):
		return false
	for pair: Array in [[&"goal_reached", reached], [&"goal_missed", missed], [&"table_started", clear]]:
		if ev.has_signal(pair[0]) and not ev.is_connected(pair[0], pair[1]):
			ev.connect(pair[0], pair[1])
	return true


## The target plate to play on, or null (no HUD, e.g. headless table tests).
func find_plate() -> Control:
	if plate != null and is_instance_valid(plate):
		return plate
	var hud: Variant = table.get("bhud") if table != null else null
	if hud is Object and (hud as Object).get("target_plate") is Control:
		plate = (hud as Object).get("target_plate")
	return plate


## True under reduced motion or the Instant speed mode (no movement then).
func is_reduced() -> bool:
	return table != null and ((table.has_method("is_reduced_motion") and bool(table.call("is_reduced_motion")))
		or ("speed_mode" in table and int(table.get("speed_mode")) >= 2))


## Goal reached: the Ember plate flare.
func reached() -> void:
	calls.append("reached")
	var p := find_plate()
	if p == null:
		return
	clear()
	flare = _make_flare(p)
	var tw := _tween(p)
	if is_reduced():
		tw.tween_interval(FLARE_TIME)
	else:
		tw.tween_property(flare, "modulate:a", 0.0, FLARE_TIME).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(clear)


## Goal missed: the plate dims and "Missed: -N Soul" (soul_loss from #229,
## shown as given) drops in under it, then both go back.
func missed(soul_loss: int) -> void:
	calls.append("missed:%d" % soul_loss)
	var p := find_plate()
	if p == null:
		return
	clear()
	var red := is_reduced()
	# Design px per spec px on PC (plate.unit), per pt on phone (hud.ui_pt_px).
	var hud: Variant = table.get("bhud") if table != null else null
	var s := float(hud.get("ui_pt_px")) if is_phone() and "ui_pt_px" in hud else (float(p.get("unit")) if "unit" in p else 1.0)
	var tag := _make_tag(p, soul_loss, s)
	var end_y := p.position.y + p.size.y + TAG_GAP * s
	tag.position = Vector2(p.position.x + p.get_theme_stylebox(&"panel").get_margin(SIDE_LEFT), end_y if red else end_y - DROP_PX)
	var tw := _tween(p).set_parallel(true)
	if red:
		p.modulate = DIM
		tag.modulate.a = 1.0
	else:
		tw.tween_property(p, "modulate", DIM, DIM_TIME)
		tw.tween_property(tag, "position:y", end_y, DIM_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw.tween_property(tag, "modulate:a", 1.0, DIM_TIME)
	tw.chain().tween_interval(MISS_HOLD)
	tw.chain().tween_callback(clear)


## True on a phone layout (landscape or portrait HUD).
func is_phone() -> bool:
	var hud: Variant = table.get("bhud") if table != null else null
	return hud is Object and (bool((hud as Object).get("is_phone_land")) or bool((hud as Object).get("is_portrait")))


## Ends any cue at once: plate back to normal, tag and flare gone.
func clear(_a: Variant = null) -> void:
	for tw in _tweens:
		if tw.is_valid():
			tw.kill()
	_tweens.clear()
	if plate != null and is_instance_valid(plate):
		plate.modulate = Color.WHITE
	for n: Node in [soul_tag, flare]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	soul_tag = null
	flare = null


## Steps held tweens by dt (captures and tests; see `hold`).
func advance(dt: float) -> void:
	for tw in _tweens.duplicate():
		if tw.is_valid():
			tw.custom_step(dt)
	_tweens = _tweens.filter(func(t: Tween) -> bool: return t.is_valid())


func _tween(p: Node) -> Tween:
	var tw := p.create_tween().set_ignore_time_scale(true)
	_tweens.append(tw)
	if hold:
		tw.pause()
	return tw


func _make_tag(p: Control, soul_loss: int, s: float) -> HBoxContainer:
	soul_tag = HBoxContainer.new()
	soul_tag.name = "GoalMissTag"
	soul_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	soul_tag.modulate.a = 0.0
	var px := ceilf((TAG_PT_PHONE if is_phone() else TAG_PX_PC) * s)
	for part: Array in [[TableGoalStrings.MISS.split(" ")[0], Palette.DANGER], [SOUL_TEXT % soul_loss, Palette.SOUL_FLAME]]:
		var l := Label.new()
		l.text = part[0]
		var ls := LabelSettings.new()
		ls.font = Palette.number_font()
		ls.font_color = part[1]
		ls.font_size = int(px)
		ls.outline_size = maxi(2, roundi(px * 0.2))
		ls.outline_color = Color(0.05, 0.03, 0.02)
		l.label_settings = ls
		soul_tag.add_child(l)
	# A sibling of the plate (not a child), so the plate's dim never dims the tag.
	(p.get_parent() if p.get_parent() != null else p).add_child(soul_tag)
	return soul_tag


func _make_flare(p: Control) -> Panel:
	var f := Panel.new()
	f.name = "GoalFlare"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(EMBER, FLARE_WASH)
	sb.border_color = EMBER
	sb.set_border_width_all(FLARE_BORDER)
	# The plate fits it to its content box; expand margins reach the plate edge.
	var ps := p.get_theme_stylebox(&"panel")
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		sb.set_expand_margin(side, ps.get_margin(side) if ps != null else 0.0)
	f.add_theme_stylebox_override(&"panel", sb)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(f)
	p.move_child(f, 0)  # first child: drawn behind the plate's text rows
	return f
