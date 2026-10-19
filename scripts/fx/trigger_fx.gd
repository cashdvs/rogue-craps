## Special-die and face-mod trigger FX (trigger_fx_spec.md v0.2): the shared
## grammar, a pre-warmed pool and the burst cap. One entry point:
##   trigger_fx(&"mirror_copy", die, {source = other_die}) -> float
## returns the seconds until the KEY HIT (the sound sync frame).
##
## Grammar (spec 1.1), stepped at 12 fps (one frame = 83 ms, toon stutter):
##   f0-f1 anticipation: squash (a Mirror / Coin glint may already travel)
##   key hit (f2/f3/f4 per row): stretch, a ring PULSE (grows and fades in
##     0.25 s, tinted per row), the row's own piece (glint / gold halo + coin
##     hop / corner needles), sparks out and down, the icon pops
##   motion beat: the row's per-frame keys (TriggerFxDefs.BEATS)
##   settle: the die returns exactly to rest; the icon holds 0.5 s and fades
## Motion is applied to the die's inner `faces` node in WORLD axes and always
## restored to the exact rest transform, so the seeded face remap and the
## table's own tweens on the die node are never disturbed. Glow only, and
## never on the die body: no material on the die is touched, and every glow
## card is open in the middle. No fire, no real lights (bloom only), sparks
## never rise above the die.
##
## Sound: TableAudio is the only caller of sfx.play_mod_trigger. At a burst's
## start this asks `audio.mod_trigger(id, die, anchor, ctx)` and, if the cue
## plays (returns seconds > 0), retimes the burst so the flash lands on the
## audio hit. Speed: 2x plays twice as fast; Instant shows static icons only;
## reduced motion keeps glow + icon, no die motion and no sparks (spec 1.3).
##
## Cap (spec 1.4, Art Director Oct 19): at most MAX_LIVE (4) bursts at once;
## the rest wait, starts are STAGGER (0.08 s) apart, biggest tier first.
class_name TriggerFx
extends Node3D

## The key-hit frame of a burst (tests, captures, HUD hooks).
signal hit(id: StringName, die: Node3D)
## The Gilded coin reached the ember pile: tick the Ember counter now.
signal coin_landed(die: Node3D)

## One pooled burst: its nodes and its play state.
class Burst:
	extends RefCounted
	## The row's own pieces: card (needles, gold glow), frame (silhouette
	## frame / shine bar), core (ember-core glow).
	var card: MeshInstance3D
	var frame: MeshInstance3D
	var core: MeshInstance3D
	var ring: MeshInstance3D
	var ring2: MeshInstance3D
	## Mirror / Coin: the travelling glass glint and its fading trail.
	var glint: MeshInstance3D
	var trail: Array[MeshInstance3D] = []
	var sparks: Array[MeshInstance3D] = []
	var icon: TriggerIcon
	var chip: TriggerChip
	var icon_tw: Tween
	var id: StringName
	var row: Dictionary
	var die: Node3D
	var source: Node3D
	var ctx: Dictionary
	var t: float = 0.0
	var rate: float = 1.0
	var f: int = -1
	var faces: Node3D
	var rest: Transform3D
	var edge: float = 0.08

var camera: Camera3D
## TableAudio (or anything with mod_trigger(id, die, anchor, ctx) -> float).
var audio: Node
var table: Node
var speed_mode: int = 0
var reduced: bool = false
## Screen point the Gilded coin flies to (default: the top-right Ember counter).
var pile_screen := Vector2(-1, -1)
var icon_layer: CanvasLayer
var events: Object
var _pool: Array[Burst] = []
var _live: Array[Burst] = []
var _queue: Array[Dictionary] = []
var _seq: int = 0
var _clock: float = 0.0
var _next_start: float = 0.0
## Gilded flight coins (screen space), pre-warmed.
var _coins: Array[TriggerIcon] = []


func _init() -> void:
	name = "TriggerFx"


