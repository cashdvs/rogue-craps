## Hearth progress candle (Hearth/Candles/RailLeft|RailRight/CandleN): lit shows the tier-1 toon
## tongue at ~0.5 scale. heat = 1 normal, 0 = snuffed (keeps `lit`, so it relights). flare = the
## all-8-lit flare (0-1, grows the tongue and boosts the core). wisp = smoke wisp progress. Visual only.
@tool
extends Node3D

const TOP := 0.066        # build_hearth.py CANDLE_TOP (wick tip at height 1)
const CARD_FOOT := 0.113  # the tongue drawing's foot inside its card
const WAX := "res://art/models/boards/hearth/materials/candle_wax.tres"
const WAX_LIT := preload("res://art/models/boards/hearth/materials/candle_wax_lit.tres")

@export var lit: bool = false:
	set(v):
		lit = v
		_apply()
## Per-candle height variety (scales the wax, moves the flame to the new wick top). Art dressing.
@export_range(0.7, 1.3) var height: float = 1.0:
	set(v):
		height = clampf(v, 0.7, 1.3)
		_apply()
## Model yaw (variety; the candle root stays square to the rail so the glow decal lies on it).
@export var spin: float = 0.0:
	set(v):
		spin = v
		_apply()
## Roll of the glow decal to sit on the curved rail top (+16 deg left rail, -16 deg right rail).
@export var glow_tilt: float = 0.0:
	set(v):
		glow_tilt = v
		_apply()
@export_range(0.0, 1.0) var heat: float = 1.0:
	set(v):
		heat = clampf(v, 0.0, 1.0)
		_apply()
@export_range(0.0, 1.0) var flare: float = 0.0:
	set(v):
		flare = clampf(v, 0.0, 1.0)
		_apply()
@export_range(0.0, 1.0) var wisp: float = 0.0:
	set(v):
		wisp = clampf(v, 0.0, 1.0)
		_apply()


func _ready() -> void:
	_apply()


func _apply() -> void:
	var fl := get_node_or_null("Flame") as Node3D
	if fl == null:
		return
	var m := get_node_or_null("Model") as Node3D
	if m != null:
		m.scale = Vector3(1.0, height, 1.0)
		m.rotation.y = spin
		# lit: the shared emissive-rim wax; unlit: the shared dim wax (silhouette still reads)
		var mi := HearthProps.mesh_of(m)
		if mi != null:
			for s in mi.mesh.get_surface_count():
				var base := mi.mesh.surface_get_material(s)
				if base != null and base.resource_path == WAX:
					mi.set_surface_override_material(s, WAX_LIT if lit else null)
	var gl := get_node_or_null("Glow") as GeometryInstance3D
	if gl != null:
		gl.visible = lit and heat > 0.001
		gl.rotation.z = deg_to_rad(glow_tilt)
		gl.set_instance_shader_parameter(&"heat", heat)
		gl.set_instance_shader_parameter(&"pulse", flare)
	fl.position.y = TOP * height - 0.0015 - fl.mesh.get_aabb().size.y * CARD_FOOT
	var wp := get_node_or_null("Wisp") as Node3D
	if wp != null:
		wp.position.y = TOP * height + 0.002 - (wp as MeshInstance3D).mesh.get_aabb().size.y * CARD_FOOT
	fl.visible = lit and heat > 0.001
	fl.set_instance_shader_parameter(&"heat", heat)
	fl.set_instance_shader_parameter(&"pulse", flare)
	HearthProps.wisp(get_node_or_null("Wisp") as Node3D, wisp if lit else 0.0)
