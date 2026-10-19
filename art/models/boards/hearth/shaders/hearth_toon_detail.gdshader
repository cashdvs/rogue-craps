// Hearth detail-pass variant of shaders/3d/toon_noir.gdshader (art/concept/bonfire_table/hearth_detail_pass.md).
// IDENTICAL toon-noir lighting (same uniforms, same bands; keep in sync if toon_noir changes) plus three
// Hearth-only extras, all off by default, so any toon_noir material can switch to this shader unchanged:
// - use_carve: the carved rail relief (textures/rail_carve.png: RG tangent normal, B brass edge mask, A cavity),
//   tiled along the rail UVs (Board A rails: 2 U per metre, V round the tube). Normal map, groove darkening and
//   a brass edge highlight on the raised parts; faded out on the far rail (carve_skip_u: Smiles' side).
// - rim_emit: a thin warm rim (unlit, fresnel step) that separates small props from the black backdrop;
//   rim_emit_up biases it to upward-facing normals (a top-edge rim, e.g. the tail).
// - use_scratches: claw scratches cut into the near-rail corners (procedural, in rail UV metres).
// - drip_mode: the wax drips down the rails creep very slowly (vertex) and a wet sheen runs down them.
// Includes hearth_instance.gdshaderinc first so the rail's instance uniforms keep their slots across its passes.
// Toon-noir shading for every opaque 3D prop (art/concept/poc_3d.md section 8).
// - 3 stepped diffuse bands (shadow / mid / lit) with optional wrap lighting.
//   Shadows go warm oxblood-black (or pit-teal-black on the felt), never grey.
// - A hard specular band (brass, bone), a stepped fresnel rim (felt "fuzz").
// - Optional extras used by a few materials: a felt print overlay texture,
//   felt grime noise, a chip notch pattern, emission (eyes, bulb, puck glow).
shader_type spatial;
render_mode specular_disabled, ambient_light_disabled;
#include "res://art/models/boards/hearth/shaders/hearth_instance.gdshaderinc"

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
uniform sampler2D overlay_tex : source_color, filter_linear_mipmap, hint_default_transparent;
uniform vec4 overlay_tint : source_color = vec4(0.91, 0.86, 0.75, 0.85);
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


// --- Hearth detail pass ---
uniform bool use_carve = false;
uniform sampler2D carve_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float carve_tile_u = 0.611409;   // 13.451 / 22: 22 tiles close round the Board A rails
uniform float carve_normal = 1.0;
uniform float carve_cavity = 0.35;
uniform vec2 carve_skip_u = vec2(0.0, 4.07);   // rail U span with no carving (the far rail)
uniform float carve_brass = 0.0;               // brass edge highlight on the raised relief (0 = off)
uniform vec4 carve_brass_color : source_color = vec4(0.886, 0.706, 0.42, 1.0);
uniform float carve_brass_emit = 0.0;          // a little unlit brass so the edges read in the lamp falloff
uniform float rim_emit = 0.0;                  // 0 = off
uniform vec4 rim_emit_color : source_color = vec4(0.91, 0.384, 0.165, 1.0);  // EMBER #E8622A
uniform float rim_emit_width = 0.22;           // fresnel band (1 - N.V) that lights: thin
uniform float rim_emit_up = 0.0;               // 0 = all round, 1 = upward-facing edges only
uniform bool use_scratches = false;
uniform vec2 scratch_u = vec2(6.80, 10.58);  // rail U where the two near-corner claw marks start
uniform float scratch_amount = 0.6;
uniform vec4 scratch_lip : source_color = vec4(0.47, 0.20, 0.22, 1.0);  // scuffed leather beside the cuts
uniform bool drip_mode = false;
uniform float drip_top = 0.1;            // board-space y the drips hang from
uniform float drip_grow = 0.12;          // the drips creep this fraction of their length
uniform float drip_period = 48.0;        // s per (very slow) creep cycle
uniform float drip_scroll = 0.004;       // m/s the wet sheen runs down
uniform vec4 drip_sheen : source_color = vec4(1.0, 0.95, 0.84, 1.0);
uniform float drip_sheen_amount = 0.16;

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