func _ready() -> void:
	icon_layer = CanvasLayer.new()
	icon_layer.name = "TriggerIcons"
	# Above the 3D post layer (1), below the HUD (2: count-up and banner).
	icon_layer.layer = 1
	add_child(icon_layer)
	var mobile := str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")) != "forward_plus"
	for i in TriggerFxDefs.POOL_MOBILE if mobile else TriggerFxDefs.POOL_PC:
		_pool.append(_make_burst())
	for i in 4:
		var c := TriggerIcon.new()
		c.visible = false
		icon_layer.add_child(c)
		_coins.append(c)
	# Pre-warm every shape texture now, so the first trigger doesn't hitch.
	var rows: Array[Dictionary] = [TriggerFxDefs.GENERIC]
	rows.append_array(TriggerFxDefs.ROWS.values())
	for row in rows:
		TriggerShapes.texture(&"ring_pulse_soft", row["ring"])
		if row.get("ring2") is Color:
			TriggerShapes.texture(&"ring_pulse_soft", row["ring2"])
		if row.get("spark") is Color:
			TriggerShapes.texture(&"spark_diamond", row["spark"])
	for pair: Array in [[&"glint_streak", TriggerFxDefs.GLASS], [&"spark_diamond", TriggerFxDefs.GLASS], [&"frame_square", TriggerFxDefs.GLASS],
			[&"needles_radial", TriggerFxDefs.BONE], [&"frame_square", TriggerFxDefs.HELLFIRE], [&"frame_hex", TriggerFxDefs.HELLFIRE],
			[&"radial_glow_soft", TriggerFxDefs.EMBER_CORE], [&"radial_glow_soft", TriggerFxDefs.BRASS_HI], [&"shine_bar", TriggerFxDefs.BRASS_HI]]:
		TriggerShapes.texture(pair[0], pair[1])
	_bind_to_parent.call_deferred()


## As a child of the table: listen to table.events (once it exists), sound
## through the sibling TableAudio, and read the game camera.
func _bind_to_parent() -> void:
	var t := get_parent()
	if t == null or table != null:
		return
	table = t
	if audio == null:
		audio = t.get_node_or_null("TableAudio")
	_sync_modes()
	var ev: Variant = t.get("events")
	if ev is Object:
		bind(ev as Object)


func pool_size() -> int:
	return _pool.size() + _live.size()


func live_count() -> int:
	return _live.size()


func queued_count() -> int:
	return _queue.size()


## Listens to Godot Dev's TableEvents. With `triggers_resolved` (#91) the
## bursts start at each entry's start_s (the pip time - 0.167 s for scoring,
## from the settle for landing copies), so the hit lands ON the tick, and
## `mod_triggered` (sent at the tick itself) is ignored to avoid doubles.
## Without it, `mod_triggered` starts the burst at once (its anchor / ctx
## arguments are optional: 5- or 7-argument forms both bind).
func bind(ev: Object, t: Node = null) -> bool:
	events = ev
	if t != null:
		table = t
	if ev == null:
		return false
	if ev.has_signal(&"triggers_resolved"):
		ev.connect(&"triggers_resolved", _on_triggers_resolved)
		return true
	if ev.has_signal(&"mod_triggered"):
		ev.connect(&"mod_triggered", _on_mod_triggered)
		return true
	return false


## Stages that get trigger FX (lit / boss beats are other FX, not triggers).
const FX_STAGES: Array[StringName] = [&"land", &"copies", &"scoring"]


## One resolve step's triggers (TableEvents.triggers_resolved): each entry
## {stage, row_id, tier, die_id, intensity, anchor, ctx, start_s}.
func _on_triggers_resolved(triggers: Array) -> void:
	for e: Dictionary in triggers:
		var stage := StringName(e.get("stage", &""))
		var id := TriggerFxDefs.hook(StringName(e.get("row_id", &"")))
		if not FX_STAGES.has(stage) or (stage != &"scoring" and not TriggerFxDefs.ROWS.has(id)):
			continue
		var ctx: Dictionary = (e.get("ctx", {}) as Dictionary).duplicate()
		var target := int(ctx.get("target_die", -1))
		if target >= 0 and target != int(e.get("die_id", -1)):
			ctx["source"] = target
		var start := float(e.get("start_s", 0.0))
		var call := func() -> void:
			_on_mod_triggered(id, int(e.get("tier", 0)), int(e.get("die_id", -1)), float(e.get("intensity", 1.0)), 0,
					StringName(e.get("anchor", &"")), ctx)
		if start <= 0.0:
			call.call()
		else:
			get_tree().create_timer(start, true, false, false).timeout.connect(call)


