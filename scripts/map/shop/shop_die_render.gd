## A shop die's 3D model seen 3/4 from above (the #178 render; mods / Seals use discs until A2).
class_name ShopDieRender
extends SubViewportContainer

var view: SubViewport


## The render for `o`, or null if its art key has no .glb yet.
static func make(o: ShopOffer, px: float) -> ShopDieRender:
	var path := "res://art/models/dice/%s.glb" % o.art_key
	if not ResourceLoader.exists(path):
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
	var box := AABB()  # Fit any model: centre it, widest side 1 unit.
	for m: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var t := Transform3D.IDENTITY
		var n: Node = m
		while n != model:
			t = (n as Node3D).transform * t if n is Node3D else t
			n = n.get_parent()
		box = t * m.get_aabb() if box.size == Vector3.ZERO else box.merge(t * m.get_aabb())
	var s := 1.0 / maxf(box.get_longest_axis_size(), 0.001)
	model.scale = Vector3.ONE * s
	model.position = -box.get_center() * s
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.75
	r.view.add_child(cam)
	cam.look_at_from_position(Vector3(1.4, 1.6, 1.8), Vector3.ZERO)
	var sun := DirectionalLight3D.new()
	r.view.add_child(sun)
	sun.light_energy = 1.6
	sun.look_at_from_position(Vector3(1, 3, 2), Vector3.ZERO)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.85, 0.8, 0.75)
	env.environment.ambient_light_energy = 1.1
	r.view.add_child(env)
	return r
