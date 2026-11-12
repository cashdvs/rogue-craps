## FrostLook: the dead-face look. A table rule whose can_light() says no
## (Cold Sixes, Mister Wick, the Pit Boss lock, Madame Shuffle's stopgap)
## keeps that face from scoring. ColdRuleText.can_score is that check.
## The die is a dim, desaturated frost, its pips fade, and a small "✕"
## sits on the top face so a pair of locked 3s cannot be read as live.
## No glow: body and pip emission stay at 0 (the cap is 0.3).
class_name FrostLook
extends RefCounted

## Shader switch on the die's body (and its d4 flat pass).
const PARAM := "die_frost"
## Cool grey, not a bright blue. Multiplied by DIM in the shader.
const TINT := Vector3(0.55, 0.64, 0.74)
## How far the frost colour is pulled down. 1 would be a tint only.
const DIM := 0.58
## Pip ink is pulled this far toward DEAD_PIP while the dead face is up.
const DEAD_PIP := Color(0.30, 0.36, 0.42)
const DEAD_PIP_MIX := 0.86
const MARK_NAME := "FrostMark"


## Turns the dead look on or off for [param d].
static func set_frost(d: DieVisual, on: bool) -> void:
	if d == null or d.body_material == null:
		return
	var v := 1.0 if on else 0.0
	for m in [d.body_material, d.body_material.next_pass]:
		if m is ShaderMaterial:
			var sm := m as ShaderMaterial
			sm.set_shader_parameter(PARAM, v)
			sm.set_shader_parameter("frost_tint", TINT)
			sm.set_shader_parameter("frost_dim", DIM)
			if on:
				# A dead die never keeps the lit rim, even mid-tween.
				sm.set_shader_parameter("die_lit", 0.0)
				sm.set_shader_parameter("die_cold", 1.0)
				sm.set_shader_parameter("emission_energy", 0.0)
	d.set_meta(&"frosted", on)
	# Apply now. The cold fade tween also calls this, but a test (and a
	# fast throw) can read the pips before that tween has finished.
	d._apply_glow(0.0 if on else d.glow_lit, 1.0 if on else d.glow_cold)
	_mark(d, on)


## True if [param d] currently shows the dead look.
static func is_frosted(d: DieVisual) -> bool:
	return d != null and bool(d.get_meta(&"frosted", false))


## Pip colour. A dead face fades its ink; any other face uses [param mix]
## (the ordinary cold fade, or 0 when the die is lit).
static func pip_albedo(d: DieVisual, ink: Color, cold_body: Color, mix: float) -> Color:
	if is_frosted(d):
		return ink.lerp(DEAD_PIP, DEAD_PIP_MIX)
	return ink.lerp(cold_body, mix)


## Pip glow. A dead face emits nothing. Anything else stays at or under 0.3.
static func pip_glow(d: DieVisual, energy: float) -> float:
	if is_frosted(d):
		return 0.0
	return minf(energy, 0.3)


## The "✕" on the top face, or null when the die is not dead.
static func mark(d: DieVisual) -> Label3D:
	if d == null:
		return null
	return d.get_node_or_null(MARK_NAME) as Label3D


## Lays a flat unlit "✕" on the world-up face. Hidden when [param on] is false.
static func _mark(d: DieVisual, on: bool) -> void:
	var m := mark(d)
	if not on:
		if m != null:
			m.visible = false
		return
	if m == null:
		m = Label3D.new()
		m.name = MARK_NAME
		m.text = "✕"
		m.font_size = 48
		m.pixel_size = 0.00085
		m.outline_size = 10
		m.modulate = Color(0.78, 0.86, 0.94)
		m.outline_modulate = Color(0.05, 0.07, 0.10, 0.95)
		m.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		m.shaded = false
		m.double_sided = false
		m.no_depth_test = false
		m.alpha_cut = Label3D.ALPHA_CUT_DISCARD
		d.add_child(m)
	var axis := (d.global_transform.basis.inverse() * Vector3.UP).normalized()
	if axis.length_squared() < 0.5:
		axis = Vector3.UP
	var hint := Vector3.FORWARD if absf(axis.dot(Vector3.UP)) > 0.9 else Vector3.UP
	m.basis = Basis.looking_at(axis, hint)
	m.position = axis * d.edge * 0.54
	m.visible = true
