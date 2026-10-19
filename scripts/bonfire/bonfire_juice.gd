## Thin adapter between the Bonfire table and the scoring juice assets
## (bonfire_map_events_juice.md sections 3 and 6). Every sound goes through
## the table's SfxManager by event name. The Sound Designer's BonfireSynth
## events and CrowdLayers (scripts/audio/README.md) and the 3D Artist's
## VFX scenes (art/vfx/bonfire/README.md "Hooks") are used ONLY if they
## exist (ResourceLoader.exists / SfxManager.has_event / has_method);
## otherwise cheap built-in emissive / particle effects and existing sounds
## stand in. So it works now and lights up when their PRs merge.
##
## `calls` logs every hook ("sfx:<event>", "art:<what>", "fb:<what>") for
## tests and captures.
class_name BonfireJuice
extends Node3D

const SYNTH_PATH := "res://scripts/audio/bonfire_synth.gd"
const CROWD_PATH := "res://scripts/audio/crowd_layers.gd"
const VFX := "res://art/vfx/bonfire/"
const FIRE_TIERS: Array[String] = ["fire_tier_1_embers", "fire_tier_2_flames", "fire_tier_3_inferno", "fire_tier_4_pillar"]
const RIG := "scenes/dice/potted_die_rig.tscn"
const IGNITE := "scenes/dice/hot_hand_ignite.tscn"
const TRAIL := "scenes/dice/fire_trail.tscn"
const LIT_FACE := "materials/lit_face_glow.tres"
const ASH_BODY := "materials/ash_body.tres"
const EMBER_PILE := "res://art/models/props/bonfire/scenes/ember_pile.tscn"
## The pip scale (same as BonfireSynth.TICK_SCALE) when the synth is absent.
const TICK_SCALE: Array[int] = [0, 2, 3, 5, 7, 8, 11, 12, 14, 15, 17, 19]
const STINGERS: Array[StringName] = [&"stinger_ember", &"stinger_flames", &"stinger_inferno", &"stinger_pillar"]
const FIRE_COLORS: Array[Color] = [Color("#FFE7A8"), Color("#F6A845"), Color("#E8622A")]
const HELL_COLORS: Array[Color] = [Color("#FFE7A8"), Color("#E8622A"), Color("#C8281E")]
const ASH := Color("#5A5E62")

var table: Bonfire3D
var calls: Array[String] = []
var crowd: Node
var _synth: GDScript
var _scenes: Dictionary = {}
var _last_count_tick_ms: int = -100000
var _rigs: Dictionary = {}
var _trails: Dictionary = {}
var _crowd_fraction: float = 0.0
## Force the fallbacks (tests: "without the art / audio branches").
var force_fallback: bool = false


func _init() -> void:
	name = "BonfireJuice"


func setup(t: Bonfire3D) -> void:
	table = t
	if ResourceLoader.exists(SYNTH_PATH):
		_synth = load(SYNTH_PATH) as GDScript
	if ResourceLoader.exists(CROWD_PATH) and not force_fallback:
		var cs := load(CROWD_PATH) as GDScript
		if cs != null and cs.can_instantiate():
			crowd = cs.new()
			add_child(crowd)


func has_audio() -> bool:
	return not force_fallback and _synth != null and table != null and table.sfx.has_method("has_event") and table.sfx.has_event(&"score_tick")


func has_art() -> bool:
	return not force_fallback and ResourceLoader.exists(VFX + "scenes/fire/" + FIRE_TIERS[0] + ".tscn")


func _log(s: String) -> void:
	calls.append(s)
	if calls.size() > 400:
		calls = calls.slice(200)


# --- Sound ---------------------------------------------------------------------------