func _on_mod_triggered(row_id: StringName, _tier: int, die_id: int, intensity: float, _hit_ms: int,
		anchor: StringName = &"", ctx: Dictionary = {}) -> void:
	var die := _die(die_id)
	if die == null:
		return
	var c := ctx.duplicate()
	c["die_id"] = die_id
	c["intensity"] = c.get("intensity", intensity)
	if anchor != &"":
		c["anchor"] = anchor
	if c.has("source") and c["source"] is int:
		c["source"] = _die(int(c["source"]))
	trigger_fx(row_id, die, c)


func _die(die_id: int) -> Node3D:
	if table == null:
		return null
	if table.has_method("die_by_id"):
		return table.call("die_by_id", die_id) as Node3D
	var list: Variant = table.get("all_dice") if "all_dice" in table else table.get("dice")
	if list is Array and die_id >= 0 and die_id < (list as Array).size():
		return (list as Array)[die_id] as Node3D
	return null


## Plays row `id` on `die`. ctx (all optional): source (the die a copy reads
## from), flavor, anchor, rate (count-up compression), cost, intensity, tier.
## Returns seconds until the key hit (an estimate if it has to wait its turn).
func trigger_fx(id: StringName, die: Node3D, ctx: Dictionary = {}) -> float:
	if die == null:
		return -1.0
	_sync_modes()
	id = TriggerFxDefs.hook(id)
	var row := TriggerFxDefs.row(id)
	if speed_mode >= 2:
		_instant(id, die, row, ctx)
		return 0.0
	_queue.append({"id": id, "die": die, "ctx": ctx, "tier": int(row["tier"]), "seq": _seq})
	_seq += 1
	var wait := maxf(0.0, _next_start - _clock)
	var started := _pump()
	if started != null and started.die == die and started.id == id:
		return TriggerFxDefs.hit_time(id) / started.rate
	return wait + TriggerFxDefs.hit_time(id) / _speed()


## Several triggers of one pot in resolve order: they start 0.08 s apart,
## biggest first, at most 4 at once. Returns their (estimated) hit times.
func play_pot(list: Array) -> Array[float]:
	var out: Array[float] = []
	for e: Dictionary in list:
		out.append(trigger_fx(e["id"], e["die"], e.get("ctx", {})))
	return out


func _speed() -> float:
	return 2.0 if speed_mode == 1 else 1.0


func _sync_modes() -> void:
	if table == null:
		return
	if table.has_method("get_speed_mode"):
		speed_mode = int(table.call("get_speed_mode"))
	elif "speed_mode" in table:
		speed_mode = int(table.get("speed_mode"))
	if table.has_method("is_reduced_motion"):
		reduced = bool(table.call("is_reduced_motion"))
	elif "reduced_motion" in table:
		reduced = bool(table.get("reduced_motion"))
	if camera == null and "camera" in table and table.get("camera") != null and "cam" in table.get("camera"):
		camera = table.get("camera").get("cam") as Camera3D


## Starts waiting bursts while there's room and the stagger allows.
func _pump() -> Burst:
	var started: Burst = null
	while not _queue.is_empty() and _live.size() < TriggerFxDefs.MAX_LIVE and not _pool.is_empty() and _clock >= _next_start - 0.0001:
		var best := 0
		for i in _queue.size():
			var q: Dictionary = _queue[i]
			var b: Dictionary = _queue[best]
			if int(q["tier"]) > int(b["tier"]) or (int(q["tier"]) == int(b["tier"]) and int(q["seq"]) < int(b["seq"])):
				best = i
		var e: Dictionary = _queue[best]
		_queue.remove_at(best)
		if not is_instance_valid(e["die"]):
			continue
		started = _start(e["id"], e["die"], e["ctx"])
		_next_start = _clock + TriggerFxDefs.STAGGER / _speed()
	return started


