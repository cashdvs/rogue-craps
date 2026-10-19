## Drives the Twin Face glow mask on a Powder Keg body material
## (`shaders/3d/toon_noir_twin.gdshader`). Sets the `settled` uniform with a
## short fade-in (~0.12 s) when the die lands, and clears it on throw so the
## Ember glyph stays dark while rolling (Art Director option Cp; 3D Artist
## hookup). Glow only — never flame; colour is Palette.EMBER via the shader.
##
## Bind a ShaderMaterial, then either:
## - `bind_events(table.events)` (prefers `dice_settled` / `dice_thrown` when
##   present; guarded with has_signal), or
## - `bind_die(die_visual)` using DieVisual.settled / rest as a fallback.
class_name TwinFaceGlow
extends Node

## Fade-in length after settle (seconds, ignore_time_scale).
const FADE_IN: float = 0.12
## Shader uniform names (must match twin_face_mask.gdshaderinc).
const PARAM_SETTLED := &"settled"
const PARAM_GLOW := &"twin_glow"
const PARAM_STRENGTH := &"twin_strength"
const PARAM_HALO := &"twin_halo_strength"
const PARAM_UNLIT := &"twin_unlit"
const PARAM_UP_LO := &"up_lo"
const PARAM_UP_HI := &"up_hi"
const PARAM_MASK := &"twin_mask"

## Up ramp: smoothstep(up_lo, up_hi, world_n.y) (AD final VALUES.md).
const DEFAULT_UP_LO: float = 0.80
const DEFAULT_UP_HI: float = 0.92
## Core emission strength (AD-approved 1.6).
const DEFAULT_STRENGTH: float = 1.6
## Halo emission strength: emission += glow * halo_strength * G.
const DEFAULT_HALO_STRENGTH: float = 1.6
## Unlit inlay albedo #403440 (renders ~#692B16 under the Hearth lamp).
const DEFAULT_UNLIT := Color("#403440")

## The keg body ShaderMaterial (toon_noir_twin).
var material: ShaderMaterial
## Target settled 0..1 (1 = landed).
var _target: float = 0.0
## Current settled 0..1 (smoothly follows _target).
var _value: float = 0.0
var _events: Object
var _die: Node
## Optional die_id filter when listening to table.events.dice_settled(die_id,...).
var die_id: int = -1


func _ready() -> void:
	set_process(true)


## Points this driver at a toon_noir_twin material and applies Ember defaults.
func bind_material(m: ShaderMaterial) -> void:
	material = m
	if material == null:
		return
	material.set_shader_parameter(PARAM_GLOW, Palette.EMBER)
	material.set_shader_parameter(PARAM_STRENGTH, DEFAULT_STRENGTH)
	material.set_shader_parameter(PARAM_HALO, DEFAULT_HALO_STRENGTH)
	material.set_shader_parameter(PARAM_UNLIT, DEFAULT_UNLIT)
	material.set_shader_parameter(PARAM_UP_LO, DEFAULT_UP_LO)
	material.set_shader_parameter(PARAM_UP_HI, DEFAULT_UP_HI)
	material.set_shader_parameter(PARAM_SETTLED, _value)


## Listen to table.events when present (dice_settled / dice_thrown).
## Safe no-op if the node has neither signal yet.
func bind_events(ev: Object) -> void:
	_unbind_events()
	_events = ev
	if ev == null:
		return
	if ev.has_signal(&"dice_settled"):
		ev.connect(&"dice_settled", _on_events_settled)
	if ev.has_signal(&"dice_thrown"):
		ev.connect(&"dice_thrown", _on_events_thrown)


## Fallback when TableEvents isn't on the table: DieVisual.settled / rest.
func bind_die(d: Node) -> void:
	_unbind_die()
	_die = d
	if d == null:
		return
	if d.has_signal(&"settled"):
		d.connect(&"settled", _on_die_settled)
	if d.has_signal(&"rest"):
		# rest fires at physical stop; we still wait for settled (reveal) to light.
		pass
	if d.has_signal(&"impact"):
		# First impact of a new throw shouldn't light; clear on any fresh motion tip:
		# Table clears via dice_thrown. Without events, clear when settled face changes
		# only through set_settled(false) from the owner.
		pass


## Snap or aim the settled gate. `on` true fades in; false clears immediately
## so a new throw never shows a lingering glow.
func set_settled(on: bool) -> void:
	_target = 1.0 if on else 0.0
	if not on:
		_value = 0.0
		_apply()


## GDScript mirror of the shader's up-facing weight (for headless tests).
static func up_weight(world_normal: Vector3, up_lo: float = DEFAULT_UP_LO, up_hi: float = DEFAULT_UP_HI) -> float:
	if world_normal.length_squared() < 1e-8:
		return 0.0
	var y := world_normal.normalized().y
	return smoothstep(up_lo, up_hi, y)


## Gated inlay / halo weights (mirror of twin_mask_sample).
static func mask_lit(mask_r: float, mask_g: float, settled: float, world_normal: Vector3, up_lo: float = DEFAULT_UP_LO, up_hi: float = DEFAULT_UP_HI) -> Vector2:
	var gate := clampf(settled, 0.0, 1.0) * up_weight(world_normal, up_lo, up_hi)
	return Vector2(mask_r * gate, mask_g * gate)


func _process(delta: float) -> void:
	if is_equal_approx(_value, _target):
		return
	if _target > _value:
		var step := delta / FADE_IN if FADE_IN > 0.0 else 1.0
		_value = minf(_target, _value + step)
	else:
		_value = _target
	_apply()


func _apply() -> void:
	if material != null:
		material.set_shader_parameter(PARAM_SETTLED, _value)


func _on_events_settled(id: Variant = null, _face: Variant = null) -> void:
	if die_id >= 0 and id != null and int(id) != die_id:
		return
	set_settled(true)


func _on_events_thrown(_flick: Variant = null) -> void:
	set_settled(false)


func _on_die_settled(_id: Variant = null, _face: Variant = null) -> void:
	set_settled(true)


func _unbind_events() -> void:
	if _events == null or not is_instance_valid(_events):
		_events = null
		return
	if _events.has_signal(&"dice_settled") and _events.is_connected(&"dice_settled", _on_events_settled):
		_events.disconnect(&"dice_settled", _on_events_settled)
	if _events.has_signal(&"dice_thrown") and _events.is_connected(&"dice_thrown", _on_events_thrown):
		_events.disconnect(&"dice_thrown", _on_events_thrown)
	_events = null


func _unbind_die() -> void:
	if _die == null or not is_instance_valid(_die):
		_die = null
		return
	if _die.has_signal(&"settled") and _die.is_connected(&"settled", _on_die_settled):
		_die.disconnect(&"settled", _on_die_settled)
	_die = null


func _exit_tree() -> void:
	_unbind_events()
	_unbind_die()
