## Hearth progress candle (Hearth/Candles/RailLeft|RailRight/CandleN): lit shows the tier-1 toon
## tongue at ~0.5 scale. heat = 1 normal, 0 = snuffed (keeps `lit`, so it relights). flare = the
## all-8-lit flare (0-1, grows the tongue and boosts the core). wisp = smoke wisp progress. Visual only.
@tool
extends Node3D

const TOP := 0.066        # build_hearth.py CANDLE_TOP (wick tip at height 1)
const CARD_FOOT := 0.113  # the tongue drawing's foot inside its card

@export var lit: bool = false:
	set(v):
		lit = v
		_apply()
## Per-candle height variety (scales the wax, moves the flame to the new wick top). Art dressing.
@export_range(0.7, 1.3) var height: float = 1.0:
	set(v):
		height = clampf(v, 0.7, 1.3)
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
	fl.position.y = TOP * height - 0.0015 - fl.mesh.get_aabb().size.y * CARD_FOOT
	var wp := get_node_or_null("Wisp") as Node3D
	if wp != null:
		wp.position.y = TOP * height + 0.002 - (wp as MeshInstance3D).mesh.get_aabb().size.y * CARD_FOOT
	fl.visible = lit and heat > 0.001
	fl.set_instance_shader_parameter(&"heat", heat)
	fl.set_instance_shader_parameter(&"pulse", flare)
	HearthProps.wisp(get_node_or_null("Wisp") as Node3D, wisp if lit else 0.0)
