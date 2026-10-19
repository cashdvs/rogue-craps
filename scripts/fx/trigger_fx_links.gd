## TriggerFx pieces that travel between places: the Mirror / Coin glass glint
## (die to die, with its arrival motes) and the Gilded coin hop to the Ember
## counter (3D to screen). Static helpers on a TriggerFx.
class_name TriggerFxLinks
extends RefCounted

## Glint streak length (x die edge): the same in every direction (the quad's
## basis is orthonormal; only the mesh size sets its length).
const STREAK: float = 1.6


## Mirror / Coin: a glass glint streak travels from b.source to the die over
## the row's glint frames [from, to], lying along its path and bowing
## sideways across the felt (never up), with two fading dots behind it. On
## arrival two small glass motes wink at the die's top-right corner, clear
## of the face's centre so the copied value stays readable (Art Director).
static func glint(fx: TriggerFx, b: TriggerFxPool.Burst, f: int, at: Vector3) -> void:
	b.glint.visible = false
	for t in b.trail:
		t.visible = false
	var g: Variant = b.row.get("glint")
	if not g is Array:
		return
	var f0 := int(g[0])
	var f1 := int(g[1])
	if f < f0 or f > f1:
		return
	var glass := TriggerFxDefs.GLASS
	var cam := fx.cam()
	if f == f1:
		var motes := mote_points(at, b.edge, cam)
		const SIZES: Array[float] = [0.34, 0.22]
		for i in 2:
			TriggerFxPool.show(b.trail[i], motes[i], b.edge * SIZES[i], TriggerShapes.texture(&"spark_dot_soft", glass), 1.0)
		return
	if b.source == null or not is_instance_valid(b.source):
		return
	var u := float(f - f0) / float(f1 - f0)
	var from := b.source.global_position
	TriggerFxPool.show(b.glint, glint_point(from, at, u, cam), b.edge * STREAK, TriggerShapes.texture(&"glint_streak", glass), 1.0)
	face_camera(b.glint, glint_point(from, at, minf(u + 0.05, 1.0), cam) - glint_point(from, at, maxf(u - 0.05, 0.0), cam), cam)
	for i in b.trail.size():
		var v := u - 0.12 * (i + 1)
		if v >= 0.0:
			TriggerFxPool.show(b.trail[i], glint_point(from, at, v, cam), b.edge * 0.3, TriggerShapes.texture(&"spark_diamond", glass), 0.7 - 0.3 * i)


## The two arrival motes: at the die's top-right corner on screen (camera
## right + up), never over the face's centre.
static func mote_points(at: Vector3, edge: float, cam: Camera3D) -> Array[Vector3]:
	var r := cam.global_basis.x if cam != null else Vector3.RIGHT
	var u := cam.global_basis.y if cam != null else Vector3.UP
	return [at + (r * 0.62 + u * 0.55) * edge, at + (r * 0.9 + u * 0.25) * edge]


## Orients the (non-billboard) glint quad to face the camera with its x axis
## along `along` (projected on the screen plane); a zero vector = upright.
## The basis stays orthonormal, so the streak is the same length any way.
static func face_camera(m: MeshInstance3D, along: Vector3, cam: Camera3D) -> void:
	var z := cam.global_basis.z if cam != null else Vector3.BACK
	var x := along - z * along.dot(z)
	if x.length() < 0.00001:
		x = cam.global_basis.x if cam != null else Vector3.RIGHT
	x = x.normalized()
	var y := z.cross(x).normalized()
	m.global_basis = Basis(x, y, z)


## A point on the glint's path at u (0 = source, 1 = target): a sideways bow
## toward the camera across the felt; height goes straight from one die to
## the other, so it never rises above the higher one.
static func glint_point(from: Vector3, to: Vector3, u: float, cam: Camera3D = null) -> Vector3:
	var d := to - from
	var side := d.cross(Vector3.UP)
	side.y = 0.0
	if side.length() < 0.0001:
		return from.lerp(to, u)
	side = side.normalized()
	if cam != null and side.dot(cam.global_position - (from + to) * 0.5) < 0.0:
		side = -side
	return from.lerp(to, u) + side * sin(PI * u) * 0.3 * Vector2(d.x, d.z).length()


## Gilded: a small brass coin hops up off the die, flipping through its
## face / tilt / edge frames, and arcs to the Ember counter; coin_landed fires
## when it gets there (spec 2a, GD 8.3). Screen space and outside the burst
## cap, so it reads at any die size.
static func coin_flight(fx: TriggerFx, die: Node3D, seconds: float) -> void:
	var c: TriggerIcon = null
	for x in fx._coins:
		if not x.visible:
			c = x
			break
	if c == null or fx.reduced or fx.speed_mode >= 2:
		fx.coin_landed.emit(die)
		return
	var sc := fx.px_scale()
	c.setup(&"brass_coin", TriggerFxDefs.MINOR, sc)
	c.coin_frame = 0
	c.visible = true
	c.modulate.a = 1.0
	var vs := fx.get_viewport().get_visible_rect().size
	var from := vs * 0.5
	var cam := fx.cam()
	if cam != null and is_instance_valid(die):
		from = cam.unproject_position(die.global_position + Vector3(0, 0.04, 0))
	from -= Vector2.ONE * c.diameter * 0.5
	var to := fx.pile_screen if fx.pile_screen.x >= 0.0 else Vector2(vs.x - 150.0 * sc, 20.0 * sc)
	var hop := 70.0 * sc
	var sprite := TriggerShapes.fixed("coin_brass_face") != null
	var seq: Array[int] = [0, 1, 2, 1]
	var tw := c.create_tween()
	tw.tween_method(func(u: float) -> void:
		# Up off the die first (a hop), then the long arc to the counter.
		var e := u * u * (3.0 - 2.0 * u)
		c.position = from.lerp(to, e) - Vector2(0, sin(minf(u * 1.6, 1.0) * PI * 0.5) * hop * (1.0 - e * 0.6))
		# Two flips at 12 fps: face, tilt, edge, tilt, face ... (the sprite's
		# frames; the code stand-in squashes instead).
		c.coin_frame = seq[int(u * seconds * TriggerFxDefs.FPS) % seq.size()]
		if not sprite:
			c.scale = Vector2(maxf(absf(cos(u * TAU * 2.0)), 0.15), 1.0), 0.0, 1.0, seconds)
	tw.tween_callback(func() -> void:
		c.visible = false
		if is_instance_valid(fx):
			fx.coin_landed.emit(die))
