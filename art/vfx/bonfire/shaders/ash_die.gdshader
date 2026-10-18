// Ash dice for a bust (show it for ~0.5 s). Toon-noir bands like toon_noir,
// then two instance uniforms the dev animates per die:
//   ash      0 = normal bone, 1 = grey ash. It spreads in noise patches with a
//            glowing ember front, so the turn reads as "burnt out", not a fade.
//   dissolve 0 = solid, 1 = crumbled away (cells drop out behind an ember rim).
// Use ash_body.tres on surface 0 and ash_pip.tres on surface 1 of bone_d6
// (set_surface_override_material), with ash_outline.tres as the ink hull.
shader_type spatial;
render_mode specular_disabled, ambient_light_disabled;
#include "res://art/vfx/bonfire/shaders/bonfire_instance.gdshaderinc"

uniform vec4 base_color : source_color = vec4(0.910, 0.863, 0.753, 1.0);   // Bone
uniform vec4 base_shadow : source_color = vec4(0.557, 0.478, 0.361, 1.0);  // #8E7A5C
uniform vec4 ash_color : source_color = vec4(0.353, 0.369, 0.384, 1.0);    // #5A5E62 (cool, so it reads grey under the warm lamp)
uniform vec4 ash_shadow : source_color = vec4(0.078, 0.086, 0.094, 1.0);   // #141618
uniform vec4 ember_color : source_color = vec4(0.910, 0.384, 0.165, 1.0);  // Ember
uniform float ember_energy = 1.6;
// Ash is matte and self-coloured: the warm lamp only half-lights it, so it reads grey, not tan.
uniform float ash_flat = 0.6;
uniform float front_width = 0.06;
uniform float cell_scale = 55.0; // noise cells per metre (object space): ~4 per 0.08 face
uniform float mid_tint = 0.8;
uniform float wrap = 0.35;
uniform float band_lo = 0.15;
uniform float band_hi = 0.55;
uniform float band_soft = 0.04;
uniform float light_gain = 1.0;
uniform float att_ref = 0.6;
uniform vec4 ambient_color : source_color = vec4(0.102, 0.031, 0.047, 1.0);
uniform float ambient_energy = 0.25;

varying vec3 obj_pos;
varying vec3 shadow_mix;
varying float ash_mask;

float hash3(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float cells(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y);
	float b = mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y);
	return mix(a, b, f.z);
}

void vertex() {
	obj_pos = VERTEX;
}

void fragment() {
	float n = cells(obj_pos * cell_scale) * 0.7 + cells(obj_pos * cell_scale * 3.1) * 0.3;
	float a_front = ash * (1.0 + front_width * 2.0) - front_width;
	float d_front = dissolve * (1.0 + front_width * 2.0) - front_width;
	if (n < d_front) {
		discard;
	}
	float is_ash = step(n, a_front);
	vec3 col = mix(base_color.rgb, ash_color.rgb, is_ash);
	col *= mix(1.0, 0.88 + 0.12 * cells(obj_pos * cell_scale * 7.0), is_ash); // ash speckle
	shadow_mix = mix(base_shadow.rgb, ash_shadow.rgb, is_ash);
	ash_mask = is_ash;
	float ember = max(step(abs(n - a_front), front_width * 0.5) * step(0.001, ash) * step(ash, 0.999),
			step(n - d_front, front_width) * step(0.001, dissolve));
	ALBEDO = col;
	vec3 shade = mix(col, shadow_mix, 0.7);
	EMISSION = ember_color.rgb * ember_energy * ember + shade * ambient_color.rgb * ambient_energy * 2.0
			+ col * ash_flat * 0.5 * is_ash;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float w = (ndl + wrap) / (1.0 + wrap);
	float att = clamp(ATTENUATION / att_ref, 0.0, 1.0);
	float l = clamp(w, 0.0, 1.0) * att;
	float b1 = smoothstep(band_lo - band_soft, band_lo + band_soft, l);
	float b2 = smoothstep(band_hi - band_soft, band_hi + band_soft, l);
	vec3 a = max(ALBEDO, vec3(0.002));
	vec3 shadow_rgb = mix(a, shadow_mix, 0.7) * 0.35;
	vec3 band = mix(mix(shadow_rgb, a * mid_tint, b1), a, b2);
	float reach = smoothstep(0.0, 0.05, ATTENUATION);
	vec3 lc = mix(LIGHT_COLOR, vec3(dot(LIGHT_COLOR, vec3(0.333))), ash_mask); // ash: desaturate the lamp
	DIFFUSE_LIGHT += band / a * (lc / PI) * light_gain * reach * mix(1.0, 1.0 - ash_flat * 0.6, ash_mask);
}
