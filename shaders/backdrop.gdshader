// Oxblood wall behind the table: grimy painted texture with a faint
// damask-like pattern and smoke drifting slowly.
shader_type canvas_item;

uniform vec4 base_color : source_color = vec4(0.231, 0.051, 0.078, 1.0); // #3B0D14
uniform vec4 deep_color : source_color = vec4(0.055, 0.078, 0.078, 1.0); // #0E1414

float hash(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 15731.743); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 5; i++) { v += a * noise(p); p *= 2.1; a *= 0.5; }
	return v;
}

void fragment() {
	vec2 p = UV * vec2(16.0, 9.0);
	float paint = fbm(p * 1.5);
	float smoke = fbm(p * 0.6 + vec2(TIME * 0.03, -TIME * 0.05));
	// Diamond wallpaper pattern, very faint.
	vec2 g = abs(fract(p * vec2(1.0, 1.0) + 0.5) - 0.5);
	float diamond = smoothstep(0.03, 0.0, abs(g.x + g.y - 0.35));
	vec3 col = mix(deep_color.rgb, base_color.rgb, 0.45 + 0.55 * paint);
	col += vec3(0.35, 0.2, 0.1) * diamond * 0.05;
	col += vec3(0.25, 0.12, 0.1) * smoothstep(0.55, 0.9, smoke) * 0.25;
	COLOR = vec4(col, 1.0);
}
