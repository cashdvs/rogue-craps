// Candle row flame (world_props_v1 §2.1): the Hearth toon tongue card (hearth_flame_card.gdshader,
// same SDF flipbook, bands, outline and alpha-cut; Compatibility-safe) plus a GUTTER control.
// Instance uniforms (hearth_instance.gdshaderinc slots): heat = alive (snuff 1 -> 0),
// pulse = flare, level = gutter 0..1: 0 steady; 0.5 = the last-hand flicker (flipbook x1.75, small
// size wobble); 1 = guttering (low, leaning, fast wobble: the bust drip / dying flame).
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_opaque;
#include "res://art/models/boards/hearth/shaders/hearth_instance.gdshaderinc"

uniform sampler2D atlas : hint_default_black, filter_linear_mipmap, repeat_disable;
uniform int mode = 0;
uniform float fps = 12.0;
uniform vec4 core_color : source_color = vec4(1.0, 0.902, 0.659, 1.0);    // Butter #FFE6A8
uniform vec4 mid_color : source_color = vec4(0.910, 0.384, 0.165, 1.0);   // Ember #E8622A
uniform vec4 outer_color : source_color = vec4(0.784, 0.157, 0.118, 1.0); // Hellfire #C8281E
uniform vec4 outline_color : source_color = vec4(0.231, 0.051, 0.078, 1.0); // Oxblood #3B0D14
uniform float core_energy = 2.2;  // > 1 only on the core: the table glow (threshold 1.0) blooms it
uniform float outline_px = 2.0;   // outline width in pixels at 1080p (scales with the viewport)
uniform float back_offset = 0.0;  // m: push the card away from the camera (rises behind the die rim)
uniform bool y_billboard = true;
uniform float erode = 0.2;        // edge shift at heat 0 (the wisp)
uniform float min_size = 0.22;    // card size at heat 0
uniform float flare_grow = 0.8;   // extra size at pulse 1 (flare)
uniform float rise = 0.0;         // mode 1 (wisp): metres the card rises as heat goes 1 -> 0
uniform float gutter_speed = 19.0; // rad/s of the gutter wobble
uniform float gutter_low = 0.45;   // card size at level 1
uniform float gutter_lean = 0.35;  // sideways lean (x card width) at level 1
varying float v_seed;
varying float v_life;

void vertex() {
	float life = clamp(COLOR.a * heat, 0.0, 1.0);
	v_life = life;
	vec3 origin = MODEL_MATRIX[3].xyz;
	v_seed = fract(sin(dot(origin.xz * 37.0 + vec2(float(INSTANCE_ID) * 1.618, origin.y * 11.0), vec2(12.9898, 78.233))) * 43758.5453);
	vec3 w;
	if (y_billboard) {
		vec3 to_cam = INV_VIEW_MATRIX[3].xyz - origin;
		to_cam.y = 0.0;
		float l = length(to_cam);
		to_cam = l > 1e-5 ? to_cam / l : vec3(0.0, 0.0, 1.0);
		vec3 right = vec3(to_cam.z, 0.0, -to_cam.x);
		float g = clamp(level, 0.0, 1.0);
		float wob = sin(TIME * gutter_speed * (0.6 + g) + v_seed * 6.283) * 0.5 + 0.5;
		float grow = mix(min_size, 1.0, life) * (1.0 + pulse * flare_grow)
			* mix(1.0, mix(gutter_low, 1.0, wob * 0.6), g) * (1.0 - 0.12 * g * wob);
		float lean = gutter_lean * g * (wob - 0.3) * max(VERTEX.y, 0.0) * length(MODEL_MATRIX[1].xyz) * grow;
		origin.y += rise * (1.0 - clamp(heat, 0.0, 1.0));
		w = origin - to_cam * back_offset + right * (VERTEX.x * length(MODEL_MATRIX[0].xyz) * grow + lean)
			+ vec3(0.0, 1.0, 0.0) * VERTEX.y * length(MODEL_MATRIX[1].xyz) * grow;
	} else {
		w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	}
	POSITION = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(w, 1.0));
}

void fragment() {
	vec2 uv = UV;
	vec3 s;
	if (mode == 0) {
		if (v_seed > 0.5) {
			uv.x = 1.0 - uv.x; // half the tongues hook the other way
		}
		float f = mod(floor(TIME * fps * (1.0 + 1.5 * clamp(level, 0.0, 1.0)) + v_seed * 16.0), 16.0);
		vec2 cell = vec2(mod(f, 4.0), floor(f / 4.0));
		s = texture(atlas, (cell + clamp(uv, 0.002, 0.998)) / 4.0).rgb;
	} else {
		s = texture(atlas, uv).rgb;
	}
	float edge = 0.5 + (1.0 - v_life) * erode;
	float ow = fwidth(s.r) * outline_px * VIEWPORT_SIZE.y / 1080.0;
	if (s.r < edge - ow) {
		discard;
	}
	vec3 col = outer_color.rgb;
	if (s.r < edge) {
		col = outline_color.rgb;
	} else if (s.b > edge) {
		col = core_color.rgb * core_energy * (1.0 + pulse * 0.4);
	} else if (s.g > edge) {
		col = mid_color.rgb;
	}
	ALBEDO = col;
}
