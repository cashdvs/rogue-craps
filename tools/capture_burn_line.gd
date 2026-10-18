## Burn Line sandbox screenshots / movie (needs a display and Vulkan; lavapipe
## under xvfb works). Writes PNGs to --out=<folder> (default user://captures_burn/):
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver vulkan \
##       --resolution 1920x1080 --script res://tools/capture_burn_line.gd -- --out=/tmp/burn/
## Add --fixed-fps 30 --write-movie /tmp/burn.avi before --script for a video
## of the same hands (exact, then a burn).
extends SceneTree

var OUT := "user://captures_burn/"
var s: BurnLine3D


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


func throw_slot(slot: int) -> void:
	await ready_to_act()
	s.rig_next_slot(slot)
	if s.quick_throw():
		await s.sequence_finished


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			OUT = a.trim_prefix("--out=").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(OUT)
	s = (load("res://scenes/burn_line.tscn") as PackedScene).instantiate() as BurnLine3D
	s.burn_seed = 11
	root.add_child(s)
	await wait(1.0)
	await shot("burn_01_start")
	await throw_slot(6)
	await throw_slot(5)
	await wait(0.3)
	await shot("burn_02_mid_hand_11")
	s.select_die(1)
	await throw_slot(5)
	await shot("burn_03_on_the_line_14")
	s.select_die(0)
	await throw_slot(1)
	s.stop_hand()
	await wait(0.35)
	await shot("burn_04_exact_stop")
	await ready_to_act()
	await wait(0.3)
	s.set_side_bet(true)
	s.change_bet(1)
	await throw_slot(6)
	await throw_slot(6)
	await ready_to_act()
	s.rig_next_slot(5)
	s.quick_throw()
	await s.hand_result_shown
	await wait(0.12)
	await shot("burn_05_burn_flash")
	await ready_to_act()
	await wait(0.6)
	s.burn_hud._open_picker()
	await wait(0.2)
	await shot("burn_06_change_dice")
	s.burn_hud.picker.visible = false
	await wait(0.3)
	print("done")
	quit()
