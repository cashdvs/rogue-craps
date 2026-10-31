// Toon-noir fire for particles and meshes (Bonfire scoring juice).
// Flat colour bands (outer / mid / core) with a thin Pit Black ink edge. It is
// alpha-cut (discard), not blended: it draws in the opaque pass with depth
// writes, so stacked flames cost no blending overdraw (cheap on mobile).
// shape: 0 flame tongue, 1 spark (4-point star), 2 round blob / drop,
//        3 column (mesh UVs, scrolls upward: the fire pillar), 4 flat ring (shockwave).
// Per-particle life comes from COLOR.a (colour ramp 1 -> 0): the shape shrinks
// as it dies instead of fading. `heat` (instance uniform, 0..1) does the same
// for the whole emitter: animate it to 0 to snuff the fire out.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_opaque;
#include "res://art/vfx/bonfire/shaders/bonfire_instance.gdshaderinc"

uniform int shape = 0;
// 0 = none (a placed mesh), 1 = camera-facing billboard (particles).
uniform int billboard = 1;
uniform vec4 outer_color : source_color = vec4(0.910, 0.384, 0.165, 1.0); // Ember #E8622A
uniform vec4 mid_color : source_color = vec4(0.965, 0.659, 0.271, 1.0);   // #F6A845
uniform vec4 core_color : source_color = vec4(1.0, 0.906, 0.659, 1.0);    // hot core #FFE7A8
uniform vec4 ink_color : source_color = vec4(0.055, 0.078, 0.078, 1.0);   // Pit Black
uniform float ink_width = 0.10;  // fraction of the shape field drawn as the ink edge (0 = none)
uniform float mid_at = 0.40;     // field value where the mid band starts
uniform float core_at = 0.70;    // field value where the core starts
uniform float energy = 1.0;      // > 1 feeds the table's HDR glow
uniform float flicker_speed = 7.0;
uniform float wobble = 0.22;
uniform float scroll_speed = 1.4; // column only
uniform float tongues = 7.0;      
varying float seed;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	seed = fract(float(INSTANCE_ID) * 0.6180339);
	if (billboard == 1) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
			vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
}

// Shape field: 1 at the heart, 0 at the silhouette, < 0 outside.
float field(vec2 uv, float t) {
	float x = uv.x - 0.5;
	float y = 1.0 - uv.y; // 0 = bottom
	if (shape == 0) {
		// Teardrop: a round belly at the bottom and a licking tongue tapering to a point.
		float n = vnoise(vec2(y * 2.2 - t * flicker_speed * 0.35 + seed * 13.0, seed * 7.0));
		float n2 = vnoise(vec2(y * 5.0 - t * flicker_speed * 0.6, seed * 5.0 + 3.0));
		x += ((n - 0.5) * 1.2 + (n2 - 0.5) * 0.4) * wobble * y;
		float rb = 0.3;
		float belly = 1.0 - length(vec2(x, (y - rb) * 1.1)) / rb;
		float w = rb * pow(clamp((1.0 - y) / (1.0 - rb), 0.0, 1.0), 1.1);
		float tongue = y > rb ? 1.0 - abs(x) / max(w, 0.001) : -1.0;
		return max(belly, tongue);
	} else if (shape == 1) {
		vec2 p = abs(vec2(x, y - 0.5)) * 2.0;
		return 1.0 - (sqrt(p.x) + sqrt(p.y));
	} else if (shape == 2) {
		return 1.0 - length(vec2(x, y - 0.5)) * 2.0;
	} else if (shape == 3) {
		// Column: smooth tongues around the circumference (seamless in u), inner flicker bands.
		float a = uv.x * 6.2831853;
		float lick = vnoise(vec2(cos(a), sin(a)) * tongues * 0.5 + vec2(t * scroll_speed * 0.7, 0.0));
		float top = 0.6 + 0.4 * lick;
		float inner = vnoise(vec2(uv.x * tongues * 2.0, y * 4.0 - t * scroll_speed * 2.0));
		return (top - y) / max(top, 0.001) * 1.4 - 0.22 * inner;
	} else {
		float r = length(vec2(x, y - 0.5)) * 2.0;
		return 1.0 - abs(r - 0.78) / 0.2;
	}
}

void fragment() {
	float life = clamp(COLOR.a * heat, 0.0, 1.0);
	float f = field(UV, TIME + seed * 3.0);
	// Dying shapes erode from the outside in (toon "shrink", no alpha fade).
	f -= (1.0 - life) * 1.05;
	if (f <= 0.0) {
		discard;
	}
	vec3 col = outer_color.rgb;
	if (f > core_at) {
		col = core_color.rgb;
	} else if (f > mid_at) {
		col = mid_color.rgb;
	}
	col *= energy;
	if (f < ink_width) {
		col = ink_color.rgb;
	}
	ALBEDO = col;
}
