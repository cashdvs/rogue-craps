## Lighting layer 5 (lighting_layers_spec.md section 5): slow warm dust motes
## in the lamp cone. Forward+: GPUParticles3D, 48 max, turbulence. Compat /
## Mobile: CPUParticles3D, 16 max, no turbulence. Emitted in a cylinder
## r 0.45 m, y 0.25-1.20 m, centred (0, ., -0.05); 2-4 mm (3-4 mm mobile)
## billboards, #FFE2B0 additive at alpha 0.18 (0.15 mobile), faded outside
## the 38 deg spot cone. The draw shader also cuts every mote below
## y 0.08, so none can reach the felt or the dice. Off (not emitting, hidden)
## under reduced motion.
class_name LampDust
extends Node3D

const COLOR := Color("#FFE2B0")
const ALPHA_PC: float = 0.18
const ALPHA_MOBILE: float = 0.15
const COUNT_PC: int = 48
const COUNT_MOBILE: int = 16
const RADIUS: float = 0.45
const Y_MIN: float = 0.25
const Y_MAX: float = 1.20
const CENTRE_Z: float = -0.05
## Nothing is drawn below this world y (m above the felt).
const FLOOR_Y: float = 0.08
const SIZE_PC := Vector2(0.002, 0.004)
const SIZE_MOBILE := Vector2(0.003, 0.004)
const SPEED := Vector2(0.01, 0.03)
const LIFETIME_MAX: float = 9.0
const LIFETIME_MIN: float = 6.0
## Max angle of the initial drift from straight up (the up-bias).
const SPREAD_DEG: float = 60.0
const LAMP_APEX := Vector3(0, 1.35, -0.05)
const CONE_DEG: float = 38.0

const SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0);
uniform float peak = 0.18;
uniform vec3 apex = vec3(0.0, 1.35, -0.05);
uniform float cos_half = 0.788;
uniform float floor_y = 0.08;
varying vec3 wpos;
void vertex() {
	wpos = MODEL_MATRIX[3].xyz;
	float s = length(MODEL_MATRIX[0].xyz);
	mat4 bb = mat4(normalize(INV_VIEW_MATRIX[0]) * s, normalize(INV_VIEW_MATRIX[1]) * s,
		normalize(INV_VIEW_MATRIX[2]) * s, MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * bb;
}
void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float dot_a = 1.0 - smoothstep(0.3, 1.0, d);
	vec3 v = normalize(wpos - apex);
	float cone = smoothstep(cos_half - 0.04, cos_half + 0.02, dot(v, vec3(0.0, -1.0, 0.0)));
	float above = step(floor_y, wpos.y);
	ALBEDO = tint.rgb;
	ALPHA = peak * dot_a * cone * above * COLOR.a;
}
"""

var table: Node
var mobile: bool = false
var particles: Node3D
var reduced: bool = false


func _init() -> void:
	name = "LampDust"


static func count_for(is_mobile: bool) -> int:
	return COUNT_MOBILE if is_mobile else COUNT_PC


static func alpha_for(is_mobile: bool) -> float:
	return ALPHA_MOBILE if is_mobile else ALPHA_PC


## Lowest world y a mote's centre can reach from emission (the up-biased
## drift never descends; the shader floor cuts anything else, e.g. turbulence).
static func lowest_emitted_y() -> float:
	# Slowest climb: SPEED.x * cos(SPREAD_DEG) > 0, so a mote only rises.
	return Y_MIN if SPEED.x * cos(deg_to_rad(SPREAD_DEG)) > 0.0 else -INF


func bind(t: Node, is_mobile: bool) -> void:
	table = t
	mobile = is_mobile
	_build()
	_sync_reduced(true)


func _material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("tint", COLOR)
	m.set_shader_parameter("peak", alpha_for(mobile))
	m.set_shader_parameter("apex", LAMP_APEX)
	m.set_shader_parameter("cos_half", cos(deg_to_rad(CONE_DEG)))
	m.set_shader_parameter("floor_y", FLOOR_Y)
	return m


func _ramp() -> Gradient:
	var g := Gradient.new()
	var fade := 1.0 / ((LIFETIME_MIN + LIFETIME_MAX) * 0.5)
	g.offsets = PackedFloat32Array([0.0, fade, 1.0 - fade, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	return g


func _build() -> void:
	if particles != null:
		particles.queue_free()
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	q.material = _material()
	var size := SIZE_MOBILE if mobile else SIZE_PC
	if mobile:
		var c := CPUParticles3D.new()
		c.amount = COUNT_MOBILE
		c.lifetime = LIFETIME_MAX
		c.lifetime_randomness = 1.0 - LIFETIME_MIN / LIFETIME_MAX
		c.preprocess = LIFETIME_MAX
		c.mesh = q
		c.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		c.emission_ring_axis = Vector3.UP
		c.emission_ring_radius = RADIUS
		c.emission_ring_inner_radius = 0.0
		c.emission_ring_height = Y_MAX - Y_MIN
		c.direction = Vector3.UP
		c.spread = SPREAD_DEG
		c.gravity = Vector3.ZERO
		c.initial_velocity_min = SPEED.x
		c.initial_velocity_max = SPEED.y
		c.scale_amount_min = size.x
		c.scale_amount_max = size.y
		c.color_ramp = _ramp()
		particles = c
	else:
		var g := GPUParticles3D.new()
		g.amount = COUNT_PC
		g.lifetime = LIFETIME_MAX
		g.preprocess = LIFETIME_MAX
		g.draw_pass_1 = q
		g.visibility_aabb = AABB(Vector3(-0.6, -0.6, -0.6), Vector3(1.2, 1.4, 1.2))
		var pm := ParticleProcessMaterial.new()
		pm.lifetime_randomness = 1.0 - LIFETIME_MIN / LIFETIME_MAX
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		pm.emission_ring_axis = Vector3.UP
		pm.emission_ring_radius = RADIUS
		pm.emission_ring_inner_radius = 0.0
		pm.emission_ring_height = Y_MAX - Y_MIN
		pm.direction = Vector3.UP
		pm.spread = SPREAD_DEG
		pm.gravity = Vector3.ZERO
		pm.initial_velocity_min = SPEED.x
		pm.initial_velocity_max = SPEED.y
		pm.scale_min = size.x
		pm.scale_max = size.y
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = 0.2
		pm.turbulence_influence_min = 0.02
		pm.turbulence_influence_max = 0.05
		var rt := GradientTexture1D.new()
		rt.gradient = _ramp()
		pm.color_ramp = rt
		g.process_material = pm
		particles = g
	particles.name = "LampDust"
	particles.position = Vector3(0, (Y_MIN + Y_MAX) * 0.5, CENTRE_Z)
	add_child(particles)


func amount() -> int:
	return int(particles.get("amount")) if particles != null else 0


func is_emitting() -> bool:
	return particles != null and bool(particles.get("emitting")) and particles.visible


func _table_reduced() -> bool:
	if table == null or not is_instance_valid(table):
		return false
	if table.has_method("is_reduced_motion"):
		return bool(table.call("is_reduced_motion"))
	if "reduced_motion" in table:
		return bool(table.get("reduced_motion"))
	return false


func _sync_reduced(force: bool = false) -> void:
	var r := _table_reduced()
	if r == reduced and not force:
		return
	reduced = r
	if particles != null:
		particles.set("emitting", not r)
		particles.visible = not r


func _process(_delta: float) -> void:
	_sync_reduced()
