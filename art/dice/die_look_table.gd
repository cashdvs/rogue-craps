## NOTE (hookup): DieVisual sets the shader param `albedo`; in toon_die.gdshader
## `albedo` is a MULTIPLIER on `albedo_tint` (keep it white unless tinting on purpose).
## Data-only look table for dice (Godot Dev's hookup interface).
## body_by_die: die id (StringName, DiceIds.DIE_*) -> body material path; key
##   &"default" is the fallback. Pip surfaces use "<body>_pip.tres" if present.
## mark_by_mod: face-mod id -> {"decal": Texture2D or null, "tint": Color,
##   optional "glow_color": Color}. A mark only ever goes on its own face; the
##   body never changes per mod (docs/props/world_props_v1.md section 3).
class_name DieLookTable
extends Resource

@export var body_by_die: Dictionary = {}
@export var mark_by_mod: Dictionary = {}


func body_path(die_id: StringName) -> String:
	return String(body_by_die.get(die_id, body_by_die.get(&"default", "")))


func pip_path(die_id: StringName) -> String:
	var p := body_path(die_id)
	var pp := p.get_basename() + "_pip.tres"
	return pp if ResourceLoader.exists(pp) else ""
