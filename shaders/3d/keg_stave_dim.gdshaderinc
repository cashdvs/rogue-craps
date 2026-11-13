// Powder Keg numeral dim. Included by toon_noir.gdshader and toon_noir_twin.gdshader
// so the fade still works if the keg body swaps to the Twin Face shader.
//
// The barrel is read from the stave that points up (face value 1, 2 or 3).
// The table camera looks down, so a neighbouring stave — a different number,
// a different atlas cell — faces the lens more than the scoring stave.
// After settle the die sets two instance uniforms on its own mesh:
//   lit_stave  0 = every numeral full (rolling, and every other prop)
//              1, 2 or 3 = that face value's cell stays full
//   stave_dim  0 = no fade yet, 1 = other numeral cells faded
// Atlas is 5x5. Value v lives in cell v-1 (BATCH3.md). Godot's mesh UV needs
// no V flip: value 1 sits near (0.1, 0.1), which is cell 0. Same rule as
// KegStaveDim.cell_of_uv. Lids and hoops (cells 23 and 24) are not numerals.
// This only scales existing ink. It adds no emission.
//
// keg_body is 1 on a Powder Keg mesh and 0 everywhere else. The keg body
// inherits the bone die's hard specular (spec_size 0.97, cream white). That
// lobe paints the up stave white, and the same highlight on the iron hoops
// reads as tally marks beside the digit. Specular and rim stay off the whole
// mustard stave: numeral cells and every gutter cell between them. Only the
// lids (cell 23) and hoops (cell 24) keep a shine, and that shine is the
// keg's own soft lobe (keg_spec_lobe) at spec_strength 0.05.

#ifndef KEG_STAVE_DIM_INC
#define KEG_STAVE_DIM_INC

instance uniform float lit_stave = 0.0;
instance uniform float stave_dim = 0.0;
instance uniform float keg_body = 0.0;

// Share of ink contrast a dimmed numeral keeps against the stave wood.
const float KEG_DIM_KEEP = 0.30;

float keg_cell_index(vec2 uv) {
	float x = floor(clamp(uv.x, 0.0, 0.999) * 5.0);
	float y = floor(clamp(uv.y, 0.0, 0.999) * 5.0);
	return y * 5.0 + x;
}

// 1 = draw the overlay ink at full strength. Lower = fade it toward the wood.
float keg_ink_keep(vec2 uv) {
	float keep = 1.0;
	// lit_stave - 1.0 is the atlas cell (value 1 -> cell 0). A wrong index
	// lights a different cell than the number the table scored.
	if (stave_dim > 0.001 && lit_stave >= 0.5) {
		float cell = keg_cell_index(uv);
		float lit_cell = lit_stave - 1.0;
		if (cell <= 2.5 && abs(cell - lit_cell) >= 0.5) {
			keep = mix(1.0, KEG_DIM_KEEP, clamp(stave_dim, 0.0, 1.0));
		}
	}
	return keep;
}

// 1 = keep specular / rim. On a keg, only the lids (23) and hoops (24) do.
// Cells 0-22 are the mustard stave, including the gutters between numerals.
float keg_spec_keep(float cell, float _ink_a) {
	if (keg_body < 0.5 || cell > 22.5) {
		return 1.0;
	}
	return 0.0;
}

// Bone dice use a hard step at spec_size (0.97). A keg uses a wider, soft
// ramp so the hoops and lids glint without a razor stripe.
float keg_spec_lobe(float ndh, float hard_size) {
	if (keg_body > 0.5) {
		return smoothstep(0.40, 0.82, ndh);
	}
	return step(hard_size, ndh);
}

#endif
