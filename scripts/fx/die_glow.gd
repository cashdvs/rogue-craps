## Glow-only feel effects for DICE: score-tier glow, the Hot Hand pulse and
## sparks, and the short ember trail behind a flying die.
##
## Hard rule (Cash, Oct 19; bonfire_map_events_juice.md 3 and 6): NO FIRE ON
## DICE. Dice only glow. Fire (flat toon flipbook) lives on board props such
## as the brazier and candles. So everything here is built from three things:
## - the die's own emission + rim glow (toon_noir `emission_*`, `rim_*`),
## - one soft round halo card behind the die (no flame silhouette, no flicker),
## - a few tiny spark dots that FALL or drift (never rise like a flame).
## Colours (Art Director): warm amber -> orange -> gold -> near-white hot.
## Never violet (Satanic dice only) and never Soul cyan (Soul / the player).
## Pips stay dark ink, so the face still reads at 48 px on the hottest tier.
class_name DieGlow
extends RefCounted

## Glow tier colours, tier 0 (under 100) .. 3 (1000+), JuicePlan score tiers.
const TIER_COLORS: Array[Color] = [Color("#E89A3C"), Color("#E8622A"), Color("#E2C06A"), Color("#FFE6A8")]
## Body emission per tier. Only the top tier's ember-core colour may bloom.
const TIER_EMISSION: Array[float] = [0.45, 0.7, 0.95, 1.3]
## Rim (fresnel) glow strength per tier.
const TIER_RIM: Array[float] = [0.5, 0.75, 1.0, 1.3]
## Halo card size (x die edge) and alpha per tier.
const TIER_HALO_SIZE: Array[float] = [1.4, 1.5, 1.65, 1.8]
const TIER_HALO_ALPHA: Array[float] = [0.22, 0.3, 0.38, 0.5]
## Ember trail: spark life (Art Director: fades within ~0.3 s), emit step.
const TRAIL_LIFE: float = 0.26
const TRAIL_STEP: float = 0.045
## Hot Hand: spark count and life (a small burst, not a flare-up).
const HOT_SPARKS: int = 6
const HOT_SPARK_LIFE: float = 0.3
const HOT_PULSE_TIME: float = 0.25
const HALO_NAME := "GlowHalo"

static var _halo_tex: GradientTexture2D


static func tier_color(tier: int) -> Color:
	return TIER_COLORS[clampi(tier, 0, TIER_COLORS.size() - 1)]


## Lights die `d` at score tier `tier`: emission, rim and a soft halo. Stays
## until clear(d). Reduced motion keeps the glow (it isn't motion).
static func apply(d: DieVisual, tier: int) -> void:
	var k := clampi(tier, 0, TIER_COLORS.size() - 1)
	var c := TIER_COLORS[k]
	var m := d.body_material
	if m != null:
		if not d.has_meta("glow_rim_color"):
			d.set_meta("glow_rim_color", m.get_shader_parameter("rim_color"))
			d.set_meta("glow_rim_strength", m.get_shader_parameter("rim_strength"))
		m.set_shader_parameter("emission_color", c)
		m.set_shader_parameter("emission_energy", TIER_EMISSION[k])
		m.set_shader_parameter("rim_color", c)
		m.set_shader_parameter("rim_strength", TIER_RIM[k])
	var halo := d.get_node_or_null(HALO_NAME) as MeshInstance3D
	if halo == null:
		halo = _make_halo(d)
	(halo.mesh as QuadMesh).size = Vector2.ONE * d.edge * TIER_HALO_SIZE[k]
	(halo.material_override as StandardMaterial3D).albedo_color = Color(c, TIER_HALO_ALPHA[k])


## Back to the plain die (no emission, rim restored, halo gone).
static func clear(d: DieVisual) -> void:
	if not is_instance_valid(d):
		return
	var m := d.body_material
	if m != null:
		m.set_shader_parameter("emission_energy", 0.0)
		if d.has_meta("glow_rim_color"):
			m.set_shader_parameter("rim_color", d.get_meta("glow_rim_color"))
			m.set_shader_parameter("rim_strength", d.get_meta("glow_rim_strength"))
			d.remove_meta("glow_rim_color")
			d.remove_meta("glow_rim_strength")
	var halo := d.get_node_or_null(HALO_NAME)
	if halo != null:
		d.remove_child(halo)
		halo.queue_free()


## Hot Hand "ignite": a full ember glow pulse on the die (up in a frame, eases
## to the held Hot Hand glow) plus a few spark dots that pop out and fall.
## Returns the tween (tests).
static func hot_hand_pulse(d: DieVisual, fx_root: Node3D, reduced: bool) -> Tween:
	apply(d, 3)
	var m := d.body_material
	var tw := d.create_tween().set_ignore_time_scale(true)
	if m != null:
		m.set_shader_parameter("emission_color", Palette.EMBER)
		tw.tween_method(func(e: float) -> void: m.set_shader_parameter("emission_energy", e), 1.6, 1.0, HOT_PULSE_TIME)
	sparks(fx_root, d.global_position, HOT_SPARKS / 2 if reduced else HOT_SPARKS, HOT_SPARK_LIFE)
	return tw


## A few diamond-ish spark dots that pop out in every direction and FALL
## (gravity down, so they never read as rising flame).
static func sparks(parent: Node3D, at: Vector3, amount: int, life: float) -> void:
	Fx3D.burst(parent, at, amount, [Color("#FFE6A8"), Palette.EMBER, Color(Palette.EMBER, 0.0)],
			Vector2(0.25, 0.55), 180.0, -2.5, Vector2(0.5, 0.9), life, 1.6)


## Ember trail behind a moving die for `seconds`: every TRAIL_STEP two tiny
## dots/dashes drop off the die and fade in TRAIL_LIFE. No ribbon, no tongue.
static func ember_trail(d: DieVisual, fx_root: Node3D, seconds: float) -> void:
	var steps := int(seconds / TRAIL_STEP)
	for i in steps:
		d.get_tree().create_timer(i * TRAIL_STEP, true, false, true).timeout.connect(func() -> void:
			if is_instance_valid(d) and is_instance_valid(fx_root):
				Fx3D.burst(fx_root, d.global_position, 2, [Color("#FFE6A8"), Palette.EMBER, Color(Palette.EMBER, 0.0)],
						Vector2(0.02, 0.08), 180.0, -1.0, Vector2(0.4, 0.8), TRAIL_LIFE, 1.4))


static func _make_halo(d: DieVisual) -> MeshInstance3D:
	if _halo_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.55))
		_halo_tex = GradientTexture2D.new()
		_halo_tex.gradient = g
		_halo_tex.fill = GradientTexture2D.FILL_RADIAL
		_halo_tex.fill_from = Vector2(0.5, 0.5)
		_halo_tex.fill_to = Vector2(0.5, 0.0)
		_halo_tex.width = 64
		_halo_tex.height = 64
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_texture = _halo_tex
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var q := QuadMesh.new()
	var halo := MeshInstance3D.new()
	halo.name = HALO_NAME
	halo.mesh = q
	halo.material_override = mat
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	d.add_child(halo)
	return halo
