// Hearth backdrop (detail pass, Oct 19): one dark card far behind Smiles with out-of-focus silhouettes of
// other tables and their hanging lamps, so the room reads as a big casino. Painted procedurally in the
// card's UV (no texture), everything soft-edged (out of focus) and capped at `max_value` (linear) so it
// stays <= 10 % value and Smiles + the brazier own the top of the frame. Unshaded; fog still applies.
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;
#include "res://art/models/boards/hearth/shaders/hearth_instance.gdshaderinc"

uniform vec4 base_color : source_color = vec4(0.035, 0.024, 0.027, 1.0);   // near Pit Black, warm
uniform vec4 table_color : source_color = vec4(0.07, 0.11, 0.10, 1.0);     // a far table's felt, lamp-lit
uniform vec4 rail_color : source_color = vec4(0.14, 0.05, 0.06, 1.0);      // its rail
uniform vec4 lamp_color : source_color = vec4(1.0, 0.69, 0.44, 1.0);       // lamp #FFB070
uniform float max_value = 0.012;   // linear cap (~10 % value after the table's tonemap)
uniform float blur = 0.012;        // edge softness (UV)
uniform vec2 card_size = vec2(7.0, 3.2);
uniform float floor_v = 1.0;       // UV.y of the floor line (card bottom = the room floor)

float soft_box(vec2 p, vec2 c, vec2 h, float b) {
	vec2 d = abs(p - c) - h;
	float e = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
	return 1.0 - smoothstep(-b, b, e);
}

float soft_ell(vec2 p, vec2 c, vec2 r, float b) {
	float e = length((p - c) / r) - 1.0;
	return 1.0 - smoothstep(-b, b, e * min(r.x, r.y));
}

void fragment() {
	// metres on the card: x from the centre, y up from the floor
	vec2 m = vec2((UV.x - 0.5) * card_size.x, (floor_v - UV.y) * card_size.y);
	vec3 col = base_color.rgb * (0.7 + 0.3 * smoothstep(1.6, 0.0, m.y));
	// far tables: [x, felt height, half width] (smaller and lower = further away)
	vec3 tables[5] = vec3[](vec3(-2.6, 0.62, 0.62), vec3(-1.1, 0.52, 0.48), vec3(0.55, 0.56, 0.52), vec3(2.1, 0.66, 0.66), vec3(3.3, 0.5, 0.42));
	for (int i = 0; i < 5; i++) {
		vec3 t = tables[i];
		float s = t.z / 0.6;
		float top = soft_ell(m, vec2(t.x, t.y), vec2(t.z, 0.045 * s), blur * card_size.y * 1.4);
		float rail = soft_ell(m, vec2(t.x, t.y), vec2(t.z * 1.06, 0.075 * s), blur * card_size.y * 1.4) - top;
		float body = soft_box(m, vec2(t.x, t.y * 0.5), vec2(t.z * 0.92, t.y * 0.5), blur * card_size.y);
		// each table under its own lamp: a soft cone of light and the shade above it
		float lamp_y = t.y + 0.95 * s;
		float cone_w = mix(0.06, t.z * 0.9, clamp((lamp_y - m.y) / (lamp_y - t.y), 0.0, 1.0));
		float cone = (1.0 - smoothstep(cone_w * 0.6, cone_w, abs(m.x - t.x))) * step(t.y, m.y) * step(m.y, lamp_y);
		float shade = soft_ell(m, vec2(t.x, lamp_y), vec2(0.11 * s, 0.05 * s), blur * card_size.y);
		col = mix(col, base_color.rgb * 0.45, body * 0.9);
		col = mix(col, rail_color.rgb, clamp(rail, 0.0, 1.0));
		col = mix(col, table_color.rgb, top);
		col += lamp_color.rgb * 0.035 * cone * (0.6 + 0.4 * smoothstep(lamp_y, t.y, m.y));
		col = mix(col, lamp_color.rgb * 0.6, shade);
	}
	// keep it a backdrop: cap the value (the lamp shades hit the cap, everything else sits under it)
	// (painted in 0..0.2, then scaled so 0.2 = max_value)
	col = min(col, vec3(0.2)) * (max_value / 0.2);
	ALBEDO = col;
}
