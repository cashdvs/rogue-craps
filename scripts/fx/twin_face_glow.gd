## Drives the Twin Face glow mask on a Powder Keg body material
## (`shaders/3d/toon_noir_twin.gdshader`). Sets the `settled` uniform with a
## short fade-in (~0.12 s of real time) when the die lands, and clears it on
## throw so the Ember glyph stays dark while rolling (Art Director option Cp;
## 3D Artist hookup). Glow only — never flame; colour is Palette.EMBER via
## the shader. On the keg material, 3D Artist may set `twin_glow` to
## `#D9480F` (pre-compensated for the lamp); the default stays Ember.
##
## Bind a ShaderMaterial, then either:
## - `bind_events(table.events)` (`dice_settled` / `dice_thrown`, guarded with
##   has_signal), or
## - `bind_die(die_visual)`: lights on `settled`, clears on the next `impact`
##   (start of the following throw) so mid-roll never stays lit.
class_name TwinFaceGlow
extends Node

## Fade-in length after settle (seconds of real time; ignores Engine.time_scale).
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
## Optional DieVisual.die_id filter for bind_die impact/settled. TableEvents
## `dice_settled` has no die_id (table-wide); this filter is ignored there.
var die_id: int = -1
var _last_usec: int = -1


func _ready() -> void:
	set_process(true)
	_last_usec = Time.get_ticks_usec()


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


## Fallback when TableEvents isn't on the table: DieVisual.settled lights the
## glow; DieVisual.impact clears it on the next throw so mid-roll stays dark.
func bind_die(d: Node) -> void:
	_unbind_die()
	_die = d
	if d == null:
		return
	if d.has_signal(&"settled"):
		d.connect(&"settled", _on_die_settled)
	if d.has_signal(&"impact"):
		d.connect(&"impact", _on_die_impact)


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


func _process(_delta: float) -> void:
	# Real-time step so the fade ignores Engine.time_scale (slow-mo / pause).
	var now := Time.get_ticks_usec()
	if _last_usec < 0:
		_last_usec = now
	var dt := clampf(float(now - _last_usec) / 1_000_000.0, 0.0, 0.1)
	_last_usec = now
	if is_equal_approx(_value, _target):
		return
	if _target > _value:
		var step := dt / FADE_IN if FADE_IN > 0.0 else 1.0
		_value = minf(_target, _value + step)
	else:
		_value = _target
	_apply()


func _apply() -> void:
	if material != null:
		material.set_shader_parameter(PARAM_SETTLED, _value)


## TableEvents.dice_settled() has no args (table-wide).
func _on_events_settled() -> void:
	set_settled(true)


func _on_events_thrown(_flick: Variant = null) -> void:
	set_settled(false)


func _on_die_settled(id: Variant = null, _face: Variant = null) -> void:
	if die_id >= 0 and id != null and int(id) != die_id:
		return
	set_settled(true)


## First contact of a new throw: clear so the glyph stays dark mid-roll.
func _on_die_impact(id: Variant = null, _surface: Variant = null, _speed: Variant = null, _impulse: Variant = null, _other: Variant = null, _material: Variant = null) -> void:
	if die_id >= 0 and id != null and int(id) != die_id:
		return
	if _target > 0.0 or _value > 0.0:
		set_settled(false)


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
	if _die.has_signal(&"impact") and _die.is_connected(&"impact", _on_die_impact):
		_die.disconnect(&"impact", _on_die_impact)
	_die = null


func _exit_tree() -> void:
	_unbind_events()
	_unbind_die()
