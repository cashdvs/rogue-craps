// Twin Face glow mask math (Powder Keg Ember pair-of-dice glyph).
// Include from toon_noir_twin.gdshader. Do NOT edit toon_noir.gdshader.
//
// Mask texture (UV1, same 1024 5x5 face atlas layout as the keg overlay):
//   R = hard-edged glyph inlay
//   G = soft halo falloff (~1.3x the glyph), glow only
//   B, A = spare
// Lights only when `settled` > 0 AND the fragment's world-space face normal
// points near world up (so the opposite 3 stave sharing the atlas cell stays dark).

#ifndef TWIN_FACE_MASK_INC
#define TWIN_FACE_MASK_INC

uniform sampler2D twin_mask : filter_linear_mipmap, hint_default_black;
uniform float settled = 0.0;
uniform vec4 twin_glow : source_color = vec4(0.9098, 0.3843, 0.1647, 1.0); // Palette.EMBER #E8622A
uniform float twin_strength = 1.35; // a bit above 1.2
uniform vec4 twin_unlit : source_color = vec4(0.4157, 0.1804, 0.1098, 1.0); // #6A2E1C
uniform float up_threshold = 0.92;
uniform float up_soft = 0.08; // smoothstep width below up_threshold

// Weight in 0..1 for a world-space face normal that faces world up.
float twin_up_weight(vec3 world_n) {
	float y = normalize(world_n).y;
	return smoothstep(up_threshold - up_soft, up_threshold, y);
}

// Gate = settled * up. inlay_w / halo_w are the masked, gated weights.
void twin_mask_sample(vec2 uv, vec3 world_n, out float inlay_w, out float halo_w, out float gate) {
	vec4 m = texture(twin_mask, uv);
	gate = clamp(settled, 0.0, 1.0) * twin_up_weight(world_n);
	inlay_w = m.r * gate;
	halo_w = m.g * gate;
}

#endif
