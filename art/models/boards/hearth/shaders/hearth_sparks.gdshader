// Hearth sparks: 4-point diamonds (fire_style.md: never round dots) that rise from the brazier,
// self-animated in the vertex shader (no particle nodes, so they are cheap and Compatibility-safe).
// The mesh is N small quads around the origin; COLOR.r = per-spark seed. Each spark loops: rises
// `rise` m over `period` s, spirals `turns` times at `radius` (brass spiral at the pillar), shrinks
// out. Time is quantised to 12 fps (on twos). Alpha-cut, unshaded; only the core band blooms.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_opaque;
#include "res://art/models/boards/hearth/shaders/hearth_instance.gdshaderinc"

uniform vec4 fill_color : source_color = vec4(0.910, 0.384, 0.165, 1.0); // Ember #E8622A
uniform vec4 core_color : source_color = vec4(1.0, 0.902, 0.659, 1.0);   // Butter #FFE6A8
uniform vec4 outline_color : source_color = vec4(0.231, 0.051, 0.078, 1.0); // Oxblood #3B0D14
uniform float core_energy = 2.0;
uniform float size = 0.014;     // diamond height (m) at birth
uniform float aspect = 0.55;    // width / height
uniform float rise = 0.25;
uniform float period = 0.9;
uniform float radius = 0.05;
uniform float turns = 0.0;
uniform float drift = 0.02;
uniform float fps = 12.0;
varying float v_life;
varying vec2 v_q;

void vertex() {
	float seed = COLOR.r;
	float tq = floor(TIME * fps) / fps;
	float t = fract(tq / period + seed * 7.13);
	float ang = seed * 6.2831 * 3.0 + t * turns * 6.2831;
	float r = radius * (0.35 + 0.65 * fract(seed * 13.7)) * (1.0 - 0.3 * t);
	vec3 local = vec3(cos(ang) * r + sin(seed * 40.0) * drift * t, t * rise * (0.7 + 0.3 * fract(seed * 5.3)), sin(ang) * r);
	vec3 origin = (MODEL_MATRIX * vec4(local, 1.0)).xyz;
	v_life = clamp((1.0 - t) * heat, 0.0, 1.0);
	v_q = UV;
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	float s = size * (0.6 + 0.4 * v_life) * step(0.02, heat);
	vec2 c = VERTEX.xy * 2.0;  // quad corners at +-0.5 -> +-1
	vec3 w = origin + right * c.x * s * aspect * 0.5 + up * c.y * s * 0.5;
	POSITION = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(w, 1.0));
}

void fragment() {
	vec2 p = abs(v_q - 0.5) * 2.0;
	float f = 1.0 - (p.x + p.y);
	f -= (1.0 - v_life) * 0.6;
	if (f <= 0.0) {
		discard;
	}
	ALBEDO = f < 0.12 ? outline_color.rgb : (f > 0.42 ? core_color.rgb * core_energy : fill_color.rgb);
}
