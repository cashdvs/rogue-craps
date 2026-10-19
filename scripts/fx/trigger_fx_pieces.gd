## TriggerFx's per-frame pieces: the ring pulse, the row's own shapes, the
## sparks and the icon + chip. Stateless; TriggerFx owns the bursts.
class_name TriggerFxPieces
extends RefCounted


## Sparks fly out and DOWN from the hit, stepped (reduced motion: none).
## Rising sparks read as flame (QA), so every direction has y < 0.
static func sparks(b: TriggerFxPool.Burst, k: int, at: Vector3, tier: int, reduced: bool) -> void:
	var spark: Variant = b.row.get("spark")
	var n := TriggerFxDefs.SPARKS[tier]
	for i in b.sparks.size():
		if k < 0 or k > 2 or i >= n or reduced or not spark is Color:
			b.sparks[i].visible = false
			continue
		var dir := Vector3.RIGHT.rotated(Vector3.UP, TAU * i / n + 0.3)
		dir = (dir + Vector3(0, -0.2 - 0.15 * absf(sin(i * 2.1)), 0)).normalized()
		TriggerFxPool.show(b.sparks[i], at + dir * b.edge * (0.8 + 0.45 * k), b.edge * 0.22,
				TriggerShapes.texture(&"spark_diamond", spark), 1.0 - 0.3 * k)


## A ring pulse frame k (0 = the hit): 1.0x -> 1.8x the shape size, alpha
## 1 -> 0 over RING_FRAMES. Hidden outside the pulse: never a static ring.
static func pulse(m: MeshInstance3D, at: Vector3, s: float, k: int, tint: Color, scale: float) -> void:
	if k < 0 or k >= TriggerFxDefs.RING_FRAMES:
		m.visible = false
		return
	var u := float(k) / TriggerFxDefs.RING_FRAMES
	TriggerFxPool.show(m, at, s * scale * (1.0 + 0.8 * u), TriggerShapes.texture(&"ring_pulse_soft", tint), 1.0 - u)


## The row's own piece (what tells rows apart at a glance). All of these are
## depth-tested at the die's centre, so the die covers their middle: they
## read as a halo / rim around it, never as a tint on the body.
static func row_fx(fx: TriggerFx, b: TriggerFxPool.Burst, k: int, at: Vector3, s: float) -> void:
	b.card.visible = false
	b.frame.visible = false
	b.core.visible = false
	var on := k == 0 or k == 1
	var a := 1.0 if k == 0 else 0.45
	match b.row["fx"]:
		&"gild":  # a gold glow + shine bar on the pip tick (2 f), then the coin hops off
			if on:
				TriggerFxPool.show(b.card, at, s * (1.9 + 0.2 * k), TriggerShapes.texture(&"radial_glow_soft", TriggerFxDefs.BRASS_HI), a)
				TriggerFxPool.show(b.frame, at, s * 1.15, TriggerShapes.texture(&"shine_bar", TriggerFxDefs.BRASS_HI), a)
			if k == 1 and b.row.has("coin_flight"):
				TriggerFxLinks.coin_flight(fx, b.die, float(b.row["coin_flight"]) / fx.speed())
		&"needles":  # bone needles shoot out (2 f) and retract; red frame; ember core
			const NEEDLE_SIZE: Array[float] = [1.05, 1.55, 1.25]
			if k >= 0 and k < NEEDLE_SIZE.size():
				TriggerFxPool.show(b.card, at, s * NEEDLE_SIZE[k], TriggerShapes.texture(&"needles_radial", TriggerFxDefs.BONE), 1.0 if k < 2 else 0.7)
			if on:
				var hex := StringName(b.ctx.get("flavor", &"")) in [&"verdict", &"midnight"]
				TriggerFxPool.show(b.frame, at, s * 0.95, TriggerShapes.texture(&"frame_hex" if hex else &"frame_square", TriggerFxDefs.HELLFIRE), 1.0 if k == 0 else 0.5)
				TriggerFxPool.show(b.core, at, s * 1.2, TriggerShapes.texture(&"radial_glow_soft", TriggerFxDefs.EMBER_CORE), 0.9 if k == 0 else 0.4)
		&"glint":  # Mirror: a pale glass frame flashes as the glint lands
			if on:
				TriggerFxPool.show(b.frame, at, s * 0.95, TriggerShapes.texture(&"frame_square", TriggerFxDefs.GLASS), a)
		&"sparkle":  # Wild / Lantern 8: a bone 4-point sparkle behind the die
			if on:
				TriggerFxPool.show(b.card, at, s * (1.5 + 0.2 * k), TriggerShapes.texture(&"spark_diamond", TriggerFxDefs.BONE), a)
				TriggerFxPool.show(b.core, at, s * 1.1, TriggerShapes.texture(&"radial_glow_soft", TriggerFxDefs.EMBER_CORE), 0.6 * a)


## Icon frame k (0 = the hit): pops 1.25 -> 1.0, rising 4 px; holds
## ICON_HOLD, then fades. The chip (if the row has one) pops a frame later.
static func icon(fx: TriggerFx, b: TriggerFxPool.Burst, k: int) -> void:
	var ic := b.icon
	var sc := fx.px_scale()
	if k == 0:
		ic.setup(b.row["icon"], int(b.row["tier"]), sc, bool(b.ctx.get("cost", false)))
		ic.modulate.a = 1.0
		ic.visible = true
		b.chip.visible = false
		b.chip.modulate.a = 1.0
		if b.icon_tw != null and b.icon_tw.is_valid():
			b.icon_tw.kill()
		b.icon_tw = ic.create_tween().set_ignore_time_scale(true)
		b.icon_tw.tween_interval(TriggerFxDefs.ICON_HOLD / fx.speed())
		b.icon_tw.tween_property(ic, "modulate:a", 0.0, TriggerFxDefs.ICON_FADE / fx.speed())
		b.icon_tw.parallel().tween_property(b.chip, "modulate:a", 0.0, TriggerFxDefs.ICON_FADE / fx.speed())
		var chip := b.chip
		b.icon_tw.tween_callback(func() -> void:
			ic.visible = false
			chip.visible = false)
	ic.scale = Vector2.ONE * (1.25 if k == 0 else 1.0)
	ic.position = icon_pos(fx, b.die, ic.diameter) - Vector2(0, (4.0 if k >= 1 else 2.0) * sc)
	var label := String(b.ctx.get("chip", b.row.get("chip", "")))
	if k >= 1 and label != "":
		if k == 1:
			b.chip.setup(label, sc)
			b.chip.visible = true
		b.chip.scale = Vector2.ONE * (1.2 if k == 1 else 1.0)
		b.chip.position = ic.position + Vector2(ic.diameter + 4.0 * sc, (ic.diameter - b.chip.size.y) * 0.5)


## Above the value-tag anchor (die + 0.07 m), clamped to the safe area.
static func icon_pos(fx: TriggerFx, die: Node3D, diameter: float) -> Vector2:
	var vs := fx.get_viewport().get_visible_rect().size
	var p := vs * 0.5
	var c := fx.cam()
	if c != null and is_instance_valid(die):
		p = c.unproject_position(die.global_position + Vector3(0, 0.07, 0))
	p -= Vector2(diameter * 0.5, diameter * 1.6)
	return p.clamp(Vector2(8, 8), vs - Vector2(diameter + 8, diameter + 8))
