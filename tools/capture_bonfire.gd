## Bonfire sandbox screenshots / movie (needs a display and Vulkan; lavapipe
## under xvfb works). PNGs go to --out=<folder> (default user://captures_bonfire/):
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver vulkan \\
##       --resolution 1920x1080 --script res://tools/capture_bonfire.gd -- --out=/tmp/bonfire/
## Add --fixed-fps 30 --write-movie /tmp/bonfire.avi before --script for a video.
extends SceneTree

var OUT := "user://captures_bonfire/"
var s: Bonfire3D


func _initialize() -> void:
	_run.call_deferred()


func shot(name: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(OUT + name + ".png")
	print("saved ", OUT + name + ".png")


func wait(t: float) -> void:
	await create_timer(t, true, false, true).timeout


func ready_to_act() -> void:
	while s.phase != Table3D.Phase.BET:
		await process_frame


func throw_faces(faces: Array[int]) -> void:
	await ready_to_act()
	await wait(0.35)
	s.rig_faces(faces)
	if s.quick_throw():
		await s.sequence_finished


func pot(idx: Array) -> void:
	for i in idx:
		s.pick_die(i)
		await wait(0.18)


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			OUT = a.trim_prefix("--out=").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(OUT)
	s = (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.bonfire_seed = 21
	root.add_child(s)
	await wait(1.0)
	await shot("bonfire_01_hand")
	await throw_faces([4, 4, 4, 5, 2] as Array[int])
	await wait(0.5)
	await shot("bonfire_02_lit")
	await pot([0, 1, 2])
	await wait(0.3)
	await shot("bonfire_03_potted_trips")
	s.throw_again()
	await throw_faces([5, 5] as Array[int])
	await pot([0, 1])
	s.throw_again()
	await throw_faces([3, 3, 6, 6, 1] as Array[int])
	await pot([0, 1, 2, 3])
	await wait(0.3)
	await shot("bonfire_04_hot_hand_two_pair")
	s.bank()
	await wait(1.6)
	await shot("bonfire_05_banked_bounties")
	print("done")
	quit()
