## Die material prototype renders (Bonfire sandbox + Hearth board, game camera).
##   xvfb-run -a -s "-screen 0 2400x2400x24" godot --path . --resolution 1920x1080 \
##     [--rendering-method gl_compatibility] --script res://art/materials/dice/src/render_die_materials.gd \
##     -- out=/abs/dir tag=fplus
## Writes <tag>_still_before.png / _after.png / _lit.png (game camera),
## closeups <tag>_<die>_<state>.png (384 px, game-camera angle, same lamp),
## and <tag>_boxes.json (screen boxes of each die in the stills).
extends SceneTree

const HEARTH := "res://art/models/boards/hearth/scenes/hearth_board.tscn"
const M := "res://art/materials/dice/"
# die glb, family body, family pip (or "" = keep), keep extra slots
const DEMO := [
	["bone_d6", "bone"], ["gilded_d6", "brass"], ["mirror_d6", "glass"],
	["wanderer_d6", "wood"], ["last_breath_d6", "obsidian"], ["lantern_d8", "locked/lantern_d8"],
]
var out := "/tmp"
var tag := "fplus"


func _initialize() -> void:
	_run.call_deferred()


func _apply(mi: MeshInstance3D, fam: String, state: String) -> void:
	var body := load(M + fam + ".tres") as ShaderMaterial
	var pipp := M + fam + "_pip.tres"
	var pip: ShaderMaterial = load(pipp) if ResourceLoader.exists(pipp) else null
	body = body.duplicate()
	if pip: pip = pip.duplicate()
	for mat in [body, pip]:
		if mat == null: continue
		if state == "lit":
			mat.set_shader_parameter("die_lit", 1.0)
			mat.set_shader_parameter("glow_energy", 0.55)
		elif state == "cold":
			mat.set_shader_parameter("die_cold", 1.0)
	for i in mi.mesh.get_surface_count():
		var orig := mi.mesh.surface_get_material(i)
		var n := orig.resource_path.get_file() if orig else ""
		if n.contains("_pip"):
			if pip: mi.set_surface_override_material(i, pip)
		elif n.contains("frame"):
			pass  # lantern frame keeps its locked material
		else:
			mi.set_surface_override_material(i, body)


func _before(mi: MeshInstance3D, state: String) -> void:
	for i in mi.mesh.get_surface_count():
		var orig := mi.mesh.surface_get_material(i)
		if orig is ShaderMaterial and state != "rest":
			var mm := (orig as ShaderMaterial).duplicate() as ShaderMaterial
			mm.set_shader_parameter("die_lit" if state == "lit" else "die_cold", 1.0)
			mi.set_surface_override_material(i, mm)
		else:
			mi.set_surface_override_material(i, null)


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): out = a.substr(4)
		if a.begins_with("tag="): tag = a.substr(4)
	var t := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = TableSetup.sandbox(t, 5)
	s.tutorial_override = 0
	root.add_child(s)
	await process_frame
	await process_frame
	var tbl := s.table.root if "root" in s.table else s.find_child("Table", true, false)
	if tbl != null:
		for c in tbl.get_children():
			if c is MeshInstance3D and c.name != "WallBack":
				(c as MeshInstance3D).visible = false
	s.add_child((load(HEARTH) as PackedScene).instantiate())
	await create_timer(0.6).timeout
	s.camera.snap_home()
	for d in s.all_dice:
		d.visible = false
	for n in s.find_children("*", "DieVisual", true, false):
		(n as Node3D).visible = false
	var dice: Array = []
	var i := 0
	for e in DEMO:
		var inst := (load("res://art/models/dice/%s.glb" % e[0]) as PackedScene).instantiate() as Node3D
		var mi := inst.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var half := mi.mesh.get_aabb().size.y * 0.5
		inst.position = Vector3(-0.375 + 0.15 * i, half, 0.08)
		inst.rotation = Vector3(0.0, deg_to_rad(28.0), 0.0)
		s.add_child(inst)
		dice.append([e, mi, inst])
		i += 1
	for k in 8: await process_frame
	var cam := s.camera.cam
	var boxes := {}
	for d in dice:
		var p := (d[2] as Node3D).global_position
		var a := cam.unproject_position(p + Vector3(-0.05, -0.05, 0))
		var b := cam.unproject_position(p + Vector3(0.05, 0.05, 0))
		boxes[d[0][0]] = [minf(a.x, b.x), minf(a.y, b.y), maxf(a.x, b.x), maxf(a.y, b.y)]
	boxes["_viewport"] = [root.get_visible_rect().size.x, root.get_visible_rect().size.y]
	FileAccess.open(out + "/%s_boxes.json" % tag, FileAccess.WRITE).store_string(JSON.stringify(boxes))
	# Close-up rig: a SubViewport sharing the world, looking from the game camera direction.
	var sv := SubViewport.new()
	sv.size = Vector2i(384, 384)
	sv.world_3d = root.get_world_3d()
	sv.msaa_3d = Viewport.MSAA_4X
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	var cc := Camera3D.new()
	sv.add_child(cc)
	cc.fov = 9.0
	var back := cam.global_transform.basis.z.normalized()
	for state in ["rest", "lit", "cold"]:
		for v in ["before", "after"]:
			for d in dice:
				if v == "before": _before(d[1], state)
				else: _apply(d[1], d[0][1], state)
			for k in 4: await process_frame
			if state == "rest" or (state == "lit"):
				var img := root.get_texture().get_image()
				img.save_png(out + "/%s_still_%s_%s.png" % [tag, v, state])
			for d in dice:
				var p := (d[2] as Node3D).global_position
				cc.global_position = p + back * 0.85
				cc.look_at(p, Vector3.UP)
				for k in 3: await RenderingServer.frame_post_draw
				sv.get_texture().get_image().save_png(out + "/%s_%s_%s_%s.png" % [tag, d[0][0], v, state])
	print("DONE ", out)
	quit()
