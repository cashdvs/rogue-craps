## Hearth brazier pot (goal_plaque_scene at Anchors/TargetPlate): iron bowl + iron goal plaque
## (NumberAnchor) + a 4-step toon fire inside (fire_style.md tiers, Board A's fire scaled to the pot).
## step 0 = coals only, 1 = one tongue, 2 = 3-tongue crown, 3 = 5 tongues + ember sparks,
## 4 = twisting column + brass spiral sparks + smoke curl cap. heat = 1 normal, 0 = snuffed (the bust).
## wisp = smoke wisp progress 0-1 (bust_snuff drives it). Visual only.
@tool
extends Node3D

@export_range(0, 4) var step: int = 1:
	set(v):
		step = clampi(v, 0, 4)
		_apply()
@export_range(0.0, 1.0) var heat: float = 1.0:
	set(v):
		heat = clampf(v, 0.0, 1.0)
		_apply()
@export_range(0.0, 1.0) var wisp: float = 0.0:
	set(v):
		wisp = clampf(v, 0.0, 1.0)
		_apply()


func _ready() -> void:
	_apply()


func _apply() -> void:
	var fire := get_node_or_null("Fire")
	if fire == null:
		return
	var lit := heat > 0.001
	for i in range(1, 5):
		var g := fire.get_node_or_null("Step%d" % i) as Node3D
		if g != null:
			g.visible = lit and i == step
			HearthProps.set_param(g, &"heat", heat)
	var coals := HearthProps.mesh_of(get_node_or_null("Model"))
	if coals != null:
		coals.set_instance_shader_parameter(&"level", float(step) + 0.6)
		coals.set_instance_shader_parameter(&"heat", heat)
	HearthProps.wisp(get_node_or_null("Wisp") as Node3D, wisp if step > 0 else 0.0)


var _twist_t: float = 0.0


func _process(delta: float) -> void:
	# The column twists, stepped at 12 fps (on twos): drawn, not tweened. Scene time (delta), so it stops on pause.
	_twist_t += delta
	var tw := get_node_or_null("Fire/Step4/Twist") as Node3D
	if tw != null and step == 4:
		tw.rotation.y = floorf(_twist_t * 12.0) / 12.0 * 1.6
