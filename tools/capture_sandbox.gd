## Sandbox launcher screenshots: the menu, then each event (table screens
## also open the 3D table). GL Compatibility under xvfb:
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 \
##       --resolution 1920x1080 --script res://tools/capture_sandbox.gd -- --out=/tmp/sb/ --floor=1 --seed=1
extends SceneTree

var OUT := "user://captures_sandbox/"


func _initialize() -> void:
	_run.call_deferred()


func shot(name: String) -> void:
	for i in 3:
		await process_frame
	root.get_texture().get_image().save_png(OUT + name + ".png")
	print("saved ", OUT + name + ".png")


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			OUT = a.trim_prefix("--out=").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(OUT)
	var title := (load("res://scenes/title.tscn") as PackedScene).instantiate()
	root.add_child(title)
	await create_timer(0.8).timeout
	await shot("sandbox_title")
	title.queue_free()
	var menu := (load("res://scenes/sandbox.tscn") as PackedScene).instantiate() as SandboxScreen
	root.add_child(menu)
	await create_timer(0.5).timeout
	await shot("sandbox_menu")
	for ev in SandboxPreset.EVENTS:
		var args := OS.get_cmdline_user_args()
		args.append("--sandbox=table")
		var p := SandboxPreset.from_args(args)
		p.event = ev
		menu.launch(p)
		await create_timer(0.5).timeout
		await shot("sandbox_%s" % ev)
		if ev != &"shop":
			menu.run_screen._play_table()
			await create_timer(4.0).timeout
			await shot("sandbox_%s_3d" % ev)
		menu.run_screen.queue_free()
		await process_frame
	quit()
