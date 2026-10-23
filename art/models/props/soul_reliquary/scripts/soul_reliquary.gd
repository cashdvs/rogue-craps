@tool
## The Soul Reliquary (world_props_v1 §2.2; AD pick health_3d #1): the 3D Soul meter on the near rail.
## Pure presentation: no game rules here. Godot Dev drives it with set_soul(cur, max) (and lethal when the
## next bust would kill). The numeral on the dark base plate is the source of truth ("cur/max", Label3D);
## the Soul-cyan liquid (shader `fill`) is secondary. When max Soul grows the cage stretches up in steps
## FIRST, then the liquid rises. Frost (glass only) shows at soul <= SOUL_FROST_AT; the lethal crack sits
## on the plate frame only. Neither ever covers the digits (separate meshes, test_soul_reliquary.gd).
## VFX hooks, not driven here: set_ghost() (red lost chunk), pulse (heartbeat), DeltaAnchor ('-N').
## Moves are stepped on twos (12 fps); reduced_motion cuts straight to the end values.
class_name SoulReliquary
extends Node3D

const STEP := 1.0 / 12.0
const SOUL_FROST_AT := 5              # tunable display constant (world_props_v1 §2.2)
const TICK_SOUL := 5                  # etched tick every 5 Soul
const BASE_MAX := 35                  # starting max Soul: the cage at its base height
const GROW_SOUL := 5                  # one cage step per started 5 max Soul above BASE_MAX
const GROW_H := 0.012                 # cage stretch per step (Rig-local metres)
const MAX_STEPS := 8
const VES_H := 0.100                  # vessel height at BASE_MAX (Rig-local)
const DOME_H := 0.012
const RING_H := 0.010                  # cage ring height (Rig-local m): hides the vessel's bottom/top, so fill maps inside
const DIGIT_CAP := 0.0320             # numeral cap height (Rig-local m) before the width fit
const DIGIT_W := 0.124                # digit window width (frame inner) minus a margin
const DUR_GROW := 0.33
const DUR_FILL := 0.42

@export var soul := 35:
	set(v):
		set_soul(v, max_soul)
@export var max_soul := 35:
	set(v):
		set_soul(soul, v)
## Next bust kills: the plate frame cracks (Godot Dev sets it; the art only shows it).
@export var lethal := false:
	set(v):
		lethal = v
		_apply_flags()
@export var reduced_motion := false
## Heartbeat hook (VFX owner animates it 0..1): brightens the liquid.
@export_range(0.0, 1.0) var pulse := 0.0:
	set(v):
		pulse = v
		_param("pulse", v)

var _soul := 35
var _max := 35
var height := VES_H                    # current shown vessel height
var fill := 1.0                        # current shown fill
var _segs: Array = []                  # [[{"height": h, "fill": f}, dur], ...]
var _from := {}
var _t := 0.0
var _acc := 0.0


func _ready() -> void:
	height = height_for(_max)
	fill = fill_for(_soul, _max)
	_apply()
	_apply_flags()


## Cage/vessel height (Rig-local) for a max Soul value: stepped.
static func steps_for(m: int) -> int:
	return clampi(ceili(float(m - BASE_MAX) / GROW_SOUL), 0, MAX_STEPS)


static func height_for(m: int) -> float:
	return VES_H + GROW_H * steps_for(m)


static func fill_for(s: int, m: int) -> float:
	return clampf(float(s) / maxf(1.0, float(m)), 0.0, 1.0)


func label_text() -> String:
	return "%d/%d" % [_soul, _max]


## Main entry. Grows the cage first (if max went up), then moves the liquid.
func set_soul(s: int, m: int, animate := true) -> void:
	m = maxi(1, m)
	s = clampi(s, 0, m)
	var grew := m > _max
	_soul = s
	_max = m
	if not is_inside_tree():
		height = height_for(m)
		fill = fill_for(s, m)
		return
	var h1 := height_for(m)
	var f1 := fill_for(s, m)
	if not animate or reduced_motion:
		_segs.clear()
		height = h1
		fill = f1
	else:
		_from = {"height": height, "fill": fill}
		_t = 0.0
		_segs.clear()
		if grew and h1 != height:
			# the old liquid keeps its absolute level while the glass stretches, then rises
			_segs.append([{"height": h1, "fill": fill * height / h1}, DUR_GROW])
		_segs.append([{"height": h1, "fill": f1}, DUR_FILL])
	_apply()
	_apply_flags()


## Red ghost chunk hook (VFX owner): the lost Soul from the current fill up to fill_top, at alpha.
func set_ghost(fill_top: float, alpha: float) -> void:
	_param("ghost_fill", fill_top)
	_param("ghost_alpha", alpha)


func is_moving() -> bool:
	return not _segs.is_empty()


func frosted() -> bool:
	return _soul <= SOUL_FROST_AT


func _process(delta: float) -> void:
	if _segs.is_empty():
		return
	_acc += delta
	if _acc < STEP:
		return
	var dt := floorf(_acc / STEP) * STEP
	_acc -= dt
	_t += dt
	var seg: Array = _segs[0]
	var k := clampf(_t / float(seg[1]), 0.0, 1.0)
	k = 1.0 - pow(1.0 - k, 2.0)
	var to: Dictionary = seg[0]
	height = lerpf(_from.height, to.height, k)
	fill = lerpf(_from.fill, to.fill, k)
	if _t >= float(seg[1]):
		_segs.pop_front()
		_from = to.duplicate()
		_t = 0.0
	_apply()


func _mat() -> ShaderMaterial:
	var v := get_node_or_null("Rig/Cage/Vessel") as MeshInstance3D
	if v == null:
		return null
	var m := v.get_surface_override_material(0) as ShaderMaterial
	if m == null:
		# per-instance copy: two reliquaries (or the editor) never share a fill
		m = (v.mesh.surface_get_material(0) as ShaderMaterial).duplicate() as ShaderMaterial
		v.set_surface_override_material(0, m)
		var d := get_node_or_null("Rig/Cage/Top/Dome") as MeshInstance3D
		if d:
			d.set_surface_override_material(0, m)
	return m


func _param(k: String, v: Variant) -> void:
	var m := _mat()
	if m:
		m.set_shader_parameter(k, v)


func _apply() -> void:
	var cage := get_node_or_null("Rig/Cage") as Node3D
	if cage == null:
		return
	(cage.get_node("Vessel") as Node3D).scale.y = height
	(cage.get_node("Bars") as Node3D).scale.y = height
	(cage.get_node("Top") as Node3D).position.y = height
	var lo := RING_H / height
	var hi := 1.0 - RING_H / height
	(cage.get_node("LiquidTop") as Node3D).position.y = height * (lo + (hi - lo) * fill)
	_param("fill_lo", lo)
	_param("fill_hi", hi)
	_param("fill", fill)
	_param("tick_step", float(TICK_SOUL) / float(_max))
	var lbl := get_node_or_null("Rig/Digits") as Label3D
	if lbl:
		lbl.text = label_text()
		# cap height DIGIT_CAP; long values ("120/120") shrink to fit the window, never overflow the frame
		var f := lbl.font
		var cap := 0.7 * lbl.font_size
		var w := f.get_string_size(lbl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, lbl.font_size).x
		var ps := DIGIT_CAP / cap
		if w * ps > DIGIT_W:
			ps = DIGIT_W / w
		lbl.pixel_size = ps


func _apply_flags() -> void:
	var c := get_node_or_null("Rig/Crack") as Node3D
	if c:
		c.visible = lethal
	_param("frost", 1.0 if _soul <= SOUL_FROST_AT else 0.0)
