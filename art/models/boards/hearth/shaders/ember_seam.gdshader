// Hearth ember seam: a thin emissive groove drawn ON the existing rail mesh (no new geometry).
// Used as the leather material's next_pass: it redraws the rail, pushed out 0.7 mm along the
// normal, and keeps only a narrow band of the rail UV's V (the "around the tube" axis of
// rails.glb: V = 1 - phi / 360, phi = 0 on top, 90 outward, 270 inward), so the band runs along the
// inner lip all the way round the felt. Groove = Pit Black edges, Ember fill, Butter core on a pulse.
// level = idle glow (0-1), pulse = the 0.15 s lit-die pulse (seam_pulse clip), heat = snuff.
shader_type spatial;
render_mode unshaded, shadows_disabled, depth_draw_opaque;
#include "res://art/models/boards/hearth/shaders/hearth_instance.gdshaderinc"

uniform float band_v = 0.125;     // centre of the band in UV.y (phi ~315 deg: the inner top lip, ~8 cm up, clear of the backboard strip)
uniform float band_half = 0.012;  // half width in UV.y (~7 mm on the 0.09 m tube)
uniform float push = 0.0007;
uniform vec4 groove_color : source_color = vec4(0.055, 0.078, 0.078, 1.0); // Pit Black
uniform vec4 ember_color : source_color = vec4(0.910, 0.384, 0.165, 1.0);  // Ember
uniform vec4 core_color : source_color = vec4(1.0, 0.902, 0.659, 1.0);     // Butter
uniform float idle_energy = 0.9;
uniform float pulse_energy = 2.4;

void vertex() {
	VERTEX += NORMAL * push;
}

void fragment() {
	float d = abs(UV.y - band_v) / band_half;
	if (d > 1.0) {
		discard;
	}
	float on = clamp(heat, 0.0, 1.0);
	float glow = (level * idle_energy + pulse * pulse_energy) * on;
	vec3 col = groove_color.rgb;
	if (d < 0.62 && glow > 0.02) {
		col = ember_color.rgb * max(glow, 0.35);
		if (pulse * on > 0.35 && d < 0.3) {
			col = core_color.rgb * (1.0 + pulse * pulse_energy * 0.6);
		}
	}
	ALBEDO = col;
}
