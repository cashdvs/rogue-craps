// Shared die surface shader: ONE material family (bone, brass, glass, wood,
// obsidian) for every die body and pip surface. It keeps toon_noir's lighting
// (light() is a verbatim copy of shaders/3d/toon_noir.gdshader, so dice shade
// exactly like before) and its die_lit / die_cold / emission uniforms (so
// DieVisual.set_glow_state keeps working), and adds, at zero triangles:
// - a thin bright bevel edge line (from the object-space normal: faces are
//   axis-aligned, the bevel crest is ~45 deg, so 1 - max|n| peaks on it)
// - edge micro-wear from bevel_map R (tiling 512 mask, triplanar, edges only)
// - wood grain (G), pores / grain speckle (B), glass frost (A)
// - pip recess: on a pip surface (pip_mode) the depth below the face plane
//   picks pip_map's shade (dark floor) and lip highlight, so a drilled pip
//   reads as a recess with a dark floor; printed pips (use_overlay, batch 3)
//   get a 1-sided inner shadow instead.
// - glass_mode: frosted/milky fake (fresnel + inner tint), fully opaque.
// Body materials never glow by themselves: glow_energy defaults to 0 and is
// driven by code (the lit state). Never put FX tints on albedo_tint.
// Interface (Godot Dev): albedo_tint, bevel_map, pip_map, glow_color, glow_energy.
shader_type spatial;
render_mode specular_disabled, ambient_light_disabled;

// --- interface ---
uniform vec4 albedo_tint : source_color = vec4(0.91, 0.86, 0.75, 1.0);
uniform sampler2D bevel_map : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform sampler2D pip_map : hint_default_white, filter_linear, repeat_disable;
uniform vec4 glow_color : source_color = vec4(0.910, 0.384, 0.165, 1.0); // Ember
uniform float glow_energy = 0.0;

// --- toon_noir lighting (same names / defaults) ---
uniform vec4 albedo : source_color = vec4(1.0, 1.0, 1.0, 1.0); // multiplier; DieVisual may set it
uniform vec4 shadow_color : source_color = vec4(0.165, 0.039, 0.063, 1.0);
uniform float mid_tint = 0.62;
uniform float wrap = 0.0;
uniform float band_lo = 0.15;
uniform float band_hi = 0.55;
uniform float band_soft = 0.04;
uniform float light_gain = 1.0;
uniform float att_ref = 0.6;
uniform vec4 ambient_color : source_color = vec4(0.102, 0.031, 0.047, 1.0);
uniform float ambient_energy = 0.25;
uniform float spec_size = 0.0;
uniform vec4 spec_color : source_color = vec4(1.0, 0.965, 0.878, 1.0);
uniform float spec_strength = 0.6;
uniform vec4 rim_color : source_color = vec4(0.18, 0.416, 0.384, 1.0);
uniform float rim_power = 3.0;
uniform float rim_strength = 0.0;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
uniform float roughness = 0.8;
uniform float die_lit = 0.0;
uniform float die_cold = 0.0;
uniform vec3 lit_albedo_mul = vec3(1.04, 1.00, 0.94);
uniform vec3 cold_albedo_mul = vec3(0.80, 0.78, 0.76);
uniform float cold_desat = 0.75;
uniform vec3 cold_warm_grey = vec3(1.00, 0.96, 0.90);
uniform float cold_light_desat = 0.8;
uniform vec4 state_rim_color : source_color = vec4(0.910, 0.384, 0.165, 1.0);
uniform float state_rim_energy = 0.85;
uniform float state_rim_power = 2.5;
uniform float lit_desat = 0.0;      // desaturate the lit response toward neutral (obsidian)

