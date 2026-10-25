// Soul Reliquary vessel: opaque toon glass with the Soul liquid inside (no fluid sim, no refraction).
// One octagonal shell; UV.y runs 0 (vessel floor) .. 1 (brim), the dome uses UV.y > 1 (glass only).
// Soul cyan (#4FE6E0) appears ONLY here, below `fill`. Unshaded so the warm Hearth lamp never shifts it.
// Hooks for the VFX owner (all off by default): ghost_fill/ghost_alpha (the red lost chunk above the
// liquid), pulse (heartbeat brightening). frost (0..1) frosts the glass at its edges and rims only.
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

uniform float fill : hint_range(0.0, 1.0) = 1.0;
uniform float fill_lo = 0.0;                  // body height (0..1) hidden by the bottom ring: fill 0 sits here
uniform float fill_hi = 1.0;                  // and fill 1 just under the top ring (set by soul_reliquary.gd)
uniform float tick_step = 0.142857;          // 5 Soul / max_soul (etched tick every 5 Soul)
uniform vec4 liquid_color : source_color = vec4(0.310, 0.902, 0.878, 1.0);   // #4FE6E0
uniform vec4 liquid_deep : source_color = vec4(0.106, 0.478, 0.490, 1.0);
uniform vec4 glass_color : source_color = vec4(0.150, 0.205, 0.212, 1.0);
uniform vec4 glass_hi : source_color = vec4(0.62, 0.72, 0.70, 1.0);
uniform vec4 frost_color : source_color = vec4(0.80, 0.87, 0.89, 1.0);
uniform float frost : hint_range(0.0, 1.0) = 0.0;
uniform float wisp_speed = 0.25;
// --- VFX hooks (not driven by the art) ---
uniform float ghost_fill : hint_range(0.0, 1.0) = 0.0;   // top of the red ghost chunk (<= fill: none)
uniform float ghost_alpha : hint_range(0.0, 1.0) = 0.0;
uniform vec4 ghost_color : source_color = vec4(1.0, 0.180, 0.243, 1.0);      // #FF2E3E
uniform float pulse : hint_range(0.0, 1.0) = 0.0;         // heartbeat: brightens the liquid

varying vec3 v_local;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	v_local = VERTEX;
}

void fragment() {
	float h = UV.y;
	float a = UV.x;
	float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	// glass: dark smoky, a stepped rim and one hard vertical highlight streak (toon glass)
	vec3 col = glass_color.rgb;
	col = mix(col, glass_hi.rgb * 0.55, step(0.62, fres));
	float streak = step(0.30, NORMAL.x) * step(NORMAL.x, 0.46);
	col = mix(col, glass_hi.rgb, streak * 0.75);
	float span = fill_hi - fill_lo;
	float lvl = fill_lo + span * fill;
	float glvl = fill_lo + span * ghost_fill;
	float hs = (h - fill_lo) / span;                     // 0..1 in Soul space for the ticks
	bool in_liquid = h < lvl;
	if (in_liquid) {
		float w = vnoise(vec2(a * 14.0 + sin(h * 9.0 + TIME * wisp_speed) * 0.8, h * 5.0 - TIME * wisp_speed));
		float band = step(0.55, w);                          // two-tone wisps, stepped (toon)
		vec3 lc = mix(liquid_deep.rgb, liquid_color.rgb, 0.55 + 0.45 * band);
		lc = mix(lc, liquid_color.rgb, 0.35);
		lc = mix(lc, liquid_deep.rgb * 0.6, step(0.72, fres));          // volume: darker at the silhouette
		float men = step(lvl - 0.035, h);                                // bright meniscus at the surface
		lc = mix(lc, mix(liquid_color.rgb, vec3(1.0), 0.45), men);
		lc *= 1.0 + 0.45 * pulse;
		col = mix(lc, col, streak * 0.45);
	} else if (h < glvl) {
		col = mix(col, ghost_color.rgb, ghost_alpha);
	}
	// etched ticks every 5 Soul, short lines on the front face only
	if (hs > 0.0 && hs < 0.999 && v_local.z > 0.0 && abs(v_local.x) < 0.009) {
		float t = fract(hs / tick_step + 0.5) - 0.5;
		float tick = step(abs(t) * tick_step * span, 0.006);
		vec3 tc = in_liquid ? liquid_deep.rgb * 0.7 : glass_hi.rgb * 0.7;
		col = mix(col, tc, tick * step(0.04, hs));
	}
	// frost: crystalline patches creeping in from the rims and the silhouette (glass only, never the plate)
	if (frost > 0.0) {
		float n = vnoise(vec2(a * 40.0, h * 22.0)) * 0.6 + vnoise(vec2(a * 90.0, h * 60.0)) * 0.4;
		// creeps down from the top rim / dome and in from the silhouette; never over the liquid (the last Soul stays cyan)
		float edge = max(smoothstep(0.70, 1.0, min(h, 1.0)), smoothstep(0.55, 0.95, fres) * 0.8);
		edge = max(edge, step(1.0, h) * 0.75);
		float m = step(1.0 - edge * frost, n) * (in_liquid ? 0.0 : 1.0);
		col = mix(col, frost_color.rgb, m * 0.9);
	}
	ALBEDO = col;
}
