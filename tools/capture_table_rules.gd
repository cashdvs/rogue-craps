## Table-rules screenshots: a boss table (Madame Shuffle + The Pit Boss) and
## an Elite twist with special dice; the HUD rules panel and the felt lock.
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver vulkan \\
##       --resolution 1920x1080 --script res://tools/capture_table_rules.gd -- --out=/tmp/table_rules/
extends SceneTree

var OUT := "user://captures_table_rules/"


func _initialize() -> void:
	_run.call_deferred()


func shot(name: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(OUT + name + ".png")
	print("saved ", OUT + name + ".png")


func wait(t: float) -> void:
	await create_timer(t, true, false, true).timeout


func table(st: TableSetup) -> Bonfire3D:
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = st
	root.add_child(s)
	await wait(0.6)
	return s


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			OUT = a.trim_prefix("--out=").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(OUT)
	var tuning := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var st := TableSetup.sandbox(tuning, 5)
	st.run_mode = true
	st.table_seed = 11
	st.rules = [{"id": &"madame_shuffle", "params": {}}, {"id": &"pit_boss", "params": {}}]
	var s := await table(st)
	await shot("rules_01_boss_hud")
	s.rig_faces([1, 2, 3, 4, 6] as Array[int])
	s.quick_throw()
	await s.throw_resolved
	await wait(0.05)
	await shot("rules_02_madame_flip")
	await wait(0.4)
	await shot("rules_03_after_flip")
	s.queue_free()
	await wait(0.2)
	st = TableSetup.sandbox(tuning, 5)
	st.run_mode = true
	st.table_seed = 4
	st.dice[0].special = &"mirror"
	st.dice[1].special = &"cracked"
	st.rules = [{"id": &"cold_sixes", "params": {"face": 6}}, {"id": &"greedy_pot", "params": {"min_pot": 2}}]
	s = await table(st)
	await shot("rules_04_twists_specials_hud")
	quit()
