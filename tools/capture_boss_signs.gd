## Floor 3 boss sign screenshots for Art Director: the boss intro with Baron
## Vig and with Odds Bodkin, the table HUD in a Vig fight with the rule
## tooltip open, the table pause menu, and the HUD in a Bodkin fight. Needs a real renderer:
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver vulkan \\
##       --resolution 1920x1080 --script res://tools/capture_boss_signs.gd -- --out=/tmp/signs/
extends SceneTree

const S := MapRun.Screen
const NT := MapGenData.NodeType
var OUT := "user://captures_boss_signs/"
var scene: RunScreen


func _initialize() -> void:
	_run.call_deferred()


func shot(name: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(OUT + name + ".png")
	print("saved ", OUT + name + ".png")


func wait(t: float) -> void:
	await create_timer(t, true, false, true).timeout


func boss_table(file: String) -> void:
	var run := scene.run
	run.boss = load("res://resources/map/rules/%s.tres" % file) as RunRuleData
	run.boss_twist = null
	run.table_type = NT.BOSS
	run.goal = run.make_goal(NT.BOSS)
	run._set_screen(S.TABLE)


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			OUT = a.trim_prefix("--out=").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(OUT)
	scene = (load("res://scenes/run.tscn") as PackedScene).instantiate()
	scene.run_seed = 5
	root.add_child(scene)
	await wait(0.5)
	scene.run._start_floor(2)
	boss_table("baron_vig")
	await wait(0.3)
	await shot("a_intro_baron_vig")
	boss_table("odds_bodkin")
	await wait(0.3)
	await shot("b_intro_odds_bodkin")
	boss_table("baron_vig")
	scene._play_table()
	await wait(1.5)
	await hover(scene._table.bhud.rules_box.get_child(0) as Control)
	await shot("c_hud_baron_vig_tooltip")
	scene._table.pause_menu.open()
	await shot("d_pause_baron_vig")
	scene._table.pause_menu.close()
	scene._table.queue_free()
	scene._table = null
	boss_table("odds_bodkin")
	scene._play_table()
	await wait(1.5)
	await hover(scene._table.bhud.rules_box.get_child(0) as Control)
	await shot("e_hud_odds_bodkin_tooltip")
	quit()


func hover(row: Control) -> void:
	var at := row.get_global_rect().get_center()
	for i in 6:
		var mm := InputEventMouseMotion.new()
		mm.position = at + Vector2(i, 0)
		mm.global_position = mm.position
		root.push_input(mm)
		await process_frame
	await wait(1.2)
