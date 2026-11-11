// Ink hull for the ash dice (outline.gdshader + the same `dissolve` cells, so
// the outline crumbles away with the die). mode 1 = push from the centre (dice).
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;
#include "res://art/vfx/bonfire/shaders/bonfire_instance.gdshaderinc"

uniform vec4 color : source_color = vec4(0.055, 0.078, 0.078, 1.0);
uniform float width = 0.0042;
uniform int mode = 1;
uniform float cell_scale = 55.0;
uniform float front_width = 0.06;

varying vec3 obj_pos;

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
	VERTEX += (mode == 0 ? normalize(NORMAL) : normalize(VERTEX)) * width;
}

void fragment() {
	float n = cells(obj_pos * cell_scale) * 0.7 + cells(obj_pos * cell_scale * 3.1) * 0.3;
	if (n < dissolve * (1.0 + front_width * 2.0) - front_width) {
		discard;
	}
	ALBEDO = color.rgb;
}
