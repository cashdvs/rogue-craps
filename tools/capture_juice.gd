## Bonfire juice captures: a normal pot (count-up + flames), a bust (snuff,
## ash, Soul flask crack, pending stamp crumbles), a Hot Hand (ignite, banner,
## fly back), and a big banked pot (pillar, slow-mo, embers, CLAIMED stamps).
## Stills go to --out; record the same run as a movie with --write-movie.
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver vulkan \\
##       --resolution 1280x720 --fixed-fps 30 --write-movie /tmp/juice.avi \\
##       --script res://tools/capture_juice.gd -- --out=/tmp/juice/
extends SceneTree

var OUT := "user://captures_juice/"


func _initialize() -> void:
	_run.call_deferred()


func shot(name: String) -> void:
	await process_frame
	root.get_texture().get_image().save_png(OUT + name + ".png")
	print("saved ", OUT + name + ".png")


func wait(t: float) -> void:
	await create_timer(t, true, false, true).timeout


func throw_faces(s: Bonfire3D, f: Array[int]) -> void:
	s.rig_faces(f)
	s.quick_throw()
	await s.throw_resolved


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			OUT = a.trim_prefix("--out=").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(OUT)
	var t := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = TableSetup.sandbox(t, 5)
	s.tutorial_override = 0
	root.add_child(s)
	await wait(0.8)
	await shot("juice_00_table")
	# Normal pot: Trips 4-4-4 = 126 (flames).
	await throw_faces(s, [4, 4, 4, 5, 2] as Array[int])
	await s.sequence_finished
	await wait(0.3)
	await shot("juice_01_lit_cards_pulse")
	s.pick_die(0); s.pick_die(1); s.pick_die(2)
	await wait(0.3)
	s.throw_again()
	await wait(0.18)
	await shot("juice_02_normal_pips")
	await wait(0.32)
	await shot("juice_03_normal_count")
	await s.bhud.countup.banner
	await wait(0.05)
	await shot("juice_04_normal_banner_flames")
	await wait(0.8)
	# Bust: the 2 cold dice land 2-6.
	await throw_faces(s, [2, 6] as Array[int])
	await wait(0.2)
	await shot("juice_05_bust_ash")
	await wait(0.3)
	await shot("juice_06_bust_flask_crack")
	await s.sequence_finished
	await wait(0.5)
	# Hot Hand: Full House of all 5.
	await throw_faces(s, [3, 3, 3, 5, 5] as Array[int])
	await s.sequence_finished
	await wait(0.3)
	for i in 5:
		s.pick_die(i)
	await wait(0.3)
	s.throw_again()
	await s.bhud.countup.banner
	await wait(0.05)
	await shot("juice_07_hot_full_house_banner")
	await s.bhud.countup.finished
	await wait(0.12)
	await shot("juice_08_hot_hand_ignite")
	await wait(0.3)
	await shot("juice_09_hot_hand_fly_back")
	await wait(0.8)
	# Big pot, banked: five 6s at Hot Hand mult (pillar, slow-mo, roar).
	await throw_faces(s, [6, 6, 6, 6, 6] as Array[int])
	await s.sequence_finished
	await wait(0.3)
	for i in 5:
		s.pick_die(i)
	await wait(0.3)
	s.bank()
	await wait(0.35)
	await shot("juice_10_big_pips")
	await s.bhud.countup.banner
	await wait(0.08)
	await shot("juice_11_big_pillar_banner")
	await s.bhud.countup.finished
	await wait(0.25)
	await shot("juice_12_bank_embers_stamp")
	await wait(0.8)
	await shot("juice_13_bank_claimed")
	await wait(1.0)
	s.queue_free()
	await wait(0.2)
	quit()
