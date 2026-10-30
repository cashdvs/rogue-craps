## The d4's "light resistance" pass (AD #198, the same idea as the #201 rare
## dice trim in rare_die_look.gd): a second, UNSHADED draw of the d4 body in
## its own body colour (and its printed marks), blended over the lit toon
## draw. The lamp's shadow leaves a d4's steep faces near black; mixing about
## half of the flat colour back in keeps them readable AND keeps the body's
## own hue (no glow, no pale tint). It follows the die's lit / cold state
## (DieVisual._apply_glow sets die_lit / die_cold on it), so a cold d4 greys
## like every other cold die.
class_name D4FlatPass
extends RefCounted

## Share of the flat colour drawn over the lit result (AD: 40-60%).
const MIX := 0.6
## A cold die gets no lamp-lit faces to brighten it, so the flat colour of a
## cold d4 is lifted by this much (a plain scale: the hue does not change)
## to land at the cold d6's brightness (~0.45 on screen).
const COLD_LIFT := 1.5

## Same colour maths as toon_noir.gdshader's fragment() albedo part (overlay
## marks, lit tint, cold grey), minus all lighting.
const SHADER := """shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;
uniform vec4 albedo : source_color;
uniform float mix_amount = 0.5;
uniform bool use_overlay = false;
uniform sampler2D overlay_tex : source_color, filter_linear_mipmap_anisotropic, hint_default_transparent;
uniform vec4 overlay_tint : source_color = vec4(0.91, 0.86, 0.75, 0.85);
uniform vec2 overlay_pivot = vec2(0.5, 0.5);
uniform float overlay_scale = 1.0;
uniform vec2 overlay_shift = vec2(0.0, 0.0);
uniform float die_lit = 0.0;
uniform float die_cold = 0.0;
uniform vec3 lit_albedo_mul = vec3(1.04, 1.00, 0.94);
uniform vec3 cold_albedo_mul = vec3(0.80, 0.78, 0.76);
uniform float cold_desat = 0.75;
uniform vec3 cold_warm_grey = vec3(1.00, 0.96, 0.90);
uniform float lit_albedo_mix_max = 0.35;
uniform float cold_lift = 1.0;
void fragment() {
	vec3 col = albedo.rgb;
	if (use_overlay) {
		vec2 ouv = overlay_pivot + (UV - overlay_pivot - overlay_shift) / max(overlay_scale, 0.01);
		vec4 ink = texture(overlay_tex, ouv);
		ink.a *= step(0.0, ouv.x) * step(ouv.x, 1.0) * step(0.0, ouv.y) * step(ouv.y, 1.0);
		col = mix(col, ink.rgb, ink.a * overlay_tint.a);
	}
	float cold_k = die_cold * (1.0 - die_lit);
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 cold_col = mix(col, luma * cold_warm_grey, cold_desat) * cold_albedo_mul;
	col = mix(col, col * lit_albedo_mul, min(die_lit, lit_albedo_mix_max));
	col = mix(col, cold_col, cold_k) * mix(1.0, cold_lift, cold_k);
	ALBEDO = col;
	ALPHA = mix_amount;
}
"""

static var _shader: Shader


## Puts the flat pass on [param body_mat] (the die's toon material), between
## it and its ink outline. Copies the colour and marks it needs. Returns it.
static func add(body_mat: ShaderMaterial) -> ShaderMaterial:
	if body_mat.next_pass is ShaderMaterial and (body_mat.next_pass as ShaderMaterial).shader == _get_shader():
		return body_mat.next_pass  # already there
	var f := ShaderMaterial.new()
	f.shader = _get_shader()
	f.set_shader_parameter("mix_amount", MIX)
	f.set_shader_parameter("cold_lift", COLD_LIFT)
	for k in ["albedo", "use_overlay", "overlay_tex", "overlay_tint", "overlay_pivot", "overlay_scale",
			"overlay_shift", "die_lit", "die_cold", "lit_albedo_mix_max"]:
		var v = body_mat.get_shader_parameter(k)
		if v != null:
			f.set_shader_parameter(k, v)
	f.next_pass = body_mat.next_pass  # the ink outline still draws last
	body_mat.next_pass = f
	return f


static func _get_shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	return _shader
