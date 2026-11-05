## FrostLook: the "frozen" look for a die a table rule keeps dark (Cold
## Sixes and friends). It sits on top of the normal cold grey: the body is
## tinted cool blue so it reads as "can't score at all" rather than "didn't
## score this time". frost_dim in toon_noir / d4_flat_pass defaults to 1.0,
## so this is a tint only (the Art Director owns any further dim). Material
## only: no glow, no emission, no particles (die_frost uniform).
class_name FrostLook
extends RefCounted

## Shader switch name on the die's body material (and its d4 flat pass).
const PARAM := "die_frost"


## Turns the frost on or off for [param d].
static func set_frost(d: DieVisual, on: bool) -> void:
	if d == null or d.body_material == null:
		return
	var v := 1.0 if on else 0.0
	for m in [d.body_material, d.body_material.next_pass]:
		if m is ShaderMaterial:
			(m as ShaderMaterial).set_shader_parameter(PARAM, v)
	d.set_meta(&"frosted", on)


## True if [param d] currently shows the frost.
static func is_frosted(d: DieVisual) -> bool:
	return d != null and bool(d.get_meta(&"frosted", false))
