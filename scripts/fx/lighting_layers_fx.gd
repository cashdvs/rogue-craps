## VFX half of lighting_layers_spec.md: layer 4 (ContactShadows) and layer 5
## (LampDust). One add_child in Table3D (Bonfire3D inherits it); the lights
## and Environment (layers 1-3) are Godot Dev's, in table_3d.gd / lamp_3d.gd.
class_name LightingLayersFx
extends Node3D

var shadows: ContactShadows
var dust: LampDust


func _init() -> void:
	name = "LightingLayersFx"
	shadows = ContactShadows.new()
	dust = LampDust.new()
	add_child(shadows)
	add_child(dust)


func _ready() -> void:
	bind(get_parent())


## render_method "" = the renderer running now (Table3D.render_method or the
## project setting).
func bind(t: Node, render_method: String = "") -> void:
	if render_method == "" and t != null and "render_method" in t:
		render_method = str(t.get("render_method"))
	var fplus := Table3D.is_forward_plus(render_method)
	shadows.bind(t, fplus)
	dust.bind(t, not fplus)
