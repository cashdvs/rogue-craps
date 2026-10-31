// Soul liquid inside the flask: flat toon cyan bands (it is its own light, so
// it is unshaded), clipped at `fill` (instance uniform 0..1 between fill_min_y
// and fill_max_y in object space) with a sloshing surface. Back faces show as
// the bright liquid top, so the clipped volume still reads solid.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
#include "res://art/vfx/bonfire/shaders/bonfire_instance.gdshaderinc"

uniform vec4 deep_color : source_color = vec4(0.118, 0.561, 0.545, 1.0); // #1E8F8B
uniform vec4 body_color : source_color = vec4(0.310, 0.902, 0.878, 1.0); // #4FE6E0
uniform vec4 top_color : source_color = vec4(0.875, 1.0, 0.992, 1.0);   // #DFFFFD
uniform float fill_min_y = 0.002;
uniform float fill_max_y = 0.066;
uniform float energy = 1.25;
uniform float slosh = 0.0015;

varying vec3 obj_pos;

void vertex() {
	obj_pos = VERTEX;
}

void fragment() {
	float level = mix(fill_min_y, fill_max_y, clamp(fill, 0.0, 1.0));
	level += sin(obj_pos.x * 220.0 + TIME * 5.0) * slosh + sin(obj_pos.z * 170.0 - TIME * 3.7) * slosh * 0.7;
	if (obj_pos.y > level) {
		discard;
	}
	vec3 c = body_color.rgb;
	float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	if (fres > 0.62) {
		c = deep_color.rgb;
	}
	if (!FRONT_FACING || obj_pos.y > level - 0.003) {
		c = top_color.rgb;
	}
	ALBEDO = c * energy;
}
