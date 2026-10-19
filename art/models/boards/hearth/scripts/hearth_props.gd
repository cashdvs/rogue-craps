## Shared helpers for the Hearth visual controllers (art only: they set shader instance uniforms
## and node visibility, nothing else; no gameplay, no physics, no signals).
class_name HearthProps
extends RefCounted


## Every GeometryInstance3D under n (n included).
static func geoms(n: Node, out: Array[GeometryInstance3D] = []) -> Array[GeometryInstance3D]:
	if n == null:
		return out
	if n is GeometryInstance3D:
		out.append(n)
	for c in n.get_children():
		geoms(c, out)
	return out


static func set_param(n: Node, param: StringName, value: Variant) -> void:
	for g in geoms(n):
		g.set_instance_shader_parameter(param, value)


## The first MeshInstance3D under n (the mesh of an instanced .glb).
static func mesh_of(n: Node) -> MeshInstance3D:
	if n == null:
		return null
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var m := mesh_of(c)
		if m != null:
			return m
	return null


## A wisp (0 = none, 0-1 = progress of the 0.4 s smoke curl): visible while in (0, 1), heat = 1 - progress.
static func wisp(n: Node3D, progress: float) -> void:
	if n == null:
		return
	n.visible = progress > 0.001 and progress < 0.999
	set_param(n, &"heat", 1.0 - progress)
