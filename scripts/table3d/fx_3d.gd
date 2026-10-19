## Small 3D effects for the moments (poc_3d.md section 9): particle bursts
## (sparks, embers, soot, felt puffs, dust), a temporary light pulse, felt
## cracks for the seven-out, and the brass shockwave ring for a point hit.
## All are fire-and-forget nodes that free themselves.
class_name Fx3D
extends RefCounted

const PARTICLE_ADD := preload("res://shaders/3d/fx_particle.gdshader")
static var _mix: Shader


static func _mix_shader() -> Shader:
	if _mix == null:
		_mix = Shader.new()
		_mix.code = PARTICLE_ADD.code.replace("blend_add,", "blend_mix,")
	return _mix


## A one-shot CPUParticles3D burst. `colors` = start -> end gradient.
static func burst(parent: Node3D, at: Vector3, amount: int, colors: Array[Color], speed: Vector2, spread_deg: float, gravity: float, size: Vector2, life: float, energy: float = 1.0, additive: bool = true, direction: Vector3 = Vector3.UP) -> void:
	if amount <= 0:
		return
	var p := CPUParticles3D.new()
	p.position = at
	p.amount = amount
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = life
	p.direction = direction
	p.spread = spread_deg
	p.initial_velocity_min = speed.x
	p.initial_velocity_max = speed.y
	p.gravity = Vector3(0, gravity, 0)
	p.damping_min = 0.5
	p.damping_max = 2.0
	p.scale_amount_min = size.x
	p.scale_amount_max = size.y
	var g := Gradient.new()
	g.set_color(0, colors[0])
	g.set_color(1, colors[colors.size() - 1])
	if colors.size() > 2:
		g.add_point(0.45, colors[1])
	p.color_ramp = g
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.01, 0.01)
	var m := ShaderMaterial.new()
	m.shader = PARTICLE_ADD if additive else _mix_shader()
	m.set_shader_parameter("energy", energy)
	mesh.material = m
	p.mesh = mesh
	p.local_coords = false
	parent.add_child(p)
	p.emitting = true
	parent.get_tree().create_timer(life + 0.5, true, false, true).timeout.connect(p.queue_free)


## A temporary OmniLight3D: 0 -> peak -> 0 over `seconds`.
static func light_pulse(parent: Node3D, at: Vector3, color: Color, peak: float, seconds: float, light_range: float = 0.9) -> void:
	var l := OmniLight3D.new()
	l.position = at
	l.light_color = color
	l.light_energy = 0.0
	l.omni_range = light_range
	parent.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", peak, seconds * 0.25)
	tw.tween_property(l, "light_energy", 0.0, seconds * 0.75)
	tw.tween_callback(l.queue_free)


## Felt cracks: jagged dark strips with a DANGER edge glow, growing out from
## the dice (0.3 s) then fading (1.0 s).
static func cracks(parent: Node3D, at: Vector3, count: int, rng: RandomNumberGenerator) -> void:
	var mat := Toon.mat(Palette.PIT_BLACK, Color.BLACK, {"emission_color": Palette.DANGER, "emission_energy": 1.5, "light_gain": 0.0})
	mat.render_priority = 2
	for i in count:
		var mi := MeshInstance3D.new()
		var im := ImmediateMesh.new()
		mi.mesh = im
		mi.material_override = mat
		var dir := Vector2.from_angle(TAU * float(i) / count + rng.randf_range(-0.4, 0.4))
		var pts: Array[Vector2] = [Vector2(at.x, at.z)]
		var p := Vector2(at.x, at.z)
		var length := rng.randf_range(0.12, 0.26)
		for s in 7:
			p += dir.rotated(rng.randf_range(-0.6, 0.6)) * (length / 7.0)
			pts.append(p)
		parent.add_child(mi)
		var tw := mi.create_tween()
		tw.tween_method(_grow_crack.bind(im, pts), 0.0, 1.0, 0.3)
		tw.tween_interval(0.4)
		tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("emission_energy", 1.5 * v), 1.0, 0.0, 1.0)
		tw.tween_callback(mi.queue_free)


static func _grow_crack(p: float, im: ImmediateMesh, pts: Array[Vector2]) -> void:
	im.clear_surfaces()
	var n := clampi(int(ceil(p * (pts.size() - 1))) + 1, 2, pts.size())
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in n:
		var a := pts[i]
		var b := pts[mini(i + 1, pts.size() - 1)] if i < pts.size() - 1 else pts[i] + (pts[i] - pts[i - 1])
		var d := (b - a).normalized()
		var side := Vector2(-d.y, d.x) * 0.006 * (1.0 - float(i) / pts.size())
		im.surface_add_vertex(Vector3(a.x + side.x, 0.0015, a.y + side.y))
		im.surface_add_vertex(Vector3(a.x - side.x, 0.0015, a.y - side.y))
	im.surface_end()


## A flat brass shockwave ring on the felt (point hit): radius 0 -> 0.6 m.
static func ring(parent: Node3D, at: Vector3, color: Color, max_radius: float = 0.6, seconds: float = 0.35) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	torus.rings = 48
	torus.ring_segments = 6
	var mi := MeshInstance3D.new()
	mi.mesh = torus
	mi.material_override = Toon.fx(color, 2.0, 1, true)
	mi.position = at + Vector3(0, 0.004, 0)
	mi.scale = Vector3(0.01, 0.05, 0.01)
	parent.add_child(mi)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(max_radius, 0.02, max_radius), seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float) -> void: (mi.material_override as ShaderMaterial).set_shader_parameter("energy", v), 2.0, 0.0, seconds)
	tw.chain().tween_callback(mi.queue_free)


## A 12-ray starburst flat on the felt (natural), scaling 0 -> 1.2, fading.
static func starburst(parent: Node3D, at: Vector3, color: Color) -> void:
	var root := Node3D.new()
	root.position = at + Vector3(0, 0.005, 0)
	parent.add_child(root)
	var mat := Toon.fx(color, 1.6, 1, true)
	for i in 12:
		var q := QuadMesh.new()
		q.size = Vector2(0.025, 0.3)
		q.orientation = PlaneMesh.FACE_Y
		q.center_offset = Vector3(0, 0, 0.17)
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.material_override = mat
		mi.rotation.y = TAU * i / 12.0
		root.add_child(mi)
	root.scale = Vector3.ONE * 0.01
	var tw := root.create_tween()
	tw.set_parallel(true)
	tw.tween_property(root, "scale", Vector3.ONE * 1.2, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(root, "rotation:y", deg_to_rad(12.0), 0.4)
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("energy", v), 1.6, 0.0, 0.45)
	tw.chain().tween_callback(root.queue_free)
