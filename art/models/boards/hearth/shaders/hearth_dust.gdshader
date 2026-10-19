// Hearth lamp dust (detail pass, Oct 19): a faint sheet of motes turning in the lamp cone, self-animated
// in the vertex shader (no particle nodes; ~16 quads PC / 8 mobile). The mesh is N small quads around the
// origin; COLOR.r = per-mote seed. Each mote wanders slowly inside `box` (Lissajous drift, on twos) and only
// glints when it turns into the light (a slow twinkle), so the sheet reads as air, not as dots. Additive,
// tiny, faint and kept high in the far half of the cone (the test checks it never projects over the felt
// from the game camera).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
#include "res://art/models/boards/hearth/shaders/hearth_instance.gdshaderinc"

uniform vec4 color : source_color = vec4(1.0, 0.69, 0.44, 1.0);  // lamp #FFB070
uniform float energy = 0.22;
uniform vec3 box = vec3(1.1, 0.5, 0.42);
uniform float size = 0.0045;
uniform float speed = 0.035;     // m/s
uniform float fps = 12.0;
varying float v_glint;
varying vec2 v_q;

void vertex() {
	float seed = COLOR.r;
	float tq = floor(TIME * fps) / fps;
	vec3 ph = vec3(seed * 17.1, seed * 29.3, seed * 41.7);
	vec3 f = vec3(0.11, 0.07, 0.09) * (0.7 + 0.6 * fract(seed * 7.7)) * speed / 0.035;
	vec3 local = 0.5 * box * vec3(sin(tq * f.x * 6.2831 + ph.x), sin(tq * f.y * 6.2831 + ph.y), sin(tq * f.z * 6.2831 + ph.z));
	vec3 origin = (MODEL_MATRIX * vec4(local, 1.0)).xyz;
	v_glint = pow(0.5 + 0.5 * sin(tq * (0.6 + seed) + seed * 50.0), 3.0) * heat;
	v_q = UV;
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	vec2 c = VERTEX.xy * 2.0;
	vec3 w = origin + (right * c.x + up * c.y) * size * 0.5;
	POSITION = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(w, 1.0));
}

void fragment() {
	vec2 p = abs(v_q - 0.5) * 2.0;
	float f = 1.0 - (p.x + p.y);   // a soft 4-point diamond, like every Hearth spark
	if (f <= 0.0) {
		discard;
	}
	ALBEDO = color.rgb * energy * v_glint * f;
}
