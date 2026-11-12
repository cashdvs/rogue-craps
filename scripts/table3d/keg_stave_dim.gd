## Fades every Powder Keg numeral except the one the table scored, once the
## barrel has settled. The scoring stave points straight up, and the camera
## looks down at about 47 degrees, so a neighbouring stave (a different
## number) is the one that faces the lens. KegValueTag still shows the read
## value. This only makes the other printed numbers quieter, so the barrel
## and the tag agree.
##
## The fade is two instance uniforms on the body mesh, not a shared material
## value, so two kegs can show two different numbers:
##   lit_stave = the face value 1, 2 or 3 (0 = every numeral full)
##   stave_dim = 0..1, how far the other numerals have faded
## shaders/3d/keg_stave_dim.gdshaderinc reads them. Both toon_noir and
## toon_noir_twin include it, so a Twin Face material swap keeps the fade.
## No new signals, and no glow: the include only scales ink that is already
## there. Reduced motion and Instant speed skip the short fade.
class_name KegStaveDim
extends Node

## Shader instance uniform: which face value stays readable. 0 = all of them.
const PARAM_LIT := &"lit_stave"
## Shader instance uniform: 0 = full ink, 1 = other staves faded.
const PARAM_DIM := &"stave_dim"
## How long the other numerals take to fade after settle (seconds).
const FADE_SEC := 0.15
## Ink mix a dimmed numeral keeps. Matches KEG_DIM_KEEP in the shader include.
const DIM_KEEP := 0.30
const VALUE_MIN := 1
const VALUE_MAX := 3

## The dressed keg this node fades. Set by attach().
var die: DieVisual
## Face value whose numeral stays full. 0 while rolling.
var _lit: int = 0
## What the barrel was showing the last time the uniform was written, so a
## direct set_read sticks until the up stave actually changes (a Nerve turn).
var _shown: int = 0
## 0..1 fade. 0 = every numeral full.
var _dim: float = 0.0
var _tween: Tween


## Adds a dimmer to [param d] (a dressed Powder Keg) and returns it.
static func attach(d: DieVisual) -> KegStaveDim:
	var n := KegStaveDim.new()
	n.name = "KegStaveDim"
	n.die = d
	d.add_child(n)
	return n


## Face value whose numeral stays full (1, 2 or 3). 0 means all of them do.
func lit_value() -> int:
	return _lit


## How far the fade has gone: 0 = full ink, 1 = other staves faded.
func dim_amount() -> float:
	return _dim


## Atlas cell for a mesh UV. Value v is cell v - 1 (cell 0 at UV ~(0.1, 0.1)).
## The shader's keg_cell_index uses this same floor rule.
static func cell_of_uv(uv: Vector2) -> int:
	var x := int(floor(clampf(uv.x, 0.0, 0.999) * 5.0))
	var y := int(floor(clampf(uv.y, 0.0, 0.999) * 5.0))
	return y * 5 + x


## True when this atlas cell's ink stays at full strength.
## [param lit_value] is the uniform (the face value, not the slot and not
## the cell). Among cells 0, 1 and 2 only cell (lit_value - 1) stays full
## once [param dim] is above 0. Lids and hoops (cell > 2) always stay.
static func cell_is_full(lit_value: float, dim: float, cell: int) -> bool:
	if dim <= 0.001 or lit_value < 0.5:
		return true
	if cell > 2:
		return true
	return absf(float(cell) - (lit_value - 1.0)) < 0.5


func _ready() -> void:
	if die == null:
		die = get_parent() as DieVisual
	if die != null and not die.settled.is_connected(_on_settled):
		die.settled.connect(_on_settled)
	var table := _table()
	if table != null and not table.throw_started.is_connected(_on_throw):
		table.throw_started.connect(_on_throw)


## The barrel settled. Light only the value it is showing now.
func _on_settled(_die_id: int, _face: int) -> void:
	var v := 0
	if die != null:
		v = die.shown_value()
	set_read(v, _wants_instant())


## A new throw: every numeral goes back to full ink at once, before the roll.
func _on_throw() -> void:
	set_read(0, true)


## Marks [param value] as the readable stave. 0 clears the fade (a new throw).
## [param instant] skips the 0.15 s fade: reduced motion, Instant speed, tests.
func set_read(value: int, instant: bool = false) -> void:
	_lit = value if value >= VALUE_MIN and value <= VALUE_MAX else 0
	_shown = die.shown_value() if die != null else _lit
	_kill_tween()
	_push(PARAM_LIT, float(_lit))
	if _lit == 0:
		_dim = 0.0
		_push(PARAM_DIM, 0.0)
		return
	if instant or not is_inside_tree():
		_dim = 1.0
		_push(PARAM_DIM, 1.0)
		return
	var from := _dim
	_tween = create_tween()
	_tween.set_ignore_time_scale(true)
	_tween.tween_method(_set_dim, from, 1.0, FADE_SEC)


func _process(_delta: float) -> void:
	# Only while a stave is lit. A rolling keg (_lit 0) keeps every numeral.
	if _lit == 0 or die == null:
		return
	var v := die.shown_value()
	if v == _shown or v < VALUE_MIN or v > VALUE_MAX:
		return
	_shown = v
	_lit = v
	_push(PARAM_LIT, float(v))


func _set_dim(v: float) -> void:
	_dim = v
	_push(PARAM_DIM, v)


func _push(param: StringName, v: float) -> void:
	var body := _body()
	if body == null:
		return
	body.set_instance_shader_parameter(param, v)


func _body() -> MeshInstance3D:
	if die == null or die.faces == null:
		return null
	return die.faces.get_node_or_null("Body") as MeshInstance3D


func _table() -> Node:
	var n: Node = self
	while n != null:
		if n.has_signal(&"throw_started"):
			return n
		n = n.get_parent()
	return null


## Reduced motion, or the table's Instant speed, snaps the fade.
func _wants_instant() -> bool:
	var n: Node = self
	while n != null:
		if n.has_method(&"is_reduced_motion") and bool(n.call(&"is_reduced_motion")):
			return true
		var mode: Variant = n.get(&"speed_mode")
		if mode != null and int(mode) == 2:
			return true
		n = n.get_parent()
	return false


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _exit_tree() -> void:
	_kill_tween()
