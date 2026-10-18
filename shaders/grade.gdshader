// Full-screen post pass drawn above the table and below the HUD
// (poc_feel.md 0 layering): base vignette, DANGER vignette for losses,
// desaturate/dim for the seven-out fizzle, and a light film grain.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float desaturate : hint_range(0.0, 1.0) = 0.0;
uniform float dim : hint_range(0.0, 1.0) = 0.0;
uniform float vignette = 0.35;
uniform vec4 danger_color : source_color = vec4(1.0, 0.18, 0.243, 1.0); // #FF2E3E
uniform float danger_vignette : hint_range(0.0, 1.0) = 0.0;
uniform float grain = 0.03;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(luma) * vec3(0.95, 1.0, 1.02), desaturate);
	col *= 1.0 - dim;
	vec2 c = SCREEN_UV - 0.5;
	float edge = 1.0 - smoothstep(0.85, 0.25, length(c * vec2(1.25, 1.0)));
	col *= 1.0 - vignette * edge;
	col = mix(col, danger_color.rgb * 0.8, danger_vignette * edge);
	col += (hash(SCREEN_UV * 900.0 + TIME) - 0.5) * grain;
	COLOR = vec4(col, 1.0);
}