// --- surface treatment ---
uniform vec4 edge_line_color : source_color = vec4(1.0, 0.97, 0.90, 1.0);
uniform float edge_line = 0.85;     // 0 = off
uniform float edge_lo = 0.17;       // 1 - max|n| band: bevel crest ~0.29
uniform float edge_hi = 0.24;
uniform float wear = 0.18;          // edge micro-wear darkening
uniform float tex_scale = 0.05;     // metres per mask tile (triplanar)
uniform float speck = 0.06;         // B: pores / brushed grain
uniform float grain = 0.0;          // G: wood grain darkening
uniform vec4 grain_color : source_color = vec4(0.30, 0.16, 0.08, 1.0);
uniform float grain_axis = 0.0;     // 0 = grain along X, 1 = along Z
// pips
uniform bool pip_mode = false;
uniform float die_half = 0.04;      // half edge (m): the face plane
uniform float pip_depth = 0.0048;   // drilled depth (m) = pip_map x 1.0
uniform vec4 pip_floor_color : source_color = vec4(0.02, 0.02, 0.02, 1.0);
uniform float pip_lip = 0.35;       // lip highlight strength
uniform float pip_dark_at = 0.18;   // depth fraction where the wall is fully floor-dark (crisp at 48 px)
// glass (frosted, opaque)
uniform bool glass_mode = false;
uniform vec4 glass_inner : source_color = vec4(0.62, 0.66, 0.66, 1.0);
uniform vec4 glass_fresnel : source_color = vec4(1.0, 0.98, 0.94, 1.0);
uniform float glass_fresnel_power = 2.2;
uniform float frost = 0.08;
uniform vec4 glass_core : source_color = vec4(1.0, 0.66, 0.36, 1.0); // lit: warm inner core
uniform float glass_core_k = 0.0;
uniform float glass_lit_boost = 0.5;
uniform float glass_lit_lift = 0.0;
uniform vec4 glass_cold_tint : source_color = vec4(0.80, 0.86, 0.92, 1.0); // cold: cool frost
uniform float glass_cold_k = 0.0;
// printed faces (batch 3, locked colours)
uniform bool use_overlay = false;
uniform sampler2D overlay_tex : source_color, filter_linear_mipmap_anisotropic, hint_default_transparent;
uniform vec4 overlay_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float ink_shadow = 0.45;    // inner shadow under printed pips
uniform vec2 ink_shadow_dir = vec2(0.004, 0.004);
// Collector: face-mark desaturation lives on the mark decal, not here.

varying vec3 obj_pos;
varying vec3 obj_normal;

vec4 tri(vec3 p, vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z + 1e-5);
	vec3 q = p / tex_scale;
	return texture(bevel_map, q.zy) * w.x + texture(bevel_map, q.xz) * w.y + texture(bevel_map, q.xy) * w.z;
}

void vertex() {
	obj_pos = VERTEX;
	obj_normal = NORMAL;
}

