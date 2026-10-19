// Demon face eyes (Hearth, Corner_FL / FR): the only emissive part of the carved faces.
// Art Director, Oct 18: eyes 2x area and brighter, with a faint glow even at eyes 0 (readability
// beats carving detail).
// level 0-3 = Hot Hand stacks 0 / 1 / 2 / 3+: off (faint smoulder) -> ember (slit pupil) -> hot (ember
// with a butter core, blooms) -> white core (white-hot centre, butter ring, thin ember rim).
// Hard bands from the distance to the eye centre (object space, uniforms from build_hearth.py).
// heat = snuff (0 = dark, the bust). No light nodes.
shader_type spatial;
render_mode specular_disabled, ambient_light_disabled;
#include "res://art/models/boards/hearth/shaders/hearth_instance.gdshaderinc"

uniform vec3 eye_left = vec3(-0.0166, 0.0666, 0.0181);
uniform vec3 eye_right = vec3(0.0166, 0.0666, 0.0181);
uniform vec2 eye_size = vec2(0.0163, 0.0096);
uniform vec4 off_color : source_color = vec4(0.118, 0.106, 0.102, 1.0);    // charcoal
uniform vec4 ember_color : source_color = vec4(0.910, 0.384, 0.165, 1.0);  // Ember
uniform vec4 hell_color : source_color = vec4(0.784, 0.157, 0.118, 1.0);   // Hellfire
uniform vec4 core_color : source_color = vec4(1.0, 0.902, 0.659, 1.0);     // Butter
uniform vec4 white_color : source_color = vec4(1.0, 0.98, 0.94, 1.0);
uniform vec4 pupil_color : source_color = vec4(0.055, 0.078, 0.078, 1.0);  // Pit Black
uniform float ember_energy = 2.4;
uniform float hot_energy = 3.2;
uniform float white_energy = 4.5;
uniform vec4 idle_color : source_color = vec4(0.42, 0.10, 0.06, 1.0); // eyes 0: a faint ember smoulder
uniform float idle_energy = 0.9;
varying vec3 obj;

void vertex() {
	obj = VERTEX;
}

void fragment() {
	vec3 c = obj.x < 0.0 ? eye_left : eye_right;
	vec2 d = (obj.xy - c.xy) / eye_size;
	float r = length(d);
	int lv = int(floor(level * heat + 0.5));
	// eyes 0 (and the snuff): a faint smoulder so the faces read from the game camera
	vec3 col = mix(off_color.rgb, idle_color.rgb, r < 0.75 ? 1.0 : 0.5);
	vec3 emit = col * idle_energy * clamp(heat, 0.0, 1.0);
	if (lv == 1) {
		col = ember_color.rgb;
		emit = ember_color.rgb * ember_energy;
		if (abs(d.x) < 0.14 && r < 0.8) { col = pupil_color.rgb; emit = vec3(0.0); }
	} else if (lv == 2) {
		col = r < 0.5 ? core_color.rgb : ember_color.rgb;
		emit = r < 0.5 ? core_color.rgb * hot_energy : ember_color.rgb * ember_energy;
		if (abs(d.x) < 0.1 && r < 0.75 && r > 0.0) { col = hell_color.rgb; emit = hell_color.rgb; }
	} else if (lv >= 3) {
		col = r < 0.5 ? white_color.rgb : (r < 0.8 ? core_color.rgb : ember_color.rgb);
		emit = r < 0.5 ? white_color.rgb * white_energy : (r < 0.8 ? core_color.rgb * hot_energy : ember_color.rgb * ember_energy);
	}
	ALBEDO = col;
	EMISSION = emit + col * 0.05;
}

void light() {
	DIFFUSE_LIGHT += vec3(0.2) * LIGHT_COLOR / PI * clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
}
