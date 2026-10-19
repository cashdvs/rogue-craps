## Special-die and face-mod trigger FX (trigger_fx_spec.md v0.2, a team doc
## outside the repo: /workspace/dice/art/concept/special_dice/): the shared
## grammar, the burst cap and the event wiring. One entry point:
##   trigger_fx(&"mirror_copy", die, {source = other_die}) -> float
## returns the seconds until the KEY HIT (the sound sync frame).
##
## Grammar (spec 1.1), stepped at 12 fps (one frame = 83 ms, toon stutter):
##   f0-f1 anticipation: squash (a Mirror / Coin glint may already travel)
##   key hit (f2/f3/f4 per row): stretch, a ring PULSE (grows and fades in
##     0.25 s, tinted per row), the row's own piece, sparks out and down, the
##     icon pops (32 px at 720p)
##   motion beat: the row's per-frame keys (TriggerFxDefs.BEATS)
##   settle: the die returns exactly to rest; the icon holds 0.5 s and fades
## Motion goes on the die's inner `faces` node in WORLD axes and is restored
## exactly at the end. If anything else moves `faces` mid-effect (the table's
## face remap on a new throw), or the die throws / the table restarts / the
## die is freed, the effect lets go WITHOUT restoring, so it never clobbers
## the table. Glow only, never on the die body: no die material is touched.
## No fire, no real lights (bloom only), sparks never rise above the die.
##
## Sound: TableAudio is the only caller of sfx.play_mod_trigger. At a burst's
## start this asks `audio.mod_trigger(id, die, anchor, ctx)` and, if the cue
## plays (returns seconds > 0), retimes the burst so the flash lands on the
## audio hit. Speed: 2x plays twice as fast; Instant shows static icons only;
## reduced motion keeps glow + icon, no die motion and no sparks (spec 1.3).
##
## Cap (spec 1.4, Art Director Oct 19): at most MAX_LIVE (4) bursts at once;
## the rest wait, starts are STAGGER (0.08 s) apart, biggest tier first.
## Pool: trigger_fx_pool.gd. Glint and coin flight: trigger_fx_links.gd.
class_name TriggerFx
extends Node3D

## The key-hit frame of a burst (tests, captures, HUD hooks).
signal hit(id: StringName, die: Node3D)
## The Gilded coin reached the ember pile: tick the Ember counter now.
signal coin_landed(die: Node3D)

## Stages of triggers_resolved that get trigger FX (lit / boss beats are
## other FX, not triggers).
const FX_STAGES: Array[StringName] = [&"land", &"copies", &"scoring"]
## Events that end every live effect at once, without restoring the die
## (the table is about to move or remap the dice).
const ABORT_SIGNALS: Array[StringName] = [&"dice_thrown", &"table_started"]

## The game camera (icons and the glint face it); found from the table.
var camera: Camera3D
## TableAudio (or anything with mod_trigger(id, die, anchor, ctx) -> float).
var audio: Node
## The table (dice by id, speed mode, reduced motion, camera).
var table: Node
## 0 = 1x, 1 = 2x, 2 = Instant (JuicePlan's speed modes).
var speed_mode: int = 0
## Reduced motion: glow + icon only, no die motion, no sparks.
var reduced: bool = false
## Screen point the Gilded coin flies to (default: the top-right Ember counter).
var pile_screen := Vector2(-1, -1)
## The screen-space layer the icons, chips and flight coins draw on.
var icon_layer: CanvasLayer
## The TableEvents node this listens to (null until bound).
var events: Object
var _pool: Array[TriggerFxPool.Burst] = []
var _live: Array[TriggerFxPool.Burst] = []
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
		_pool.append(TriggerFxPool.make_burst(self, icon_layer))
	for i in 4:
		var c := TriggerIcon.new()
		c.visible = false
		icon_layer.add_child(c)
		_coins.append(c)
	TriggerFxPool.prewarm()
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


## Bursts in the pool plus live ones (the pool never grows).
func pool_size() -> int:
	return _pool.size() + _live.size()


## Bursts playing now (at most TriggerFxDefs.MAX_LIVE).
func live_count() -> int:
	return _live.size()


