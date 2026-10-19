## Special-die and face-mod trigger FX (trigger_fx_spec.md v0.2): the shared
## grammar, a pre-warmed pool and the burst cap. One entry point:
##   trigger_fx(&"mirror_copy", die, {source = other_die}) -> float
## returns the seconds until the KEY HIT (the sound sync frame).
##
## Grammar (spec 1.1), stepped at 12 fps (one frame = 83 ms, toon stutter):
##   f0-f1 anticipation: squash, a tight charge ring at 0.9x die
##   key hit (f2/f3/f4 per row): stretch, the glow shape at full size,
##     diamond sparks, the link beam/arc lands
##   icon pop: on the hit (minor) or hit + 1 (major / signature)
##   motion beat: the row's per-frame keys (TriggerFxDefs.BEATS)
##   settle: shapes go, the die returns exactly to rest, the icon fades
## Motion is applied to the die's inner `faces` node in WORLD axes and always
## restored to the exact rest transform, so the seeded face remap and the
## table's own tweens on the die node are never disturbed. Glow only: no fire
## on dice (spec 0), no real lights (bloom only).
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
	var card: MeshInstance3D
	var ring: MeshInstance3D
	var flash: MeshInstance3D
	var link: MeshInstance3D
	var sparks: Array[MeshInstance3D] = []
	var arc: Array[MeshInstance3D] = []
	var icon: TriggerIcon
	var coin: TriggerIcon
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
	# Pre-warm every shape texture now, so the first trigger doesn't hitch.
	var rows: Array[Dictionary] = [TriggerFxDefs.GENERIC]
	rows.append_array(TriggerFxDefs.ROWS.values())
	for row in rows:
		TriggerShapes.texture(row["shape"], row["tint"])
		TriggerShapes.texture(&"ring", row["tint2"])
	TriggerShapes.texture(&"diamond", TriggerFxDefs.EMBER_CORE)
	TriggerShapes.texture(&"flash", TriggerFxDefs.EMBER_CORE)
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
	if f >= frames:
		_release(b)
		return
	if not is_instance_valid(b.die):
		_release(b)
		return
	var at := b.die.global_position
	_motion(b, f, f == frames - 1)
	var s := b.edge * TriggerFxDefs.SHAPE_SCALE[tier]
	# Anticipation: the charge ring.
	if f < hit_f:
		_show(b.ring, at, b.edge * 0.9 * (1.0 - 0.05 * f), TriggerShapes.texture(&"ring", b.row["tint2"]), 0.8)
	# Key hit: the glow shape at full size, sparks, the flash on signatures.
	if f == hit_f:
		_show(b.card, at, s, TriggerShapes.texture(b.row["shape"], b.row["tint"]), 1.0)
		if tier >= TriggerFxDefs.MAJOR:
			_show(b.ring, at, s * 1.1, TriggerShapes.texture(&"ring", b.row["tint2"]), 0.9)
		else:
			b.ring.visible = false
		if tier == TriggerFxDefs.SIGNATURE:
			_show(b.flash, at, s * 0.9, TriggerShapes.texture(&"flash", TriggerFxDefs.EMBER_CORE), 1.0)
		hit.emit(b.id, b.die)
	elif f > hit_f:
		b.flash.visible = false
		var k := f - hit_f
		var shrink := 1.0 - 0.18 * k if b.row["shape"] == &"needles" else 1.0 + 0.06 * k
		_show(b.card, at, s * shrink, null, 0.5 if f == frames - 1 else 1.0)
		if b.ring.visible:
			_show(b.ring, at, s * (1.1 + 0.12 * k), null, maxf(0.0, 0.9 - 0.3 * k))
	# Sparks fly out from the hit, stepped (reduced motion: none).
	for i in b.sparks.size():
		var sp := b.sparks[i]
		var n := TriggerFxDefs.SPARKS[tier]
		if f < hit_f or i >= n or reduced:
			sp.visible = false
			continue
		# Out and slightly DOWN, never up: rising sparks read as flame (QA).
		var dir := Vector3.RIGHT.rotated(Vector3.UP, TAU * i / n + 0.3)
		dir = (dir + Vector3(0, -0.2 - 0.15 * absf(sin(i * 2.1)), 0)).normalized()
		_show(sp, at + dir * b.edge * (0.8 + 0.45 * (f - hit_f)), b.edge * 0.22, TriggerShapes.texture(&"diamond", TriggerFxDefs.EMBER_CORE), 1.0 - 0.25 * (f - hit_f))
	_link(b, f, hit_f, at)
	# Icon pop: scale 0 -> 1.25 -> 1.0 over 2 frames, rising 6 pt.
	var pop_f := hit_f if tier == TriggerFxDefs.MINOR else hit_f + 1
	if f >= pop_f:
		_icon(b, f - pop_f)


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


