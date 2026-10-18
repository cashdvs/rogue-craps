// Soul flask glass: mostly clear, with a stepped cyan-white rim, one painted
// highlight stripe and procedural cracks. `crack` (instance uniform 0..1)
// grows Pit Black crack lines out from `crack_point` (object space) with a
// thin Soul-cyan glow inside them. Soul cyan is the player's colour: this
// prop IS the Soul meter, so it is allowed here (style_guide.md).
shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_never, shadows_disabled;
#include "res://art/vfx/bonfire/shaders/bonfire_instance.gdshaderinc"

uniform vec4 tint : source_color = vec4(0.118, 0.561, 0.545, 0.12); // Soul deep #1E8F8B
uniform vec4 rim_color : source_color = vec4(0.875, 1.0, 0.992, 0.9); // Soul core #DFFFFD
uniform vec4 crack_color : source_color = vec4(0.055, 0.078, 0.078, 1.0);
uniform vec4 crack_glow : source_color = vec4(0.310, 0.902, 0.878, 1.0); // Soul flame
uniform vec3 crack_point = vec3(0.012, 0.032, 0.031); // front-right of the belly (faces the player)
uniform float crack_reach = 0.05; // metres the cracks spread at crack = 1
uniform float crack_cells = 85.0;

varying vec3 obj_pos;
varying vec3 obj_n;

vec2 hash2(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}
// Distance to the nearest Voronoi cell border (crack lines).
float voronoi_edge(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			float d = length(g + hash2(i + g) - f);
			if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
		}
	}
	return d2 - d1;
}

void vertex() {
	obj_pos = VERTEX;
	obj_n = NORMAL;
}

void fragment() {
	float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec4 c = tint;
	if (fres > 0.72) {
		c = vec4(rim_color.rgb, rim_color.a * 0.55);
	}
	if (fres > 0.86) {
		c = rim_color;
	}
	// Painted highlight: a vertical stripe on the upper-left of the body.
	float ang = atan(obj_pos.z, obj_pos.x);
	if (abs(ang - 2.3) < 0.18 && obj_pos.y > 0.012 && obj_pos.y < 0.05) {
		c = vec4(rim_color.rgb, 0.85);
	}
	if (crack > 0.0) {
		float r = distance(obj_pos, crack_point);
		float reach = crack * crack_reach;
		vec2 p = vec2(atan(obj_pos.z, obj_pos.x) * 0.034, obj_pos.y) * crack_cells;
		float e = voronoi_edge(p);
		float on = step(r, reach) * step(e, 0.07 * (1.0 - r / max(reach, 0.0001)) + 0.035);
		if (on > 0.5) {
			c = e < 0.03 ? vec4(crack_glow.rgb * 1.4, 1.0) : crack_color;
		}
	}
	ALBEDO = c.rgb;
	ALPHA = c.a;
}
