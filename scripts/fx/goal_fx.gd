## Table goal FX: listens to TableEvents.goal_reached and goal_missed(soul_loss)
## (#229) and plays a short, visual-only cue on the HUD's TargetPlate. Nothing
## here touches the dice, the run or the pot flow (tweens ignore time scale and
## nothing awaits), so a pot is never slowed.
## - reached: an Ember (#E8622A) flare on the plate, FLARE_TIME long;
## - missed: the plate dims and an Ember "-N Soul" drops in under it, showing
##   the soul_loss #229 sends (never recomputed here);
## - reduced motion / Instant: no movement; the flare and dim hold still and
##   snap back, the Soul tag shows without the drop.
## Cleared at once on table_started. Guarded with has_signal, so it binds to
## nothing until #229 lands.
class_name GoalFx
extends Node

const EMBER := Color("#E8622A")
## The flare: an Ember border (FLARE_BORDER px) and a faint Ember wash laid
## over the plate (a sibling Panel), fading from full to clear.
const FLARE_BORDER: int = 3
const FLARE_WASH: float = 0.22
const FLARE_TIME: float = 0.35
## Plate modulate at the miss dim, and how long the dim and tag last.
const DIM := Color(0.55, 0.5, 0.48)
const DIM_TIME: float = 0.25
const MISS_HOLD: float = 1.4
const DROP_PX: float = 14.0
## design/strings_v1.md goal_miss_soul_float "-{n} Soul"; {n} = goal_missed's soul_loss.
const SOUL_TEXT := "-%d Soul"  # goal_miss_soul_float
const SOUL_FONT: int = 30

var table: Node
var events: Object
## The plate the cue plays on (found via table.bhud.target_plate; tests set it).
var plate: Control
## The "-N Soul" tag (null until the first miss).
var soul_tag: Label
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
	_bind_to_parent.call_deferred()


func _bind_to_parent() -> void:
	if table != null or get_parent() == null:
		return
	var t := get_parent()
	var ev: Variant = t.get("events")
	bind(ev as Object if ev is Object else null, t)


## Hooks goal_reached / goal_missed (and table_started to clear) if the events
## node has them. Returns false when #229's signals are missing.
func bind(ev: Object, t: Node) -> bool:
	table = t
	events = ev
	if ev == null or not ev.has_signal(&"goal_reached") or not ev.has_signal(&"goal_missed"):
		return false
	if not ev.is_connected(&"goal_reached", reached):
		ev.connect(&"goal_reached", reached)
	if not ev.is_connected(&"goal_missed", missed):
		ev.connect(&"goal_missed", missed)
	if ev.has_signal(&"table_started") and not ev.is_connected(&"table_started", clear):
		ev.connect(&"table_started", clear)
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
	if table == null:
		return false
	if table.has_method("is_reduced_motion") and bool(table.call("is_reduced_motion")):
		return true
	return "speed_mode" in table and int(table.get("speed_mode")) >= 2


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


## Goal missed: the plate dims and the Ember "-N Soul" tag (soul_loss from
## #229, shown as given) drops in under it, then both fade back.
func missed(soul_loss: int) -> void:
	calls.append("missed:%d" % soul_loss)
	var p := find_plate()
	if p == null:
		return
	clear()
	var red := is_reduced()
	var tag := _make_tag(p, soul_loss)
	var end_y := p.position.y + p.size.y + 4.0
	tag.position = Vector2(p.position.x, end_y if red else end_y - DROP_PX)
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


## Ends any cue at once: plate back to normal, Soul tag gone.
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


func _make_tag(p: Control, soul_loss: int) -> Label:
	soul_tag = Label.new()
	soul_tag.name = "GoalSoulTag"
	soul_tag.text = SOUL_TEXT % soul_loss
	var ls := LabelSettings.new()
	ls.font_color = EMBER
	ls.font_size = SOUL_FONT
	ls.outline_size = 6
	ls.outline_color = Color(0.05, 0.03, 0.02)
	soul_tag.label_settings = ls
	soul_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	soul_tag.modulate.a = 0.0
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
	sb.set_expand_margin_all(FLARE_BORDER)
	f.add_theme_stylebox_override(&"panel", sb)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.position = p.position
	f.size = p.size
	(p.get_parent() if p.get_parent() != null else p).add_child(f)
	return f
