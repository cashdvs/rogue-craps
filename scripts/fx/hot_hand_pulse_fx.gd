## Hot Hand pulse (AD spec): while the hand is HOT (events.hot_hand until the
## hand ends: banked, bust, table_started or table_cleared), every lit die's
## ember hull outline (DieVisual.hull_outline, die_hull_outline.gdshader)
## breathes: width 1.0-1.5x the base 0.010 m on a 0.9 s sine, colour
## #E8622A -> #FFA13A in step with the width. Emission is held at 0.3 (never
## above, never pulsed). Reduced motion: a static 1.25x outline at the
## midpoint colour. No scale pulse (optional in the spec; left out so the
## die transform stays the sim's). Outline uniforms only: the die body is
## never tinted, no particles, no fire.
class_name HotHandPulseFx
extends Node

const PERIOD := 0.9
const BASE_WIDTH := 0.010
const WIDTH_MIN := 1.0
const WIDTH_MAX := 1.5
const REDUCED_WIDTH := 1.25
const COLOR_LOW := Color("#E8622A")
const COLOR_PEAK := Color("#FFA13A")
const EMISSION := 0.3

## The Table3D this sits under (parent, set in _ready).
var table: Node
## Forces reduced motion on (else read from table.is_reduced_motion()).
@export var reduced_motion: bool = false
var active: bool = false
var _t: float = 0.0
## Dice whose outline this node has changed (restored on stop).
var _touched: Dictionary = {}


func _ready() -> void:
	if table == null:
		table = get_parent()
	var ev: Object = table.get("events") if table != null else null
	if ev == null:
		return
	if ev.has_signal(&"hot_hand"):
		ev.connect(&"hot_hand", func(_c: int) -> void: start())
	if ev.has_signal(&"banked"):
		ev.connect(&"banked", func(_p: int) -> void: stop())
	if ev.has_signal(&"bust"):
		ev.connect(&"bust", func(_s: int, _ids: Array) -> void: stop())
	for sig in [&"table_started", &"table_cleared"]:
		if ev.has_signal(sig):
			ev.connect(sig, stop)


func is_reduced() -> bool:
	if reduced_motion:
		return true
	return table != null and table.has_method(&"is_reduced_motion") and bool(table.call(&"is_reduced_motion"))


## 0..1 pulse phase at time t (0 = low at t=0, 1 = peak at PERIOD/2).
static func phase(t: float) -> float:
	return 0.5 - 0.5 * cos(TAU * t / PERIOD)


## {width_mult, width, color, emission} at time t.
static func sample(t: float, reduced: bool = false) -> Dictionary:
	var k := 0.5 if reduced else phase(t)
	var mult := REDUCED_WIDTH if reduced else lerpf(WIDTH_MIN, WIDTH_MAX, k)
	return {"width_mult": mult, "width": BASE_WIDTH * mult, "color": COLOR_LOW.lerp(COLOR_PEAK, k), "emission": EMISSION}


func start() -> void:
	active = true
	_t = 0.0
	_apply()


func stop() -> void:
	active = false
	for d in _touched.keys():
		if is_instance_valid(d):
			_restore(d)
	_touched.clear()


func _process(delta: float) -> void:
	if active:
		step(delta)


## Advances the pulse by dt seconds and applies it (tests call this directly).
func step(dt: float) -> void:
	_t = fmod(_t + dt, PERIOD)
	_apply()


func current() -> Dictionary:
	return sample(_t, is_reduced())


func _dice() -> Array:
	if table == null or not ("dice" in table):
		return []
	return table.get("dice")


func _apply() -> void:
	var s := current()
	var dice := _dice()
	for d in _touched.keys():
		if not is_instance_valid(d) or not dice.has(d):
			_touched.erase(d)
	for d in dice:
		var dv := d as DieVisual
		if dv == null or dv.hull_outline == null:
			continue
		if not dv.hull_outline.visible or dv.outline_dimmed:
			if _touched.has(dv):
				_restore(dv)
				_touched.erase(dv)
			continue
		var m := dv.hull_outline.material_override as ShaderMaterial
		m.set_shader_parameter("width", float(s["width"]))
		m.set_shader_parameter("color", s["color"])
		m.set_shader_parameter("emission_energy", float(s["emission"]))
		_touched[dv] = true


func _restore(d: DieVisual) -> void:
	if d.hull_outline == null:
		return
	(d.hull_outline.material_override as ShaderMaterial).set_shader_parameter("width", BASE_WIDTH)
	d.call(&"_apply_outline_state")
