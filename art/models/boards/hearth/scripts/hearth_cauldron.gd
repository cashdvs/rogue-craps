## Hearth ember cauldron (Anchors/ChipTray): fill 0-1 raises the glowing ember mound inside the pot
## (0 = empty, 1 = brim). heat = 1 normal, 0 = snuffed. wisp = smoke wisp progress. Visual only.
@tool
extends Node3D

## Inner wall of the pot (build_hearth.py CAUL_INNER): (y, radius) in the cauldron's local space.
const INNER: Array[Vector2] = [Vector2(0.016, 0.062), Vector2(0.05, 0.076), Vector2(0.086, 0.07), Vector2(0.104, 0.061)]
const CENTRE := Vector3(0.106, 0.0, 0.0)

@export_range(0.0, 1.0) var fill: float = 0.5:
	set(v):
		fill = clampf(v, 0.0, 1.0)
		_apply()
@export_range(0.0, 1.0) var heat: float = 1.0:
	set(v):
		heat = clampf(v, 0.0, 1.0)
		_apply()
@export_range(0.0, 1.0) var wisp: float = 0.0:
	set(v):
		wisp = clampf(v, 0.0, 1.0)
		_apply()


func _ready() -> void:
	_apply()


static func inner_radius(y: float) -> float:
	if y <= INNER[0].x:
		return INNER[0].y
	for i in range(1, INNER.size()):
		if y <= INNER[i].x:
			var t := (y - INNER[i - 1].x) / (INNER[i].x - INNER[i - 1].x)
			return lerpf(INNER[i - 1].y, INNER[i].y, t)
	return INNER[INNER.size() - 1].y


func _apply() -> void:
	var f := get_node_or_null("Fill") as Node3D
	if f == null:
		return
	var y := lerpf(INNER[0].x, INNER[INNER.size() - 1].x - 0.004, fill)
	var r := inner_radius(y) * 0.98
	f.visible = fill > 0.01
	f.position = CENTRE + Vector3(0, y, 0)
	f.scale = Vector3(r, 1.0 + fill * 0.6, r)
	HearthProps.set_param(f, &"level", 1.0)
	HearthProps.set_param(f, &"heat", heat)
	HearthProps.wisp(get_node_or_null("Wisp") as Node3D, wisp if fill > 0.01 else 0.0)
	var w := get_node_or_null("Wisp") as Node3D
	if w != null:
		w.position = CENTRE + Vector3(0, y + 0.01, 0)
