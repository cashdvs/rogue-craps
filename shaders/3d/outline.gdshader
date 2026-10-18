// Ink outline as an "inverted hull" next_pass (poc_3d.md section 8):
// draw the mesh again, pushed out a little, showing only its back faces.
// mode 0: push along the (smooth) normal. mode 1: push away from the mesh
// center (works for boxes/cylinders whose normals are hard).
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

uniform vec4 color : source_color = vec4(0.055, 0.078, 0.078, 1.0); // PIT_BLACK
uniform float width = 0.0042;
uniform int mode = 0;

void vertex() {
	if (mode == 0) {
		VERTEX += normalize(NORMAL) * width;
	} else {
		VERTEX += normalize(VERTEX) * width;
	}
}

void fragment() {
	ALBEDO = color.rgb;
}
