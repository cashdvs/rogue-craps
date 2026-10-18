## The bare-bulb hanging lamp (poc_3d.md section 7): an enamel cone shade on
## a 1 m cord, a blooming bulb, and the key SpotLight3D. It sways a little
## on two slow sines, flickers, and can dip / brighten for moments.
class_name Lamp3D
extends Node3D

const BASE_ENERGY: float = 7.0

var spot: SpotLight3D
var bulb_mat: ShaderMaterial
var reduced_motion: bool = false
## Moment multiplier (tweened by the director: 0.3 dip on seven-out, 1.15 on natural).
var boost: float = 1.0
var _impulse: float = 0.0
var _dip_t: float = 0.0
var _next_dip: float = 7.0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 2024
	position = Vector3(0, 2.35, -0.05)  # cord top (the sway pivot)
	var cord := Toon.mat(Color("#1A1A18"), Color.BLACK)
	Toon.add_mesh(self, Toon.cylinder(0.004, 1.0, 6), cord, Vector3(0, -0.5, 0))
	var shade_out := Toon.inked(Color("#2A2A26"), Color.BLACK, 0.004, {"spec_size": 0.95, "spec_color": Color("#6A6A60")}, 1)
	var shade := Toon.add_mesh(self, Toon.cylinder(0.2, 0.14, 24, 0.035), shade_out, Vector3(0, -1.0 + 0.07, 0))
	shade.name = "Shade"
	var inner := StandardMaterial3D.new()
	inner.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	inner.albedo_color = Color("#FFE2B0")
	inner.cull_mode = BaseMaterial3D.CULL_FRONT
	Toon.add_mesh(self, Toon.cylinder(0.195, 0.135, 24, 0.033), inner, Vector3(0, -1.0 + 0.07, 0))
	bulb_mat = Toon.mat(Color("#FFE2B0"), Color("#FFE2B0"), {"emission_color": Color("#FFE2B0"), "emission_energy": 8.0, "light_gain": 0.0})
	Toon.add_mesh(self, Toon.sphere(0.045, 16), bulb_mat, Vector3(0, -1.0 + 0.01, 0)).name = "Bulb"
	spot = SpotLight3D.new()
	spot.name = "KeyLight"
	spot.light_color = Color("#FFB070")
	spot.light_energy = BASE_ENERGY
	spot.spot_range = 3.0
	spot.spot_angle = 38.0
	spot.spot_angle_attenuation = 1.6
	spot.shadow_enabled = true
	spot.shadow_blur = 1.5
	spot.shadow_bias = 0.02
	spot.shadow_normal_bias = 1.0
	spot.light_size = 0.08
	spot.light_volumetric_fog_energy = 2.5
	spot.position = Vector3(0, -1.0, 0)
	spot.rotation_degrees = Vector3(-90, 0, 0)
	add_child(spot)


## An extra swing (seven-out), decaying over 2 s.
func swing(deg: float = 3.0) -> void:
	_impulse = deg


func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	if not reduced_motion:
		var kick := _impulse * sin(t * TAU * 0.6)
		rotation_degrees.x = 1.2 * sin(t * TAU * 0.21) + kick
		rotation_degrees.z = 0.8 * sin(t * TAU * 0.17) + kick * 0.5
	else:
		rotation_degrees = Vector3.ZERO
	_impulse = move_toward(_impulse, 0.0, delta * 1.5)
	var f := 1.0
	if not reduced_motion:
		f = 1.0 + 0.04 * sin(t * 7.3) + 0.03 * sin(t * 13.1)
		_next_dip -= delta
		if _next_dip <= 0.0:
			_dip_t = 0.06
			_next_dip = _rng.randf_range(6.0, 10.0)
		if _dip_t > 0.0:
			_dip_t -= delta
			f *= 0.6
	spot.light_energy = BASE_ENERGY * f * boost
	bulb_mat.set_shader_parameter("emission_energy", 8.0 * f * boost)