func _start(id: StringName, die: Node3D, ctx: Dictionary) -> Burst:
	var b: Burst = _pool.pop_back()
	b.id = id
	b.row = TriggerFxDefs.row(id)
	b.die = die
	b.ctx = ctx
	b.source = null
	if ctx.get("source") is Node3D:
		b.source = ctx["source"] as Node3D
	b.t = 0.0
	b.f = -1
	b.edge = float(die.get("edge")) if "edge" in die else 0.08
	b.faces = die.get("faces") as Node3D if "faces" in die else null
	if b.faces != null:
		b.rest = b.faces.transform
	b.rate = _speed() * float(ctx.get("rate", 1.0))
	if audio != null and audio.has_method("mod_trigger"):
		var s := float(audio.call("mod_trigger", id, ctx.get("die_id", die), StringName(ctx.get("anchor", b.row["anchor"])), ctx))
		if s > 0.0:
			b.rate = clampf(TriggerFxDefs.hit_time(id) / s, 0.5, 3.0)
	_live.append(b)
	_step(b, 0)
	b.f = 0
	return b


func _process(delta: float) -> void:
	_clock += delta
	for b in _live.duplicate():
		b.t += delta * b.rate
		var f := int(b.t * TriggerFxDefs.FPS)
		while b.f < f and _live.has(b):
			b.f += 1
			_step(b, b.f)
	_pump()


## One 12 fps frame of burst `b`.
func _step(b: Burst, f: int) -> void:
	var hit_f := int(b.row["hit"])
	var frames := int(b.row["frames"])
	var tier := int(b.row["tier"])
	if f >= frames or not is_instance_valid(b.die):
		_release(b)
		return
	var at := b.die.global_position
	_motion(b, f, f == frames - 1)
	var s := b.edge * TriggerFxDefs.SHAPE_SCALE[tier]
	var k := f - hit_f
	# The ring pulse (and an inner one a frame later): grows and fades out.
	_pulse(b.ring, at, s, k, b.row["ring"], 1.0)
	if b.row.get("ring2") is Color:
		_pulse(b.ring2, at, s, k - 1, b.row["ring2"], 0.75)
	_row_fx(b, f, k, at, s)
	_glint(b, f, at)
	# Sparks fly out and DOWN from the hit, stepped (reduced motion: none).
	var spark: Variant = b.row.get("spark")
	var n := TriggerFxDefs.SPARKS[tier]
	for i in b.sparks.size():
		var sp := b.sparks[i]
		if k < 0 or k > 2 or i >= n or reduced or not spark is Color:
			sp.visible = false
			continue
		# Rising sparks read as flame (QA): out and slightly down only.
		var dir := Vector3.RIGHT.rotated(Vector3.UP, TAU * i / n + 0.3)
		dir = (dir + Vector3(0, -0.2 - 0.15 * absf(sin(i * 2.1)), 0)).normalized()
		_show(b.sparks[i], at + dir * b.edge * (0.8 + 0.45 * k), b.edge * 0.22, TriggerShapes.texture(&"spark_diamond", spark), 1.0 - 0.3 * k)
	if k == 0:
		hit.emit(b.id, b.die)
	# The icon pops ON the hit (all tiers), then follows the die while live.
	if k >= 0:
		_icon(b, k)


## A ring pulse frame k (0 = the hit): 1.0x -> 1.8x the shape size, alpha
## 1 -> 0 over RING_FRAMES. Hidden outside the pulse: never a static ring.
func _pulse(m: MeshInstance3D, at: Vector3, s: float, k: int, tint: Color, scale: float) -> void:
	if k < 0 or k >= TriggerFxDefs.RING_FRAMES:
		m.visible = false
		return
	var u := float(k) / TriggerFxDefs.RING_FRAMES
	_show(m, at, s * scale * (1.0 + 0.8 * u), TriggerShapes.texture(&"ring_pulse_soft", tint), 1.0 - u)


