// Toon-noir shading for every opaque 3D prop (art/concept/poc_3d.md section 8).
// - 3 stepped diffuse bands (shadow / mid / lit) with optional wrap lighting.
//   Shadows go warm oxblood-black (or pit-teal-black on the felt), never grey.
// - A hard specular band (brass, bone), a stepped fresnel rim (felt "fuzz").
// - Optional extras used by a few materials: a felt print overlay texture,
//   felt grime noise, a chip notch pattern, emission (eyes, bulb, puck glow).
shader_type spatial;
render_mode specular_disabled, ambient_light_disabled;

uniform vec4 albedo : source_color = vec4(0.91, 0.86, 0.75, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.165, 0.039, 0.063, 1.0); // #2A0A10
uniform float mid_tint = 0.62;
uniform float wrap = 0.0;
uniform float band_lo = 0.15;
uniform float band_hi = 0.55;
uniform float band_soft = 0.04;
// How bright a "fully lit" surface is, relative to its albedo.
uniform float light_gain = 1.0;
// Light attenuation that counts as "fully lit" (lamp falloff gets stepped too).
uniform float att_ref = 0.6;
// Ambient: a flat fraction of the shadow band everywhere (the room is dark).
uniform vec4 ambient_color : source_color = vec4(0.102, 0.031, 0.047, 1.0); // #1A080C
uniform float ambient_energy = 0.25;

uniform float spec_size = 0.0; // 0 = off; brass 0.92, bone 0.97
uniform vec4 spec_color : source_color = vec4(1.0, 0.965, 0.878, 1.0);
uniform float spec_strength = 0.6;

uniform vec4 rim_color : source_color = vec4(0.18, 0.416, 0.384, 1.0);
uniform float rim_power = 3.0;
uniform float rim_strength = 0.0;

uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
uniform float roughness = 0.8;

// Felt extras: print overlay (alpha = ink), grime noise, flash/scorch pulses.
uniform bool use_overlay = false;
uniform sampler2D overlay_tex : source_color, filter_linear_mipmap_anisotropic, hint_default_transparent;
uniform vec4 overlay_tint : source_color = vec4(0.91, 0.86, 0.75, 0.85);
// Emission of the overlay print, x its colour (the Bonfire combo table: 0.35,
// so the print reads in the lamp's falloff). 0 = off.
uniform float overlay_emission = 0.0;
// The print's placement on the felt (UV units): scaled by overlay_scale about
// overlay_pivot, then moved by overlay_shift. Identity by default. Phone
// portrait shrinks the combo block into the camera's view.
uniform vec2 overlay_pivot = vec2(0.5, 0.5);
uniform float overlay_scale = 1.0;
uniform vec2 overlay_shift = vec2(0.0, 0.0);
uniform float grime = 0.0;
uniform vec4 grime_color : source_color = vec4(0.059, 0.188, 0.172, 1.0); // FELT_STAIN
uniform float flash = 0.0;
uniform vec4 flash_color : source_color = vec4(0.886, 0.753, 0.416, 1.0);
uniform float scorch = 0.0;

// Chip extras: 8 edge notches + an inset ring (object space, chip radius 1).
uniform bool chip_mode = false;
uniform vec4 notch_color : source_color = vec4(0.91, 0.86, 0.75, 1.0);
uniform vec4 ring_color : source_color = vec4(0.43, 0.10, 0.14, 1.0);
uniform float chip_radius = 0.0275;

// Die readability states (art/ui/readability/dice_states, design section 4).
// die_lit 1 = a scoring die: warm albedo + an emissive ember fresnel rim
// (energy 0.85 stays under the 1.0 glow threshold, so the rim never blooms).
// die_cold 1 = a die that did not score: matte, desaturated warm grey, no
// gloss. Both are 0 on every other prop, so nothing else changes.
uniform float die_lit = 0.0;
uniform float die_cold = 0.0;
uniform vec3 lit_albedo_mul = vec3(1.04, 1.00, 0.94);
uniform vec3 cold_albedo_mul = vec3(0.80, 0.78, 0.76);
uniform float cold_desat = 0.75;
uniform vec3 cold_warm_grey = vec3(1.00, 0.96, 0.90);
// How much a cold die greys the lights on it too (the lamp and the rail
// glow are warm / red: without this a cold die reads brown, not grey).
uniform float cold_light_desat = 0.8;
uniform vec4 state_rim_color : source_color = vec4(0.910, 0.384, 0.165, 1.0); // #E8622A
uniform float state_rim_energy = 0.85;
uniform float state_rim_power = 2.5;

varying vec3 obj_pos;
varying vec3 obj_normal;
varying vec3 world_pos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	obj_pos = VERTEX;
	obj_normal = NORMAL;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 col = albedo.rgb;
	if (grime > 0.0) {
		float n = vnoise(world_pos.xz * 4.0) * 0.6 + vnoise(world_pos.xz * 11.0) * 0.4;
		col = mix(col, grime_color.rgb, smoothstep(0.55, 0.8, n) * grime);
		col *= 0.94 + 0.06 * vnoise(world_pos.xz * 160.0); // fabric grain
	}
	vec3 overlay_emit = vec3(0.0);
	if (use_overlay) {
		vec2 ouv = overlay_pivot + (UV - overlay_pivot - overlay_shift) / max(overlay_scale, 0.01);
		vec4 ink = texture(overlay_tex, ouv);
		ink.a *= step(0.0, ouv.x) * step(ouv.x, 1.0) * step(0.0, ouv.y) * step(ouv.y, 1.0);
		col = mix(col, ink.rgb, ink.a * overlay_tint.a);
		overlay_emit = ink.rgb * ink.a * overlay_tint.a * overlay_emission;
	}
	if (chip_mode) {
		float r = length(obj_pos.xz) / chip_radius;
		float ang = atan(obj_pos.z, obj_pos.x);
		float notch = step(0.5, fract(ang / 6.28318 * 8.0));
		bool side = abs(obj_normal.y) < 0.5;
		if (side || r > 0.82) {
			col = mix(col, notch_color.rgb, notch);
		} else if (abs(r - 0.72) < 0.035) {
			col = ring_color.rgb;
		}
	}
	if (scorch > 0.0) {
		col *= 1.0 - 0.5 * scorch;
	}
	float cold_k = die_cold * (1.0 - die_lit);
	if (die_lit > 0.0 || die_cold > 0.0) {
		vec3 lit_col = col * lit_albedo_mul;
		float luma = dot(col, vec3(0.299, 0.587, 0.114));
		vec3 cold_col = mix(col, luma * cold_warm_grey, cold_desat) * cold_albedo_mul;
		col = mix(col, lit_col, die_lit);
		col = mix(col, cold_col, cold_k);
	}
	ALBEDO = col;
	ROUGHNESS = mix(mix(roughness, 0.5, die_lit), 1.0, cold_k);
	vec3 emit = emission_color.rgb * emission_energy + overlay_emit;
	emit += flash_color.rgb * flash;
	// Ambient: the shadow band at ambient strength (so unlit sides stay warm).
	vec3 shade = mix(col, shadow_color.rgb, 0.7);
	emit += shade * ambient_color.rgb * ambient_energy * 2.0;
	if (die_lit > 0.0) {
		float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), state_rim_power);
		emit += die_lit * state_rim_color.rgb * state_rim_energy * fres;
	}
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
