## Renders 3D table screenshots (needs a display and Vulkan; lavapipe under
## xvfb works):
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver vulkan \
##       --resolution 1920x1080 --script res://tools/capture_table_3d.gd -- --out=/some/folder/
## Output goes to `--out=<folder>` (default user://captures_3d/, inside
## Godot's user data folder). Pass `idle` after `--` to only render the idle
## shot (quick look-dev).
extends SceneTree

var OUT := "user://captures_3d/"
var scene: Table3D


func _initialize() -> void:
	_run.call_deferred()


func shot(name: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	img.save_png(OUT + name + ".png")
	print("saved ", OUT + name + ".png")


func wait(s: float) -> void:
	await create_timer(s, true, false, true).timeout


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			OUT = a.trim_prefix("--out=").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(OUT)
	scene = (load("res://scenes/table_3d.tscn") as PackedScene).instantiate() as Table3D
	scene.rng_seed = 31
	root.add_child(scene)
	await wait(0.8)
	scene.place()
	await wait(0.12)
	scene.place()
	await wait(0.6)
	await shot("3d_01_idle_bets")
	if "idle" in OS.get_cmdline_user_args():
		quit()
		return

	# Held dice, dragged up-left over the felt.
	var hand := scene.camera.cam.unproject_position(Table3D.HAND)
	scene.phase = Table3D.Phase.HELD
	scene.gesture.press(hand, 0.0)
	var held_at := hand + Vector2(-140, -60)
	scene.hold_point_override = held_at
	await wait(0.4)
	await shot("3d_02_grab")
	scene.phase = Table3D.Phase.BET
	scene.hold_point_override = Vector2.INF

	# Natural: mid-throw, then the reveal flash.
	scene.rig_next_roll(5, 6)
	scene.throw(Vector2(-1500, -2400), held_at)
	# Wait until the recorded throw is playing, then a little into it.
	while scene._play_t < 0.3:
		await process_frame
	await shot("3d_03_mid_throw")
	await scene.dice_landed
	await wait(0.3)
	await shot("3d_04_settle_reveal")
	await scene.outcome_shown
	await wait(0.12)
	await shot("3d_05_natural")
	await scene.sequence_finished
	await wait(0.3)

	# Point set (4), then seven-out with Soul burn.
	scene.place()
	scene.place()
	scene.place()
	await wait(0.4)
	scene.rig_next_roll(1, 3)
	scene.quick_throw()
	await scene.outcome_shown
	await wait(0.45)
	await shot("3d_06_point_set")
	await scene.sequence_finished
	await wait(0.3)
	scene.rig_next_roll(3, 4)
	scene.quick_throw()
	await scene.outcome_shown
	await wait(0.3)
	await shot("3d_07_seven_out")
	await wait(0.4)
	await shot("3d_08_soul_burn")
	await scene.sequence_finished
	await wait(0.3)
	scene.set_reduced_motion(true)
	await wait(0.3)
	await shot("3d_09_reduced_motion")
	quit()
