## Lighting layers 4-5 stills (lighting_layers_spec.md test checklist 5-6):
## the real Bonfire table and game camera, dice at rest, then one die lifted
## to h 0.15 m (faded, grown contact blob), then reduced motion (no dust).
## Run once per renderer:
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-method forward_plus --rendering-driver vulkan \\
##       --resolution 1280x720 --script res://tools/capture_lighting_layers.gd -- --out=/tmp/ll/ --tag=fplus
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-method gl_compatibility \\
##       --rendering-driver opengl3 --resolution 1280x720 --script res://tools/capture_lighting_layers.gd -- --out=/tmp/ll/ --tag=compat
extends SceneTree

var OUT := "user://captures_lighting_layers/"
var TAG := "fplus"


func _initialize() -> void:
	_run.call_deferred()


func wait(t: float) -> void:
	await create_timer(t, true, false, true).timeout


func shot(name: String) -> void:
	await process_frame
	await process_frame
	var p := OUT + "ll_%s_%s.png" % [TAG, name]
	root.get_viewport().get_texture().get_image().save_png(p)
	print("saved ", p)


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			OUT = a.trim_prefix("--out=").trim_suffix("/") + "/"
		elif a.begins_with("--tag="):
			TAG = a.trim_prefix("--tag=")
	DirAccess.make_dir_recursive_absolute(OUT)
	var t := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = TableSetup.sandbox(t, 4)
	s.tutorial_override = 0
	root.add_child(s)
	await wait(1.0)
	while s.phase != Table3D.Phase.BET:
		await process_frame
	s.rig_faces([2, 3, 4, 6] as Array[int])
	if s.quick_throw():
		await s.sequence_finished
	await wait(1.5)
	print("renderer ", RenderingServer.get_current_rendering_method())
	await shot("rest")
	var d := s.all_dice[1]
	d.global_position.y += 0.15
	await wait(0.2)
	await shot("midair_h015")
	s.set_reduced_motion(true)
	await wait(0.3)
	await shot("reduced_motion")
	quit()
