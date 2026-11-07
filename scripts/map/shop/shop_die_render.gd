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


## Where the model meets the counter, in viewport pixels.
## x is the centre of the projected bounds; y is the lowest corner.
## (-1, -1) when the rig has no mesh. The counter pad anchors here.
func contact_local() -> Vector2:
	var model := _subject()
	var cam := _camera()
	if model == null or cam == null:
		return Vector2(-1, -1)
	var box := _world_bounds(model)
	if box.size == Vector3.ZERO:
		return Vector2(-1, -1)
	var p := box.position
	var s := box.size
	var min_x := INF
	var max_x := -INF
	var low_y := -INF
	for corner in [
		p,
		p + Vector3(s.x, 0, 0),
		p + Vector3(0, s.y, 0),
		p + Vector3(0, 0, s.z),
		p + Vector3(s.x, s.y, 0),
		p + Vector3(s.x, 0, s.z),
		p + Vector3(0, s.y, s.z),
		p + s,
	]:
		var sp := cam.unproject_position(corner)
		min_x = minf(min_x, sp.x)
		max_x = maxf(max_x, sp.x)
		low_y = maxf(low_y, sp.y)
	return Vector2((min_x + max_x) * 0.5, low_y)


## The model under the camera (not a light).
func _subject() -> Node3D:
	if view == null:
		return null
	for ch in view.get_children():
		if ch is Node3D and not (ch is Camera3D) and not (ch is Light3D):
			return ch
	return null


## The rig's existing camera. Not moved by the pad.
func _camera() -> Camera3D:
	if view == null:
		return null
	for ch in view.get_children():
		if ch is Camera3D:
			return ch
	return null


## Mesh bounds in world space, after the fit scale in `make_model`.
func _world_bounds(model: Node3D) -> AABB:
	var out := AABB()
	var first := true
	model.force_update_transform()
	for m in model.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		mi.force_update_transform()
		var g: AABB = mi.global_transform * mi.get_aabb()
		out = g if first else out.merge(g)
		first = false
	return out


## Path of the model for art key `key` ("" if the file doesn't exist).
static func model_path(key: StringName) -> String:
	var p := "res://art/models/dice/%s.glb" % key
	return p if ResourceLoader.exists(p) else ""


## The render for `o` at `px` square, or null when there is no model yet.
## Dice use a .glb; chips and tokens use ShopChipBuild (AD chips_3d_nov5).
static func make(o: ShopOffer, px: float) -> ShopDieRender:
	if o.kind != ShopOffer.Kind.DIE:
		# Chips use id; mods/Seals/Draught use art_key for the bone token.
		var key: StringName = o.id if o.kind == ShopOffer.Kind.CHIP else o.art_key
		return make_model(ShopChipBuild.make(key), px)
	var path := model_path(o.art_key)
	if path == "":
		return null
	return make_model((load(path) as PackedScene).instantiate(), px)


## A live SubViewport of any Node3D at `px` square (shared camera / lights).
static func make_model(model: Node3D, px: float) -> ShopDieRender:
	var r := ShopDieRender.new()
	r.stretch = true
	r.custom_minimum_size = Vector2(px, px)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.view = SubViewport.new()
	r.view.transparent_bg = true
	r.view.own_world_3d = true
	r.view.size = Vector2i(int(px), int(px))
	r.add_child(r.view)
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