// One claw mark: 4 tapered parallel slashes in rail-surface metres (p = along, across the tube).
float claw(vec2 p, float dir) {
	vec2 d = normalize(vec2(1.0 * dir, 0.85));
	vec2 n = vec2(-d.y, d.x);
	vec2 q = p - vec2(0.045 * dir, -0.028);
	float along = dot(q, d);
	float across = dot(q, n);
	float sp = 0.0085;
	float idx = clamp(floor(across / sp + 2.0), 0.0, 3.0);
	float off = across - (idx - 1.5) * sp;
	float half_len = 0.026 + 0.007 * sin(idx * 2.3 + dir);
	float t = clamp(along / half_len, -1.0, 1.0);
	float w = 0.0012 * (1.0 - t * t);
	return smoothstep(w, w * 0.35, abs(off)) * step(abs(along), half_len);
}

void vertex() {
	if (drip_mode) {
		float below = max(drip_top - VERTEX.y, 0.0);
		float ph = hash(floor((VERTEX.xz + vec2(3.0)) * 20.0));
		float g = 1.0 - drip_grow * (0.5 + 0.5 * cos(6.28318 * (TIME / drip_period + ph)));
		VERTEX.y = drip_top - below * g;
	}
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
	if (use_overlay) {
		vec4 ink = texture(overlay_tex, UV);
		col = mix(col, ink.rgb, ink.a * overlay_tint.a);
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
	vec3 carve_emit = vec3(0.0);
	if (use_carve) {
		vec4 c = texture(carve_tex, vec2(UV.x / carve_tile_u, UV.y));
		float on = 1.0 - smoothstep(carve_skip_u.x - 0.06, carve_skip_u.x + 0.06, UV.x) * (1.0 - smoothstep(carve_skip_u.y - 0.06, carve_skip_u.y + 0.06, UV.x));
		NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), vec3(c.rg, 1.0), on);
		NORMAL_MAP_DEPTH = carve_normal;
		col *= 1.0 - carve_cavity * c.a * on;
		col = mix(col, carve_brass_color.rgb, carve_brass * c.b * on);
		carve_emit = carve_brass_color.rgb * carve_brass_emit * c.b * on;
	}
	if (use_scratches) {
		float w = (UV.y > 0.5 ? UV.y - 1.0 : UV.y) * 0.565487;  // arc metres from the tube top (+ = felt side)
		float s = 0.0;
		float lip = 0.0;
		for (int i = 0; i < 2; i++) {
			float u0 = i == 0 ? scratch_u.x : scratch_u.y;
			vec2 p = vec2((UV.x - u0) * 0.5, w);
			float dir = i == 0 ? 1.0 : -1.0;
			s = max(s, claw(p, dir));
			lip = max(lip, claw(p + vec2(0.0006, 0.0006), dir));
		}
		col = mix(col, scratch_lip.rgb, clamp(lip - s, 0.0, 1.0) * scratch_amount);
		col *= 1.0 - 0.55 * s * scratch_amount;
	}
	if (drip_mode) {
		float b = fract((world_pos.y + TIME * drip_scroll) * 22.0);
		col += drip_sheen.rgb * drip_sheen_amount * smoothstep(0.82, 0.97, b) * (1.0 - smoothstep(0.97, 1.0, b));
	}
	if (scorch > 0.0) {
		col *= 1.0 - 0.5 * scorch;
	}
	ALBEDO = col;
	ROUGHNESS = roughness;
	vec3 emit = emission_color.rgb * emission_energy + carve_emit;
	if (rim_emit > 0.0) {
		float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		float ny = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y;
		float up = mix(1.0, smoothstep(0.05, 0.45, ny), rim_emit_up);
		emit += rim_emit_color.rgb * rim_emit * smoothstep(1.0 - rim_emit_width - 0.04, 1.0 - rim_emit_width, fres) * up;
	}
	emit += flash_color.rgb * flash;
	// Ambient: the shadow band at ambient strength (so unlit sides stay warm).
	vec3 shade = mix(col, shadow_color.rgb, 0.7);
	emit += shade * ambient_color.rgb * ambient_energy * 2.0;
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
	// DIFFUSE_LIGHT is multiplied by ALBEDO later, so divide it back out.
	DIFFUSE_LIGHT += band / a * lc * light_gain * reach;
	if (spec_size > 0.0) {
		vec3 h = normalize(VIEW + LIGHT);
		float s = step(spec_size, dot(NORMAL, h)) * step(0.3, l);
		SPECULAR_LIGHT += spec_color.rgb * spec_strength * s * lc * att;
	}
	if (rim_strength > 0.0) {
		float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
		SPECULAR_LIGHT += rim_color.rgb * rim_strength * step(0.5, rim) * step(0.05, l) * lc;
	}
}
