// Hearth corner light pools (detail pass v2, Art Director Oct 19): a warm ADDITIVE pool of candlelight on
// the rail top under each corner cluster, so the props sit in light instead of glowing on their own.
// Painted on a thin patch hugging the rail (build_dressing.py pool(), slot dressing_pool) from its
// board-space position: an ellipse per pool (centre x/z, half-extent along x/z), two soft toon bands
// (an outer Ember wash, a brighter brass core), aimed at ~25-35 % value on the dark leather.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

uniform vec4 pool_color : source_color = vec4(0.91, 0.627, 0.376, 1.0);   // #E8A060 candle brass
uniform vec4 core_color : source_color = vec4(1.0, 0.82, 0.55, 1.0);
uniform float energy = 0.16;
uniform float core_energy = 0.07;
uniform float core_at = 0.55;
// x, z centre and x, z half-extent per pool (FL, FR, NR, NL: build_dressing.py POOLS)
const vec4 POOLS[4] = vec4[4](vec4(-0.907, -0.645, 0.093, 0.055), vec4(0.85, -0.645, 0.145, 0.055),
	vec4(0.915, 0.645, 0.08, 0.055), vec4(-0.92, 0.645, 0.075, 0.055));
varying vec3 obj;

void vertex() {
	obj = VERTEX;
}

void fragment() {
	float r = 10.0;
	for (int i = 0; i < 4; i++) {
		vec2 d = (obj.xz - POOLS[i].xy) / POOLS[i].zw;
		r = min(r, length(d));
	}
	if (r > 1.0) {
		discard;
	}
	float wash = 1.0 - smoothstep(0.7, 1.0, r);
	float core = 1.0 - smoothstep(core_at - 0.08, core_at + 0.08, r);
	ALBEDO = pool_color.rgb * energy * wash + core_color.rgb * core_energy * core;
}
