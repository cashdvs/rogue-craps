// Hearth coal bed (brazier) and ember mound (cauldron): toon-dark charcoal lumps with hard ember
// cracks and butter hot spots (3 flat bands, no gradients), flickering on twos (12 fps).
// level = how hot (brazier: pot step 0-4 -> more of the bed glows; cauldron: 1). heat = snuff (0 = dark).
shader_type spatial;
render_mode specular_disabled, ambient_light_disabled;
#include "res://art/models/boards/hearth/shaders/hearth_instance.gdshaderinc"

uniform vec4 char_color : source_color = vec4(0.118, 0.106, 0.102, 1.0);  // charcoal #1E1B1A
uniform vec4 ember_color : source_color = vec4(0.910, 0.384, 0.165, 1.0); // Ember
uniform vec4 core_color : source_color = vec4(1.0, 0.902, 0.659, 1.0);    // Butter
uniform vec4 brass_color : source_color = vec4(0.886, 0.753, 0.416, 1.0); // brass hi #E2C06A (coins)
uniform float coin_amount = 0.0;  // cauldron: share of brass coin flecks
uniform float scale = 38.0;       // crack cells per object-space unit (metres for the brazier, radii for the cauldron mound)
uniform float level_max = 4.0;
uniform float ember_energy = 1.0;
uniform float core_energy = 1.8;
varying vec3 obj;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	obj = VERTEX;
}

void fragment() {
	float tq = floor(TIME * 12.0) / 12.0;
	vec2 p = obj.xz * scale;
	float n = vn(p) * 0.65 + vn(p * 2.3 + 7.0) * 0.35;
	float flick = vn(p * 0.5 + vec2(tq * 3.0, tq * 1.7));
	float hot = clamp(level / level_max, 0.0, 1.0) * heat;
	vec3 col = char_color.rgb;
	vec3 emit = vec3(0.0);
	// cracks: the middle of the noise range; wider and hotter with level
	float crack = 1.0 - abs(n - 0.5) * 2.0;
	float t_ember = mix(1.02, 0.74, hot) - flick * 0.06;
	if (hot > 0.0 && crack > t_ember) {
		emit = ember_color.rgb * ember_energy;
		col = ember_color.rgb;
		if (hot > 0.45 && crack > t_ember + mix(0.2, 0.13, hot)) {
			emit = core_color.rgb * core_energy;
			col = core_color.rgb;
		}
	}
	if (coin_amount > 0.0 && vn(p * 0.8 + 31.0) > 1.0 - coin_amount) {
		col = brass_color.rgb;
		emit = brass_color.rgb * 0.25 * heat;
	}
	ALBEDO = col;
	EMISSION = emit + col * 0.04;
}

void light() {
	float l = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * clamp(ATTENUATION / 0.6, 0.0, 1.0);
	DIFFUSE_LIGHT += mix(vec3(0.35), vec3(1.0), step(0.4, l)) * LIGHT_COLOR / PI * 0.6;
}
