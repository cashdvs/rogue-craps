// Felt (poc_feel.md 1): UNDERFELT base, low-frequency cellular stains,
// a few burn marks, edge darkening, rounded-rect mask. Luminance variation
// stays small so dice/chips always read on top.
shader_type canvas_item;

uniform vec4 felt_color : source_color = vec4(0.071, 0.227, 0.212, 1.0); // #123A36
uniform vec4 stain_color : source_color = vec4(0.059, 0.188, 0.173, 1.0); // #0F302C
uniform vec4 burn_color : source_color = vec4(0.231, 0.051, 0.078, 1.0); // OXBLOOD
uniform vec2 rect_size = vec2(1360.0, 760.0);
uniform float corner_radius = 110.0;
uniform float edge_px = 120.0;
uniform vec2 light_uv = vec2(0.5, 0.32);
uniform float light_strength = 0.25;
uniform float flicker = 1.0;
// 0..1: seven-out darkening / crack heat.
uniform float scorch = 0.0;
// Additive felt flash (wins: BRASS 0.25 for 0.12 s).
uniform vec4 flash_color : source_color = vec4(0.69, 0.553, 0.235, 1.0);
uniform float flash = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
vec2 hash2(vec2 p) { return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float cellular(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	float d = 1.0;
	for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
		vec2 g = vec2(float(x), float(y));
		vec2 o = hash2(i + g);
		d = min(d, length(g + o - f));
	}
	return d;
}
float rounded_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 px = UV * rect_size;
	// Rounded-rect mask (anti-aliased).
	float sd = rounded_box(px - rect_size * 0.5, rect_size * 0.5, corner_radius);
	float mask = clamp(0.5 - sd, 0.0, 1.0);
	// Fine fibre + stains (6-10% alpha cells).
	float fiber = noise(px * vec2(0.8, 0.22)) * 0.5 + noise(px * vec2(0.22, 0.8)) * 0.5;
	vec3 col = felt_color.rgb * (0.95 + 0.07 * fiber);
	float cells = smoothstep(0.55, 0.15, cellular(px / 170.0));
	col = mix(col, stain_color.rgb, cells * 0.08);
	// Burn marks: a few small dark rings.
	float burn = 0.0;
	burn += smoothstep(26.0, 6.0, length(px - rect_size * vec2(0.18, 0.72)));
	burn += smoothstep(18.0, 4.0, length(px - rect_size * vec2(0.83, 0.28)));
	burn += smoothstep(14.0, 3.0, length(px - rect_size * vec2(0.66, 0.84)));
	col = mix(col, burn_color.rgb, clamp(burn, 0.0, 1.0) * 0.4);
	// Warm light pool from the bulb above the table.
	vec2 d = (UV - light_uv) * vec2(rect_size.x / rect_size.y, 1.0);
	float l = smoothstep(0.9, 0.0, length(d)) * light_strength * flicker;
	col *= (0.9 + l);
	// Edge darkening to 20% black over edge_px.
	float edge = smoothstep(0.0, edge_px, -sd);
	col *= mix(0.8, 1.0, edge);
	col *= 1.0 - scorch * 0.25;
	col += flash_color.rgb * flash;
	COLOR = vec4(col, mask);
}
