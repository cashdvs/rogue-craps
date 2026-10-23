// Candle row gutter drip (world_props_v1 §2.1 "a bust also adds a gutter-drip on the wax").
// A Y-locked card on the camera side of the candle: one wax run from the rim down the side with a
// round bead at its end. Procedural (no texture), alpha-cut + depth (Compatibility-safe), drawn on
// twos. level (instance) = drip progress 0..1 (the run length); heat = 0 hides it.
// Wax colour sits in the lit-wax value range, with the Pit Black ink edge of the props.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_opaque;
#include "res://art/models/boards/hearth/shaders/hearth_instance.gdshaderinc"

uniform vec4 wax_color : source_color = vec4(0.784, 0.659, 0.459, 1.0);   // #C8A875 (darker than the lit wax)
uniform vec4 ink_color : source_color = vec4(0.055, 0.078, 0.078, 1.0);   // Pit Black #0E1414
uniform float width = 0.16;     // run width (card-relative)
uniform float bead = 0.24;      // bead radius (card-relative, x)
uniform float ink = 0.05;       // ink edge (card-relative)
uniform float front = 0.0145;   // m: card pushed toward the camera (candle radius)

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 to_cam = INV_VIEW_MATRIX[3].xyz - origin;
	to_cam.y = 0.0;
	to_cam = normalize(to_cam + vec3(1e-5, 0.0, 0.0));
	vec3 right = vec3(to_cam.z, 0.0, -to_cam.x);
	vec3 w = origin + to_cam * front + right * VERTEX.x * length(MODEL_MATRIX[0].xyz)
		+ vec3(0.0, 1.0, 0.0) * VERTEX.y * length(MODEL_MATRIX[1].xyz);
	POSITION = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(w, 1.0));
}

void fragment() {
	// UV.y 0 = rim (top), 1 = bottom. The run grows down on twos (8 drawings).
	float prog = floor(clamp(level, 0.0, 1.0) * 8.0 + 0.5) / 8.0;
	if (prog <= 0.0 || heat <= 0.001) {
		discard;
	}
	float x = abs(UV.x - 0.5) * 2.0;           // 0 centre .. 1 edge
	float end = 0.08 + prog * 0.72;            // bead centre (UV.y)
	float run = (UV.y < end) ? x - width * (0.8 + 0.4 * UV.y) : 9.0;
	float bd = length(vec2(x * 0.5, (UV.y - end) * 1.6)) * 2.0 - bead;
	float d = min(run, bd);                    // < 0 inside
	if (d > ink) {
		discard;
	}
	ALBEDO = d > 0.0 ? ink_color.rgb : wax_color.rgb * (0.85 + 0.15 * (1.0 - UV.y));
}
