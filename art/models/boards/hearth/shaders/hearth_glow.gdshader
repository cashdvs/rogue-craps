// Hearth candle glow decal: a small ADDITIVE emissive pool on the rail top under each lit candle
// (Art Director, Oct 18: no real light). A flat quad laid on the rail surface; elliptical, two hard
// toon bands (Ember outer, Butter inner), so it reads as a drawn glow. heat = snuff, pulse = flare.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
#include "res://art/models/boards/hearth/shaders/hearth_instance.gdshaderinc"

uniform vec4 outer_color : source_color = vec4(0.910, 0.384, 0.165, 1.0); // Ember
uniform vec4 inner_color : source_color = vec4(1.0, 0.902, 0.659, 1.0);   // Butter
uniform float outer_energy = 0.35;
uniform float inner_energy = 0.45;
uniform float inner_at = 0.5;     // inner band radius (0-1 of the quad)
uniform float fps = 12.0;
varying float v_seed;

void vertex() {
	v_seed = fract(dot(MODEL_MATRIX[3].xyz, vec3(13.1, 7.7, 29.3)));
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float tq = floor(TIME * fps) / fps;
	float flick = 1.0 + 0.08 * sin(tq * 17.0 + v_seed * 40.0);
	float k = clamp(heat, 0.0, 1.0) * (1.0 + pulse * 0.8) * flick;
	if (r > 1.0 || k <= 0.0) {
		discard;
	}
	vec3 c = r < inner_at * (1.0 + pulse * 0.3) ? inner_color.rgb * inner_energy + outer_color.rgb * outer_energy : outer_color.rgb * outer_energy;
	// soften only the very rim (2 px-ish) so the additive edge does not alias
	c *= smoothstep(1.0, 0.92, r);
	ALBEDO = c * k;
}
