## A shop die's real 3D model, seen 3/4 from above in a small SubViewport.
## This is the one icon rig for the shop: ShopIcon uses it for dice, and PR B
## (ShopCard) can call `ShopDieRender.make` too. The model file is picked by
## the offer's art key, so a new die needs no code here, only its .glb.
class_name ShopDieRender
extends SubViewportContainer

## Rig lights (AD review): a warm key light from the camera's upper left so
## bone reads cream, a soft neutral fill from the other side so shadow faces
## keep their detail, and a dim warm ambient. Materials are untouched.
const KEY_COLOR := Color("#FFEAD0")
const KEY_ENERGY := 2.1
const FILL_COLOR := Color("#E6E0D6")
const FILL_ENERGY := 0.45
const AMBIENT_COLOR := Color("#A89A88")
const AMBIENT_ENERGY := 0.6

## The 3D world the die lives in. Tests read it.
var view: SubViewport


## Path of the model for art key `key` ("" if the file doesn't exist).
static func model_path(key: StringName) -> String:
	var p := "res://art/models/dice/%s.glb" % key
	return p if ResourceLoader.exists(p) else ""


## The render for `o` at `px` square, or null if its art key has no .glb yet.
static func make(o: ShopOffer, px: float) -> ShopDieRender:
	var path := model_path(o.art_key)
	if path == "":
		return null
	var r := ShopDieRender.new()
	r.stretch = true
	r.custom_minimum_size = Vector2(px, px)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.view = SubViewport.new()
	r.view.transparent_bg = true
	r.view.own_world_3d = true
	r.view.size = Vector2i(int(px), int(px))
	r.add_child(r.view)
	var model: Node3D = (load(path) as PackedScene).instantiate()
	r.view.add_child(model)
	# Fit any model size: centre it and scale its widest side to 1 unit.
	var box := _bounds(model)
	var s := 1.0 / maxf(box.get_longest_axis_size(), 0.001)
	model.scale = Vector3.ONE * s
	model.position = -box.get_center() * s
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.75
	r.view.add_child(cam)
	cam.look_at_from_position(Vector3(1.4, 1.6, 1.8), Vector3.ZERO)
	r._add_lights()
	return r


func _add_lights() -> void:
	for l: Array in [[KEY_COLOR, KEY_ENERGY, Vector3(0.6, 3.0, 2.4)], [FILL_COLOR, FILL_ENERGY, Vector3(2.6, 0.8, -0.6)]]:
		var light := DirectionalLight3D.new()
		light.light_color = l[0]
		light.light_energy = l[1]
		view.add_child(light)
		light.look_at_from_position(l[2], Vector3.ZERO)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = AMBIENT_COLOR
	env.environment.ambient_light_energy = AMBIENT_ENERGY
	view.add_child(env)


## The combined box around every mesh under `n`, in n's own space. It walks
## parent transforms by hand, so it works before the model enters the tree.
static func _bounds(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var t := Transform3D.IDENTITY
		var p: Node = mi
		while p != null and p != n:
			if p is Node3D:
				t = (p as Node3D).transform * t
			p = p.get_parent()
		out = t * mi.get_aabb() if first else out.merge(t * mi.get_aabb())
		first = false
	return out
