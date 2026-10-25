## SurfaceTool wrapper used by the Soul Reliquary generators (tri/quad with winding fixed from the normals).
extends RefCounted

var st := SurfaceTool.new()
var n := 0
func _init() -> void:
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
func vert(p: Vector3, nrm: Vector3, uv := Vector2.ZERO) -> void:
	st.set_normal(nrm.normalized())
	st.set_uv(uv)
	st.add_vertex(p)
func tri(a: Array, b: Array, c: Array) -> void:   # [pos, normal, uv]; winding fixed from the normals
	var nn: Vector3 = a[1] + b[1] + c[1]
	if ((b[0] - a[0]) as Vector3).cross(c[0] - a[0]).dot(nn) < 0.0:
		var t := b
		b = c
		c = t
	for v in [a, c, b]:                            # Godot front faces are clockwise
		vert(v[0], v[1], v[2])
	n += 1
func quad(a: Array, b: Array, c: Array, d: Array) -> void:
	tri(a, b, c)
	tri(a, c, d)