## The row's own piece (what tells rows apart at a glance). All of these are
## depth-tested at the die's centre, so the die covers their middle: they
## read as a halo / rim around it, never as a tint on the body.
func _row_fx(b: Burst, f: int, k: int, at: Vector3, s: float) -> void:
	b.card.visible = false
	b.frame.visible = false
	b.core.visible = false
	match b.row["fx"]:
		&"gild":  # a gold glow + shine bar on the pip tick (2 f), then the coin hops off
			if k == 0 or k == 1:
				var a := 1.0 if k == 0 else 0.45
				_show(b.card, at, s * (1.9 + 0.2 * k), TriggerShapes.texture(&"radial_glow_soft", TriggerFxDefs.BRASS_HI), a)
				_show(b.frame, at, s * 1.15, TriggerShapes.texture(&"shine_bar", TriggerFxDefs.BRASS_HI), a)
			if k == 1 and b.row.has("coin_flight"):
				_coin_flight(b.die, float(b.row["coin_flight"]) / _speed())
		&"needles":  # bone needles shoot out (2 f) and retract; red frame; ember core
			const NEEDLE_SIZE: Array[float] = [1.05, 1.55, 1.25]
			if k >= 0 and k < NEEDLE_SIZE.size():
				_show(b.card, at, s * NEEDLE_SIZE[k], TriggerShapes.texture(&"needles_radial", TriggerFxDefs.BONE), 1.0 if k < 2 else 0.7)
			if k == 0 or k == 1:
				var hex := StringName(b.ctx.get("flavor", &"")) in [&"verdict", &"midnight"]
				_show(b.frame, at, s * 0.95, TriggerShapes.texture(&"frame_hex" if hex else &"frame_square", TriggerFxDefs.HELLFIRE), 1.0 if k == 0 else 0.5)
				_show(b.core, at, s * 1.2, TriggerShapes.texture(&"radial_glow_soft", TriggerFxDefs.EMBER_CORE), 0.9 if k == 0 else 0.4)
		&"glint":  # Mirror: a pale glass frame flashes as the glint lands
			if k == 0 or k == 1:
				_show(b.frame, at, s * 0.95, TriggerShapes.texture(&"frame_square", TriggerFxDefs.GLASS), 1.0 if k == 0 else 0.45)


## Mirror / Coin: a glass glint streak travels from ctx.source to the die over
## the row's glint frames [from, to], lying along its path and bowing
## sideways across the felt (never up), with two fading diamond dots behind
## it; on arrival it twinkles on the die as a glass diamond.
func _glint(b: Burst, f: int, at: Vector3) -> void:
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
	if f == f1 or b.source == null or not is_instance_valid(b.source):
		if f == f1:
			_show(b.glint, at, b.edge * 0.9, TriggerShapes.texture(&"spark_diamond", glass), 1.0)
			_face_camera(b.glint, Vector3.ZERO)
		return
	var u := float(f - f0) / float(f1 - f0)
	var from := b.source.global_position
	var p := glint_point(from, at, u)
	_show(b.glint, p, b.edge * 1.6, TriggerShapes.texture(&"glint_streak", glass), 1.0)
	_face_camera(b.glint, glint_point(from, at, minf(u + 0.05, 1.0)) - glint_point(from, at, maxf(u - 0.05, 0.0)))
	for i in b.trail.size():
		var v := u - 0.12 * (i + 1)
		if v >= 0.0:
			_show(b.trail[i], glint_point(from, at, v), b.edge * 0.3, TriggerShapes.texture(&"spark_diamond", glass), 0.7 - 0.3 * i)


