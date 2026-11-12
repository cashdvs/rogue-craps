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

#ifndef KEG_STAVE_DIM_INC
#define KEG_STAVE_DIM_INC

instance uniform float lit_stave = 0.0;
instance uniform float stave_dim = 0.0;

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

#endif
