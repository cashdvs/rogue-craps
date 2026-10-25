// Lit / dimmed die outline (AD #162): an inverted hull grown in VIEW space,
// radially in the screen plane from the die centre,
// so it hugs the silhouette evenly on every side; it is nudged toward the
// camera so the felt never hides its bottom edge. (A world-space grow or
// scale also shows the far wall above the top faces: the "flare".)
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

uniform vec4 color : source_color = vec4(0.910, 0.384, 0.165, 1.0); // #E8622A
uniform float width = 0.010;
uniform float emission_energy = 0.4;

void vertex() {
	vec3 c = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 p = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 d = p.xy - c.xy;
	float l = length(d);
	if (l > 1e-5) {
		p.xy += d / l * width;
	}
	p.z += width * 0.6;
	POSITION = PROJECTION_MATRIX * vec4(p, 1.0);
}

void fragment() {
	ALBEDO = color.rgb * (1.0 + emission_energy);
}
