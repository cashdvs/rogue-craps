// Unshaded additive/alpha helper for FX quads, sparks, smoke, cones and the
// room's gradient walls. Vertex color (from CPUParticles3D) tints it.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 tint : source_color = vec4(1.0);
uniform float energy = 1.0;
// 0 = round soft dot, 1 = flat, 2 = vertical gradient (walls), 3 = soft sheet (smoke)
uniform int shape = 0;
uniform vec4 bottom : source_color = vec4(0.102, 0.039, 0.055, 1.0);
uniform vec4 top : source_color = vec4(0.055, 0.078, 0.078, 1.0);

void fragment() {
	vec4 c = tint * COLOR;
	float a = c.a;
	if (shape == 0) {
		float d = length(UV - 0.5) * 2.0;
		a *= smoothstep(1.0, 0.2, d);
	} else if (shape == 2) {
		c.rgb = mix(bottom.rgb, top.rgb, clamp(UV.y * -1.0 + 1.0, 0.0, 1.0));
		a = 1.0;
	} else if (shape == 3) {
		float d = length(UV - 0.5) * 2.0;
		a *= smoothstep(1.0, 0.0, d) * (0.6 + 0.4 * sin(UV.x * 9.0 + TIME * 0.3));
	}
	ALBEDO = c.rgb * energy;
	ALPHA = a;
}