## Plays `event` if the SfxManager has it, else `fallback` (if any).
func sfx(event: StringName, pitch: float = 1.0, volume_db: float = 0.0, jitter: float = 0.0,
		fallback: StringName = &"", fb_pitch: float = 1.0, fb_volume_db: float = 0.0) -> void:
	if table == null:
		return
	if not force_fallback and table.sfx.has_event(event):
		table.sfx.play(event, pitch, volume_db, jitter)
		_log("sfx:%s" % event)
	elif fallback != &"" and table.sfx.has_event(fallback):
		table.sfx.play(fallback, fb_pitch, fb_volume_db, 0.0)
		_log("sfx:%s(fb)" % fallback)


func tick_pitch(i: int) -> float:
	if has_audio() and _synth.has_method("tick_pitch"):
		return float(_synth.call("tick_pitch", i))
	return pow(2.0, TICK_SCALE[clampi(i, 0, TICK_SCALE.size() - 1)] / 12.0)


func stinger(score_tier: int) -> StringName:
	if has_audio() and _synth.has_method("stinger_for_tier"):
		return StringName(_synth.call("stinger_for_tier", score_tier))
	return STINGERS[clampi(score_tier, 0, 3)]


func pip_sound(i: int) -> void:
	sfx(&"score_tick", tick_pitch(i), 0.0, 0.0, &"chip_place", tick_pitch(i) * 0.9, -4.0)


func slam_sound(k: int) -> void:
	sfx(&"mult_slam", 1.0 - 0.05 * k, 0.0, 0.0, &"dice_drop", 0.8 - 0.05 * k, -1.0)


## One per visible count step, at most every juice_count_tick_min_gap.
func count_sound(progress: float) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_count_tick_ms < int(table.bonfire_tuning.juice_count_tick_min_gap * 1000.0):
		return
	_last_count_tick_ms = now
	sfx(&"count_tick", 1.0 + 0.5 * progress, -4.0, 0.0, &"chip_place", 1.4 + 0.5 * progress, -12.0)


func banner_sound(score_tier: int) -> void:
	sfx(&"combo_banner", 1.0, -3.0, 0.0)
	sfx(stinger(score_tier), 1.0, 0.0, 0.0, &"win_big" if score_tier >= 2 else &"rim_hit", 1.0 if score_tier >= 2 else 1.2, -6.0 if score_tier < 3 else 0.0)


# --- Crowd ------------------------------------------------------------------------------

func crowd_start() -> void:
	if crowd != null and crowd.has_method("start"):
		crowd.call("start")
		_log("art:crowd_start")


func crowd_pot(pot: int) -> void:
	_crowd_fraction = clampf(float(pot) / maxf(table.bonfire_tuning.juice_crowd_full_pot, 1.0), 0.0, 1.0)
	if crowd != null and crowd.has_method("set_pot_fraction"):
		crowd.call("set_pot_fraction", _crowd_fraction)
		_log("sfx:crowd_%.2f" % _crowd_fraction)


func crowd_roar() -> void:
	if crowd != null and crowd.has_method("set_pot_fraction"):
		crowd.call("set_pot_fraction", 1.0, 0.15)
		_log("sfx:crowd_roar")
		get_tree().create_timer(1.2, true, false, true).timeout.connect(func() -> void:
			if is_instance_valid(crowd):
				crowd.call("set_pot_fraction", _crowd_fraction))
	else:
		sfx(&"crowd_roar_missing", 1.0, 0.0, 0.0, &"win_big", 0.8, -2.0)


func crowd_stop() -> void:
	if crowd != null and crowd.has_method("stop"):
		crowd.call("stop")


# --- Art scenes ---------------------------------------------------------------------

func _cpu() -> bool:
	return str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")) == "gl_compatibility"


func _scene(rel: String) -> PackedScene:
	if force_fallback:
		return null
	var path := rel if rel.begins_with("res://") else VFX + rel
	if _scenes.has(path):
		return _scenes[path]
	var ps: PackedScene = null
	if ResourceLoader.exists(path):
		ps = load(path) as PackedScene
	_scenes[path] = ps
	return ps


func _fire_scene(k: int) -> PackedScene:
	var base := "scenes/fire/" + FIRE_TIERS[k]
	if _cpu() and ResourceLoader.exists(VFX + "scenes/fire/cpu/" + FIRE_TIERS[k] + "_cpu.tscn"):
		return _scene("scenes/fire/cpu/" + FIRE_TIERS[k] + "_cpu.tscn")
	return _scene(base + ".tscn")