## Triggers waiting for a free slot or their stagger.
func queued_count() -> int:
	return _queue.size()


## Listens to Godot Dev's TableEvents. With `triggers_resolved` (#91) the
## bursts start at each entry's start_s (the pip time - 0.167 s for scoring,
## from the settle for landing copies), so the hit lands ON the tick, and
## `mod_triggered` (sent at the tick itself) is ignored to avoid doubles.
## Without it, `mod_triggered` starts the burst at once (its anchor / ctx
## arguments are optional: 5- or 7-argument forms both bind). `dice_thrown`
## and `table_started` end live effects without restoring the dice.
func bind(ev: Object, t: Node = null) -> bool:
	events = ev
	if t != null:
		table = t
	if ev == null:
		return false
	for sig in ABORT_SIGNALS:
		if ev.has_signal(sig) and not ev.is_connected(sig, _on_abort):
			ev.connect(sig, _on_abort)
	if ev.has_signal(&"triggers_resolved"):
		ev.connect(&"triggers_resolved", _on_triggers_resolved)
		return true
	if ev.has_signal(&"mod_triggered"):
		ev.connect(&"mod_triggered", _on_mod_triggered)
		return true
	return false


func _on_abort(_a: Variant = null) -> void:
	abort_all()


## Ends every live and queued effect now WITHOUT touching the dice' faces
## (the table owns them from here: a new throw remaps them). Icons fade.
func abort_all() -> void:
	_queue.clear()
	for b in _live.duplicate():
		_release(b, false)


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
		var args := [StringName(e.get("row_id", &"")), int(e.get("tier", 0)), int(e.get("die_id", -1)),
				float(e.get("intensity", 1.0)), 0, StringName(e.get("anchor", &"")), ctx]
		var start := float(e.get("start_s", 0.0))
		if start <= 0.0:
			_on_mod_triggered.callv(args)
		else:
			# A child timer: freed with us, so it never fires on a freed table.
			var tm := Timer.new()
			tm.one_shot = true
			tm.wait_time = start
			add_child(tm)
			tm.timeout.connect(func() -> void:
				tm.queue_free()
				_on_mod_triggered.callv(args))
			tm.start()


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
	if table == null or not is_instance_valid(table):
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
	if TriggerFxDefs.flavor_of(id) != &"" and not ctx.has("flavor"):
		ctx = ctx.duplicate()
		ctx["flavor"] = TriggerFxDefs.flavor_of(id)
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
	return wait + TriggerFxDefs.hit_time(id) / speed()


## Several triggers of one pot in resolve order: they start 0.08 s apart,
## biggest first, at most 4 at once. Returns their (estimated) hit times.
func play_pot(list: Array) -> Array[float]:
	var out: Array[float] = []
	for e: Dictionary in list:
		out.append(trigger_fx(e["id"], e["die"], e.get("ctx", {})))
	return out


## 2.0 at 2x speed, else 1.0.
func speed() -> float:
	return 2.0 if speed_mode == 1 else 1.0


func _sync_modes() -> void:
	if table == null or not is_instance_valid(table):
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
func _pump() -> TriggerFxPool.Burst:
	var started: TriggerFxPool.Burst = null
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
		_next_start = _clock + TriggerFxDefs.STAGGER / speed()
	return started


