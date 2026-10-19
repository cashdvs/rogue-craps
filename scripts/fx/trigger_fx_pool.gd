## TriggerFx's pre-warmed nodes (spec 1.7: pooled, nothing allocated while
## playing): one Burst per live effect, its billboard cards and its icon /
## chip. Static helpers; TriggerFx owns the nodes.
class_name TriggerFxPool
extends RefCounted


## One pooled burst: its nodes and its play state.
class Burst:
	extends RefCounted
	## The row's own pieces: card (needles, gold glow), frame (silhouette
	## frame / shine bar), core (ember-core glow).
	var card: MeshInstance3D
	var frame: MeshInstance3D
	var core: MeshInstance3D
	## The ring pulse and an optional inner one a frame later.
	var ring: MeshInstance3D
	var ring2: MeshInstance3D
	## Mirror / Coin: the travelling glass glint; on arrival, one of the two motes.
	var glint: MeshInstance3D
	## The glint's two fading dots (in flight) or the second mote (on arrival).
	var trail: Array[MeshInstance3D] = []
	var sparks: Array[MeshInstance3D] = []
	var icon: TriggerIcon
	var chip: TriggerChip
	var icon_tw: Tween
	var id: StringName
	var row: Dictionary
	var die: Node3D
	## The die a copy reads from (ctx.source), or null.
	var source: Node3D
	var ctx: Dictionary
	## Play time (s, scaled by rate) and the last 12 fps frame stepped.
	var t: float = 0.0
	var rate: float = 1.0
	var f: int = -1
	## The die's inner `faces` node, its transform at start, and what the FX
	## last wrote there (if the table changes it, the FX lets go: B4).
	var faces: Node3D
	var rest: Transform3D
	var written: Transform3D
	var edge: float = 0.08


## A fresh burst with all its nodes under `owner` / `icon_layer`, hidden.
static func make_burst(owner: Node3D, icon_layer: CanvasLayer) -> Burst:
	var b := Burst.new()
	b.core = card(owner, 0)
	b.card = card(owner, 0)
	b.frame = card(owner, 0)
	b.ring = card(owner, 0)
	b.ring2 = card(owner, 0)
	b.glint = card(owner, 2)
	(b.glint.material_override as StandardMaterial3D).billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	for i in 8:
		b.sparks.append(card(owner, 1))
	for i in 2:
		b.trail.append(card(owner, 2))
	b.icon = TriggerIcon.new()
	b.icon.visible = false
	icon_layer.add_child(b.icon)
	b.chip = TriggerChip.new()
	b.chip.visible = false
	icon_layer.add_child(b.chip)
	return b


## Every 3D card of `b`.
static func meshes(b: Burst) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = [b.card, b.frame, b.core, b.ring, b.ring2, b.glint]
	out.append_array(b.sparks)
	out.append_array(b.trail)
	return out


## A billboard card. priority 0 = glow (depth-tested so the die hides the
## back half), 1 = sparks, 2 = the glint (spec 1.6), both without depth test.
static func card(owner: Node3D, priority: int) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = QuadMesh.new()
	m.material_override = mat(priority)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.visible = false
	owner.add_child(m)
	return m


## Unshaded, alpha, billboarded (glow only: no lights, no fire).
static func mat(priority: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	m.no_depth_test = priority > 0
	m.render_priority = priority
	return m


## Shows card `m` at `at`, `size` m square, with `tex` (null = keep) at `alpha`.
static func show(m: MeshInstance3D, at: Vector3, size: float, tex: Texture2D, alpha: float, tint: Color = Color.WHITE) -> void:
	var mt := m.material_override as StandardMaterial3D
	if tex != null:
		mt.albedo_texture = tex
	mt.albedo_color = Color(tint, alpha)
	(m.mesh as QuadMesh).size = Vector2.ONE * size
	m.global_position = at
	m.visible = alpha > 0.0


## Every shape texture the rows use, so the first trigger doesn't hitch.
static func prewarm() -> void:
	var rows: Array[Dictionary] = [TriggerFxDefs.GENERIC]
	rows.append_array(TriggerFxDefs.ROWS.values())
	for row in rows:
		TriggerShapes.texture(&"ring_pulse_soft", row["ring"])
		if row.get("ring2") is Color:
			TriggerShapes.texture(&"ring_pulse_soft", row["ring2"])
		if row.get("spark") is Color:
			TriggerShapes.texture(&"spark_diamond", row["spark"])
	for pair: Array in [[&"glint_streak", TriggerFxDefs.GLASS], [&"spark_diamond", TriggerFxDefs.GLASS],
			[&"spark_dot_soft", TriggerFxDefs.GLASS], [&"frame_square", TriggerFxDefs.GLASS], [&"needles_radial", TriggerFxDefs.BONE],
			[&"frame_square", TriggerFxDefs.HELLFIRE], [&"frame_hex", TriggerFxDefs.HELLFIRE], [&"radial_glow_soft", TriggerFxDefs.EMBER_CORE],
			[&"radial_glow_soft", TriggerFxDefs.BRASS_HI], [&"shine_bar", TriggerFxDefs.BRASS_HI], [&"spark_diamond", TriggerFxDefs.BONE]]:
		TriggerShapes.texture(pair[0], pair[1])