## Orients the (non-billboard) glint quad to face the camera with its x axis
## along `along` (projected on the screen plane); a zero vector = upright.
func _face_camera(m: MeshInstance3D, along: Vector3) -> void:
	var cam := _cam()
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
func glint_point(from: Vector3, to: Vector3, u: float) -> Vector3:
	var d := to - from
	var side := d.cross(Vector3.UP)
	side.y = 0.0
	if side.length() < 0.0001:
		return from.lerp(to, u)
	side = side.normalized()
	var cam := _cam()
	if cam != null and side.dot(cam.global_position - (from + to) * 0.5) < 0.0:
		side = -side
	return from.lerp(to, u) + side * sin(PI * u) * 0.3 * Vector2(d.x, d.z).length()


func _cam() -> Camera3D:
	if camera != null:
		return camera
	return get_viewport().get_camera_3d() if is_inside_tree() else null


## The die's motion beat, in world axes, on its inner `faces` node.
func _motion(b: Burst, f: int, last: bool) -> void:
	if b.faces == null or reduced:
		return
	if last:
		b.faces.transform = b.rest
		return
	var k := TriggerFxDefs.beat_key(b.row["beat"], f)
	var B := b.die.global_basis.orthonormalized()
	var world := Basis(Vector3.RIGHT, deg_to_rad(float(k[1]))) * Basis(Vector3.UP, deg_to_rad(float(k[2])))
	world = Basis.from_scale(Vector3(k[4], k[3], k[4])) * world
	var local := B.inverse() * world * B
	var jit := float(k[5]) * b.edge * (1.0 if f % 2 == 0 else -1.0)
	b.faces.transform = Transform3D(local * b.rest.basis, b.rest.origin + B.inverse() * Vector3(jit, float(k[0]) * b.edge, 0))


## Icon frame k (0 = the hit): pops 1.25 -> 1.0, rising 4 px; holds
## ICON_HOLD, then fades. The chip (if the row has one) pops a frame later.
func _icon(b: Burst, k: int) -> void:
	var ic := b.icon
	var sc := _px_scale()
	if k == 0:
		ic.setup(b.row["icon"], int(b.row["tier"]), sc, bool(b.ctx.get("cost", false)))
		ic.modulate.a = 1.0
		ic.visible = true
		b.chip.visible = false
		b.chip.modulate.a = 1.0
		if b.icon_tw != null and b.icon_tw.is_valid():
			b.icon_tw.kill()
		b.icon_tw = ic.create_tween().set_ignore_time_scale(true)
		b.icon_tw.tween_interval(TriggerFxDefs.ICON_HOLD / _speed())
		b.icon_tw.tween_property(ic, "modulate:a", 0.0, TriggerFxDefs.ICON_FADE / _speed())
		b.icon_tw.parallel().tween_property(b.chip, "modulate:a", 0.0, TriggerFxDefs.ICON_FADE / _speed())
		var chip := b.chip
		b.icon_tw.tween_callback(func() -> void:
			ic.visible = false
			chip.visible = false)
	ic.scale = Vector2.ONE * (1.25 if k == 0 else 1.0)
	ic.position = _icon_pos(b.die, ic.diameter) - Vector2(0, (4.0 if k >= 1 else 2.0) * sc)
	var label := String(b.ctx.get("chip", b.row.get("chip", "")))
	if k >= 1 and label != "":
		if k == 1:
			b.chip.setup(label, sc)
			b.chip.visible = true
		b.chip.scale = Vector2.ONE * (1.2 if k == 1 else 1.0)
		b.chip.position = ic.position + Vector2(ic.diameter + 4.0 * sc, (ic.diameter - b.chip.size.y) * 0.5)


## Viewport height / 720 (icon sizes are authored at 720p).
func _px_scale() -> float:
	var vs := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1280, 720)
	return maxf(vs.y / 720.0, 0.6)


## Above the value-tag anchor (die + 0.07 m), clamped to the safe area.
func _icon_pos(die: Node3D, diameter: float) -> Vector2:
	var vs := get_viewport().get_visible_rect().size
	var p := vs * 0.5
	if camera != null and is_instance_valid(die):
		p = camera.unproject_position(die.global_position + Vector3(0, 0.07, 0))
	p -= Vector2(diameter * 0.5, diameter * 1.6)
	return p.clamp(Vector2(8, 8), vs - Vector2(diameter + 8, diameter + 8))


