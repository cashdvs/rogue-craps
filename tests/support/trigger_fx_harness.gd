## Shared harness for trigger FX headless tests (see test_fx_trigger*.gd).
## Stubs, world/camera setup, and die/fx helpers used by every split file.
class_name TriggerFxHarness
extends SceneTree

const DT: float = 1.0 / 120.0
const FIRE_WORDS: Array[String] = ["fire", "flame", "ignite", "pillar"]

var _passed: int = 0
var _failed: int = 0
var _world: Node3D
var _cam: Camera3D

class StubAudio:
	extends Node
	var calls: Array = []
	var reply: float = -1.0
	var fx: TriggerFx

	func mod_trigger(id: StringName, die: Variant = null, anchor: StringName = &"", ctx: Dictionary = {}) -> float:
		calls.append([id, die, anchor, ctx, fx._clock if fx != null else 0.0])
		return reply


## A SfxManager stand-in with the Sound Designer's hook.

class StubSfx:
	extends Node
	var calls: Array = []
	var trigger_speed_mode: int = 0
	var crowd: Node

	func play_mod_trigger(id: StringName, tier: int = -1, intensity: float = 1.0, hit_ms: float = -1.0, flavor: StringName = &"") -> float:
		calls.append([id, tier, intensity, hit_ms, flavor])
		return 0.3


## BonfireJuice stand-in: just its crowd.

class JuiceStub:
	extends Node
	var crowd: Node


## A table stand-in: dice by id, speed / reduced flags, a juice with a crowd.

class StubTable:
	extends Node3D
	var all_dice: Array = []
	var speed_mode: int = 0
	var reduced_motion: bool = false
	var juice: Node


## A table with the events and sfx nodes TableAudio binds through.

class EventsTable:
	extends StubTable
	var events: Node
	var sfx: Node


func _check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


func _die(at: Vector3, yaw: float = 0.0) -> DieVisual:
	var d := DieVisual.new(0.08)
	_world.add_child(d)
	d.global_transform = Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, 0.3), at)
	d.faces.basis = Basis(Vector3.FORWARD, PI / 2.0)  # a face remap the FX must keep
	return d


func _fx(audio: Node = null) -> TriggerFx:
	var fx := TriggerFx.new()
	fx.camera = _cam
	fx.audio = audio
	_world.add_child(fx)
	fx.set_process(false)
	return fx


func _step(fx: TriggerFx, seconds: float) -> void:
	for i in int(round(seconds / DT)):
		fx._process(DT)


func _free(list: Array) -> void:
	for n: Node in list:
		if is_instance_valid(n):
			n.free()


func _cyan_or_violet(c: Color) -> bool:
	var h := c.h * 360.0
	return c.s > 0.12 and ((h >= 165.0 and h <= 205.0) or (h >= 255.0 and h <= 305.0))


func _die_look(d: DieVisual) -> Dictionary:
	var out := {"faces_children": d.faces.get_child_count()}
	for p: String in ["albedo", "shadow_color", "emission_color", "emission_energy", "mid_tint"]:
		out[p] = d.body_material.get_shader_parameter(p)
	var mats: Array = []
	for m: Node in d.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		mats.append([mi.material_override, mi.get_surface_override_material_count() > 0 and mi.get_surface_override_material(0) != null, mi.transparency])
		if mi.material_override is StandardMaterial3D:
			mats.append((mi.material_override as StandardMaterial3D).albedo_color)
		elif mi.material_override is ShaderMaterial:
			mats.append((mi.material_override as ShaderMaterial).get_shader_parameter("albedo"))
	out["mats"] = mats
	return out


func _motes_ok(b: TriggerFxPool.Burst, die: Node3D) -> bool:
	var c := _cam.unproject_position(die.global_position)
	var ok := true
	for i in 2:
		var m := b.trail[i]
		var p := _cam.unproject_position(m.global_position)
		ok = ok and m.visible and m.material_override.albedo_texture == TriggerShapes.texture(&"spark_dot_soft", TriggerFxDefs.GLASS)
		ok = ok and (m.mesh as QuadMesh).size.x <= 0.35 * float(die.get("edge")) + 0.0001
		ok = ok and p.x > c.x and p.y < c.y and m.global_position.distance_to(die.global_position) > 0.5 * float(die.get("edge"))
	_check(ok, "motes: two small glass dots, offset up-right from the die centre (Art Director)")
	return ok


func _setup_world() -> void:
	_world = Node3D.new()
	root.add_child(_world)
	_cam = Camera3D.new()
	_world.add_child(_cam)
	_cam.look_at_from_position(Vector3(0, 1.2, 0.9), Vector3.ZERO)


func _finish() -> void:
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