## Instances a clip scene, plays `clip` and frees it afterwards.
func _play_scene(ps: PackedScene, parent: Node, at: Vector3, clip: String, delay: float = 0.0) -> Node3D:
	var n := ps.instantiate() as Node3D
	parent.add_child(n)
	n.global_position = at
	n.global_basis = Basis.IDENTITY
	var ap := n.get_node_or_null("AnimationPlayer") as AnimationPlayer
	var life := 1.5
	if ap != null and ap.has_animation(clip):
		life = ap.get_animation(clip).length + 0.6
		if delay > 0.0:
			get_tree().create_timer(delay, true, false, true).timeout.connect(func() -> void:
				if is_instance_valid(ap):
					ap.play(clip))
		else:
			ap.play(clip)
	get_tree().create_timer(life + delay, true, false, true).timeout.connect(func() -> void:
		if is_instance_valid(n):
			n.queue_free())
	return n


# --- Pot: lift, fire tiers, escalation --------------------------------------------

## Potted dice lift and light up one at a time (stagger 0.08 s, 0.14 s big).
func lift(dice: Array[DieVisual], big: bool, speed: float = 1.0) -> void:
	var stagger := (0.14 if big else 0.08) / maxf(speed, 0.001)
	var rig := _scene(RIG)
	for i in dice.size():
		var d := dice[i]
		if not is_instance_valid(d):
			continue
		if rig != null:
			var r := rig.instantiate() as Node3D
			add_child(r)
			r.global_transform = Transform3D(Basis(Vector3.UP, d.global_basis.get_euler().y), d.global_position)
			var follow := r.get_node_or_null("Lift/Follow") as RemoteTransform3D
			if follow != null:
				follow.update_rotation = false
				follow.remote_path = follow.get_path_to(d)
			var ap := r.get_node_or_null("AnimationPlayer") as AnimationPlayer
			if ap != null:
				ap.speed_scale = speed
				get_tree().create_timer(i * stagger, true, false, true).timeout.connect(func() -> void:
					if is_instance_valid(ap) and ap.has_animation("lift_light"):
						ap.play("lift_light")
						if ap.has_animation("hold"):
							ap.queue("hold"))
			_rigs[d] = r
			_log("art:lift_light")
		else:
			var base := d.position
			var tw := d.create_tween().set_ignore_time_scale(true)
			tw.tween_interval(i * stagger)
			tw.tween_callback(func() -> void:
				if table.has_method("_set_lit"):
					table.call("_set_lit", d, true)
				d.body_material.set_shader_parameter("emission_color", Palette.EMBER)
				d.body_material.set_shader_parameter("emission_energy", 0.9))
			tw.tween_property(d, "position", base + Vector3(0, d.edge * 0.45, 0), 0.12 / speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			d.set_meta("juice_rest", base)
			d.set_meta("juice_tw", tw)
			_log("fb:lift")


## Ends the lift (dice settle back down; the art rig plays `drop`).
func drop(dice: Array, immediate: bool = false) -> void:
	for d in dice:
		if not is_instance_valid(d):
			continue
		var dv := d as DieVisual
		if dv.has_meta("juice_tw"):
			var old: Tween = dv.get_meta("juice_tw")
			if old != null and old.is_valid() and immediate:
				old.kill()
			if immediate:
				dv.remove_meta("juice_tw")
		if _rigs.has(d):
			var r: Node3D = _rigs[d]
			_rigs.erase(d)
			if is_instance_valid(r):
				var follow := r.get_node_or_null("Lift/Follow") as RemoteTransform3D
				if immediate:
					if follow != null:
						follow.remote_path = NodePath()
					r.queue_free()
					continue
				var ap := r.get_node_or_null("AnimationPlayer") as AnimationPlayer
				if ap != null and ap.has_animation("drop"):
					ap.play("drop")
				get_tree().create_timer(0.3, true, false, true).timeout.connect(func() -> void:
					if is_instance_valid(follow):
						follow.remote_path = NodePath()
					if is_instance_valid(r):
						r.queue_free())
		elif dv.has_meta("juice_rest"):
			var rest: Vector3 = dv.get_meta("juice_rest")
			dv.remove_meta("juice_rest")
			if table.has_method("_set_lit"):
				table.call("_set_lit", dv, false)
			dv.body_material.set_shader_parameter("emission_energy", 0.0)
			if immediate:
				dv.position = rest
				continue
			var tw := dv.create_tween().set_ignore_time_scale(true)
			tw.tween_property(dv, "position", rest, 0.12)
			dv.set_meta("juice_tw", tw)


## The score tier hits the potted dice: fire (tiers 0-2 per die; tier 3 =
## inferno per die + ONE central pillar), shake, slow-mo and the crowd roar.
func escalate(score_tier: int, dice: Array[DieVisual], reduced: bool, instant: bool) -> void:
	var t := table.bonfire_tuning
	var k := clampi(score_tier, 0, 3)
	var per_die := mini(k, 2)
	var ps := _fire_scene(per_die) if has_art() else null
	var centre := Vector3.ZERO
	var n := 0
	for d in dice:
		if not is_instance_valid(d):
			continue
		centre += d.global_position
		n += 1
		if ps != null:
			_play_scene(ps, self, d.global_position, "burst")
		else:
			_fallback_fire(per_die, d.global_position, reduced)
	_log(("art:" if ps != null else "fb:") + "fire_" + String(JuicePlan.TIER_NAMES[per_die]))
	if n > 0:
		centre /= n
	if k == 3 and n > 0:
		var floor_c := Vector3(centre.x, centre.y - table.tuning.die_size * 0.5, centre.z)
		var pillar := _fire_scene(3) if has_art() else null
		if pillar != null:
			var spread := 0.0
			for d in dice:
				if is_instance_valid(d):
					spread = maxf(spread, Vector2(d.global_position.x - centre.x, d.global_position.z - centre.z).length() * 2.0)
			var p := _play_scene(pillar, self, floor_c, "burst")
			var s := clampf(maxf(spread, 0.2) / 0.66, 0.4, 1.4)
			p.scale = Vector3(s, 1.0, s)
			_log("art:pillar")
		else:
			_fallback_pillar(floor_c, reduced)
			_log("fb:pillar")
	if ps == null and n > 0 and k >= 1:
		# Cheap fallback: one flash of firelight on the pot (the art fire glows on its own).
		Fx3D.light_pulse(table.fx_root, centre + Vector3(0, 0.08, 0), FIRE_COLORS[0] if k < 3 else HELL_COLORS[0], 1.5 + 1.5 * k, 0.35 + 0.15 * k, 0.6 + 0.3 * k)
	if not reduced:
		var px: float = t.juice_shake_px[k] if k < t.juice_shake_px.size() else 0.0
		var secs: float = t.juice_shake_time[k] if k < t.juice_shake_time.size() else 0.0
		if px > 0.0 and secs > 0.0:
			table._camera_shake(px, secs)
			_log("fx:shake_%d" % k)
	if k == 3:
		if not reduced and not instant:
			slow_mo(t.juice_slowmo_time, t.juice_slowmo_scale)
		crowd_roar()


func slow_mo(seconds: float, scale: float) -> void:
	Engine.time_scale = scale
	_log("fx:slowmo")
	await get_tree().create_timer(seconds, true, false, true).timeout
	if is_equal_approx(Engine.time_scale, scale):
		Engine.time_scale = 1.0


func _fallback_fire(k: int, at: Vector3, reduced: bool) -> void:
	var root: Node3D = table.fx_root
	var m := 0.5 if reduced else 1.0
	match k:
		0:
			Fx3D.burst(root, at + Vector3(0, 0.03, 0), int(8 * m), [Palette.BRASS_HI, Palette.EMBER, Color(Palette.EMBER, 0.0)], Vector2(0.25, 0.6), 35.0, 0.3, Vector2(0.4, 0.8), 0.6, 2.0)
		1:
			Fx3D.burst(root, at + Vector3(0, 0.035, 0), int(18 * m), [FIRE_COLORS[0], FIRE_COLORS[1], Color(FIRE_COLORS[2], 0.0)], Vector2(0.15, 0.45), 22.0, 0.6, Vector2(1.2, 2.2), 0.7, 2.6)
		_:
			Fx3D.burst(root, at + Vector3(0, 0.03, 0), int(34 * m), [HELL_COLORS[0], HELL_COLORS[1], Color(HELL_COLORS[2], 0.0)], Vector2(0.2, 0.7), 40.0, 0.9, Vector2(1.6, 3.0), 0.9, 3.0)
			Fx3D.ring(root, Vector3(at.x, 0.003, at.z), HELL_COLORS[2], 0.12, 0.3)


func _fallback_pillar(at: Vector3, reduced: bool) -> void:
	var root: Node3D = table.fx_root
	var m := 0.5 if reduced else 1.0
	Fx3D.burst(root, at + Vector3(0, 0.02, 0), int(70 * m), [HELL_COLORS[0], HELL_COLORS[1], Color(HELL_COLORS[2], 0.0)], Vector2(1.4, 2.4), 7.0, 0.8, Vector2(2.0, 3.6), 1.1, 3.2)
	Fx3D.burst(root, at + Vector3(0, 0.02, 0), int(40 * m), [Palette.BRASS_HI, Palette.EMBER, Color(Palette.EMBER, 0.0)], Vector2(0.6, 1.6), 60.0, 1.2, Vector2(0.5, 1.0), 1.0, 2.5)
	Fx3D.ring(root, Vector3(at.x, 0.003, at.z), Palette.EMBER, 0.6, 0.45)


# --- Moments --------------------------------------------------------------------------

## Hot Hand: every die ignites (the fly-back trail starts with fly_start).
func hot_hand(dice: Array[DieVisual]) -> void:
	sfx(&"hot_hand", 1.0, 0.0, 0.0, &"win_big", 1.1, -4.0)
	var ps := _scene(IGNITE)
	for d in dice:
		if ps != null:
			_play_scene(ps, self, d.global_position, "ignite")
		else:
			Fx3D.burst(table.fx_root, d.global_position, 14, [FIRE_COLORS[0], FIRE_COLORS[1], Color(FIRE_COLORS[2], 0.0)], Vector2(0.3, 0.8), 70.0, 0.5, Vector2(0.8, 1.6), 0.5, 2.6)
		d.body_material.set_shader_parameter("emission_color", Palette.EMBER)
		d.body_material.set_shader_parameter("emission_energy", 1.2)
	_log(("art:" if ps != null else "fb:") + "hot_hand_ignite")


## Fire trails while the dice fly back (call fly_stop when they land).
func fly_start(dice: Array[DieVisual], seconds: float) -> void:
	var ps := _scene(TRAIL)
	for d in dice:
		if ps != null:
			var tr := ps.instantiate() as Node3D
			d.add_child(tr)
			var ap := tr.get_node_or_null("AnimationPlayer") as AnimationPlayer
			if ap != null and ap.has_animation("start"):
				ap.play("start")
			_trails[d] = tr
		else:
			_fallback_trail(d, seconds)
	_log(("art:" if ps != null else "fb:") + "fire_trail")


func fly_stop(dice: Array) -> void:
	for d in dice:
		if _trails.has(d):
			var tr: Node3D = _trails[d]
			_trails.erase(d)
			if is_instance_valid(tr):
				var ap := tr.get_node_or_null("AnimationPlayer") as AnimationPlayer
				if ap != null and ap.has_animation("stop"):
					ap.play("stop")
				get_tree().create_timer(0.8, true, false, true).timeout.connect(func() -> void:
					if is_instance_valid(tr):
						tr.queue_free())
		if is_instance_valid(d):
			(d as DieVisual).body_material.set_shader_parameter("emission_energy", 0.0)


func _fallback_trail(d: DieVisual, seconds: float) -> void:
	var steps := int(seconds / 0.05)
	for i in steps:
		get_tree().create_timer(i * 0.05, true, false, true).timeout.connect(func() -> void:
			if is_instance_valid(d) and is_instance_valid(table):
				Fx3D.burst(table.fx_root, d.global_position, 3, [FIRE_COLORS[0], FIRE_COLORS[2], Color(Palette.SMOKE, 0.0)], Vector2(0.02, 0.1), 180.0, 0.2, Vector2(1.0, 1.8), 0.35, 2.2))


## Bank: the hellish cash register (the HUD flies the embers).
func bank_sound() -> void:
	sfx(&"bank", 1.0, 0.0, 0.0, &"chip_collect", 1.0, 0.0)


func stamp_sound() -> void:
	sfx(&"bounty_claimed", 1.0, 0.0, 0.0, &"win_big", 1.2, -6.0)


## Ember pile pickup on the rail (art only; the HUD counter is the fallback).
func ember_pile(at: Vector3) -> void:
	var ps := _scene(EMBER_PILE)
	if ps == null:
		_log("fb:ember_pile")
		return
	var n := _play_scene(ps, self, at, "collect")
	n.scale = Vector3.ONE
	_log("art:ember_pile")


## Bust: flames snuff, the dice go to ash for juice_ash_time and back to
## bone, the low thud, then the Soul flask cracks.
func bust(dice: Array[DieVisual], reduced: bool) -> void:
	var t := table.bonfire_tuning
	sfx(&"bust", 1.0, 0.0, 0.0, &"seven_out", 1.0, 0.0)
	get_tree().create_timer(t.juice_flask_crack_delay, true, false, true).timeout.connect(func() -> void:
		sfx(&"soul_flask_crack", 1.0, 0.0, 0.0, &"soul_burn", 0.7, -2.0))
	var ash_mat: Material = null
	if has_art() and ResourceLoader.exists(VFX + ASH_BODY):
		ash_mat = load(VFX + ASH_BODY) as Material
	for d in dice:
		if not is_instance_valid(d):
			continue
		table._set_lit(d, false)
		Fx3D.burst(table.fx_root, d.global_position + Vector3(0, 0.03, 0), 4 if reduced else 8, [Color(Palette.PIT_BLACK, 0.7), Color(ASH, 0.0)], Vector2(0.05, 0.2), 50.0, 0.1, Vector2(3.0, 5.0), 0.9, 1.0, false)
		var body := d.faces.get_node_or_null("Body") as MeshInstance3D
		if ash_mat != null and body != null:
			var old := body.material_override
			body.material_override = ash_mat
			body.set_instance_shader_parameter("ash", 0.0)
			var tw := body.create_tween().set_ignore_time_scale(true)
			tw.tween_method(func(v: float) -> void: body.set_instance_shader_parameter("ash", v), 0.0, 1.0, 0.12)
			tw.tween_interval(t.juice_ash_time - 0.24)
			tw.tween_method(func(v: float) -> void: body.set_instance_shader_parameter("ash", v), 1.0, 0.0, 0.12)
			tw.tween_callback(func() -> void:
				if is_instance_valid(body):
					body.material_override = old)
		else:
			var bone: Color = d.body_material.get_shader_parameter("albedo")
			var tw := d.create_tween().set_ignore_time_scale(true)
			tw.tween_method(func(f: float) -> void: d.body_material.set_shader_parameter("albedo", bone.lerp(ASH, f)), 0.0, 1.0, 0.12)
			tw.tween_interval(t.juice_ash_time - 0.24)
			tw.tween_method(func(f: float) -> void: d.body_material.set_shader_parameter("albedo", bone.lerp(ASH, f)), 1.0, 0.0, 0.12)
	_log(("art:" if ash_mat != null else "fb:") + "ash")
