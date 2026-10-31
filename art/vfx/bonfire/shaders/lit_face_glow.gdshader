// Lit-face glow for scoring dice: an overlay that lights the face
// pointing at `face_dir` (world space, default +Y = the face that was rolled).
// Works as GeometryInstance3D.material_overlay on any centred die mesh
// (bone_d6.glb: edge 0.08, so half_size 0.04) or on a flat 0.08 quad laid on
// the top face. The face gets a painted ember frame (alpha-mixed, so it reads
// even on bright bone) with HDR values that bloom, and a faint warm fill so
// the pips stay dark; `body_glow` adds an ember rim around the whole die.
// round_pool = a soft additive-looking stepped pool for the felt under a die.
// `glow` is an instance uniform: animate instance_shader_parameters/glow.
shader_type spatial;
render_mode blend_mix, unshaded, cull_back, depth_draw_never, shadows_disabled, fog_disabled;
#include "res://art/vfx/bonfire/shaders/bonfire_instance.gdshaderinc"

uniform vec4 glow_color : source_color = vec4(1.0, 0.690, 0.439, 1.0); // lamp warm #FFB070
uniform vec4 edge_color : source_color = vec4(0.910, 0.384, 0.165, 1.0); // Ember #E8622A
uniform vec3 face_dir = vec3(0.0, 1.0, 0.0);
uniform float face_threshold = 0.9;
uniform float half_size = 0.04;
uniform float face_fill = 0.18;
uniform float frame_at = 0.66;   // 0 = face centre, 1 = face edge
uniform float hot_at = 0.84;
uniform float energy = 1.6;
uniform float body_glow = 0.6;
uniform float pulse_speed = 6.0;
uniform float pulse_amount = 0.12;
// Round pool instead of a square face frame (the glow on the felt under a die).
uniform bool round_pool = false;

varying vec3 obj_pos;
varying vec3 obj_n;
varying vec3 world_n;

void vertex() {
	obj_pos = VERTEX;
	obj_n = NORMAL;
	world_n = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	float facing = smoothstep(face_threshold, face_threshold + 0.04, dot(normalize(world_n), normalize(face_dir)));
	vec3 an = abs(obj_n);
	vec2 q = an.x >= an.y && an.x >= an.z ? obj_pos.yz : (an.y >= an.z ? obj_pos.xz : obj_pos.xy);
	float d = (round_pool ? length(q) : max(abs(q.x), abs(q.y))) / half_size;
	float band = face_fill;
	vec3 col = glow_color.rgb;
	if (round_pool) {
		// Stepped pool: warm centre, ember ring, nothing past the edge.
		band = d < 0.45 ? 0.45 : (d < 0.8 ? 0.25 : (d < 1.0 ? 0.1 : 0.0));
		col = d < 0.45 ? glow_color.rgb : edge_color.rgb;
	} else if (d > hot_at) {
		band = 0.95;
		col = edge_color.rgb;
	} else if (d > frame_at) {
		band = 0.8;
		col = glow_color.rgb;
	}
	float pulse = 1.0 - pulse_amount + pulse_amount * sin(TIME * pulse_speed);
	float g = clamp(glow, 0.0, 2.0);
	float rim = step(0.6, pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.5)) * body_glow * (1.0 - facing);
	float a_face = band * facing;
	float a = max(a_face, rim) * min(g, 1.0);
	if (a < 0.01) {
		discard;
	}
	vec3 c = a_face >= rim ? col : edge_color.rgb;
	ALBEDO = c * energy * pulse * max(g, 1.0);
	ALPHA = clamp(a, 0.0, 1.0);
}
