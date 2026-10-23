## Layer 1 of the Bonfire juice adapter (see bonfire_juice.gd for the whole
## picture): its constants and variables, the hook log, and every sound:
## SfxManager events with fallbacks, the pip / count / stinger sounds and
## the crowd layers. BonfireJuice extends this and adds the visual effects,
## slow-mo and timers. Only BonfireJuice is ever created.
@abstract
class_name BonfireJuiceSound
extends Node3D


const SYNTH_PATH := "res://scripts/audio/bonfire_synth.gd"
const CROWD_PATH := "res://scripts/audio/crowd_layers.gd"
const VFX := "res://art/vfx/bonfire/"
const RIG := "scenes/dice/potted_die_rig.tscn"
const LIT_FACE := "materials/lit_face_glow.tres"
const ASH_BODY := "materials/ash_body.tres"
const EMBER_PILE := "res://art/models/props/bonfire/scenes/ember_pile.tscn"
## The pip scale (same as BonfireSynth.TICK_SCALE) when the synth is absent.
const TICK_SCALE: Array[int] = [0, 2, 3, 5, 7, 8, 11, 12, 14, 15, 17, 19]
const STINGERS: Array[StringName] = [&"stinger_ember", &"stinger_flames", &"stinger_inferno", &"stinger_pillar"]
const ASH := Color("#5A5E62")
## 1000+: how long the brazier holds its fire column (spec: back by ~0.6 s).
const BRAZIER_COLUMN_TIME: float = 0.5

var table: Bonfire3D
var calls: Array[String] = []
var crowd: Node
var _synth: GDScript
var _scenes: Dictionary = {}
var _last_count_tick_ms: int = -100000
var _rigs: Dictionary = {}
var _crowd_fraction: float = 0.0
## Force the fallbacks (tests: "without the art / audio branches").
var force_fallback: bool = false
## Every timer this node starts; unhooked when it leaves the tree (#128).
var _timers := ExitTimers.new()
## The slow-mo time scale in effect (0 = none), to undo it if cut short.
var _slowmo_scale: float = 0.0


func has_audio() -> bool:
	return not force_fallback and _synth != null and table != null and table.sfx.has_method("has_event") and table.sfx.has_event(&"score_tick")


func has_art() -> bool:
	return not force_fallback and ResourceLoader.exists(VFX + RIG)


func _log(s: String) -> void:
	calls.append(s)
	if calls.size() > 400:
		calls = calls.slice(200)


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
		_timers.start(self, 1.2, true, false, true).timeout.connect(func() -> void:
			if is_instance_valid(crowd):
				crowd.call("set_pot_fraction", _crowd_fraction))
	else:
		sfx(&"crowd_roar_missing", 1.0, 0.0, 0.0, &"win_big", 0.8, -2.0)


func crowd_stop() -> void:
	if crowd != null and crowd.has_method("stop"):
		crowd.call("stop")
