// Toon mirror finish for the Mirror Die (art/models/dice/SPECIAL_DICE.md).
// A dark obsidian body that "reflects" a stepped, fake room instead of a real probe:
// the world-space reflection vector picks one of 4 hard bands (lamp / steel / ink horizon /
// felt). On a flat-shaded faceted mesh every facet flips band on its own as the die tumbles,
// which reads as polished mirror planes in the toon-noir style (no gradients, no probe, no
// screen-space reflections; Compatibility-safe). The lamp still adds toon light bands and a
// hard specular pip, like shaders/3d/toon_noir.gdshader.
shader_type spatial;
render_mode specular_disabled, ambient_light_disabled;

uniform vec4 albedo : source_color = vec4(0.102, 0.133, 0.149, 1.0);       // #1A2226 obsidian
uniform vec4 shadow_color : source_color = vec4(0.055, 0.078, 0.078, 1.0); // Pit Black
uniform vec4 lamp_band : source_color = vec4(0.91, 0.863, 0.753, 1.0);     // Bone #E8DCC0
uniform vec4 steel_band : source_color = vec4(0.384, 0.420, 0.427, 1.0);   // #626B6D
uniform vec4 horizon_band : source_color = vec4(0.055, 0.078, 0.078, 1.0); // Pit Black
uniform vec4 felt_band : source_color = vec4(0.071, 0.227, 0.212, 1.0);    // Underfelt #123A36
uniform float lamp_lo = 0.72;    // reflection.y above this = the lamp
uniform float steel_lo = 0.18;   // .. above this = steel sky
uniform float horizon_lo = -0.18; // .. above this = ink horizon, below = felt
uniform float reflect_energy = 0.55;
uniform float lamp_energy = 1.1;  // the lamp band only; > 1 lets it catch bloom
uniform float light_gain = 0.6;
uniform float att_ref = 0.6;
uniform float spec_size = 0.985;
uniform vec4 spec_color : source_color = vec4(1.0, 0.965, 0.878, 1.0);
uniform float spec_strength = 2.0;

void fragment() {
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 v = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	vec3 r = reflect(-v, n);
	vec3 band = felt_band.rgb;
	band = mix(band, horizon_band.rgb, step(horizon_lo, r.y));
	band = mix(band, steel_band.rgb, step(steel_lo, r.y));
	float lamp = step(lamp_lo, r.y);
	band = mix(band, lamp_band.rgb * lamp_energy, lamp);
	ALBEDO = albedo.rgb;
	ROUGHNESS = 0.1;
	EMISSION = band * reflect_energy;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float att = clamp(ATTENUATION / att_ref, 0.0, 1.0);
	float l = clamp(ndl, 0.0, 1.0) * att;
	vec3 a = max(ALBEDO, vec3(0.002));
	vec3 lit = mix(mix(a, shadow_color.rgb, 0.7) * 0.35, a, step(0.35, l));
	vec3 lc = LIGHT_COLOR / PI;
	float reach = smoothstep(0.0, 0.05, ATTENUATION);
	DIFFUSE_LIGHT += lit / a * lc * light_gain * reach;
	vec3 h = normalize(VIEW + LIGHT);
	SPECULAR_LIGHT += spec_color.rgb * spec_strength * step(spec_size, dot(NORMAL, h)) * step(0.2, l) * lc * att;
}