void fragment() {
	vec3 n = normalize(obj_normal);
	vec3 an = abs(n);
	float e = 1.0 - max(an.x, max(an.y, an.z));
	vec4 m = tri(obj_pos, n);
	vec3 col = albedo_tint.rgb * albedo.rgb;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), glass_fresnel_power);
	if (pip_mode) {
		float face = max(abs(obj_pos.x), max(abs(obj_pos.y), abs(obj_pos.z)));
		float t = clamp((die_half - face) / pip_depth, 0.0, 1.0);
		vec4 pr = texture(pip_map, vec2(t, 0.5));
		float dk = smoothstep(0.0, pip_dark_at, t);
		col = mix(col, pip_floor_color.rgb, max(dk, 1.0 - pr.r));
		col += albedo_tint.rgb * pr.g * pip_lip;
	} else {
		col *= 1.0 - speck * (m.b - 0.3);
		if (grain > 0.0) {
			vec3 gp = grain_axis < 0.5 ? obj_pos.zyx : obj_pos.xyz;
			vec4 g = tri(gp, grain_axis < 0.5 ? n.zyx : n);
			col = mix(col, grain_color.rgb, g.g * grain);
		}
		if (glass_mode) {
			col = mix(glass_inner.rgb * albedo.rgb, col, 0.55 + 0.45 * fres);
			col = mix(col, glass_fresnel.rgb, fres * 0.6);
			col *= 1.0 + frost * (m.a - 0.5);
		}
		if (use_overlay) {
			vec4 ink = texture(overlay_tex, UV);
			float sh = texture(overlay_tex, UV + ink_shadow_dir).a;
			col *= 1.0 - ink_shadow * clamp(sh - ink.a, 0.0, 1.0);
			col = mix(col, ink.rgb * overlay_tint.rgb, ink.a * overlay_tint.a);
		}
		float edge_m = smoothstep(edge_lo, edge_hi, e);
		float worn = m.r * smoothstep(edge_lo * 0.6, edge_hi, e);
		col = mix(col, edge_line_color.rgb, edge_m * edge_line * (1.0 - 0.6 * m.r));
		col *= 1.0 - wear * worn;
	}
	float cold_k = die_cold * (1.0 - die_lit);
	if (die_lit > 0.0 || die_cold > 0.0) {
		vec3 lit_col = col * lit_albedo_mul;
		float luma = dot(col, vec3(0.299, 0.587, 0.114));
		vec3 cold_col = mix(col, luma * cold_warm_grey, cold_desat) * cold_albedo_mul;
		col = mix(col, lit_col, die_lit);
		col = mix(col, cold_col, cold_k);
	}
	if (glass_mode && !pip_mode) {
		// lit: warm core shows through the frost (centre of each face), cold: cool desaturated frost
		col = mix(col, glass_core.rgb, die_lit * glass_core_k * (1.0 - fres));
		col = mix(col, glass_cold_tint.rgb * dot(col, vec3(0.299, 0.587, 0.114)) * 1.15, cold_k * glass_cold_k);
	}
	col = mix(col, vec3(dot(col, vec3(0.299, 0.587, 0.114))), lit_desat * die_lit);
	ALBEDO = col;
	ROUGHNESS = mix(mix(roughness, 0.5, die_lit), 1.0, cold_k);
	vec3 emit = emission_color.rgb * emission_energy;
	vec3 shade = mix(col, shadow_color.rgb, 0.7);
	emit += shade * ambient_color.rgb * ambient_energy * 2.0;
	float vf = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), state_rim_power);
	if (die_lit > 0.0) {
		emit += die_lit * state_rim_color.rgb * state_rim_energy * vf;
	}
	// Code-driven lit glow only (0 by default): an even wash + a rim, kept
	// under the 1.0 bloom threshold so it also reads without glow (Compatibility).
	emit += glow_color.rgb * glow_energy * (0.35 + 0.65 * vf);
	if (glass_mode && !pip_mode) {
		emit += glass_core.rgb * glow_energy * glass_core_k * glass_lit_boost * (1.0 - 0.5 * fres);
		emit += col * die_lit * glass_lit_lift; // lit brightness step (0 at rest)
	}
	emit = mix(emit, vec3(dot(emit, vec3(0.299, 0.587, 0.114))), lit_desat * die_lit);
	EMISSION = emit;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float w = (ndl + wrap) / (1.0 + wrap);
	float att = clamp(ATTENUATION / att_ref, 0.0, 1.0);
	float l = clamp(w, 0.0, 1.0) * att;
	float b1 = smoothstep(band_lo - band_soft, band_lo + band_soft, l);
	float b2 = smoothstep(band_hi - band_soft, band_hi + band_soft, l);
	vec3 a = max(ALBEDO, vec3(0.002));
	vec3 shadow_rgb = mix(a, shadow_color.rgb, 0.7) * 0.35;
	vec3 band = mix(mix(shadow_rgb, a * mid_tint, b1), a, b2);
	// Only where this light reaches at all (outside the cone = nothing).
	float reach = smoothstep(0.0, 0.05, ATTENUATION);
	vec3 lc = LIGHT_COLOR / PI;
	float cold_l = die_cold * (1.0 - die_lit) * cold_light_desat;
	lc = mix(lc, vec3(dot(lc, vec3(0.299, 0.587, 0.114))), cold_l);
	// DIFFUSE_LIGHT is multiplied by ALBEDO later, so divide it back out.
	DIFFUSE_LIGHT += band / a * lc * light_gain * reach;
	if (spec_size > 0.0) {
		vec3 h = normalize(VIEW + LIGHT);
		float s = step(spec_size, dot(NORMAL, h)) * step(0.3, l);
		// A cold die has no gloss at all (specular 0).
		SPECULAR_LIGHT += spec_color.rgb * spec_strength * s * lc * att * (1.0 - die_cold * (1.0 - die_lit));
	}
	if (rim_strength > 0.0) {
		float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
		SPECULAR_LIGHT += rim_color.rgb * rim_strength * step(0.5, rim) * step(0.05, l) * lc;
	}
}