## Mirror: a straight thin bone beam from the source die (grows to the hit).
## Coin: a swooping arc of diamond sparks from the source down onto the coin.
func _link(b: Burst, f: int, hit_f: int, at: Vector3) -> void:
	var link: StringName = b.row["link"]
	b.link.visible = false
	for a in b.arc:
		a.visible = false
	if link == &"" or b.source == null or not is_instance_valid(b.source) or f > hit_f:
		return
	var from := b.source.global_position
	var grow := clampf(float(f + 1) / float(hit_f + 1), 0.0, 1.0)
	if link == &"beam":
		var to := from.lerp(at, grow)
		var mid := (from + to) * 0.5
		var len := maxf(from.distance_to(to), 0.001)
		b.link.visible = true
		b.link.global_transform = Transform3D(Basis.looking_at((to - from).normalized() if len > 0.002 else Vector3.FORWARD, Vector3.UP).scaled(Vector3(1, 1, len)), mid)
	elif link == &"arc":
		# A low swoop (half a die above the higher end), then down onto the coin.
		var top := (from + at) * 0.5
		top.y = maxf(from.y, at.y) + b.edge * 0.5
		for i in b.arc.size():
			var u := float(i + 1) / float(b.arc.size())
			if u > grow:
				continue
			var p := from.lerp(top, u).lerp(top.lerp(at, u), u)
			_show(b.arc[i], p, b.edge * 0.25, TriggerShapes.texture(&"diamond", TriggerFxDefs.BRASS_HI), 1.0)


func _icon(b: Burst, k: int) -> void:
	var ic := b.icon
	if k == 0:
		ic.setup(b.row["icon"], int(b.row["tier"]), _px_per_pt(), bool(b.ctx.get("cost", false)))
		ic.modulate.a = 1.0
		ic.visible = true
	ic.scale = Vector2.ONE * (0.0 if k < 0 else (1.25 if k == 0 else 1.0))
	ic.position = _icon_pos(b.die, ic.diameter) - Vector2(0, (6.0 if k >= 1 else 3.0) * _px_per_pt())


func _px_per_pt() -> float:
	var vs := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1920, 1080)
	return maxf(vs.y / 1080.0, 0.75)


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
	ic.setup(row["icon"], int(row["tier"]), _px_per_pt(), bool(ctx.get("cost", false)))
	ic.position = _icon_pos(die, ic.diameter)
	get_tree().create_timer(TriggerFxDefs.INSTANT_ICON, true, false, true).timeout.connect(ic.queue_free)


func _release(b: Burst) -> void:
	if b.faces != null and is_instance_valid(b.faces):
		b.faces.transform = b.rest
	for m: MeshInstance3D in [b.card, b.ring, b.flash, b.link] + b.sparks + b.arc:
		m.visible = false
	var ic := b.icon
	if ic.visible:
		var tw := ic.create_tween().set_ignore_time_scale(true)
		tw.tween_property(ic, "modulate:a", 0.0, TriggerFxDefs.ICON_FADE / _speed())
		tw.tween_callback(func() -> void: ic.visible = false)
	if b.row.has("coin_flight") and is_instance_valid(b.die):
		_coin_flight(b, float(b.row["coin_flight"]) / _speed())
	_live.erase(b)
	_pool.append(b)
	_pump()


## Gilded: a flat brass coin flips twice and arcs to the Ember counter;
## coin_landed fires when it gets there (spec 2a, GD 8.3).
func _coin_flight(b: Burst, seconds: float) -> void:
	var c := b.coin
	var die := b.die
	c.setup(&"coin", TriggerFxDefs.MINOR, _px_per_pt())
	c.visible = true
	c.modulate.a = 1.0
	var vs := get_viewport().get_visible_rect().size
	var from := _icon_pos(die, c.diameter)
	var to := pile_screen if pile_screen.x >= 0.0 else Vector2(vs.x - 150.0 * _px_per_pt(), 20.0 * _px_per_pt())
	if reduced or speed_mode >= 2:
		c.visible = false
		coin_landed.emit(die)
		return
	var tw := c.create_tween()
	tw.tween_method(func(u: float) -> void:
		c.position = from.lerp(to, u) - Vector2(0, sin(u * PI) * 80.0 * _px_per_pt())
		c.scale = Vector2(absf(cos(u * TAU * 2.0)), 1.0), 0.0, 1.0, seconds)
	tw.tween_callback(func() -> void:
		c.visible = false
		coin_landed.emit(die))


func _make_burst() -> Burst:
	var b := Burst.new()
	b.card = _card(0)
	b.ring = _card(0)
	b.flash = _card(0)
	for i in 8:
		b.sparks.append(_card(1))
	for i in 6:
		b.arc.append(_card(2))
	b.link = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.006, 0.006, 1.0)
	b.link.mesh = box
	var lm := _mat(2)
	lm.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	lm.albedo_color = TriggerFxDefs.BONE
	b.link.material_override = lm
	b.link.visible = false
	add_child(b.link)
	b.icon = TriggerIcon.new()
	b.icon.visible = false
	icon_layer.add_child(b.icon)
	b.coin = TriggerIcon.new()
	b.coin.visible = false
	icon_layer.add_child(b.coin)
	return b


## A billboard card. priority 0 = glow (depth-tested so the die hides the
## back half), 1 = sparks, 2 = links (spec 1.6), both without depth test.
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


func _show(m: MeshInstance3D, at: Vector3, size: float, tex: Texture2D, alpha: float) -> void:
	var mat := m.material_override as StandardMaterial3D
	if tex != null:
		mat.albedo_texture = tex
	mat.albedo_color = Color(1, 1, 1, alpha)
	(m.mesh as QuadMesh).size = Vector2.ONE * size
	m.global_position = at
	m.visible = alpha > 0.0
