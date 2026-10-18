## Title + Options screenshots (needs a display; lavapipe under xvfb works):
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver vulkan \
##       --resolution 1920x1080 --script res://tools/capture_title.gd -- --out=/tmp/title/
extends SceneTree

var OUT := "user://captures_title/"


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
	var t := (load("res://scenes/title.tscn") as PackedScene).instantiate() as TitleScreen
	root.add_child(t)
	await create_timer(0.8).timeout
	await shot("title_01_menu")
	t.open_options()
	await create_timer(0.3).timeout
	await shot("title_02_options")
	quit()