## Instant speed: no burst or motion, the icon shows static for 0.25 s.
func _instant(id: StringName, die: Node3D, row: Dictionary, ctx: Dictionary) -> void:
	if audio != null and audio.has_method("mod_trigger"):
		audio.call("mod_trigger", id, ctx.get("die_id", die), StringName(ctx.get("anchor", row["anchor"])), ctx)
	var ic := TriggerIcon.new()
	icon_layer.add_child(ic)
	ic.setup(row["icon"], int(row["tier"]), _px_scale(), bool(ctx.get("cost", false)))
	ic.position = _icon_pos(die, ic.diameter)
	get_tree().create_timer(TriggerFxDefs.INSTANT_ICON, true, false, true).timeout.connect(ic.queue_free)


func _release(b: Burst) -> void:
	if b.faces != null and is_instance_valid(b.faces):
		b.faces.transform = b.rest
	for m: MeshInstance3D in [b.card, b.frame, b.core, b.ring, b.ring2, b.glint] + b.sparks + b.trail:
		m.visible = false
	# The icon and chip finish their own hold + fade (started at the pop).
	_live.erase(b)
	_pool.append(b)
	_pump()


## Gilded: a small brass coin hops up off the die, flipping, and arcs to the
## Ember counter; coin_landed fires when it gets there (spec 2a, GD 8.3).
## Screen space and outside the burst cap, so it reads at any die size.
func _coin_flight(die: Node3D, seconds: float) -> void:
	var c: TriggerIcon = null
	for x in _coins:
		if not x.visible:
			c = x
			break
	if c == null or reduced or speed_mode >= 2:
		coin_landed.emit(die)
		return
	var sc := _px_scale()
	c.setup(&"brass_coin", TriggerFxDefs.MINOR, sc)
	c.coin_frame = 0
	c.visible = true
	c.modulate.a = 1.0
	var vs := get_viewport().get_visible_rect().size
	var from := vs * 0.5
	var cam := _cam()
	if cam != null and is_instance_valid(die):
		from = cam.unproject_position(die.global_position + Vector3(0, 0.04, 0))
	from -= Vector2.ONE * c.diameter * 0.5
	var to := pile_screen if pile_screen.x >= 0.0 else Vector2(vs.x - 150.0 * sc, 20.0 * sc)
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
		coin_landed.emit(die))


func _make_burst() -> Burst:
	var b := Burst.new()
	b.core = _card(0)
	b.card = _card(0)
	b.frame = _card(0)
	b.ring = _card(0)
	b.ring2 = _card(0)
	b.glint = _card(2)
	(b.glint.material_override as StandardMaterial3D).billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	for i in 8:
		b.sparks.append(_card(1))
	for i in 2:
		b.trail.append(_card(2))
	b.icon = TriggerIcon.new()
	b.icon.visible = false
	icon_layer.add_child(b.icon)
	b.chip = TriggerChip.new()
	b.chip.visible = false
	icon_layer.add_child(b.chip)
	return b


## A billboard card. priority 0 = glow (depth-tested so the die hides the
## back half), 1 = sparks, 2 = the glint (spec 1.6), both without depth test.
func _card(priority: int) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = QuadMesh.new()
	m.material_override = _mat(priority)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.visible = false
	add_child(m)
	return m


func _mat(priority: int) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	mat.no_depth_test = priority > 0
	mat.render_priority = priority
	return mat


func _show(m: MeshInstance3D, at: Vector3, size: float, tex: Texture2D, alpha: float, tint: Color = Color.WHITE) -> void:
	var mat := m.material_override as StandardMaterial3D
	if tex != null:
		mat.albedo_texture = tex
	mat.albedo_color = Color(tint, alpha)
	(m.mesh as QuadMesh).size = Vector2.ONE * size
	m.global_position = at
	m.visible = alpha > 0.0
