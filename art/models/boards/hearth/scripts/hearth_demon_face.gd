## Hearth carved demon face (Corner_FL / Corner_FR): only the eyes glow.
## eyes 0 = off, 1 = ember, 2 = hot, 3 = white (Hot Hand stacks). heat = 1 normal, 0 = snuffed. Visual only.
@tool
extends Node3D

@export_range(0, 3) var eyes: int = 0:
	set(v):
		eyes = clampi(v, 0, 3)
		_apply()
@export_range(0.0, 1.0) var heat: float = 1.0:
	set(v):
		heat = clampf(v, 0.0, 1.0)
		_apply()


func _ready() -> void:
	_apply()


func _apply() -> void:
	var m := HearthProps.mesh_of(get_node_or_null("Model"))
	if m != null:
		m.set_instance_shader_parameter(&"level", float(eyes))
		m.set_instance_shader_parameter(&"heat", heat)