func _start(id: StringName, die: Node3D, ctx: Dictionary) -> TriggerFxPool.Burst:
	var b: TriggerFxPool.Burst = _pool.pop_back()
	b.id = id
	b.row = TriggerFxDefs.row(id)
	b.die = die
	b.ctx = ctx
	b.source = ctx["source"] as Node3D if ctx.get("source") is Node3D else null
	b.t = 0.0
	b.f = -1
	b.edge = float(die.get("edge")) if "edge" in die else 0.08
	b.faces = die.get("faces") as Node3D if "faces" in die else null
	if b.faces != null:
		b.rest = b.faces.transform
		b.written = b.rest
	b.rate = speed() * float(ctx.get("rate", 1.0))
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
func _step(b: TriggerFxPool.Burst, f: int) -> void:
	if not is_instance_valid(b.die):
		_release(b, false)
		return
	var hit_f := int(b.row["hit"])
	var tier := int(b.row["tier"])
	if f >= int(b.row["frames"]):
		_release(b, true)
		return
	var at := b.die.global_position
	_motion(b, f, f == int(b.row["frames"]) - 1)
	var s := b.edge * TriggerFxDefs.SHAPE_SCALE[tier]
	var k := f - hit_f
	# The ring pulse (and an inner one a frame later): grows and fades out.
	TriggerFxPieces.pulse(b.ring, at, s, k, b.row["ring"], 1.0)
	if b.row.get("ring2") is Color:
		TriggerFxPieces.pulse(b.ring2, at, s, k - 1, b.row["ring2"], 0.75)
	TriggerFxPieces.row_fx(self, b, k, at, s)
	TriggerFxLinks.glint(self, b, f, at)
	TriggerFxPieces.sparks(b, k, at, tier, reduced)
	if k == 0:
		hit.emit(b.id, b.die)
	# The icon pops ON the hit, then follows the die while live.
	if k >= 0:
		TriggerFxPieces.icon(self, b, k)


## The die's motion beat, in world axes, on its inner `faces` node. If the
## faces aren't where the FX left them, someone else (the table's remap)
## owns them now: let go without writing or restoring (QA B4).
func _motion(b: TriggerFxPool.Burst, f: int, last: bool) -> void:
	if b.faces == null or reduced:
		return
	if not is_instance_valid(b.faces) or not b.faces.transform.is_equal_approx(b.written):
		b.faces = null
		return
	if last:
		b.faces.transform = b.rest
	else:
		var k := TriggerFxDefs.beat_key(b.row["beat"], f)
		var B := b.die.global_basis.orthonormalized()
		var world := Basis(Vector3.RIGHT, deg_to_rad(float(k[1]))) * Basis(Vector3.UP, deg_to_rad(float(k[2])))
		world = Basis.from_scale(Vector3(k[4], k[3], k[4])) * world
		var local := B.inverse() * world * B
		var jit := float(k[5]) * b.edge * (1.0 if f % 2 == 0 else -1.0)
		b.faces.transform = Transform3D(local * b.rest.basis, b.rest.origin + B.inverse() * Vector3(jit, float(k[0]) * b.edge, 0))
	b.written = b.faces.transform


## Viewport height / 720 (icon sizes are authored at 720p).
func px_scale() -> float:
	var vs := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1280, 720)
	return maxf(vs.y / 720.0, 0.6)


## The camera icons and the glint face (the table's, else the viewport's).
func cam() -> Camera3D:
	if camera != null:
		return camera
	return get_viewport().get_camera_3d() if is_inside_tree() else null


## Instant speed: no burst or motion, the icon shows static for 0.25 s.
func _instant(id: StringName, die: Node3D, row: Dictionary, ctx: Dictionary) -> void:
	if audio != null and audio.has_method("mod_trigger"):
		audio.call("mod_trigger", id, ctx.get("die_id", die), StringName(ctx.get("anchor", row["anchor"])), ctx)
	var ic := TriggerIcon.new()
	icon_layer.add_child(ic)
	ic.setup(row["icon"], int(row["tier"]), px_scale(), bool(ctx.get("cost", false)))
	ic.position = TriggerFxPieces.icon_pos(self, die, ic.diameter)
	get_tree().create_timer(TriggerFxDefs.INSTANT_ICON, true, false, true).timeout.connect(ic.queue_free)


## Back to the pool. restore: put the die's faces back to rest (a normal
## end); false when the table owns them now (abort, freed die).
func _release(b: TriggerFxPool.Burst, restore: bool) -> void:
	if restore and b.faces != null and is_instance_valid(b.faces) and b.faces.transform.is_equal_approx(b.written):
		b.faces.transform = b.rest
	b.faces = null
	for m in TriggerFxPool.meshes(b):
		m.visible = false
	# The icon and chip finish their own hold + fade (started at the pop).
	_live.erase(b)
	_pool.append(b)
	_pump()
