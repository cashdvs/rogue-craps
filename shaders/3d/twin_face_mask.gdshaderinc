// Twin Face glow mask math (Powder Keg Ember pair-of-dice glyph).
// Include from toon_noir_twin.gdshader. Do NOT edit toon_noir.gdshader.
//
// Mask texture (UV1, same 1024 5x5 face atlas layout as the keg overlay):
//   R = hard-edged glyph inlay (binary at bake)
//   G = soft halo falloff outside the glyph (~1.3x; 0 inside silhouette)
//   B, A = spare
// Import as non-colour / linear data with mipmaps (hint_default_black, no source_color).
// Lights only when `settled` > 0 AND world normal.y is in the up ramp
// smoothstep(up_lo, up_hi, n.y) — opposite 3 stave sharing the cell stays dark.
// Final values: AD-approved C+ Ember (VALUES.md, Oct 19 2026).

#ifndef TWIN_FACE_MASK_INC
#define TWIN_FACE_MASK_INC

uniform sampler2D twin_mask : hint_default_black, filter_linear_mipmap;
uniform float settled = 0.0;
uniform vec4 twin_glow : source_color = vec4(0.9098, 0.3843, 0.1647, 1.0); // Ember #E8622A
uniform float twin_strength = 1.6; // core emission
uniform float twin_halo_strength = 1.6; // halo emission = strength * G
uniform vec4 twin_unlit : source_color = vec4(0.2510, 0.2039, 0.2510, 1.0); // #403440 (renders ~#692B16)
uniform float up_lo = 0.80;
uniform float up_hi = 0.92;

// Weight in 0..1 for a world-space face normal that faces world up.
float twin_up_weight(vec3 world_n) {
	float y = normalize(world_n).y;
	return smoothstep(up_lo, up_hi, y);
}

// Gate = settled * up. inlay_w / halo_w are the masked, gated weights.
void twin_mask_sample(vec2 uv, vec3 world_n, out float inlay_w, out float halo_w, out float gate) {
	vec4 m = texture(twin_mask, uv);
	gate = clamp(settled, 0.0, 1.0) * twin_up_weight(world_n);
	inlay_w = m.r * gate;
	halo_w = m.g * gate;
}

#endif
