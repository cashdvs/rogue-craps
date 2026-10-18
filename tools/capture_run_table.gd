## Run-table screenshots: a 7-die TableSetup with face mods (Hellfire, Wild,
## Twin, Blank) face up, then the run-mode pause menu (Forfeit table) and the
## forfeit end panel (CONTINUE). Same display needs as capture_bonfire.gd:
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver vulkan \\
##       --resolution 1920x1080 --script res://tools/capture_run_table.gd -- --out=/tmp/run_table/
extends SceneTree

var OUT := "user://captures_run_table/"
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


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			OUT = a.trim_prefix("--out=").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(OUT)
	var lib: Array = []
	for id in ["hellfire", "wild", "twin", "blank"]:
		lib.append(load("res://resources/mods/%s.tres" % id))
	var st := TableSetup.new()
	st.dice.append(TableDie.from_mod_ids([&"", &"", &"", &"hellfire", &"", &""], lib))
	st.dice.append(TableDie.from_mod_ids([&"", &"", &"", &"", &"", &"wild"], lib))
	st.dice.append(TableDie.from_mod_ids([&"", &"", &"", &"twin", &"", &""], lib))
	st.dice.append(TableDie.from_mod_ids([&"", &"blank", &"", &"", &"", &""], lib))
	for i in 3:
		st.dice.append(TableDie.new())
	st.goal = (load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning).table_goal
	st.starting_soul = 24
	st.max_soul = 35
	st.table_seed = 8
	s = (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = st
	root.add_child(s)
	await wait(1.0)
	await shot("run_01_hand_7_dice")
	while s.phase != Table3D.Phase.BET:
		await process_frame
	await wait(0.3)
	s.rig_slots([4, 6, 4, 2, 4, 2, 5] as Array[int])
	if s.quick_throw():
		await s.sequence_finished
	await wait(0.5)
	await shot("run_02_mods_lit")
	for i in [0, 1, 2, 4]:
		s.pick_die(i)
		await wait(0.18)
	await wait(0.3)
	await shot("run_03_potted_mods")
	s.pause_menu.open()
	await shot("run_04_pause_forfeit")
	s.pause_menu.ask_forfeit()
	await shot("run_05_forfeit_confirm")
	s.pause_menu.confirm_forfeit()
	await wait(0.6)
	await shot("run_06_forfeit_end")
	quit()
