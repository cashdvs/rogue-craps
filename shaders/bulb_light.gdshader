// Additive light cone from the bare bulb, with dust motes in the beam.
// Use on a ColorRect covering the screen with an additive CanvasItemMaterial
// feel (we set blend_add via render_mode).
shader_type canvas_item;
render_mode blend_add;

uniform vec2 bulb_pos = vec2(640.0, 30.0);   // screen pixels
uniform vec2 screen_size = vec2(1280.0, 720.0);
uniform vec4 light_color : source_color = vec4(1.0, 0.72, 0.4, 1.0);
uniform float strength = 0.22;
uniform float cone_width = 0.55;
uniform float flicker = 1.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 px = UV * screen_size;
	vec2 d = px - bulb_pos;
	float dist = length(d);
	// Cone: brightness falls off with angle away from straight down.
	float ang = abs(atan(d.x, max(d.y, 1.0)));
	float cone = smoothstep(cone_width, 0.0, ang) * smoothstep(900.0, 60.0, dist);
	// Hot glow right around the bulb.
	float glow = smoothstep(120.0, 0.0, dist);
	// Dust motes drifting in the beam.
	vec2 cell = floor((px + vec2(0.0, TIME * 12.0)) / 6.0);
	float mote = step(0.9975, hash(cell)) * cone;
	float a = (cone * strength + glow * 0.6 + mote * 0.5) * flicker;
	COLOR = vec4(light_color.rgb * a, 1.0);
}
