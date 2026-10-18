// Hot ember faces on the ember-pile pickup: unshaded stepped Ember -> Bone heat
// cells that slowly crawl. `heat` (instance uniform; 1 = idle, 2 = flare,
// 0 = cold) drives brightness and how much of the face is white-hot.
shader_type spatial;
render_mode unshaded, shadows_disabled;
#include "res://art/vfx/bonfire/shaders/bonfire_instance.gdshaderinc"

uniform vec4 cool_color : source_color = vec4(0.231, 0.051, 0.078, 1.0); // Oxblood #3B0D14
uniform vec4 hot_color : source_color = vec4(0.910, 0.384, 0.165, 1.0);  // Ember
uniform vec4 white_color : source_color = vec4(0.965, 0.659, 0.271, 1.0); // #F6A845
uniform float energy = 1.8;
uniform float crawl = 0.6;
uniform float cell_scale = 260.0;

varying vec3 obj_pos;

float hash3(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }

void vertex() {
	obj_pos = VERTEX;
}

void fragment() {
	vec3 cell = floor(obj_pos * cell_scale);
	float n = fract(hash3(cell) + TIME * crawl * 0.1);
	n = abs(n * 2.0 - 1.0); // 0..1 triangle wave, each cell at its own phase
	float h = clamp(heat, 0.0, 2.0);
	vec3 c = cool_color.rgb;
	if (n < 0.4 * h + 0.2) { c = hot_color.rgb; }
	if (n < 0.18 * h) { c = white_color.rgb; }
	ALBEDO = c * energy * (0.35 + 0.65 * min(h, 1.0)) * (1.0 + max(h - 1.0, 0.0));
}
